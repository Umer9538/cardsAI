import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../theme/app_colors.dart';
import 'device_time_zone.dart';
import 'reminder_schedule.dart';

/// What happened when someone asked for a test reminder.
enum ReminderTestResult {
  sent,

  /// The OS is dropping notifications for this app. Permission can be taken
  /// away in system settings long after it was given.
  noPermission,

  /// The plugin could not start at all — no platform side, or the icon
  /// resource did not resolve.
  unavailable,
}

/// Schedules the meal reminders.
///
/// Local notifications only. Nothing here needs a server to decide when to
/// notify — the times come from the person's own diary — and push would mean an
/// APNs certificate, a token registry, and a second thing that can wake the app.
///
/// Every failure is swallowed. A notification that cannot be scheduled is a
/// missing nicety; an exception on the path that also renders Home is a broken
/// app.
/// The kinds of notification this app sends, which is also the set of Android
/// channels it owns.
enum NotificationChannel { meals, water, weighIn, progress, milestones }

class ReminderService {
  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Built per notification rather than held as a constant, because
  /// [BigTextStyleInformation] carries the body: without it Android truncates
  /// the collapsed line and there is nothing to expand to, so the half of the
  /// sentence that says what to do is simply lost on a narrow phone.
  /// One Android channel per kind, not one for everything.
  ///
  /// A channel is the unit Android gives people to mute: with a single channel,
  /// someone who does not want the water nudges can only silence the meal
  /// reminders too, and the usual outcome of that choice is all of them off.
  /// The ids are fixed forever — a channel's importance is set when it is first
  /// created and renaming the id makes a second one rather than editing the
  /// first.
  static ({String id, String name, String description}) _channel(
    NotificationChannel channel,
  ) =>
      switch (channel) {
        NotificationChannel.meals => (
            id: 'meal_reminders',
            name: 'Meal reminders',
            description: 'A reminder at your usual meal times.',
          ),
        NotificationChannel.water => (
            id: 'water_reminders',
            name: 'Water reminders',
            description: 'A nudge to drink something, across your own day.',
          ),
        NotificationChannel.weighIn => (
            id: 'weigh_in',
            name: 'Weekly weigh-in',
            description: 'One reminder a week to step on the scales.',
          ),
        NotificationChannel.progress => (
            id: 'progress',
            name: 'Daily progress',
            description: 'How the day went against your calorie target.',
          ),
        NotificationChannel.milestones => (
            id: 'milestones',
            name: 'Milestones',
            description: 'Streaks, and getting closer to your goal weight.',
          ),
      };

  static NotificationDetails _detailsFor(
    String body, {
    NotificationChannel channel = NotificationChannel.meals,
  }) {
    final spec = _channel(channel);
    return NotificationDetails(
        android: AndroidNotificationDetails(
          spec.id,
          spec.name,
          channelDescription: spec.description,
          // Default, not high: this makes a sound and sits in the shade. A
          // heads-up banner over whatever someone is doing is not what a meal
          // reminder is worth, and is how a channel gets muted.
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // Android draws a small icon from its **alpha channel only**, so the
          // launcher icon — opaque edge to edge — renders as a solid white
          // square. This is the monochrome mark from
          // `tool/make_notification_icon.py`.
          icon: 'ic_stat_meal',
          // Tints that icon and the app name on the notification.
          color: AppColors.primary,
          category: channel == NotificationChannel.milestones
              ? AndroidNotificationCategory.status
              : AndroidNotificationCategory.reminder,
          styleInformation: BigTextStyleInformation(body),
          ticker: spec.name,
        ),
        iOS: DarwinNotificationDetails(
          // Groups a kind under one heading in Notification Centre instead of
          // one stack per notification from the same app.
          threadIdentifier: spec.id,
          interruptionLevel: InterruptionLevel.active,
        ),
    );
  }

  Future<bool> _init() async {
    if (_ready) return true;
    try {
      await DeviceTimeZone.resolve();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_meal'),
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

  /// Whether notifications are currently allowed — without prompting.
  ///
  /// Permission can be taken away after it was given, in system settings, and
  /// nothing tells the app when that happens. Without this the toggle keeps
  /// saying "on" over an OS that is dropping every notification, which is the
  /// exact state this feature is written to avoid.
  Future<bool> hasPermission() async {
    if (!await _init()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.checkPermissions();
        return granted?.isEnabled ?? false;
      }
      return false;
    } catch (error) {
      debugPrint('permission check failed: $error');
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

  /// Rewrites the schedule to [reminders].
  ///
  /// Cancel-then-schedule rather than diffing: there are at most three, the
  /// times move as habits move, and a stale reminder at the wrong hour is the
  /// one that gets notifications switched off for good.
  ///
  /// It schedules what it is given and works nothing out. Deciding *when* is
  /// [ReminderSchedule], which is a pure function and therefore testable
  /// exactly; this half cannot be, because it ends at a platform channel.
  /// Rewrites every scheduled reminder this app owns.
  ///
  /// One call for all three kinds on purpose: it opens with [cancelAll], so a
  /// second scheduler running alongside it would silently cancel these.
  ///
  /// **There is no `enabled` flag.** It schedules exactly what it is handed,
  /// and an empty list is how a kind is switched off — which is what keeps the
  /// three switches independent. The flag it used to take was the *meal*
  /// preference and it returned early, so switching meal reminders off also
  /// silently unscheduled the weekly weigh-in someone had turned on.
  Future<void> sync(
    List<MealReminder> reminders, {
    WeightReminder? weighIn,
    List<WaterReminder> water = const [],
    DaySummaryReminder? daySummary,
  }) async {
    if (!await _init()) return;

    try {
      await cancelAll();

      for (final reminder in reminders) {
        final body = ReminderSchedule.body(reminder.slot);
        await _plugin.zonedSchedule(
          reminder.id,
          ReminderSchedule.title(reminder.slot),
          body,
          _nextInstanceOf(
            reminder.hour,
            reminder.minute,
            // Already eaten and logged, so today's firing has nothing to ask
            // for. The daily repeat starts tomorrow instead.
            skipToday: reminder.loggedToday,
          ),
          _detailsFor(body),
          // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM, which
          // Play reviews and which this does not deserve — nobody needs a meal
          // reminder to the second.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      if (weighIn != null) {
        await _plugin.zonedSchedule(
          WeightReminder.notificationId,
          WeighInSchedule.title,
          WeighInSchedule.body,
          _nextWeekly(
            weighIn.weekday,
            weighIn.hour,
            weighIn.minute,
            // Already weighed this week, so this week's firing has nothing to
            // ask for; the weekly repeat picks up next week.
            skipThisWeek: weighIn.loggedThisWeek,
          ),
          _detailsFor(WeighInSchedule.body,
              channel: NotificationChannel.weighIn),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // Weekly, not daily — the component set is what makes the repeat
          // land on the same weekday rather than every morning.
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      if (daySummary != null) {
        await _plugin.zonedSchedule(
          DaySummaryReminder.notificationId,
          DaySummarySchedule.title,
          DaySummarySchedule.body,
          _nextInstanceOf(daySummary.hour, daySummary.minute),
          _detailsFor(DaySummarySchedule.body,
              channel: NotificationChannel.progress),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      for (final drink in water) {
        await _plugin.zonedSchedule(
          drink.id,
          WaterSchedule.title,
          WaterSchedule.body,
          _nextInstanceOf(drink.hour, drink.minute),
          _detailsFor(WaterSchedule.body,
              channel: NotificationChannel.water),
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

  /// The next [weekday] at [hour]:[minute], in the device's own zone.
  tz.TZDateTime _nextWeekly(
    int weekday,
    int hour,
    int minute, {
    bool skipThisWeek = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour,
        minute);
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return skipThisWeek ? next.add(const Duration(days: 7)) : next;
  }

  /// Fires a reminder immediately.
  ///
  /// **The feature is otherwise untestable.** The first real reminder is hours
  /// away, so someone who has just switched them on has no way to tell the
  /// difference between working, permission silently refused, and broken — and
  /// neither does anyone trying to support them. Waiting until the evening to
  /// find out is not a diagnosis.
  ///
  /// It goes through the same channel and the same [_detailsFor] as the real
  /// ones, so a test that arrives proves the three things that actually fail:
  /// the permission is granted, the channel is not muted, and the small icon
  /// resolves. It cannot prove the *scheduling* survives an aggressive OEM
  /// battery manager, which is the one remaining failure and is a different
  /// class of problem.
  Future<ReminderTestResult> sendTest() async {
    if (!await _init()) return ReminderTestResult.unavailable;
    if (!await hasPermission()) return ReminderTestResult.noPermission;

    try {
      await _plugin.show(
        _testId,
        'Test reminder',
        'Reminders are working. Real ones arrive at your meal times.',
        _detailsFor('Reminders are working. Real ones arrive at your meal times.'),
      );
      return ReminderTestResult.sent;
    } catch (error) {
      debugPrint('test reminder failed: $error');
      return ReminderTestResult.unavailable;
    }
  }

  /// Clear of the meal ids, which are 100 + the slot index.
  static const int _testId = 199;

  /// Posts [body] now, on [channel].
  ///
  /// For the things that are **facts rather than figures**: a seven-day streak
  /// or two kilos from a goal is true the moment it is derived and stays true,
  /// so it can be put on the lock screen as it happens. A calorie total cannot
  /// — it changes with the next meal — which is why the daily summary is a
  /// scheduled, number-free nudge instead.
  ///
  /// [id] is derived from the feed entry's own stable id, so the same milestone
  /// cannot be posted twice: Android replaces a notification that reuses an id
  /// rather than stacking a second one.
  Future<void> post({
    required int id,
    required String title,
    required String body,
    required NotificationChannel channel,
  }) async {
    if (!await _init()) return;
    if (!await hasPermission()) return;
    try {
      await _plugin.show(id, title, body, _detailsFor(body, channel: channel));
    } catch (error) {
      debugPrint('notification post failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!await _init()) return;
    try {
      for (final slot in ReminderSchedule.slots) {
        await _plugin.cancel(100 + slot.index);
      }
      await _plugin.cancel(WeightReminder.notificationId);
      await _plugin.cancel(DaySummaryReminder.notificationId);
      // Every id the water run can occupy, not just the ones currently
      // scheduled: turning the count down from six to three has to cancel the
      // three that are no longer wanted, and nothing here knows what the
      // previous count was.
      for (var i = 0; i < WaterSchedule.maxPerDay; i++) {
        await _plugin.cancel(WaterReminder(index: i, minuteOfDay: 0).id);
      }
    } catch (error) {
      debugPrint('reminder cancel failed: $error');
    }
  }

  static tz.TZDateTime _nextInstanceOf(
    int hour,
    int minute, {
    bool skipToday = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // Today's slot has already passed, or has already been logged, so the
    // first firing is tomorrow's. The repeat itself is daily either way —
    // `matchDateTimeComponents: time` keeps it firing without the app.
    if (skipToday || !at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }
}
