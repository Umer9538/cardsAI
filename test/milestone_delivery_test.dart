import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/activity_feed.dart';
import 'package:carbsai/core/notifications/notification_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which feed entries are allowed onto the lock screen, and why only those.
void main() {
  final now = DateTime(2026, 10, 6, 21);

  DailyLog log({int kcal = 0}) => DailyLog(
        date: DateTime(2026, 10, 6),
        meals: kcal == 0
            ? const []
            : [
                Meal(
                  id: 'm',
                  slot: MealSlot.dinner,
                  eatenAt: DateTime(2026, 10, 6, 19),
                  items: [
                    FoodItem(
                      id: 'f',
                      name: 'Dinner',
                      nutrition: Nutrition(calories: kcal.toDouble()),
                    ),
                  ],
                )
              ],
        targets: const Nutrition(calories: 2000),
      );

  List<AppNotification> feed({int streak = 0}) => ActivityFeed.build(
        now: now,
        settings: {
          for (final c in NotificationCategory.values) c.key: true,
        },
        today: log(kcal: 1900),
        yesterday: log(kcal: 1950),
        streakDays: streak,
      );

  test('a streak milestone is categorised so it can be delivered', () {
    final milestones = feed(streak: 7)
        .where((e) => e.category == NotificationCategory.goalMilestones);

    // The category used to be decided by ActivityFeed and then dropped on the
    // floor — the entry carried no record of which switch had let it through,
    // so the delivery layer could not tell a streak from a lunch nudge.
    expect(milestones, isNotEmpty);
    expect(milestones.first.body, contains('7'));
  });

  test('progress entries are not milestones', () {
    // They carry a live figure, which is wrong the moment anything else is
    // logged — so they stay in the app, and the scheduled nightly nudge
    // carries no number at all.
    final progress = feed()
        .where((e) => e.category == NotificationCategory.progressSummary);
    expect(progress, isNotEmpty);
    for (final entry in progress) {
      expect(entry.category, isNot(NotificationCategory.goalMilestones));
    }
  });

  test('the notification id is stable and clear of the reminder ids', () {
    const id = 'streak-2026-10-06';
    expect(ActivityFeed.notificationId(id), ActivityFeed.notificationId(id));
    // Meals are 100-102, the weigh-in 200, the summary 201, water from 300.
    expect(ActivityFeed.notificationId(id), greaterThanOrEqualTo(1000));
  });

  test('different entries get different ids', () {
    expect(
      ActivityFeed.notificationId('streak-2026-10-06'),
      isNot(ActivityFeed.notificationId('goal-2026-10-06')),
    );
  });

  test('the category survives the JSON round trip', () {
    final entry = AppNotification(
      id: 'streak-2026-10-06',
      body: '7 days in a row.',
      createdAt: now,
      category: NotificationCategory.goalMilestones,
    );

    // Delivery reads it back off a stored entry, so losing it in storage would
    // silently stop every milestone reaching the lock screen.
    expect(
      AppNotification.fromJson(entry.toJson()).category,
      NotificationCategory.goalMilestones,
    );
    // And an entry written before the field existed must not throw.
    expect(
      AppNotification.fromJson(const {
        'id': 'old',
        'body': 'x',
        'createdAt': '2026-01-01T00:00:00.000',
      }).category,
      isNull,
    );
  });
}
