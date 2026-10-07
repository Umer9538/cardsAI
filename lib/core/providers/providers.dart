// mergeSort, because List.sort is not stable: every catalogue plan has a null
// createdAt and therefore compares equal, so an unstable sort would reshuffle
// them on each rebuild.
import 'package:collection/collection.dart';
// `show debugPrint`: foundation also exports mergeSort, which collides with
// the collection import above that the plan sorting relies on.
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/firebase_auth_repository.dart';
import '../../data/firebase/firestore_food_repository.dart';
import '../../data/firebase/firestore_repositories.dart';
import '../../data/firebase/firestore_subscription_repository.dart';
import '../../data/firebase/functions_scan_repository.dart';
import '../../data/firebase/storage_photo_repository.dart';
import '../../data/food/open_food_facts_repository.dart';
import '../../data/local/json_store.dart';
import '../../data/worker/worker_planner_repository.dart';
import '../../data/local/local_planner_repository.dart';
import '../../data/local/local_activity_repository.dart';
import '../../data/local/local_water_repository.dart';
import '../../data/local/local_weight_repository.dart';
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
import '../notifications/meal_reminders.dart';
import '../nutrition/plan_purpose.dart';
import '../nutrition/recent_foods.dart';
import '../notifications/activity_feed.dart';
import '../notifications/device_time_zone.dart';
import '../notifications/meal_clock.dart';
import '../notifications/notification_category.dart';
import '../notifications/reminder_schedule.dart';
import '../notifications/reminder_service.dart';
import '../nutrition/target_calculator.dart';
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

final firebaseAuthProvider = Provider<fb.FirebaseAuth>(
  (ref) => fb.FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

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

final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

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

/// Writes a one-day plan from the user's own targets.
///
/// On Firebase it goes to the Worker and the same model the scan pipeline
/// uses; on local it composes one from the catalogue, so the flow stays
/// walkable with no network.
final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return WorkerPlannerRepository(ref.watch(functionsProvider));
  }
  return LocalPlannerRepository(
    ref.watch(dietRepositoryProvider),
    () => ref.read(targetsProvider),
    purpose: () => ref.read(planPurposeProvider)?.label,
  );
});

/// What a plan built now would be for — see [PlanPurpose]. Null until the
/// profile carries a goal. On Firebase the Worker makes the same reading of
/// the same profile and returns it; this is what the local planner and the
/// quiz's build step show in its place.
final planPurposeProvider = Provider<PlanPurpose?>(
  (ref) => PlanPurpose.of(ref.watch(profileProvider).value),
);

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreWeightRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalWeightRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// The weight log, oldest first.
final weightHistoryProvider = StreamProvider<WeightHistory>(
  (ref) => ref.watch(weightRepositoryProvider).watch(),
);

final waterRepositoryProvider = Provider<WaterRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreWaterRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalWaterRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

/// How much water a day should hold, for this person.
///
/// Scaled from bodyweight when the profile has one, because 35 ml/kg tracks
/// how intake actually differs between a 50 kg and a 100 kg person far better
/// than one number for everyone. Falls back to the familiar eight glasses.
final waterTargetProvider = Provider<double>((ref) {
  final profile = ref.watch(profileProvider).value;
  return WaterTargets.fromWeight(profile?.weightKg);
});

/// Today's drinks and what they add up to.
final waterLogProvider = Provider<WaterLog>((ref) {
  final day = ref.watch(selectedDateProvider);
  return WaterLog(
    entries: ref.watch(waterDayProvider(day)).value ?? const [],
    targetMl: ref.watch(waterTargetProvider),
  );
});

/// True when the day's stream is erroring rather than merely empty.
///
/// See [_reportingErrors]. The card needs this because `.value ?? const []`
/// cannot tell "nothing logged" from "the read was refused", and those want
/// opposite things said to the person holding the phone.
final waterFailedProvider = Provider<bool>((ref) {
  final day = ref.watch(selectedDateProvider);
  return ref.watch(waterDayProvider(day)).hasError;
});

final waterDayProvider = StreamProvider.family<List<WaterEntry>, DateTime>((
  ref,
  day,
) {
  return _reportingErrors(
    'water',
    ref.watch(waterRepositoryProvider).watchDay(day),
  );
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  if (ref.watch(backendProvider) == AppBackend.firebase) {
    return FirestoreActivityRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
    );
  }
  final repository = LocalActivityRepository(ref.watch(jsonStoreProvider));
  ref.onDispose(repository.dispose);
  return repository;
});

final activityDayProvider =
    StreamProvider.family<List<ActivityEntry>, DateTime>((ref, day) {
      return _reportingErrors(
        'activity',
        ref.watch(activityRepositoryProvider).watchDay(day),
      );
    });

/// Today's exercise and what it adds up to.
final activityLogProvider = Provider<ActivityLog>((ref) {
  final day = ref.watch(selectedDateProvider);
  return ActivityLog(
    entries: ref.watch(activityDayProvider(day)).value ?? const [],
  );
});

/// True when the day's stream is erroring rather than merely empty.
final activityFailedProvider = Provider<bool>((ref) {
  final day = ref.watch(selectedDateProvider);
  return ref.watch(activityDayProvider(day)).hasError;
});

/// Logs a stream's errors on the way past, and rethrows them.
///
/// Every consumer of these day streams reads `.value ?? const []`, so a failed
/// read renders as an empty day — indistinguishable from a day with nothing in
/// it, for ever, with nothing in the console either. That is exactly how a
/// missing `firestore.rules` deployment on `users/{uid}/water` and
/// `users/{uid}/activity` presented: the offline cache accepted each write and
/// served it straight back, the listener was refused by the server, and the
/// card calmly said "Nothing logged today" after a save that looked fine.
///
/// It took three separate bug reports to find. The rethrow is the point — this
/// only adds a trace and a flag, it does not swallow anything.
Stream<T> _reportingErrors<T>(String what, Stream<T> source) =>
    source.handleError((Object error, StackTrace stack) {
      debugPrint('[$what] day stream failed: $error');
      Error.throwWithStackTrace(error, stack);
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
  if (ref.watch(backendProvider) != AppBackend.firebase) return openFoodFacts;

  // Three layers, cheapest and most reliable first:
  //
  //   Firestore mirror   ~100-200ms, offline-capable, cannot be broken by FDC
  //   Worker -> USDA     live, 1-5s, drops one call in twelve
  //   Open Food Facts    keyless, and where barcode goes regardless
  //
  // Each falls through to the next only when it has nothing to offer, so a
  // search always answers with something.
  return FirestoreFoodRepository(
    ref.watch(firestoreProvider),
    WorkerFoodRepository(ref.watch(functionsProvider), openFoodFacts),
  );
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
/// Metric or imperial, defaulting from the device locale.
///
/// Display only — see [UnitSystem]. Everything stored and every calculation
/// stays metric.
class UnitSystemController extends Notifier<UnitSystem> {
  @override
  UnitSystem build() => UnitSystem.fromName(
    ref.watch(jsonStoreProvider).readString(StoreKeys.units),
  );

  void set(UnitSystem system) {
    state = system;
    ref.read(jsonStoreProvider).writeString(StoreKeys.units, system.name);
  }

  void toggle() =>
      set(state.isMetric ? UnitSystem.imperial : UnitSystem.metric);
}

final unitSystemProvider = NotifierProvider<UnitSystemController, UnitSystem>(
  UnitSystemController.new,
);

final targetsProvider = Provider<Nutrition>((ref) {
  final stored =
      ref.watch(profileProvider).value?.targets ?? UserProfile.defaultTargets;

  // Fibre is derived on read when it is missing, rather than being left at
  // whatever was stored.
  //
  // Targets are persisted on the profile, so every account created before the
  // fibre goal existed carries `fiber: 0` — and showed "Fibre 0g" on Home with
  // no goal beside it, forever. A figure the app knows how to compute should
  // not be permanently absent because of when the account was made.
  if (stored.fiber > 0 || stored.calories <= 0) return stored;
  return stored.copyWith(
    fiber: (stored.calories / 1000 * TargetCalculator.fibrePer1000Kcal)
        .roundToDouble(),
  );
});

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

  /// Selects [date], or today when [date] is in the future.
  ///
  /// The clamp is here rather than only at the week strip because the diary
  /// has no forward direction at all: a future day can hold nothing, so every
  /// figure keyed off it — the ring, the macro cards, the meal list — would be
  /// a real reading of an empty day rather than a day with nothing in it yet.
  /// One caller already got this wrong.
  void select(DateTime date) {
    final today = _midnight(DateTime.now());
    final at = _midnight(date);
    state = at.isAfter(today) ? today : at;
  }

  void today() => state = _midnight(DateTime.now());

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
}

final selectedDateProvider = NotifierProvider<SelectedDate, DateTime>(
  SelectedDate.new,
);

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

/// The foods this person logs most, for the search screen's opening state.
///
/// Recomputed whenever today's diary changes, so a food logged a minute ago is
/// at the top of the list the next time the screen opens.
final recentFoodsProvider = FutureProvider<List<FrequentFood>>((ref) async {
  ref.watch(dayMealsProvider(SelectedDate._midnight(DateTime.now())));
  final now = DateTime.now();
  final meals = await ref
      .watch(diaryRepositoryProvider)
      .mealsBetween(now.subtract(RecentFoods.window), now);
  return RecentFoods.from(meals, now: now);
});

final streakProvider = FutureProvider<int>((ref) {
  // Recompute whenever any day's meals change.
  ref.watch(dayMealsProvider(SelectedDate._midnight(DateTime.now())));
  return ref.watch(diaryRepositoryProvider).currentStreak();
});

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

/// Every plan, put in the user's own terms.
///
/// The scaling happens here rather than in each screen so there is exactly one
/// path from the repository to a rendered plan, and no way to draw an unscaled
/// one by forgetting. See [DietPlan.scaledTo] for why a raw catalogue figure
/// beside a personal target makes both numbers look invented.
List<DietPlan> _inUserTerms(Ref ref, List<DietPlan> plans) {
  final targets = ref.watch(targetsProvider);
  final scaled = [for (final plan in plans) plan.scaledTo(targets)];

  // Newest generated plan first, catalogue after, each group otherwise left in
  // the order the repository gave.
  //
  // It is sorted here for the same reason it is scaled here: one path from the
  // repository to a rendered plan. The backends disagreed about order and
  // Firestore's was simply arbitrary — `plans` streamed with no `orderBy`, so
  // documents came back by id and `plan-mine-<uuid4>` interleaved with the
  // catalogue's fixed ids. Sorting on the client rather than in the query also
  // means no composite index and no migration: a plan stored before
  // `createdAt` existed sorts with the catalogue instead of vanishing.
  final order = List<DietPlan>.from(scaled);
  mergeSort(
    order,
    compare: (a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    },
  );
  return order;
}

final allDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref
      .watch(dietRepositoryProvider)
      .watchAll()
      .map((plans) => _inUserTerms(ref, plans)),
);

final myDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref
      .watch(dietRepositoryProvider)
      .watchMine()
      .map((plans) => _inUserTerms(ref, plans)),
);

final favoriteDietsProvider = StreamProvider<List<DietPlan>>(
  (ref) => ref
      .watch(dietRepositoryProvider)
      .watchFavorites()
      .map((plans) => _inUserTerms(ref, plans)),
);

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).watch(),
);

/// Recomputes the in-app feed from the diary and posts anything new.
///
/// The feed used to be seven fixed strings from the artboard. `ActivityFeed`
/// derives it from what the person actually did, and this is the seam between
/// that pure function and storage: it reads the state the function needs,
/// hands the result to [NotificationRepository.upsertAll], and lets the
/// stable ids do the de-duplication.
///
/// Read `.value` to trigger it; it returns the number of entries posted so a
/// test can assert on it.
final feedRefreshProvider = FutureProvider<int>((ref) async {
  final settings = ref.watch(notificationSettingsProvider).value;
  if (settings == null) return 0;

  final today = ref.watch(todayLogProvider);
  final targets = ref.watch(targetsProvider);
  final now = DateTime.now();
  final yesterdayDate = SelectedDate._midnight(
    now.subtract(const Duration(days: 1)),
  );
  final yesterday = DailyLog(
    date: yesterdayDate,
    meals: ref.watch(dayMealsProvider(yesterdayDate)).value ?? const [],
    targets: targets,
  );

  final profile = ref.watch(profileProvider).value;

  final entries = ActivityFeed.build(
    now: now,
    settings: settings,
    today: today,
    yesterday: yesterday,
    streakDays: ref.watch(streakProvider).value ?? 0,
    weight: ref.watch(weightHistoryProvider).value,
    goalWeightKg: profile?.goalWeightKg,
    // A brand-new account has nothing in the diary and no streak; the welcome
    // entry is the only thing the feed can honestly say.
    hasEverLogged:
        today.meals.isNotEmpty || (ref.watch(streakProvider).value ?? 0) > 0,
  );

  final fresh = await ref
      .watch(notificationRepositoryProvider)
      .upsertAll(entries);

  // And out to the lock screen, for the ones that can honestly go there.
  //
  // Only the *newly* derived entries, which is what the stable ids already
  // know: re-posting would be the same notification arriving every time the
  // app opens. And only [NotificationCategory.goalMilestones], because a
  // milestone is a fact rather than a figure — "seven days in a row" is true
  // when it is derived and stays true, while "300 under today" is wrong by the
  // next meal. The daily summary carries no number for that reason, and the
  // meal nudges already have their own scheduled reminders; posting those
  // again would be the same prompt twice.
  final service = ref.watch(reminderServiceProvider);
  for (final entry in fresh) {
    if (entry.category != NotificationCategory.goalMilestones) continue;
    await service.post(
      // Derived from the entry's own id, so Android replaces rather than
      // stacks if the same milestone is ever re-derived.
      id: ActivityFeed.notificationId(entry.id),
      title: 'Carbs AI',
      body: entry.body,
      channel: NotificationChannel.milestones,
    );
  }
  return entries.length;
});

final unreadNotificationCountProvider = Provider<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0,
);

final notificationSettingsProvider = StreamProvider<Map<String, bool>>(
  (ref) => ref.watch(notificationSettingsRepositoryProvider).watch(),
);

/// The local-notification plugin, wrapped.
///
/// A `Provider` rather than a singleton so a test can override it — the real
/// one talks to a platform channel that does not exist under `flutter test`.
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// When this device's country eats, for the bottom rung of the reminder ladder.
///
/// A provider rather than a direct call so a test can pin a country, and so
/// the Settings caption and the scheduler cannot disagree about which one is
/// in play.
/// The taste answers the last generated plan came from, if there are any.
///
/// Read by the plan detail screen's "Something else", which regenerates from
/// them rather than sending someone back through the quiz. Written by the quiz
/// itself on a successful build.
class LastTasteController extends Notifier<TasteProfile?> {
  @override
  TasteProfile? build() {
    final stored = ref.watch(jsonStoreProvider).readMap(StoreKeys.lastTaste);
    if (stored == null) return null;
    // A blob written by another build must not cost someone the button.
    try {
      return TasteProfile.fromJson(stored);
    } catch (_) {
      return null;
    }
  }

  void remember(TasteProfile profile) {
    state = profile;
    ref.read(jsonStoreProvider).writeMap(StoreKeys.lastTaste, profile.toJson());
  }
}

final lastTasteProvider = NotifierProvider<LastTasteController, TasteProfile?>(
  LastTasteController.new,
);

final mealClockProvider = Provider<MealClock>(
  (ref) => MealClock.forDevice(timeZone: DeviceTimeZone.name),
);

final mealRemindersProvider = Provider<MealReminders>(MealReminders.new);

/// The meal-reminder times the person set, and the slots they switched off.
///
/// A [Notifier] over [JsonStore] rather than a repository, for the reason on
/// [StoreKeys.reminderTimes]: a notification schedule belongs to the handset
/// that rings, so there is nothing for the backend seam to switch between.
class ReminderPreferencesController extends Notifier<ReminderPreferences> {
  @override
  ReminderPreferences build() {
    final stored = ref
        .watch(jsonStoreProvider)
        .readMap(StoreKeys.reminderTimes);
    return stored == null
        ? const ReminderPreferences()
        : ReminderPreferences.fromJson(stored);
  }

  /// Moves one meal's reminder, or hands it back to the diary when [minuteOfDay]
  /// is null.
  void setTime(MealSlot slot, int? minuteOfDay) =>
      _write(state.withTime(slot, minuteOfDay));

  void setEnabled(MealSlot slot, {required bool enabled}) =>
      _write(state.withEnabled(slot, enabled: enabled));

  void _write(ReminderPreferences next) {
    state = next;
    ref
        .read(jsonStoreProvider)
        .writeMap(StoreKeys.reminderTimes, next.toJson());
    // The stored times are only half of it — the OS is holding the old ones
    // until something rewrites them, and nothing else on this path will.
    ref.read(mealRemindersProvider).refresh();
  }
}

final reminderPreferencesProvider =
    NotifierProvider<ReminderPreferencesController, ReminderPreferences>(
      ReminderPreferencesController.new,
    );

/// The weekly weigh-in prompt's own settings.
///
/// Separate from [ReminderPreferencesController] because it is a different
/// cadence and a different question, but stored the same way and for the same
/// reason — see [StoreKeys.reminderTimes].
class WeighInPreferenceController extends Notifier<WeighInPreference> {
  @override
  WeighInPreference build() {
    final stored = ref
        .watch(jsonStoreProvider)
        .readMap(StoreKeys.weighInReminder);
    return stored == null
        ? const WeighInPreference()
        : WeighInPreference.fromJson(stored);
  }

  void setEnabled({required bool enabled}) =>
      _write(state.copyWith(enabled: enabled));

  void setWeekday(int weekday) => _write(state.copyWith(weekday: weekday));

  void setTime(int minuteOfDay) =>
      _write(state.copyWith(minuteOfDay: minuteOfDay));

  void _write(WeighInPreference next) {
    state = next;
    ref
        .read(jsonStoreProvider)
        .writeMap(StoreKeys.weighInReminder, next.toJson());
    // The OS is holding the old schedule until something rewrites it.
    ref.read(mealRemindersProvider).refresh();
  }
}

final weighInPreferenceProvider =
    NotifierProvider<WeighInPreferenceController, WeighInPreference>(
      WeighInPreferenceController.new,
    );

/// The water nudges' switch and how many a day.
///
/// Stored beside the others and for the same reason — see
/// [StoreKeys.reminderTimes].
class WaterPreferenceController extends Notifier<WaterPreference> {
  @override
  WaterPreference build() {
    final stored = ref
        .watch(jsonStoreProvider)
        .readMap(StoreKeys.waterReminder);
    return stored == null
        ? const WaterPreference()
        : WaterPreference.fromJson(stored);
  }

  void setEnabled({required bool enabled}) =>
      _write(state.copyWith(enabled: enabled));

  void setCount(int count) =>
      _write(state.copyWith(count: count.clamp(1, WaterSchedule.maxPerDay)));

  void _write(WaterPreference next) {
    state = next;
    ref
        .read(jsonStoreProvider)
        .writeMap(StoreKeys.waterReminder, next.toJson());
    // The OS is holding the old schedule until something rewrites it.
    ref.read(mealRemindersProvider).refresh();
  }
}

final waterPreferenceProvider =
    NotifierProvider<WaterPreferenceController, WaterPreference>(
      WaterPreferenceController.new,
    );

/// Every slot's reminder time as the scheduler would compute it.
///
/// What Settings renders, so the row and the notification cannot disagree
/// about when it will fire or where the time came from.
///
/// Slots the person switched off are computed too — [ReminderSchedule.from]
/// drops them, and a row showing no time gives no way to check one before
/// turning it back on.
final reminderPreviewProvider = FutureProvider<Map<MealSlot, MealReminder>>((
  ref,
) async {
  // Recompute when today's diary changes: logging breakfast is what moves the
  // median, and it is the moment someone is most likely to be looking.
  ref.watch(dayMealsProvider(SelectedDate._midnight(DateTime.now())));
  final preferences = ref.watch(reminderPreferencesProvider);

  final now = DateTime.now();
  final meals = await ref
      .watch(diaryRepositoryProvider)
      .mealsBetween(
        now.subtract(const Duration(days: ReminderSchedule.window)),
        now,
      );

  return {
    for (final reminder in ReminderSchedule.from(
      meals,
      preferences: ReminderPreferences(times: preferences.times),
      clock: ref.watch(mealClockProvider),
      now: now,
    ))
      reminder.slot: reminder,
  };
});
