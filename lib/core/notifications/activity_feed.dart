import '../models/models.dart';
import 'notification_category.dart';

/// Builds the in-app notification feed out of what the person actually did.
///
/// Before this, the feed was seven strings from `SeedData` — every account saw
/// the same fake messages an hour apart, including a hydration tip for a
/// feature the app does not have. A feed that cannot be acted on is decoration,
/// and decoration next to real numbers is what makes the real numbers look
/// invented too.
///
/// Pure, like [ReminderSchedule] and `TargetCalculator`, and for the same
/// reason: everything here is a judgement about someone's day, so it is worth
/// being able to state each one exactly in a test rather than inferring it
/// from a render.
///
/// Every entry carries a **stable, date-keyed id** (`progress-2026-09-22`), so
/// recomputing the feed re-derives the same entry rather than posting a
/// duplicate, and the read flag stored against that id survives.
abstract final class ActivityFeed {
  /// Calorie band that counts as on track for the day. Below it the day is
  /// unfinished rather than missed, and above 110% the app says nothing —
  /// see [_progress].
  static const double onTrackLow = 0.8;
  static const double onTrackHigh = 1.1;

  /// Hour after which an unlogged lunch is worth mentioning, and the same for
  /// dinner. Both are late enough to be past the meal for almost everyone —
  /// a nudge that arrives before you have eaten is a nag.
  static const int lunchNudgeHour = 14;
  static const int dinnerNudgeHour = 20;

  /// Streak lengths worth saying something about. Every day would be noise.
  static const List<int> streakMilestones = [3, 7, 14, 30, 60, 100];

  /// A stable notification id for a feed entry.
  ///
  /// Android keys a notification by int, and the feed keys an entry by a
  /// date-stamped string. Hashing one onto the other means the same milestone
  /// always lands on the same notification id, so it replaces itself instead
  /// of stacking — and it cannot collide with the reminder ids, which are the
  /// small fixed numbers 100-199.
  static int notificationId(String entryId) =>
      1000 + (entryId.hashCode.abs() % 100000);

  static List<AppNotification> build({
    required DateTime now,
    required Map<String, bool> settings,
    required DailyLog today,
    required DailyLog yesterday,
    int streakDays = 0,
    WeightHistory? weight,
    double? goalWeightKg,
    String? suggestedPlanName,
    bool hasEverLogged = true,
  }) {
    final entries = <AppNotification>[];

    void add(
      NotificationCategory? category,
      String idPrefix,
      String body, {
      DateTime? at,
    }) {
      if (category != null && !category.isOn(settings)) return;
      entries.add(
        AppNotification(
          id: '$idPrefix-${_dayKey(at ?? now)}',
          body: body,
          createdAt: at ?? now,
          category: category,
        ),
      );
    }

    // Uncategorised on purpose: it is the first thing a new account sees and
    // there is no preference it could sensibly hang off.
    if (!hasEverLogged) {
      add(
        null,
        'welcome',
        'Welcome to Carbs AI. Snap your first meal and the numbers start '
            'filling themselves in.',
      );
      return entries;
    }

    _progress(add, now, today, yesterday);
    _mealNudges(add, now, today);
    _milestones(add, now, streakDays, weight, goalWeightKg);

    if (suggestedPlanName != null) {
      add(
        NotificationCategory.planSuggestions,
        'plan',
        '$suggestedPlanName looks like a fit for your targets. Take a look '
            'in Diets.',
      );
    }

    return entries;
  }

  static void _progress(
    void Function(NotificationCategory?, String, String, {DateTime? at}) add,
    DateTime now,
    DailyLog today,
    DailyLog yesterday,
  ) {
    final target = today.targets.calories;
    if (target > 0) {
      final ratio = today.consumed.calories / target;
      // Only the on-track band gets a message. Under it the day is simply not
      // finished, and over it the honest options are silence or a scolding —
      // and a tracker that tells people off about food is the one they delete.
      if (ratio >= onTrackLow && ratio <= onTrackHigh) {
        add(
          NotificationCategory.progressSummary,
          'ontrack',
          'You are on track — ${today.consumed.calories.round()} of '
              '${target.round()} kcal today.',
        );
      }
    }

    if (yesterday.meals.isNotEmpty) {
      final eaten = yesterday.consumed;
      add(
        NotificationCategory.progressSummary,
        'yesterday',
        'Yesterday: ${eaten.calories.round()} kcal across '
            '${yesterday.meals.length} '
            '${yesterday.meals.length == 1 ? 'meal' : 'meals'}, '
            '${eaten.protein.round()}g protein.',
      );
    }
  }

  static void _mealNudges(
    void Function(NotificationCategory?, String, String, {DateTime? at}) add,
    DateTime now,
    DailyLog today,
  ) {
    bool logged(MealSlot slot) =>
        today.meals.any((meal) => meal.slot == slot);

    if (now.hour >= lunchNudgeHour && !logged(MealSlot.lunch)) {
      add(
        NotificationCategory.mealReminders,
        'nudge-lunch',
        'Lunch is not logged yet. Adding it keeps today\'s numbers honest.',
      );
    }
    if (now.hour >= dinnerNudgeHour && !logged(MealSlot.dinner)) {
      add(
        NotificationCategory.mealReminders,
        'nudge-dinner',
        'Dinner is not logged yet — it takes about ten seconds.',
      );
    }
  }

  static void _milestones(
    void Function(NotificationCategory?, String, String, {DateTime? at}) add,
    DateTime now,
    int streakDays,
    WeightHistory? weight,
    double? goalWeightKg,
  ) {
    if (streakMilestones.contains(streakDays)) {
      add(
        NotificationCategory.goalMilestones,
        'streak-$streakDays',
        '$streakDays days logged in a row. That consistency is the whole '
            'game.',
      );
    }

    // Weight milestones speak in trend, never the last reading — a kilo of
    // water is not progress and telling someone it is teaches them to
    // distrust the number. Neither direction is congratulated or scolded:
    // the app does not know whether they are cutting or gaining.
    final trend = weight?.trendKg;
    final goal = goalWeightKg;
    if (trend != null && goal != null) {
      final remaining = (trend - goal).abs();
      if (remaining <= 0.5) {
        add(
          NotificationCategory.goalMilestones,
          'goal-weight',
          'Your trend weight has reached your goal of '
              '${goal.toStringAsFixed(1)} kg.',
        );
      }
    }
  }

  static String _dayKey(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}
