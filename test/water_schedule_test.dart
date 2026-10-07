import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure, like the meal ladder and the weigh-in, and tested for the same
/// reason: every value here decides whether someone is interrupted.
void main() {
  // 08:00 and 20:00 — a twelve-hour eating window.
  const window = [8 * 60, 13 * 60, 20 * 60];

  List<int> minutesOf(List<WaterReminder> run) =>
      [for (final r in run) r.minuteOfDay];

  group('switch', () {
    test('off produces nothing to schedule', () {
      expect(WaterSchedule.from(enabled: false, mealTimes: window), isEmpty);
    });

    test('ships off, like every other notification here', () {
      expect(WaterSchedule.defaultEnabled, isFalse);
    });
  });

  group('the run', () {
    test('sits inside the eating window, never on its edges', () {
      final run = WaterSchedule.from(enabled: true, mealTimes: window);
      expect(run, hasLength(4));
      for (final r in run) {
        expect(r.minuteOfDay, greaterThan(window.first));
        expect(r.minuteOfDay, lessThan(window.last));
      }
    });

    test('is evenly spaced', () {
      // 08:00 to 20:00 in five intervals of 144 minutes.
      expect(
        minutesOf(WaterSchedule.from(enabled: true, mealTimes: window)),
        [8 * 60 + 144, 8 * 60 + 288, 8 * 60 + 432, 8 * 60 + 576],
      );
    });

    test('never lands on a meal reminder — two at once reads as a duplicate',
        () {
      final run = WaterSchedule.from(enabled: true, mealTimes: window);
      expect(minutesOf(run), isNot(contains(window.first)));
      expect(minutesOf(run), isNot(contains(window.last)));
    });

    test('follows a late riser rather than the office day', () {
      final late = WaterSchedule.from(
        enabled: true,
        mealTimes: [13 * 60, 23 * 60],
      );
      expect(late.first.minuteOfDay, greaterThan(13 * 60));
      expect(late.last.minuteOfDay, lessThan(23 * 60));
    });

    test('with no meal times at all it falls back to waking hours', () {
      final run = WaterSchedule.from(enabled: true);
      expect(run, isNotEmpty);
      expect(run.first.minuteOfDay,
          greaterThanOrEqualTo(WaterSchedule.fallbackStartMinute));
      expect(run.last.minuteOfDay,
          lessThanOrEqualTo(WaterSchedule.fallbackEndMinute));
    });
  });

  group('spacing is a floor, and the count yields to it', () {
    test('a short window drops reminders rather than bunching them', () {
      // Four hours cannot hold four an hour apart.
      final run = WaterSchedule.from(
        enabled: true,
        mealTimes: [12 * 60, 16 * 60],
        count: 4,
      );
      expect(run.length, lessThan(4));
      for (var i = 1; i < run.length; i++) {
        expect(
          run[i].minuteOfDay - run[i - 1].minuteOfDay,
          greaterThanOrEqualTo(WaterSchedule.minimumGapMinutes),
        );
      }
    });

    test('a window too short for even one gets nothing', () {
      expect(
        WaterSchedule.from(enabled: true, mealTimes: [12 * 60, 13 * 60]),
        isEmpty,
      );
    });

    test('a window with no width at all gets nothing', () {
      expect(
        WaterSchedule.from(enabled: true, mealTimes: [12 * 60, 12 * 60]),
        isEmpty,
      );
    });

    test('the count is capped, so the day cannot fill with notifications', () {
      final run = WaterSchedule.from(
        enabled: true,
        mealTimes: [6 * 60, 23 * 60],
        count: 20,
      );
      expect(run.length, WaterSchedule.maxPerDay);
    });

    test('asking for none gets none', () {
      expect(
        WaterSchedule.from(enabled: true, mealTimes: window, count: 0),
        isEmpty,
      );
    });
  });

  group('ids', () {
    test('cannot collide with a meal slot or the weigh-in', () {
      final taken = {
        for (final slot in MealSlot.values)
          MealReminder(slot: slot, hour: 9, minute: 0).id,
        WeightReminder.notificationId,
      };
      for (var i = 0; i < WaterSchedule.maxPerDay; i++) {
        expect(taken, isNot(contains(WaterReminder(index: i, minuteOfDay: 0).id)));
      }
    });

    test('are distinct within a run', () {
      final run = WaterSchedule.from(
        enabled: true,
        mealTimes: [6 * 60, 23 * 60],
        count: WaterSchedule.maxPerDay,
      );
      expect({for (final r in run) r.id}, hasLength(run.length));
    });
  });

  group('preference', () {
    test('survives a round trip', () {
      const prefs = WaterPreference(enabled: true, count: 6);
      expect(WaterPreference.fromJson(prefs.toJson()), prefs);
    });

    test('a corrupt stored count falls back rather than filling the day', () {
      expect(
        WaterPreference.fromJson(const {'enabled': true, 'count': 99}).count,
        4,
      );
      expect(
        WaterPreference.fromJson(const {'enabled': true, 'count': 0}).count,
        4,
      );
    });
  });
}
