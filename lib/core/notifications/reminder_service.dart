import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'reminder_schedule.dart';

/// Schedules the meal reminders.
///
/// Local notifications only. Nothing here needs a server to decide when to
/// notify — the times come from the person's own diary — and push would mean an
/// APNs certificate, a token registry, and a second thing that can wake the app.
///
/// Every failure is swallowed. A notification that cannot be scheduled is a
/// missing nicety; an exception on the path that also renders Home is a broken
/// app.
class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const AndroidNotificationDetails _android =
      AndroidNotificationDetails(
    'meal_reminders',
    'Meal reminders',
    channelDescription: 'A nudge at the time you usually eat.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is asked for when the toggle is turned on, not at
          // launch: a permission prompt before anyone has seen the feature is
          // the one people deny.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
      return true;
    } catch (error) {
      debugPrint('reminders unavailable: $error');
      return false;
    }
  }

  /// Asks for permission. Returns false if it was refused or is unavailable.
  Future<bool> requestPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } catch (error) {
      debugPrint('notification permission failed: $error');
      return false;
    }
  }

  /// Rewrites the schedule from [meals].
  ///
  /// Cancel-then-schedule rather than diffing: there are at most three, the
  /// times move as habits move, and a stale reminder at the wrong hour is the
  /// one that gets notifications switched off for good.
  Future<void> sync(List<Meal> meals, {required bool enabled}) async {
    if (!await _init()) return;

    try {
      await cancelAll();
      if (!enabled) return;

      for (final reminder in ReminderSchedule.from(meals)) {
        await _plugin.zonedSchedule(
          reminder.id,
          ReminderSchedule.title(reminder.slot),
          ReminderSchedule.body(reminder.slot),
          _nextInstanceOf(reminder.hour, reminder.minute),
          _details,
          // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM, which
          // Play reviews and which this does not deserve — nobody needs a meal
          // reminder to the second.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (error) {
      debugPrint('reminder sync failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!await _init()) return;
    try {
      for (final slot in ReminderSchedule.slots) {
        await _plugin.cancel(100 + slot.index);
      }
    } catch (error) {
      debugPrint('reminder cancel failed: $error');
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Today's slot has already passed, so the first firing is tomorrow's.
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}
