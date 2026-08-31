import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/firebase_auth_repository.dart';
import '../../data/firebase/firestore_repositories.dart';
import '../../data/firebase/firestore_subscription_repository.dart';
import '../../data/firebase/functions_scan_repository.dart';
import '../../data/firebase/storage_photo_repository.dart';
import '../../data/food/open_food_facts_repository.dart';
import '../../data/local/json_store.dart';
import '../../data/local/local_auth_repository.dart';
import '../../data/local/local_diary_repository.dart';
import '../../data/local/local_diet_repository.dart';
import '../../data/local/local_notification_repository.dart';
import '../../data/local/local_profile_repository.dart';
import '../../data/local/local_scan_repository.dart';
import '../../data/local/local_subscription_repository.dart';
import '../../data/store/store_subscription_repository.dart';
import '../../data/worker/r2_photo_repository.dart';
import '../../data/worker/worker_food_repository.dart';
import '../app_config.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// The key-value store every local repository writes through.
///
/// Opening it is async, so it is resolved in `main()` and injected as an
/// override. Reading it without that override is a programming error, not a
/// runtime condition — hence the throw rather than a null.
final jsonStoreProvider = Provider<JsonStore>(
  (ref) => throw StateError(
    'jsonStoreProvider must be overridden in main() with an opened JsonStore.',
  ),
);

// ---------------------------------------------------------------------------
// Backend selection
// ---------------------------------------------------------------------------

/// Which implementations the repository providers below resolve to.
///
/// Defaults to [AppConfig.backend], and is overridden in `main()` to
/// [AppBackend.local] when Firebase fails to start — a missing config file or
/// no network on first launch should degrade to a working offline app, not a
/// crash on the splash screen.
final backendProvider = Provider<AppBackend>((ref) => AppConfig.backend);

final firebaseAuthProvider =
    Provider<fb.FirebaseAuth>((ref) => fb.FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Kept even though the backend now lives on Cloudflare Workers.
///
/// Every call goes through `workerCallable`, which uses
/// `httpsCallableFromUri` — so the region below is irrelevant, but the SDK is
/// still what attaches the Firebase ID token and turns a callable error body
/// back into a `FirebaseFunctionsException`. Those two behaviours are why the
/// dependency survived the port.
final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: 'us-central1'),
);

final storageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// ---------------------------------------------------------------------------
// Repositories
//
// Every one of these is a seam: the screens above only ever see the interface,
// so switching backend swaps the implementation and touches nothing else.
// ---------------------------------------------------------------------------

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreProfileRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalProfileRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirebaseAuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
      ref.watch(functionsProvider),
      ref.watch(profileRepositoryProvider),
    );
  }
  final repository = LocalAuthRepository(
    ref.watch(jsonStoreProvider),
    ref.watch(profileRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreDiaryRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalDiaryRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final dietRepositoryProvider = Provider<DietRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreDietRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalDietRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// The real pipeline on Firebase, the stub on local.
///
/// The Firebase path calls `analyzeMeal` on the Cloudflare Worker, so it needs
/// `--dart-define=WORKER_URL=...` and a deployed Worker. It does NOT need the
/// Blaze plan — moving the server leg off Cloud Functions is precisely what
/// removed that requirement, since Spark blocks outbound calls to any
/// non-Google host and OpenAI is one. Run with `--dart-define=BACKEND=local`
/// to exercise the flow against the stub instead.
final scanRepositoryProvider = Provider<ScanRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FunctionsScanRepository(
      ref.watch(functionsProvider),
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  return LocalScanRepository(ref.watch(jsonStoreProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreNotificationRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  return LocalNotificationRepository(ref.watch(jsonStoreProvider));
});

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreNotificationSettingsRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  return LocalNotificationSettingsRepository(ref.watch(jsonStoreProvider));
});

/// Food search and barcode lookup.
///
/// Two databases, because they answer different questions. Search goes to USDA
/// FoodData Central through the Worker — it holds the reference foods, and it
/// is what the scan prompt already tells the model to match against, so a
/// searched food and an estimated one agree. Barcode stays on Open Food Facts,
/// which is stronger for packaged goods and needs no key, so it remains a
/// direct client call.
///
/// On the local backend there is no Worker, so Open Food Facts serves both —
/// which keeps the whole app runnable offline with nothing configured.
final foodDatabaseProvider = Provider<FoodDatabaseRepository>((ref) {
  final openFoodFacts = OpenFoodFactsRepository();
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return WorkerFoodRepository(ref.watch(functionsProvider), openFoodFacts);
  }
  return openFoodFacts;
});

/// Meal photos go to Cloudflare R2 through the Worker, not Cloud Storage.
///
/// R2 charges nothing for egress, which is the part of an image-heavy app that
/// eventually costs real money. [StoragePhotoRepository] is still in the tree
/// and still satisfies this contract, so switching back is one line.
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return R2PhotoRepository(ref.watch(firebaseAuthProvider));
  }
  return const LocalPhotoRepository();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    final entitlement = FirestoreSubscriptionRepository(
      ref.watch(firestoreProvider),
      ref.watch(functionsProvider),
      ref.watch(firebaseAuthProvider),
    );
    final repository = StoreBackedSubscriptionRepository(
      entitlement: entitlement,
      store: StoreSubscriptionRepository(
        ref.watch(functionsProvider),
        entitlement.current,
      ),
    );
    ref.onDispose(repository.dispose);
    // Product details arrive asynchronously; the chooser falls back to our
    // own prices until they do.
    repository.loadProducts();
    return repository;
  }
  final repository = LocalSubscriptionRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

/// Who is signed in. Null once resolved means signed out; the loading state
/// means the stored session has not been read back yet.
final authStateProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in person's profile, falling back to the session copy so the
/// name and avatar are present on the very first frame after sign-in.
final profileProvider = StreamProvider<UserProfile?>((ref) async* {
  yield ref.watch(authStateProvider).value;
  yield* ref.watch(profileRepositoryProvider).watch();
});

/// Daily goals, with a sensible default before a profile exists — no screen
/// should have to handle "targets unknown".
final targetsProvider = Provider<Nutrition>(
  (ref) =>
      ref.watch(profileProvider).value?.targets ??
      UserProfile.defaultTargets,
);

/// The account's entitlement.
final subscriptionProvider = StreamProvider<Subscription>(
  (ref) => ref.watch(subscriptionRepositoryProvider).watch(),
);

/// The one flag the UI gates on. Defaults to false while the entitlement is
/// still loading — showing premium content and then taking it away is worse
/// than a beat of nothing.
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).value?.isActive ?? false,
);

// ---------------------------------------------------------------------------
// Diary
// ---------------------------------------------------------------------------

/// The day the diary is showing. Always local midnight — the meal streams are
/// keyed on this, and an unnormalised value would spawn a new family entry per
/// millisecond.
class SelectedDate extends Notifier<DateTime> {
  @override
  DateTime build() => _midnight(DateTime.now());

  void select(DateTime date) => state = _midnight(date);

  void today() => state = _midnight(DateTime.now());

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}

final selectedDateProvider =
    NotifierProvider<SelectedDate, DateTime>(SelectedDate.new);

final dayMealsProvider = StreamProvider.family<List<Meal>, DateTime>(
  (ref, date) => ref.watch(diaryRepositoryProvider).watchDay(date),
);

/// The selected day as a whole: its meals and the goals they count against.
///
/// Synchronous by design. It starts as an empty day and fills in when the
/// meals arrive, so Home never has to render a spinner over its own layout.
final dailyLogProvider = Provider<DailyLog>((ref) {
  final date = ref.watch(selectedDateProvider);
  return DailyLog(
    date: date,
    meals: ref.watch(dayMealsProvider(date)).value ?? const [],
    targets: ref.watch(targetsProvider),
  );
});

/// Today specifically, regardless of which day the diary is showing.
final todayLogProvider = Provider<DailyLog>((ref) {
  final today = SelectedDate._midnight(DateTime.now());
  return DailyLog(
    date: today,
    meals: ref.watch(dayMealsProvider(today)).value ?? const [],
    targets: ref.watch(targetsProvider),
  );
});

final streakProvider = FutureProvider<int>((ref) {
  // Recompute whenever any day's meals change.
  ref.watch(dayMealsProvider(SelectedDate._midnight(DateTime.now())));
  return ref.watch(diaryRepositoryProvider).currentStreak();
});

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

final allDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref.watch(dietRepositoryProvider).watchAll(),
);

final myDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref.watch(dietRepositoryProvider).watchMine(),
);

final favoriteDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref.watch(dietRepositoryProvider).watchFavorites(),
);

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).watch(),
);

final unreadNotificationCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(notificationsProvider)
          .value
          ?.where((n) => !n.read)
          .length ??
      0,
);

final notificationSettingsProvider = StreamProvider<Map<String, bool>>(
  (ref) => ref.watch(notificationSettingsRepositoryProvider).watch(),
);
