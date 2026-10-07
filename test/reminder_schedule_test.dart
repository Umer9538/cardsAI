import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/meal_clock.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prompts timed to a person's own meals raised food-photo capture from 2.8 to
/// 4.6 images a day (p≤.001). Generic fixed-time prompts produced +0.83 at
/// p=.23 — no effect. So the observed median is what this reaches for first.
///
/// It used to reach for that and nothing else, and therefore reminded nobody:
/// a slot needs three logged meals before a median means anything, and the
/// diary that would supply them is what the reminders exist to produce. The
/// tests below pin the ladder that breaks the circle — chosen, then observed,
/// then a suggested time the person can move.
void main() {
  final now = DateTime(2026, 3, 20, 12);

  Meal at(int daysAgo, int hour, int minute, MealSlot slot) => Meal(
        id: '$daysAgo-${slot.name}-$hour',
        eatenAt: now.subtract(Duration(days: daysAgo)).copyWith(
              hour: hour,
              minute: minute,
            ),
        slot: slot,
        items: const [
          FoodItem(id: 'f', name: 'x', nutrition: Nutrition(calories: 1)),
        ],
      );

  MealReminder only(List<MealReminder> all, MealSlot slot) =>
      all.singleWhere((r) => r.slot == slot);

  group('learning from the diary', () {
    test('reminders land after the usual time, not at it', () {
      final meals = [
        for (var d = 1; d <= 5; d++) at(d, 8, 0, MealSlot.breakfast),
      ];

      final breakfast =
          only(ReminderSchedule.from(meals, now: now), MealSlot.breakfast);
      // 08:00 + 45 minutes of grace. Reminding at the median is reminding
      // someone of something they have already done.
      expect(breakfast.hour, 8);
      expect(breakfast.minute, 45);
      expect(breakfast.source, ReminderSource.observed);
    });

    test('one odd hour does not move the time', () {
      final meals = [
        for (var d = 1; d <= 5; d++) at(d, 13, 0, MealSlot.lunch),
        // A single very late lunch. A mean would drag the reminder past 15:00.
        at(6, 22, 0, MealSlot.lunch),
      ];

      final lunch = only(ReminderSchedule.from(meals, now: now), MealSlot.lunch);
      expect(lunch.hour, 13);
      expect(lunch.minute, 45);
    });

    test('history older than the window is not learned from', () {
      final meals = [
        for (var d = 40; d <= 45; d++) at(d, 8, 0, MealSlot.breakfast),
      ];

      final breakfast =
          only(ReminderSchedule.from(meals, now: now), MealSlot.breakfast);
      expect(breakfast.source, ReminderSource.suggested);
    });

    test('a late dinner never rolls past midnight', () {
      final meals = [
        for (var d = 1; d <= 5; d++) at(d, 23, 40, MealSlot.dinner),
      ];

      // 23:40 + 45 is tomorrow, which is nobody's dinner reminder. The slot is
      // dropped rather than wrapped — and rather than falling back to the
      // suggested 19:30, which would be a reminder at an hour this person has
      // never once eaten at.
      final reminders = ReminderSchedule.from(meals, now: now);
      expect(reminders.map((r) => r.slot), isNot(contains(MealSlot.dinner)));
    });

    test('snacks never get one', () {
      final meals = [
        for (var d = 1; d <= 10; d++) at(d, 16, 0, MealSlot.snack),
      ];

      // A snack has no time of day worth predicting, and a fourth notification
      // is how people turn all of them off.
      final reminders = ReminderSchedule.from(meals, now: now);
      expect(reminders.map((r) => r.slot), isNot(contains(MealSlot.snack)));
    });
  });

  group('before there is a diary to learn from', () {
    test('an empty diary still gets all three reminders', () {
      final reminders = ReminderSchedule.from(const [], now: now);

      expect(reminders.map((r) => r.slot), ReminderSchedule.slots);
      expect(
        reminders.every((r) => r.source == ReminderSource.suggested),
        isTrue,
      );
    });

    test('two mornings is not a habit, so the time stays suggested', () {
      final meals = [
        for (var d = 1; d <= 5; d++) at(d, 19, 0, MealSlot.dinner),
        at(1, 8, 0, MealSlot.breakfast),
        at(2, 8, 0, MealSlot.breakfast),
      ];

      final reminders = ReminderSchedule.from(meals, now: now);
      // Below the sample floor the median is one or two mornings, which is a
      // habit the app invented. The suggested time at least does not claim to
      // be about this person.
      expect(only(reminders, MealSlot.breakfast).source,
          ReminderSource.suggested);
      expect(only(reminders, MealSlot.dinner).source, ReminderSource.observed);
    });

    test('a suggested time is the country pattern plus the same grace', () {
      const clock = MealClock(
        region: 'nowhere',
        breakfast: 8 * 60,
        lunch: 13 * 60,
        dinner: 19 * 60 + 30,
      );

      final reminders = ReminderSchedule.from(const [], clock: clock, now: now);

      // Both derived rungs say when someone *eats*, so both need turning into
      // a time to remind. Only a time the person typed is taken literally.
      for (final reminder in reminders) {
        expect(
          reminder.minuteOfDay,
          clock[reminder.slot] + ReminderSchedule.graceMinutes,
        );
      }
    });

    test('the country decides where a slot starts', () {
      List<int> at(String country) => ReminderSchedule.from(
            const [],
            clock: MealClock.forCountry(country),
            now: now,
          ).map((r) => r.minuteOfDay).toList();

      // The whole reason the table exists: one default cannot be right in both
      // of these places, and being two hours out is a reminder that arrives
      // after dinner or before anyone is hungry.
      expect(at('SE'), isNot(at('ES')));
      expect(at('SE').last, lessThan(at('ES').last));
      expect(at('PK').last, greaterThan(at('US').last));
    });
  });

  group('what the person asked for', () {
    test('a chosen time beats an observed one', () {
      final meals = [
        for (var d = 1; d <= 10; d++) at(d, 8, 0, MealSlot.breakfast),
      ];

      final breakfast = only(
        ReminderSchedule.from(
          meals,
          preferences:
              const ReminderPreferences(times: {MealSlot.breakfast: 6 * 60}),
          now: now,
        ),
        MealSlot.breakfast,
      );

      // Ten mornings of evidence, overruled. A time someone typed is a
      // statement of intent; the median is an inference about the past.
      expect(breakfast.hour, 6);
      expect(breakfast.minute, 0);
      expect(breakfast.source, ReminderSource.chosen);
    });

    test('a slot switched off is dropped', () {
      final reminders = ReminderSchedule.from(
        const [],
        preferences: const ReminderPreferences(off: {MealSlot.breakfast}),
        now: now,
      );

      expect(reminders.map((r) => r.slot), [MealSlot.lunch, MealSlot.dinner]);
    });

    test('preferences survive a JSON round trip', () {
      const before = ReminderPreferences(
        times: {MealSlot.breakfast: 7 * 60 + 15, MealSlot.dinner: 20 * 60},
        off: {MealSlot.lunch},
      );

      expect(ReminderPreferences.fromJson(before.toJson()), before);
    });

    test('a preferences blob from another build costs nobody a reminder', () {
      // Read on the path that also schedules. Anything unrecognised is dropped
      // rather than thrown, or a later build's extra key would silently mean
      // no notifications at all.
      final preferences = ReminderPreferences.fromJson(const {
        'times': {'breakfast': 480, 'brunch': 600, 'lunch': 99999},
        'off': ['dinner', 'elevenses'],
        'somethingNew': true,
      });

      expect(preferences.times, {MealSlot.breakfast: 480});
      expect(preferences.off, {MealSlot.dinner});
    });
  });

  group('a meal already logged today', () {
    test('is flagged so the scheduler can skip today', () {
      final meals = [
        for (var d = 1; d <= 5; d++) at(d, 8, 0, MealSlot.breakfast),
        // This morning's, already in the diary.
        at(0, 8, 5, MealSlot.breakfast),
      ];

      final reminders = ReminderSchedule.from(meals, now: now);
      // A reminder to log the breakfast you logged an hour ago is the one that
      // teaches people the notifications are not worth reading.
      expect(only(reminders, MealSlot.breakfast).loggedToday, isTrue);
      expect(only(reminders, MealSlot.lunch).loggedToday, isFalse);
    });

    test('still counts towards the median', () {
      final meals = [
        for (var d = 0; d <= 4; d++) at(d, 8, 0, MealSlot.breakfast),
      ];

      // Today's meal is evidence like any other; excluding it would need three
      // *previous* days rather than three.
      expect(only(ReminderSchedule.from(meals, now: now), MealSlot.breakfast)
          .source, ReminderSource.observed);
    });
  });
}
