import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The nightly "how did today go" nudge.
///
/// It carries **no number**, and that is the design rather than an omission: a
/// scheduled local notification's text is fixed when it is scheduled, hours
/// before it fires, so "you are 300 under today" would be a figure from the
/// morning read out at night. The personal part is on the other side of the
/// tap.
void main() {
  MealReminder dinner(int hour, int minute) => MealReminder(
        slot: MealSlot.dinner,
        hour: hour,
        minute: minute,
      );

  test('it lands two hours after dinner', () {
    final at = DaySummarySchedule.from(
      enabled: true,
      mealReminders: [dinner(20, 15)],
    );
    expect(at!.hour, 22);
    expect(at.minute, 15);
  });

  test('Northern Europe still gets it in the evening, unclamped', () {
    // Stockholm eats dinner at 17:30 and the reminder lands 45 minutes later,
    // so two hours past that is 20:15 — already evening, and nothing to clamp.
    final at = DaySummarySchedule.from(
      enabled: true,
      mealReminders: [dinner(18, 15)],
    );
    expect(at!.minuteOfDay, 20 * 60 + 15);
  });

  test('but an unusually early dinner is floored', () {
    // Someone who set their own dinner reminder to 17:00. "How did today go"
    // at 19:00 arrives before the evening has happened.
    final at = DaySummarySchedule.from(
      enabled: true,
      mealReminders: [dinner(17, 0)],
    );
    expect(at!.minuteOfDay, DaySummarySchedule.earliestMinuteOfDay);
  });

  test('a late-eating country does not get it in the small hours', () {
    // Madrid eats at 21:30 and Karachi at 21:15; two hours past either is
    // after 23:00, which is a notification someone reads the next morning
    // about a day they can no longer act on.
    final at = DaySummarySchedule.from(
      enabled: true,
      mealReminders: [dinner(22, 15)],
    );
    expect(at!.minuteOfDay, DaySummarySchedule.latestMinuteOfDay);
  });

  test('no dinner reminder falls back rather than guessing', () {
    // Someone who switched the dinner slot off. The meal clock's pattern is
    // not this schedule's to re-derive.
    final at = DaySummarySchedule.from(enabled: true);
    expect(at!.minuteOfDay, DaySummarySchedule.earliestMinuteOfDay);
  });

  test('off means nothing is scheduled', () {
    expect(
      DaySummarySchedule.from(enabled: false, mealReminders: [dinner(20, 0)]),
      isNull,
    );
  });

  test('it never quotes a figure', () {
    // The one rule this text has to keep.
    final text = '${DaySummarySchedule.title} ${DaySummarySchedule.body}';
    expect(RegExp(r'\d').hasMatch(text), isFalse, reason: text);
    expect(text, isNot(contains('!')));
  });

  test('its id cannot collide with the other kinds', () {
    expect(DaySummaryReminder.notificationId,
        isNot(WeightReminder.notificationId));
    // Meals are 100 + slot index; water starts at 300.
    expect(DaySummaryReminder.notificationId, greaterThan(102));
    expect(DaySummaryReminder.notificationId, lessThan(300));
  });
}
