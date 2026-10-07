import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ads_providers.dart';
import '../providers/providers.dart';
import 'notification_category.dart';
import 'reminder_schedule.dart';

/// Keeps the scheduled reminders in step with the diary and the toggle.
///
/// One object owns every trigger, because the failure mode of scattering this
/// is a reminder left over from a habit someone no longer has. The triggers
/// are: the app starting, a meal being logged, and the toggle being changed.
///
/// It owns the **weekly weigh-in** as well as the meals, despite the name.
/// That is not tidiness: [ReminderService.sync] opens with `cancelAll`, so a
/// second coordinator scheduling alongside this one would cancel these on its
/// way past. Every scheduled reminder this app owns goes out of one call.
class MealReminders {
  MealReminders(this._ref);

  final Ref _ref;

  /// The preference the settings screen writes.
  static const String key = 'mealReminders';

  /// Rewrites the schedule from the last four weeks of the diary.
  ///
  /// Also reconciles the preference with the OS. Permission can be withdrawn in
  /// system settings at any time and nothing tells the app; left alone, the
  /// toggle goes on saying "on" while Android drops every notification. When
  /// that has happened the preference is turned **off**, so what Settings shows
  /// is what the person will actually get.
  Future<void> refresh() async {
    final settings = await _ref
        .read(notificationSettingsRepositoryProvider)
        .watch()
        .first;
    var enabled = settings[key] ?? false;

    if (enabled && !await _ref.read(reminderServiceProvider).hasPermission()) {
      enabled = false;
      await _ref
          .read(notificationSettingsRepositoryProvider)
          .setEnabled(key, enabled: false);
    }

    await _apply(enabled: enabled, settings: settings);
  }

  /// Handles the toggle.
  ///
  /// Permission is asked for here — the moment someone turns reminders on —
  /// rather than at launch. A prompt that arrives before anyone has seen the
  /// feature is the one that gets denied, and on Android a denied
  /// `POST_NOTIFICATIONS` cannot be asked for twice.
  ///
  /// Returns the value the toggle should settle on: refusing permission leaves
  /// it off, because a switch that says on while the OS drops every
  /// notification is worse than one that says off.
  Future<bool> setEnabled({required bool enabled}) async {
    if (enabled && !await _grantPermission()) return false;

    await _ref
        .read(notificationSettingsRepositoryProvider)
        .setEnabled(key, enabled: enabled);
    await _apply(
      enabled: enabled,
      settings: await _ref
          .read(notificationSettingsRepositoryProvider)
          .watch()
          .first,
    );
    return enabled;
  }

  /// Asks the OS, if we are about to start sending something.
  ///
  /// Shared by all three switches: each one is the first that might need
  /// permission, and asking at launch instead is the prompt people deny.
  Future<bool> _grantPermission() async {
    // The system permission sheet pauses the app; coming back from it is not
    // someone opening the app.
    _ref.read(adsServiceProvider).suppressNextResume();
    final granted =
        await _ref.read(reminderServiceProvider).requestPermission();
    if (!granted) await _ref.read(reminderServiceProvider).cancelAll();
    return granted;
  }

  /// The weekly weigh-in switch. Returns what it should settle on.
  ///
  /// Goes through here rather than writing the preference directly so it gets
  /// the same permission prompt the meal toggle does — it is switched on from
  /// its own card, which may well be the first notification anyone enables.
  Future<bool> setWeighInEnabled({required bool enabled}) async {
    if (enabled && !await _grantPermission()) return false;
    _ref.read(weighInPreferenceProvider.notifier).setEnabled(enabled: enabled);
    // Awaited, unlike the controller's own fire-and-forget rewrite: a caller
    // that is told the switch settled on true has been told the notification
    // is scheduled.
    await refresh();
    return enabled;
  }

  /// The water switch, for the same reason.
  Future<bool> setWaterEnabled({required bool enabled}) async {
    if (enabled && !await _grantPermission()) return false;
    _ref.read(waterPreferenceProvider.notifier).setEnabled(enabled: enabled);
    await refresh();
    return enabled;
  }

  /// Rewrites the schedule after the diary changed.
  ///
  /// The doc comment above has always claimed a meal being logged was one of
  /// the triggers, and it was not wired to anything — so the times only moved
  /// when the app was next opened, and today's reminder went on asking for a
  /// meal already in the diary. Cheap enough to call on every write: it reads
  /// the preference, and reschedules at most three notifications.
  Future<void> mealLogged() async {
    try {
      final settings = await _ref
          .read(notificationSettingsRepositoryProvider)
          .watch()
          .first;
      await _apply(enabled: settings[key] ?? false, settings: settings);
    } catch (error) {
      // Called from the log paths and never awaited by them. A meal that was
      // written must not be reported as failed because a notification could
      // not be moved.
      debugPrint('reminder reschedule failed: $error');
    }
  }

  /// The weekly prompt, or null when it is off.
  ///
  /// Read from the same preference map as the meal toggle, so the two cannot
  /// disagree about whether notifications are permitted at all.
  WeightReminder? _weighIn(DateTime now) {
    final prefs = _ref.read(weighInPreferenceProvider);
    return WeighInSchedule.from(
      enabled: prefs.enabled,
      entries: _ref.read(weightHistoryProvider).value?.entries ?? const [],
      weekday: prefs.weekday,
      hour: prefs.hour,
      minute: prefs.minute,
      now: now,
    );
  }

  /// The water run, spread across the meal reminders' own window.
  ///
  /// Derived from [meals] rather than from the clock so the nudges land inside
  /// the hours this person is actually awake and eating — a 10:00 prompt is
  /// useless to someone whose day starts at 13:00.
  List<WaterReminder> _water(List<MealReminder> meals) {
    final prefs = _ref.read(waterPreferenceProvider);
    return WaterSchedule.from(
      enabled: prefs.enabled,
      mealTimes: [for (final meal in meals) meal.hour * 60 + meal.minute],
      count: prefs.count,
    );
  }

  /// Rewrites every scheduled notification this app owns.
  ///
  /// [enabled] is the *meal* preference and nothing more. The weigh-in and the
  /// water nudges carry their own switches and are scheduled — or not — from
  /// those, so turning meal reminders off no longer takes the other two with
  /// it.
  Future<void> _apply({
    required bool enabled,
    required Map<String, bool> settings,
  }) async {
    final service = _ref.read(reminderServiceProvider);

    try {
      final now = DateTime.now();
      final meals = await _ref
          .read(diaryRepositoryProvider)
          .mealsBetween(
            now.subtract(const Duration(days: ReminderSchedule.window)),
            now,
          );
      final scheduled = ReminderSchedule.from(
        meals,
        preferences: _ref.read(reminderPreferencesProvider),
        clock: _ref.read(mealClockProvider),
        now: now,
      );
      await service.sync(
        enabled ? scheduled : const [],
        weighIn: _weighIn(now),
        // The window comes from the meal times whether or not the meal
        // reminders themselves are being sent: it says when this person is
        // awake and eating, which is true either way.
        water: _water(scheduled),
        // Likewise derived from the meal times rather than the clock, and
        // governed by its own switch: the Progress Summary category used to
        // post only into the in-app feed, so someone who never opened the app
        // never saw it.
        daySummary: DaySummarySchedule.from(
          enabled: NotificationCategory.progressSummary.isOn(settings),
          mealReminders: scheduled,
          now: now,
        ),
      );
    } catch (error) {
      // A diary read that fails is a network or storage problem the rest of
      // the app already reports. It must not take the shell down with it.
      debugPrint('reminder refresh failed: $error');
    }
  }
}
