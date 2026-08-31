import 'package:flutter/foundation.dart';

import 'meal.dart';
import 'nutrition.dart';

/// One day of the diary: the meals logged against it and the targets they are
/// measured against.
///
/// Built by the diary repository rather than stored — it is a view over the
/// meals for a date, so there is nothing to keep in sync.
@immutable
class DailyLog {
  const DailyLog({
    required this.date,
    required this.meals,
    required this.targets,
  });

  /// Midnight local.
  final DateTime date;
  final List<Meal> meals;

  /// The day's goals, from the user's profile.
  final Nutrition targets;

  static DailyLog empty(DateTime date, Nutrition targets) => DailyLog(
        date: DateTime(date.year, date.month, date.day),
        meals: const [],
        targets: targets,
      );

  Nutrition get consumed => Nutrition.sum(meals.map((meal) => meal.nutrition));

  /// What is left of the calorie goal. Negative once the goal is passed, which
  /// the ring shows as an overage rather than clamping to zero.
  double get caloriesRemaining => targets.calories - consumed.calories;

  /// 0..1 for the ring. Clamped, because the arc cannot draw past full.
  double get calorieProgress {
    if (targets.calories <= 0) return 0;
    return (consumed.calories / targets.calories).clamp(0.0, 1.0);
  }

  /// 0..1 progress toward a macro goal, by selector.
  double progressOf(double Function(Nutrition) field) {
    final target = field(targets);
    if (target <= 0) return 0;
    return (field(consumed) / target).clamp(0.0, 1.0);
  }

  List<Meal> mealsIn(MealSlot slot) =>
      meals.where((meal) => meal.slot == slot).toList();

  bool get isEmpty => meals.isEmpty;

  /// A day counts toward the streak once it has two or more logged meals.
  bool get countsForStreak => meals.length >= 2;
}
