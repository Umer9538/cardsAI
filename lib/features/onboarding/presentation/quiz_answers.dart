import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/nutrition/target_calculator.dart';

/// What the quiz has collected so far.
///
/// Held separately from [UserProfile] because a half-answered quiz is not a
/// profile: the sliders need a sensible starting position before anyone has
/// touched them, while the choices must stay null so the Next button can tell
/// "not answered yet" from "answered with the default".
@immutable
class QuizAnswers {
  const QuizAnswers({
    this.gender,
    this.age = 30,
    this.heightCm = 170,
    this.weightKg = 70,
    this.activity,
    this.goal,
    this.goalWeightKg,
    this.weeklyRateKg = 0.5,
    this.motivation,
    this.dietPreference,
    this.mealsPerDay = 3,
    this.obstacle,
    this.wantsReminders = true,
  });

  final Gender? gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel? activity;
  final WeightGoal? goal;
  final double? goalWeightKg;
  final double weeklyRateKg;
  final Motivation? motivation;
  final DietPreference? dietPreference;
  final int mealsPerDay;
  final Obstacle? obstacle;
  final bool wantsReminders;

  QuizAnswers copyWith({
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    WeightGoal? goal,
    double? goalWeightKg,
    double? weeklyRateKg,
    Motivation? motivation,
    DietPreference? dietPreference,
    int? mealsPerDay,
    Obstacle? obstacle,
    bool? wantsReminders,
  }) =>
      QuizAnswers(
        gender: gender ?? this.gender,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activity: activity ?? this.activity,
        goal: goal ?? this.goal,
        goalWeightKg: goalWeightKg ?? this.goalWeightKg,
        weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
        motivation: motivation ?? this.motivation,
        dietPreference: dietPreference ?? this.dietPreference,
        mealsPerDay: mealsPerDay ?? this.mealsPerDay,
        obstacle: obstacle ?? this.obstacle,
        wantsReminders: wantsReminders ?? this.wantsReminders,
      );

  /// Enough answered to compute a target, which is what the running estimate
  /// waits for before it appears.
  bool get canEstimate => activity != null && goal != null;

  /// A profile to compute against, so the plan screen can show real numbers
  /// before anything is saved.
  ///
  /// Age is stored as a date of birth because that is what the profile holds —
  /// the 1 January is a deliberate approximation, and the only thing that reads
  /// it back is the age calculation it came from.
  UserProfile applyTo(UserProfile base) {
    final goalWeight = goal == WeightGoal.maintain ? null : goalWeightKg;
    final draft = base.copyWith(
      dateOfBirth: DateTime(DateTime.now().year - age, 1, 1),
      gender: gender ?? Gender.unspecified,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activity,
      goal: goal,
      goalWeightKg: goalWeight,
      weeklyRateKg: weeklyRateKg,
      motivation: motivation,
      dietPreference: dietPreference,
      mealsPerDay: mealsPerDay,
      obstacle: obstacle,
      wantsReminders: wantsReminders,
    );
    return draft.copyWith(targets: TargetCalculator.forProfile(draft));
  }
}
