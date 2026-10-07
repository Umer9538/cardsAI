import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/activity_feed.dart';
import 'package:carbsai/core/notifications/notification_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every entry in the feed is a judgement about someone's day, so each one is
/// stated exactly here rather than inferred from a render.

const _targets = Nutrition(calories: 2000, protein: 150, carbs: 200, fat: 60);

Map<String, bool> _allOn() => {
      for (final c in NotificationCategory.values) c.key: true,
    };

Meal _meal(MealSlot slot, DateTime at, {double calories = 500}) => Meal(
      id: '${slot.name}-${at.millisecondsSinceEpoch}',
      slot: slot,
      eatenAt: at,
      items: [
        FoodItem(
          id: '${slot.name}-item',
          name: slot.name,
          nutrition: Nutrition(
            calories: calories,
            protein: 30,
            carbs: 40,
            fat: 15,
          ),
        ),
      ],
    );

DailyLog _log(DateTime day, List<Meal> meals) =>
    DailyLog(date: day, meals: meals, targets: _targets);

List<String> _ids(List<AppNotification> entries) =>
    [for (final e in entries) e.id];

void main() {
  final today = DateTime(2026, 9, 22);
  final yesterday = DateTime(2026, 9, 21);

  group('new account', () {
    test('sees a welcome and nothing else', () {
      final entries = ActivityFeed.build(
        now: today.add(const Duration(hours: 21)),
        settings: _allOn(),
        today: _log(today, const []),
        yesterday: _log(yesterday, const []),
        hasEverLogged: false,
      );

      expect(entries.length, 1);
      expect(entries.single.body, contains('Welcome'));
    });

    test('welcome ignores the category switches, having none', () {
      final entries = ActivityFeed.build(
        now: today,
        settings: const {},
        today: _log(today, const []),
        yesterday: _log(yesterday, const []),
        hasEverLogged: false,
      );
      expect(entries, hasLength(1));
    });
  });

  group('progress', () {
    test('on track inside 80–110% of the target', () {
      final entries = ActivityFeed.build(
        now: today.add(const Duration(hours: 12)),
        settings: _allOn(),
        today: _log(today, [
          _meal(MealSlot.breakfast, today.add(const Duration(hours: 8)),
              calories: 900),
          _meal(MealSlot.lunch, today.add(const Duration(hours: 12)),
              calories: 800),
        ]),
        yesterday: _log(yesterday, const []),
      );

      expect(_ids(entries), contains('ontrack-2026-09-22'));
    });

    test('says nothing when the day is only half eaten', () {
      final entries = ActivityFeed.build(
        now: today.add(const Duration(hours: 12)),
        settings: _allOn(),
        today: _log(today, [
          _meal(MealSlot.breakfast, today.add(const Duration(hours: 8)),
              calories: 400),
        ]),
        yesterday: _log(yesterday, const []),
      );

      expect(_ids(entries).where((id) => id.startsWith('ontrack')), isEmpty);
    });

    test('says nothing when the target is passed — no scolding', () {
      final entries = ActivityFeed.build(
        now: today.add(const Duration(hours: 21)),
        settings: _allOn(),
        today: _log(today, [
          _meal(MealSlot.dinner, today.add(const Duration(hours: 19)),
              calories: 3000),
        ]),
        yesterday: _log(yesterday, const []),
      );

      expect(_ids(entries).where((id) => id.startsWith('ontrack')), isEmpty);
    });

    test('recaps yesterday only when something was logged', () {
      final withFood = ActivityFeed.build(
        now: today,
        settings: _allOn(),
        today: _log(today, const []),
        yesterday: _log(yesterday, [
          _meal(MealSlot.dinner, yesterday.add(const Duration(hours: 19))),
        ]),
      );
      expect(_ids(withFood), contains('yesterday-2026-09-22'));

      final empty = ActivityFeed.build(
        now: today,
        settings: _allOn(),
        today: _log(today, const []),
        yesterday: _log(yesterday, const []),
      );
      expect(_ids(empty).where((id) => id.startsWith('yesterday')), isEmpty);
    });
  });

  group('meal nudges', () {
    test('lunch is mentioned after 14:00 and not before', () {
      List<String> at(int hour) => _ids(ActivityFeed.build(
            now: today.add(Duration(hours: hour)),
            settings: _allOn(),
            today: _log(today, const []),
            yesterday: _log(yesterday, const []),
          ));

      expect(at(13).where((id) => id.startsWith('nudge-lunch')), isEmpty);
      expect(at(14), contains('nudge-lunch-2026-09-22'));
    });

    test('a logged lunch is never nudged', () {
      final entries = ActivityFeed.build(
        now: today.add(const Duration(hours: 16)),
        settings: _allOn(),
        today: _log(today, [
          _meal(MealSlot.lunch, today.add(const Duration(hours: 13))),
        ]),
        yesterday: _log(yesterday, const []),
      );

      expect(_ids(entries).where((id) => id.startsWith('nudge-lunch')), isEmpty);
    });
  });

  group('milestones', () {
    test('only the listed streak lengths are celebrated', () {
      List<String> at(int days) => _ids(ActivityFeed.build(
            now: today,
            settings: _allOn(),
            today: _log(today, const []),
            yesterday: _log(yesterday, const []),
            streakDays: days,
          ));

      expect(at(7), contains('streak-7-2026-09-22'));
      expect(at(6).where((id) => id.startsWith('streak')), isEmpty);
    });

    test('goal weight is judged on the trend, not the last reading', () {
      // Latest reading is on the goal, but the trend is not — a kilo of water
      // is not an achievement, and saying so teaches people to distrust it.
      final history = WeightHistory([
        for (var i = 6; i >= 1; i--)
          WeightEntry(
            id: '$i',
            at: today.subtract(Duration(days: i)),
            kg: 78,
          ),
        WeightEntry(id: '0', at: today, kg: 70),
      ]);

      final entries = ActivityFeed.build(
        now: today,
        settings: _allOn(),
        today: _log(today, const []),
        yesterday: _log(yesterday, const []),
        weight: history,
        goalWeightKg: 70,
      );

      expect(_ids(entries).where((id) => id.startsWith('goal-weight')), isEmpty);
    });
  });

  group('categories', () {
    test('a switched-off category posts nothing', () {
      final settings = {
        ..._allOn(),
        NotificationCategory.progressSummary.key: false,
      };

      final entries = ActivityFeed.build(
        now: today,
        settings: settings,
        today: _log(today, const []),
        yesterday: _log(yesterday, [
          _meal(MealSlot.dinner, yesterday.add(const Duration(hours: 19))),
        ]),
      );

      expect(_ids(entries).where((id) => id.startsWith('yesterday')), isEmpty);
    });

    test('an unknown key is off, so a new category cannot post unasked', () {
      expect(NotificationCategory.progressSummary.isOn(const {}), isFalse);
    });

    test('every category key is distinct and stored under its own name', () {
      final keys = {for (final c in NotificationCategory.values) c.key};
      expect(keys.length, NotificationCategory.values.length);
    });
  });

  test('ids are stable across runs, so read state survives a recompute', () {
    List<String> run() => _ids(ActivityFeed.build(
          now: today.add(const Duration(hours: 15)),
          settings: _allOn(),
          today: _log(today, const []),
          yesterday: _log(yesterday, const []),
          streakDays: 7,
        ));

    expect(run(), run());
    expect(run(), isNotEmpty);
  });
}
