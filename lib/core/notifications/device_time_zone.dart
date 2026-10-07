import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Where this phone is, as an IANA zone name.
///
/// Resolved once at start-up rather than inside whatever needs it first,
/// because two separate things depend on it and both are wrong without it:
///
///   * **Scheduling.** `zonedSchedule` takes a `TZDateTime`, and one built in
///     `tz.local` is built in **UTC** until something calls `setLocalLocation`
///     — `initializeTimeZones()` does not. Every reminder fired at the wrong
///     hour: a 09:00 breakfast was 14:00 in Karachi and 04:00 in New York.
///   * **The suggested meal times.** [MealClock] reads the zone to decide what
///     time a country eats, and it has to answer synchronously.
abstract final class DeviceTimeZone {
  static String? _name;

  /// The zone, or null before [resolve] has run or if it could not be found.
  static String? get name => _name;

  @visibleForTesting
  static set nameForTest(String? value) => _name = value;

  static bool _done = false;

  /// Points `tz.local` at this phone's zone. Safe to call more than once.
  ///
  /// Never throws. A phone whose zone cannot be resolved must still run the
  /// app, and it still gets reminders — at the offset guess below, or failing
  /// that at UTC, which is where it already was.
  static Future<void> resolve() async {
    if (_done) return;
    _done = true;

    try {
      tz_data.initializeTimeZones();
    } catch (error) {
      debugPrint('time zone database unavailable: $error');
      return;
    }

    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      _name = zone.identifier;
      return;
    } catch (error) {
      // No platform implementation, or a name the database does not carry.
      debugPrint('device time zone unavailable: $error');
    }

    // Any zone that currently agrees with the device's offset. It is not the
    // right zone — Karachi and Yekaterinburg both sit at +05:00 and share no
    // history — but it puts reminders at the right wall-clock time today,
    // which staying on UTC does not. The *name* is deliberately left null:
    // it is a guess, and MealClock must not read a country out of it.
    try {
      final offset = DateTime.now().timeZoneOffset.inMilliseconds;
      final at = DateTime.now().millisecondsSinceEpoch;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.timeZone(at).offset == offset) {
          tz.setLocalLocation(location);
          debugPrint('time zone guessed from offset: ${location.name}');
          return;
        }
      }
    } catch (error) {
      debugPrint('time zone fallback failed: $error');
    }
  }
}
