/// Repository contracts for the whole app.
///
/// The presentation layer only ever sees these. Today every one of them is
/// backed by an on-device implementation in `lib/data/local/`; swapping in
/// Firebase means adding a second implementation and changing one provider
/// override, with no screen touched.
library;

import '../models/models.dart';

/// Signals a failure the UI is expected to show. Anything else is a bug and
/// should surface as a crash in debug.
class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'RepositoryException($code): $message';
}

/// Who is signed in.
abstract interface class AuthRepository {
  /// Emits the current user, or null when signed out. Emits immediately on
  /// listen so the app can decide its first screen without a race.
  Stream<UserProfile?> authStateChanges();

  UserProfile? get currentUser;

  Future<UserProfile> signIn({
    required String email,
    required String password,
  });

  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<UserProfile> signInWithGoogle();

  Future<UserProfile> signInWithApple();

  /// Starts the reset flow. Succeeds whether or not the address exists — not
  /// revealing which is deliberate.
  Future<void> sendPasswordReset(String email);

  /// Sends a fresh verification code to the signed-in account's email.
  ///
  /// Called on entering the verification screen and behind "Resend code". The
  /// server throttles it, so calling twice in quick succession fails rather
  /// than sending twice.
  Future<void> sendEmailOtp();

  /// Checks a code from [sendEmailOtp] and marks the email verified.
  Future<void> verifyCode(String code);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  /// Removes the account and everything attached to it.
  Future<void> deleteAccount();
}

/// The signed-in person's details and goals.
abstract interface class ProfileRepository {
  Stream<UserProfile?> watch();
  Future<UserProfile?> load();
  Future<UserProfile> save(UserProfile profile);
}

/// Logged meals.
abstract interface class DiaryRepository {
  /// Every meal on [date] (local midnight to midnight), oldest first.
  Stream<List<Meal>> watchDay(DateTime date);

  /// Meals between [from] and [to] inclusive — the History and Analysis views.
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to);

  Future<Meal> addMeal(Meal meal);
  Future<Meal> updateMeal(Meal meal);
  Future<void> deleteMeal(String id);

  /// Consecutive days ending today with at least two logged meals.
  Future<int> currentStreak();
}

/// Published plans, the user's own list, and favorites.
abstract interface class DietRepository {
  Stream<List<DietPlan>> watchAll();
  Stream<List<DietPlan>> watchMine();
  Stream<List<DietPlan>> watchFavorites();

  Future<DietPlan> setFavorite(String id, {required bool favorite});
  Future<DietPlan> setMine(String id, {required bool mine});

  /// Saves a plan the user created, and marks it theirs.
  Future<DietPlan> add(DietPlan plan);
}

/// The weight log.
///
/// Separate from the diary because the two answer different questions and are
/// written at different rhythms — meals several times a day, weight once in the
/// morning if at all.
abstract interface class WeightRepository {
  /// Oldest first, so a chart can plot it without sorting.
  Stream<WeightHistory> watch();

  /// Records a reading. **One per day**: a second entry on the same date
  /// replaces the first, because two readings hours apart are the same
  /// measurement taken twice and averaging them would quietly weight that day
  /// double.
  Future<void> log(double kg, {DateTime? at});

  Future<void> remove(String id);
}

/// Writes a one-day eating plan for this user.
///
/// The targets are **not** a parameter: the server reads them from the profile.
/// They are `TargetCalculator`'s output, which is where the deficit cap and the
/// calorie floors are applied, so letting a client send its own would let the
/// one feature that most needs those guards bypass them.
abstract interface class PlannerRepository {
  /// [notes] is the user's own free text — cuisine, allergies, dislikes.
  Future<DietPlan> generate({String? notes});
}

/// Turns a capture into nutrition figures.
abstract interface class ScanRepository {
  /// Analyses the image at [imagePath].
  ///
  /// [hint] is the optional one-line description the user can add before
  /// analysing ("chicken burrito, no rice"), which measurably improves mixed-
  /// dish accuracy.
  Future<ScanResult> analyzePhoto({
    required String imagePath,
    String? hint,
    ScanInput input = ScanInput.photo,
  });

  /// Text-only path, for the "describe it" fallback.
  Future<ScanResult> analyzeText(String description);

  /// Barcode lookup.
  Future<ScanResult> lookupBarcode(String barcode);

  /// Scans this user has run, newest first.
  Future<List<ScanResult>> history({int limit = 50});
}

/// Messages in the notifications list.
abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watch();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> clear();
}

/// A food database, for the paths that are a lookup rather than an estimate.
///
/// Barcode and search do not go through the model: a barcode identifies a
/// product exactly, and a search is someone telling us what they ate. Guessing
/// at either would be worse and cost money.
abstract interface class FoodDatabaseRepository {
  /// The product behind [barcode], or null when the database has never seen it
  /// — which is common and is not an error.
  Future<FoodItem?> lookupBarcode(String barcode);

  Future<List<FoodItem>> search(String query, {int limit = 20});
}

/// Where meal photos live once a meal is kept.
abstract interface class PhotoRepository {
  /// Uploads [localPath] and returns a durable URL, or null when there is
  /// nothing worth uploading (the bundled stand-in, a missing file, no
  /// session).
  Future<String?> upload(String localPath, {required String mealId});

  Future<void> delete(String mealId);
}

/// What the account is entitled to, and how that changes.
///
/// Purchases do NOT belong here as a client-side write. Whatever implements
/// this must end up validating a store receipt server-side — an entitlement a
/// client can grant itself is not an entitlement.
abstract interface class SubscriptionRepository {
  /// The purchasable plans. From the store once there is one, so prices are
  /// localised.
  List<SubscriptionPlan> get plans;

  Stream<Subscription> watch();

  Future<Subscription> current();

  /// Buys [planId] and returns the resulting entitlement.
  Future<Subscription> purchase(String planId);

  /// Re-reads entitlement from the store — required by both app stores for any
  /// app selling a subscription.
  Future<Subscription> restore();

  /// Stops the renewal. Access continues until the paid term ends.
  Future<Subscription> cancel();
}

/// Which notification categories the user has switched on.
abstract interface class NotificationSettingsRepository {
  Stream<Map<String, bool>> watch();
  Future<void> setEnabled(String key, {required bool enabled});
}
