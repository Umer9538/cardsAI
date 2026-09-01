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
  });

  final Gender? gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel? activity;
  final WeightGoal? goal;
  final double? goalWeightKg;
  final double weeklyRateKg;

  QuizAnswers copyWith({
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    WeightGoal? goal,
    double? goalWeightKg,
    double? weeklyRateKg,
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
      );

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
    );
    return draft.copyWith(targets: TargetCalculator.forProfile(draft));
  }
}
