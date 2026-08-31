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

  static const List<String> all = [
    profile,
    meals,
    subscription,
    plans,
    notifications,
    notificationSettings,
    scans,
    session,
  ];
}
