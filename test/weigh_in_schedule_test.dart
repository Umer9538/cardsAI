import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure, like the meal ladder, and tested exactly for the same reason: every
/// value here decides whether someone is interrupted.
void main() {
  // A Wednesday.
  final now = DateTime(2026, 9, 23, 10);

  WeightEntry entry(DateTime at) =>
      WeightEntry(id: at.toIso8601String(), at: at, kg: 76);

  group('switch', () {
    test('off produces nothing to schedule', () {
      expect(WeighInSchedule.from(enabled: false, now: now), isNull);
    });

    test('ships off, so an account that never answered is never messaged', () {
      expect(WeighInSchedule.defaultEnabled, isFalse);
    });
  });

  group('defaults', () {
    test('Sunday morning', () {
      final reminder = WeighInSchedule.from(enabled: true, now: now)!;
      expect(reminder.weekday, DateTime.sunday);
      expect(reminder.hour, 9);
      expect(reminder.minute, 0);
    });

    test('a chosen day and time are used verbatim', () {
      final reminder = WeighInSchedule.from(
        enabled: true,
        weekday: DateTime.tuesday,
        hour: 7,
        minute: 30,
        now: now,
      )!;
      expect(reminder.weekday, DateTime.tuesday);
      expect(reminder.minuteOfDay, 7 * 60 + 30);
    });
  });

  group('already weighed', () {
    test('a reading earlier this week skips this week', () {
      // Monday of the same week as the Wednesday above.
      final reminder = WeighInSchedule.from(
        enabled: true,
        entries: [entry(DateTime(2026, 9, 21, 8))],
        now: now,
      )!;
      expect(reminder.loggedThisWeek, isTrue);
    });

    test('last week does not count', () {
      final reminder = WeighInSchedule.from(
        enabled: true,
        entries: [entry(DateTime(2026, 9, 20, 8))], // the Sunday before
        now: now,
      )!;
      expect(reminder.loggedThisWeek, isFalse);
    });

    test('weeks start on Monday, matching DateTime.weekday', () {
      // Sunday 27th is the same week as Wednesday 23rd; Monday 28th is not.
      final sunday = WeighInSchedule.from(
        enabled: true,
        entries: [entry(DateTime(2026, 9, 27, 8))],
        now: now,
      )!;
      final monday = WeighInSchedule.from(
        enabled: true,
        entries: [entry(DateTime(2026, 9, 28, 8))],
        now: now,
      )!;
      expect(sunday.loggedThisWeek, isTrue);
      expect(monday.loggedThisWeek, isFalse);
    });

    test('no history means nothing was logged', () {
      expect(
        WeighInSchedule.from(enabled: true, now: now)!.loggedThisWeek,
        isFalse,
      );
    });
  });

  group('preference', () {
    test('survives a round trip', () {
      const prefs = WeighInPreference(
        enabled: true,
        weekday: DateTime.friday,
        hour: 18,
        minute: 45,
      );
      expect(WeighInPreference.fromJson(prefs.toJson()), prefs);
    });

    test('a corrupt stored value falls back rather than scheduling nonsense',
        () {
      final prefs = WeighInPreference.fromJson(const {
        'enabled': true,
        'weekday': 99,
        'hour': -4,
        'minute': 600,
      });
      expect(prefs.weekday, WeighInSchedule.defaultWeekday);
      expect(prefs.hour, WeighInSchedule.defaultHour);
      expect(prefs.minute, WeighInSchedule.defaultMinute);
    });

    test('setting a time keeps the day, and vice versa', () {
      const prefs = WeighInPreference(enabled: true);
      expect(prefs.copyWith(minuteOfDay: 7 * 60).weekday, prefs.weekday);
      expect(prefs.copyWith(weekday: DateTime.monday).minuteOfDay,
          prefs.minuteOfDay);
    });
  });

  test('its notification id cannot collide with a meal slot', () {
    final mealIds = {
      for (final slot in MealSlot.values)
        MealReminder(slot: slot, hour: 9, minute: 0).id,
    };
    expect(mealIds, isNot(contains(WeightReminder.notificationId)));
  });
}
