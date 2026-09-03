import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ads_providers.dart';
import '../providers/providers.dart';
import 'reminder_schedule.dart';

/// Keeps the scheduled reminders in step with the diary and the toggle.
///
/// One object owns every trigger, because the failure mode of scattering this
/// is a reminder left over from a habit someone no longer has. The triggers
/// are: the app starting, a meal being logged, and the toggle being changed.
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

    await _apply(enabled: enabled);
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
    if (enabled) {
      // The system permission sheet pauses the app; coming back from it is not
      // someone opening the app.
      _ref.read(adsServiceProvider).suppressNextResume();
      final granted = await _ref.read(reminderServiceProvider).requestPermission();
      if (!granted) {
        await _ref.read(reminderServiceProvider).cancelAll();
        return false;
      }
    }

    await _ref
        .read(notificationSettingsRepositoryProvider)
        .setEnabled(key, enabled: enabled);
    await _apply(enabled: enabled);
    return enabled;
  }

  Future<void> _apply({required bool enabled}) async {
    final service = _ref.read(reminderServiceProvider);
    if (!enabled) {
      await service.cancelAll();
      return;
    }

    try {
      final now = DateTime.now();
      final meals = await _ref
          .read(diaryRepositoryProvider)
          .mealsBetween(
            now.subtract(const Duration(days: ReminderSchedule.window)),
            now,
          );
      await service.sync(meals, enabled: true);
    } catch (error) {
      // A diary read that fails is a network or storage problem the rest of
      // the app already reports. It must not take the shell down with it.
      debugPrint('reminder refresh failed: $error');
    }
  }
}
