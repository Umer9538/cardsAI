import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the notification actually says.
///
/// Reviewers of this category describe guilt-worded reminders — a mascot
/// pleading, a streak about to break — as the reason they turned notifications
/// off for good, and a notification nobody receives is worth less than none.
/// The other failure is quieter: the identical sentence at the identical time
/// becomes furniture inside a week and stops being read at all.
void main() {
  /// Every line the app can put on a lock screen, across a year.
  List<String> allBodies(MealSlot slot) => [
        for (var day = 0; day < 366; day++)
          ReminderSchedule.body(slot, on: DateTime(2026).add(Duration(days: day))),
      ];

  test('it rotates rather than repeating one line forever', () {
    for (final slot in ReminderSchedule.slots) {
      expect(allBodies(slot).toSet().length, greaterThan(1), reason: slot.name);
    }
  });

  test('the same day always says the same thing', () {
    // A pure function of the date, not a shuffle: two reschedules on one day —
    // opening the app, then logging lunch — must not rewrite the evening's
    // notification into something different.
    final morning = ReminderSchedule.body(
      MealSlot.dinner,
      on: DateTime(2026, 6, 14, 7),
    );
    final evening = ReminderSchedule.body(
      MealSlot.dinner,
      on: DateTime(2026, 6, 14, 22),
    );
    expect(morning, evening);
  });

  test('every line names the meal it is about, or the action', () {
    for (final slot in ReminderSchedule.slots) {
      for (final body in allBodies(slot).toSet()) {
        final lower = body.toLowerCase();
        expect(
          lower.contains(slot.name) ||
              lower.contains('photo') ||
              lower.contains('snap') ||
              lower.contains('camera'),
          isTrue,
          reason: 'says nothing useful: "$body"',
        );
      }
    }
  });

  test('nothing scolds, counts or shouts', () {
    // Each of these is a habit-app cliché that costs the notification
    // permission outright. There is no streak to break here and no number that
    // would still be true by the time the notification fires — the OS holds
    // the text of a repeating notification until something reschedules it.
    const forbidden = [
      'streak', 'don’t', "don't", 'missed', 'forgot', 'behind',
      // Bare "still" is not the problem — "still on the plate" is fine. The
      // scolding constructions are.
      'still not', 'still haven', 'failed', 'oops', 'hurry',
      'last chance', 'you should', '!',
    ];
    for (final slot in MealSlot.values) {
      for (final body in allBodies(slot).toSet()) {
        for (final word in forbidden) {
          expect(
            body.toLowerCase().contains(word),
            isFalse,
            reason: '"$body" contains "$word"',
          );
        }
      }
      expect(ReminderSchedule.title(slot), isNot(contains('!')));
    }
  });

  test('a line fits a lock screen', () {
    for (final slot in MealSlot.values) {
      for (final body in allBodies(slot).toSet()) {
        // Android collapses to roughly one line; BigTextStyle expands it, but
        // the collapsed line is the one most people ever read.
        expect(body.length, lessThanOrEqualTo(60), reason: body);
        expect(body, endsWith('.'));
      }
      expect(ReminderSchedule.title(slot).length, lessThanOrEqualTo(12));
    }
  });

  test('the title is the meal and not the app name', () {
    // Android prints the app name above the title and iOS beside it, so a
    // title of "Carbs AI — Lunch" says Carbs AI twice.
    for (final slot in MealSlot.values) {
      expect(ReminderSchedule.title(slot).toLowerCase(), isNot(contains('carbsai')));
    }
    expect(ReminderSchedule.title(MealSlot.lunch), 'Lunch');
  });
}
