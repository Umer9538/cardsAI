import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tailored prompts timed to a person's own meals raised food-photo capture
/// from 2.8 to 4.6 images a day (p≤.001). Generic fixed-time prompts produced
/// +0.83 at p=.23 — no effect. Fixed times would be shipping a measured null
/// result, and spending the notification permission to do it.
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

  test('reminders land after the usual time, not at it', () {
    final meals = [
      for (var d = 1; d <= 5; d++) at(d, 8, 0, MealSlot.breakfast),
    ];

    final reminders = ReminderSchedule.from(meals, now: now);
    expect(reminders.length, 1);
    // 08:00 + 45 minutes of grace. Reminding at the median is reminding
    // someone of something they have already done.
    expect(reminders.single.hour, 8);
    expect(reminders.single.minute, 45);
    expect(reminders.single.slot, MealSlot.breakfast);
  });

  test('one odd hour does not move the time', () {
    final meals = [
      for (var d = 1; d <= 5; d++) at(d, 13, 0, MealSlot.lunch),
      // A single very late lunch. A mean would drag the reminder past 15:00.
      at(6, 22, 0, MealSlot.lunch),
    ];

    final reminders = ReminderSchedule.from(meals, now: now);
    expect(reminders.single.hour, 13);
    expect(reminders.single.minute, 45);
  });

  test('a slot nobody logs gets no reminder', () {
    final meals = [
      for (var d = 1; d <= 5; d++) at(d, 19, 0, MealSlot.dinner),
      // Two breakfasts is not a habit, it is two mornings.
      at(1, 8, 0, MealSlot.breakfast),
      at(2, 8, 0, MealSlot.breakfast),
    ];

    final reminders = ReminderSchedule.from(meals, now: now);
    expect(reminders.map((r) => r.slot), [MealSlot.dinner]);
  });

  test('an empty diary asks for nothing', () {
    expect(ReminderSchedule.from(const [], now: now), isEmpty);
  });

  test('history older than the window is ignored', () {
    final meals = [
      for (var d = 40; d <= 45; d++) at(d, 8, 0, MealSlot.breakfast),
    ];
    expect(ReminderSchedule.from(meals, now: now), isEmpty);
  });

  test('snacks never get one', () {
    final meals = [
      for (var d = 1; d <= 10; d++) at(d, 16, 0, MealSlot.snack),
    ];
    // A snack has no time of day worth predicting, and a fourth notification is
    // how people turn all of them off.
    expect(ReminderSchedule.from(meals, now: now), isEmpty);
  });

  test('a late dinner never rolls past midnight', () {
    final meals = [
      for (var d = 1; d <= 5; d++) at(d, 23, 40, MealSlot.dinner),
    ];
    expect(ReminderSchedule.from(meals, now: now), isEmpty);
  });
}
