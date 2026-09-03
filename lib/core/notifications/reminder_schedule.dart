import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// One reminder: which meal, and what time of day to fire.
@immutable
class MealReminder {
  const MealReminder({
    required this.slot,
    required this.hour,
    required this.minute,
  });

  final MealSlot slot;
  final int hour;
  final int minute;

  int get id => 100 + slot.index;

  @override
  bool operator ==(Object other) =>
      other is MealReminder &&
      other.slot == slot &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(slot, hour, minute);

  @override
  String toString() =>
      '${slot.name} at ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

/// Works out when to remind someone, from when they actually eat.
///
/// **This is the whole feature, and it is not a detail.** Tailored prompts
/// timed to a person's own meals raised food-photo capture from 2.8 to 4.6
/// images a day (p≤.001). Generic fixed-time prompts at 7:15 / 11:15 / 17:15
/// produced +0.83 at p=.23 — no effect. Shipping 8am / 1pm / 7pm reminders
/// would be shipping a measured null result, and spending the notification
/// permission to do it.
///
/// A pure function of the diary, so it can be checked exactly.
abstract final class ReminderSchedule {
  /// Slots that get a reminder. Snacks do not: they have no time of day worth
  /// predicting, and a fourth notification is how people turn all of them off.
  static const List<MealSlot> slots = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
  ];

  /// Days of history to learn from.
  static const int window = 28;

  /// A slot needs this many logged meals before it is worth predicting.
  ///
  /// Below it the median is one or two mornings, which is a habit the app has
  /// invented rather than observed — and a reminder at the wrong hour is worse
  /// than none, because it is the one that gets notifications switched off.
  static const int minimumSamples = 3;

  /// Minutes after the usual time. Reminding at the median is reminding of
  /// something already done; the point is the day it is running late.
  static const int graceMinutes = 45;

  /// The reminders to schedule for [meals], or empty when there is not enough
  /// history to say anything.
  static List<MealReminder> from(List<Meal> meals, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final since = today.subtract(const Duration(days: window));

    final byslot = <MealSlot, List<int>>{};
    for (final meal in meals) {
      if (meal.eatenAt.isBefore(since)) continue;
      if (!slots.contains(meal.slot)) continue;
      byslot
          .putIfAbsent(meal.slot, () => [])
          .add(meal.eatenAt.hour * 60 + meal.eatenAt.minute);
    }

    final reminders = <MealReminder>[];
    for (final slot in slots) {
      final times = byslot[slot];
      if (times == null || times.length < minimumSamples) continue;

      // Median, not mean: one 2am snack logged as breakfast would drag a mean
      // across the whole morning, and the median simply ignores it.
      times.sort();
      final median = times[times.length ~/ 2];
      final at = median + graceMinutes;

      // Past midnight is nobody's meal reminder.
      if (at >= 24 * 60) continue;
      reminders.add(
        MealReminder(slot: slot, hour: at ~/ 60, minute: at % 60),
      );
    }
    return reminders;
  }

  /// What the notification says.
  ///
  /// Neutral, and deliberately so. Reviewers of this category describe
  /// guilt-worded reminders — a mascot pleading, a streak about to break — as
  /// the reason they turned notifications off for good, and a notification
  /// nobody receives is worth less than none at all. It names the meal and
  /// stops.
  static String title(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => 'Breakfast',
        MealSlot.lunch => 'Lunch',
        MealSlot.dinner => 'Dinner',
        MealSlot.snack => 'Snack',
      };

  static String body(MealSlot slot) =>
      'Log your ${title(slot).toLowerCase()} while you remember it.';
}
