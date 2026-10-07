import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A tiny JSON-over-[SharedPreferences] store.
///
/// Deliberately minimal: this is the persistence layer only until Firestore
/// arrives, and everything it holds is small enough to rewrite whole. Anything
/// that needs querying — history ranges, aggregates — is computed in Dart rather
/// than pushed down here, because that logic has to move to Firestore queries
/// anyway and is easier to port from one place.
class JsonStore {
  JsonStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<JsonStore> open() async =>
      JsonStore(await SharedPreferences.getInstance());

  /// Decodes a stored list, or null when the key has never been written.
  ///
  /// Null and empty are different: null means "seed me", empty means "the user
  /// deleted everything". Conflating them resurrects deleted data on restart.
  List<Map<String, dynamic>>? readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on FormatException {
      // Corrupt or written by an incompatible build: drop it and reseed rather
      // than trapping the user on a launch crash.
      _prefs.remove(key);
      return null;
    }
  }

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);

  bool flag(String key) => _prefs.getBool(key) ?? false;

  Future<void> setFlag(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  /// Wipes everything this app wrote — the delete-account path.
  Future<void> clear() => _prefs.clear();
}

/// Every key the store uses, in one place so account deletion cannot miss one.
abstract final class StoreKeys {
  static const String profile = 'carbsai.profile';
  static const String meals = 'carbsai.meals';
  static const String plans = 'carbsai.plans';
  static const String notifications = 'carbsai.notifications';
  static const String notificationSettings = 'carbsai.notificationSettings';
  static const String scans = 'carbsai.scans';
  static const String session = 'carbsai.session';
  static const String subscription = 'carbsai.subscription';

  /// Whether the intro carousel has been seen. Deliberately NOT in [all]:
  /// deleting an account should not replay onboarding.
  static const String onboardingSeen = 'carbsai.onboardingSeen';

  /// Whether the person has been told, in the app, that a photo or a
  /// description of their meal leaves the device and goes to a third-party AI
  /// provider.
  ///
  /// Google Play's User Data policy requires that disclosure *in the app*,
  /// before the data is collected, and not only in a policy behind two menus.
  /// Shown once, before the first AI action of any kind. Device-scoped like
  /// [onboardingSeen]: it is a disclosure to the person holding the phone.
  static const String aiDisclosureSeen = 'carbsai.aiDisclosureSeen';

  /// Whether the personalisation quiz has been answered or skipped.
  ///
  /// Separate from the profile's own completeness because skipping is a valid
  /// answer: without this flag, anyone who skipped would be asked again on
  /// every launch.
  static const String quizSeen = 'carbsai.quizSeen';

  /// The weight log.
  /// The water diary. Belongs to the person, so it is in [all].
  static const String water = 'carbsai.water';

  /// The exercise diary, for the same reason.
  static const String activity = 'carbsai.activity';

  static const String weights = 'carbsai.weights';

  /// Plans the user generated, kept apart from the catalogue copy so the
  /// catalogue reconcile cannot delete them.
  static const String myPlans = 'carbsai.myPlans';

  /// Which revision of the plan catalogue the stored copy was written from.
  /// See `LocalDietRepository._load`.
  static const String plansVersion = 'carbsai.plansVersion';

  /// The taste answers the last generated plan was built from.
  ///
  /// `DietPlan.builtFor` is the *summary* frozen on the plan — "South Asian",
  /// "No dairy" — which is the right thing to show and not enough to generate
  /// from again. Keeping the profile itself is what lets "Something else" give
  /// someone a different plan without making them answer fifty seconds of
  /// questions they have already answered.
  ///
  /// Device-scoped and in [all]: it is theirs, and it is the shape of their
  /// last answer rather than a record of anything.
  static const String lastTaste = 'carbsai.lastTaste';

  /// Meal-reminder times the person set, and slots they switched off.
  ///
  /// Device-scoped storage, but it is theirs, so it is in [all]. Notifications
  /// are scheduled by the OS on this handset — there is nothing to sync — and
  /// keeping it out of the profile means the schedule works identically on
  /// `BACKEND=local`, which is where reminders are usually tested.
  static const String reminderTimes = 'carbsai.reminderTimes';

  /// Weekday and time for the weekly weigh-in prompt. Device-scoped for the
  /// same reason as [reminderTimes].
  static const String weighInReminder = 'carbsai.weighInReminder';

  /// The water nudges' switch and how many a day, for the same reason as
  /// [reminderTimes] — the OS that rings is this handset.
  static const String waterReminder = 'carbsai.waterReminder';

  /// Metric or imperial, for display only. Deliberately NOT in [all]: deleting
  /// an account should not put an American back on centimetres.
  static const String units = 'carbsai.units';

  /// Everything a deleted account takes with it.
  ///
  /// [onboardingSeen] and [units] are excluded for the reasons stated on each.
  /// Everything else belongs to the person, including [quizSeen] — leaving it
  /// set meant the next account on the device was never asked, and silently
  /// took the default 2000 kcal target the quiz exists to replace.
  static const List<String> all = [
    profile,
    myPlans,
    weights,
    water,
    activity,
    meals,
    subscription,
    plans,
    plansVersion,
    notifications,
    notificationSettings,
    scans,
    session,
    quizSeen,
    reminderTimes,
    weighInReminder,
    waterReminder,
  ];
}
