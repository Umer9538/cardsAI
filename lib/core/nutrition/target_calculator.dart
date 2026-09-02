import 'dart:math' as math;

import '../models/models.dart';

/// Turns a profile into the daily calorie and macro goals the whole app counts
/// against.
///
/// This is the same pipeline MyFitnessPal, Lose It and Cal AI run, and it is
/// deliberately a pure function of a [UserProfile] — no providers, no clock, no
/// I/O — because it is the one piece of this app whose correctness can be
/// checked exactly, and every number the user sees on Home depends on it.
///
/// ```
///   Mifflin-St Jeor BMR  ->  x activity  ->  +/- goal  ->  macro split
/// ```
///
/// Mifflin-St Jeor rather than Harris-Benedict: it is the more accurate of the
/// two on modern populations and is what the field has standardised on.
abstract final class TargetCalculator {
  /// kcal in a kilogram of body mass. The conventional figure, and the one
  /// every "0.5 kg a week" recommendation is derived from.
  static const double kcalPerKg = 7700;

  /// The most a target may sit below maintenance, as a share of it.
  ///
  /// A percentage rather than a fixed number because 500 kcal off a small
  /// person is a far more aggressive cut than 500 off a large one. This is the
  /// guard that stops a low bodyweight plus an ambitious rate producing a
  /// number nobody should eat to.
  static const double maxDeficitFraction = 0.25;

  /// Absolute floors, whatever the arithmetic says.
  static const double minCaloriesFemale = 1200;
  static const double minCaloriesMale = 1500;

  /// The lowest BMI this app will help anyone aim for.
  ///
  /// 18.5 is the bottom of the WHO healthy range. It is here as a hard floor
  /// rather than a suggestion because the goal-weight slider previously ran
  /// down to 35 kg for everyone: at 175 cm that is a BMI of 11.4, and the plan
  /// screen would then affirm it with a date — "On track for 35 kg by 14 March
  /// 2027." Google Play's Inappropriate Content policy names apps that promote
  /// eating disorders as a **removal** category, not a rating one, and an app
  /// endorsing an underweight target with a completion date is squarely that.
  ///
  /// Presented as our own guardrail, never as clinical advice — see the note on
  /// [minCaloriesFemale].
  static const double minHealthyBmi = 18.5;

  /// The lowest goal weight offered for someone [heightCm] tall, kg.
  ///
  /// Rounded up to the next 0.5 kg so the slider lands on a value it can
  /// actually represent, and so the floor is never crossed by rounding down.
  static double healthyGoalFloorKg(double heightCm) {
    final metres = heightCm / 100;
    final raw = minHealthyBmi * metres * metres;
    return (raw * 2).ceilToDouble() / 2;
  }

  /// True when [goalWeightKg] is below the healthy floor for [heightCm].
  ///
  /// The slider cannot produce one, but a profile saved before the floor
  /// existed can, so everything that renders a goal checks this rather than
  /// trusting the input.
  static bool isGoalBelowHealthyFloor({
    required double goalWeightKg,
    required double heightCm,
  }) =>
      goalWeightKg < healthyGoalFloorKg(heightCm);

  /// Grams per kg of bodyweight. Protein at the upper end of the ordinary
  /// recommendation because it is the macro that best preserves muscle in a
  /// deficit and the one people under-eat; fat at the low end of adequate,
  /// leaving carbohydrate as the remainder rather than a target of its own.
  static const double proteinPerKg = 1.8;
  static const double fatPerKg = 0.9;

  /// Basal metabolic rate, kcal/day.
  ///
  /// The constant is the only place sex enters the equation: +5 for male, -161
  /// for female. [Gender.other] and [Gender.unspecified] take the midpoint,
  /// which is the honest answer when the input is genuinely unknown — better
  /// than silently assuming one or the other.
  static double basalRate({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return base +
        switch (gender) {
          Gender.male => 5,
          Gender.female => -161,
          Gender.other || Gender.unspecified => -78,
        };
  }

  /// Maintenance calories — BMR scaled by how much the person moves.
  static double maintenance(UserProfile profile) {
    final bmr = basalRate(
      weightKg: profile.weightKg!,
      heightCm: profile.heightCm!,
      age: profile.age!,
      gender: profile.gender,
    );
    return bmr * (profile.activityLevel ?? ActivityLevel.sedentary).multiplier;
  }

  /// The daily goals for [profile], or [UserProfile.defaultTargets] when there
  /// is not enough information to compute them.
  ///
  /// Returning the shared default rather than throwing keeps every screen free
  /// of "targets unknown" handling: a profile that skipped the quiz still has a
  /// number, it is just not personal to them.
  static Nutrition forProfile(UserProfile profile) {
    if (!profile.canPersonaliseTargets) return UserProfile.defaultTargets;

    final tdee = maintenance(profile);
    final weight = profile.weightKg!;

    // A rate is kilograms per week; the daily calorie change is that mass in
    // energy, spread over seven days.
    final dailyChange = (profile.weeklyRateKg.abs() * kcalPerKg) / 7;

    var calories = switch (profile.goal!) {
      WeightGoal.lose => tdee - math.min(dailyChange, tdee * maxDeficitFraction),
      WeightGoal.gain => tdee + dailyChange,
      WeightGoal.maintain => tdee,
    };

    final floor = profile.gender == Gender.male
        ? minCaloriesMale
        : minCaloriesFemale;
    calories = math.max(calories, floor);

    // Protein and fat are set from bodyweight, and carbohydrate takes whatever
    // energy is left. Doing it the other way round — fixed macro percentages —
    // gives a very light person too little protein and a very heavy one more
    // than they can use.
    final protein = proteinPerKg * weight;
    final fat = fatPerKg * weight;
    final carbs = math.max(0.0, (calories - protein * 4 - fat * 9) / 4);

    return Nutrition(
      calories: _round(calories),
      protein: _round(protein),
      carbs: _round(carbs),
      fat: _round(fat),
    );
  }

  /// The date [profile] reaches its goal weight at its chosen rate, or null
  /// when it is not heading anywhere.
  ///
  /// Shown on the plan screen. It is arithmetic, not a promise, and the copy
  /// around it says so.
  static DateTime? goalDate(UserProfile profile, {DateTime? from}) {
    final goal = profile.goal;
    final target = profile.goalWeightKg;
    final weight = profile.weightKg;
    if (goal == null || goal == WeightGoal.maintain) return null;
    if (target == null || weight == null || profile.weeklyRateKg <= 0) {
      return null;
    }

    // Never put a date on an underweight target. A projection is the app
    // agreeing with the goal, and there is one goal it must not agree with.
    final height = profile.heightCm;
    if (height != null &&
        isGoalBelowHealthyFloor(goalWeightKg: target, heightCm: height)) {
      return null;
    }

    final delta = (target - weight).abs();
    if (delta < 0.1) return null;

    final weeks = delta / profile.weeklyRateKg;
    return (from ?? DateTime.now()).add(Duration(days: (weeks * 7).round()));
  }

  /// Whole numbers everywhere: a goal of 2147.3 kcal implies a precision the
  /// estimate behind it does not have.
  static double _round(double value) => value.roundToDouble();
}
