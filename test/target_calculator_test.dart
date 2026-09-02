import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/target_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The calorie target is the app's central claim — the ring on Home, the macro
/// cards, and every "remaining" figure count against it. It is also the only
/// part of this app that is a pure function, so it is the only part that can be
/// checked exactly rather than eyeballed against a render.
UserProfile profileOf({
  double weightKg = 80,
  double heightCm = 180,
  int age = 30,
  Gender gender = Gender.male,
  ActivityLevel? activity = ActivityLevel.moderate,
  WeightGoal? goal = WeightGoal.maintain,
  double weeklyRateKg = 0.5,
  double? goalWeightKg,
}) {
  final now = DateTime.now();
  return UserProfile(
    id: 'u1',
    name: 'Test',
    email: 't@example.com',
    // Mid-year so the birthday has always passed and `age` is exact.
    dateOfBirth: DateTime(now.year - age, 1, 1),
    gender: gender,
    heightCm: heightCm,
    weightKg: weightKg,
    activityLevel: activity,
    goal: goal,
    goalWeightKg: goalWeightKg,
    weeklyRateKg: weeklyRateKg,
  );
}

void main() {
  // The goal-weight slider ran from 35 kg for everyone, so a 175 cm user could
  // set a BMI-11.4 target and the plan screen would then affirm it with a date.
  // Play treats an app that promotes eating disorders as a removal category.
  group('healthy goal floor', () {
    test('is BMI 18.5 for the entered height', () {
      // 18.5 * 1.75^2 = 56.66 -> rounded up to the next half kilo.
      expect(TargetCalculator.healthyGoalFloorKg(175), 57.0);
      // 18.5 * 1.50^2 = 41.625
      expect(TargetCalculator.healthyGoalFloorKg(150), 42.0);
      // 18.5 * 1.90^2 = 66.785
      expect(TargetCalculator.healthyGoalFloorKg(190), 67.0);
    });

    test('rounds up, never down, so the floor is not crossed by rounding', () {
      for (var h = 120.0; h <= 220.0; h += 1) {
        final floor = TargetCalculator.healthyGoalFloorKg(h);
        final bmi = floor / ((h / 100) * (h / 100));
        expect(bmi, greaterThanOrEqualTo(TargetCalculator.minHealthyBmi),
            reason: '$h cm -> $floor kg is BMI $bmi');
      }
    });

    test('35 kg at 175 cm is below the floor', () {
      expect(
        TargetCalculator.isGoalBelowHealthyFloor(
            goalWeightKg: 35, heightCm: 175),
        isTrue,
      );
    });

    test('no goal date is offered for an underweight target', () {
      // A profile saved before the floor existed can still carry one.
      final profile = profileOf(
        heightCm: 175,
        weightKg: 80,
        goal: WeightGoal.lose,
        goalWeightKg: 35,
      );
      expect(TargetCalculator.goalDate(profile), isNull);
    });

    test('a healthy target still gets its date', () {
      final profile = profileOf(
        heightCm: 175,
        weightKg: 80,
        goal: WeightGoal.lose,
        goalWeightKg: 70,
      );
      expect(TargetCalculator.goalDate(profile), isNotNull);
    });
  });

  group('Mifflin-St Jeor', () {
    test('male constant is +5', () {
      // 10*80 + 6.25*180 - 5*30 + 5
      expect(
        TargetCalculator.basalRate(
          weightKg: 80,
          heightCm: 180,
          age: 30,
          gender: Gender.male,
        ),
        closeTo(1780, 0.01),
      );
    });

    test('female constant is -161', () {
      // 10*60 + 6.25*165 - 5*30 - 161
      expect(
        TargetCalculator.basalRate(
          weightKg: 60,
          heightCm: 165,
          age: 30,
          gender: Gender.female,
        ),
        closeTo(1320.25, 0.01),
      );
    });

    test('unspecified sits midway between the two, rather than guessing', () {
      final male = TargetCalculator.basalRate(
          weightKg: 70, heightCm: 170, age: 30, gender: Gender.male);
      final female = TargetCalculator.basalRate(
          weightKg: 70, heightCm: 170, age: 30, gender: Gender.female);
      final unknown = TargetCalculator.basalRate(
          weightKg: 70, heightCm: 170, age: 30, gender: Gender.unspecified);

      expect(unknown, closeTo((male + female) / 2, 0.01));
    });
  });

  group('maintenance', () {
    test('scales BMR by the activity multiplier', () {
      expect(
        TargetCalculator.maintenance(profileOf()),
        closeTo(1780 * 1.55, 0.01),
      );
    });

    test('a more active profile always needs more', () {
      var previous = 0.0;
      for (final level in ActivityLevel.values) {
        final value =
            TargetCalculator.maintenance(profileOf(activity: level));
        expect(value, greaterThan(previous));
        previous = value;
      }
    });
  });

  group('forProfile', () {
    test('maintain returns maintenance', () {
      final targets = TargetCalculator.forProfile(profileOf());
      expect(targets.calories, closeTo(1780 * 1.55, 1));
    });

    test('losing 0.5kg a week is 550 kcal off maintenance', () {
      // 0.5 kg * 7700 kcal/kg / 7 days
      final targets =
          TargetCalculator.forProfile(profileOf(goal: WeightGoal.lose));
      expect(targets.calories, closeTo(1780 * 1.55 - 550, 1));
    });

    test('gaining adds the same amount', () {
      final targets =
          TargetCalculator.forProfile(profileOf(goal: WeightGoal.gain));
      expect(targets.calories, closeTo(1780 * 1.55 + 550, 1));
    });

    test('the deficit is capped at a quarter of maintenance', () {
      // A small person with an aggressive rate: the raw subtraction would take
      // more than a quarter off, which is exactly the case the cap exists for.
      final profile = profileOf(
        weightKg: 50,
        heightCm: 155,
        age: 25,
        gender: Gender.female,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
        weeklyRateKg: 1.5,
      );
      final tdee = TargetCalculator.maintenance(profile);
      final targets = TargetCalculator.forProfile(profile);

      expect(targets.calories, greaterThanOrEqualTo(tdee * 0.75 - 1));
    });

    test('never returns a target below the floor for that sex', () {
      final targets = TargetCalculator.forProfile(profileOf(
        weightKg: 42,
        heightCm: 148,
        age: 60,
        gender: Gender.female,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
        weeklyRateKg: 1.0,
      ));
      expect(targets.calories, greaterThanOrEqualTo(1200));
    });

    test('macros account for the calories they are derived from', () {
      final targets = TargetCalculator.forProfile(profileOf());
      final atwater =
          targets.protein * 4 + targets.carbs * 4 + targets.fat * 9;
      // Rounding to whole grams moves this a little; anything larger means the
      // split and the total have come apart.
      expect(atwater, closeTo(targets.calories, 12));
    });

    test('protein and fat scale with bodyweight, not with calories', () {
      final light = TargetCalculator.forProfile(profileOf(weightKg: 55));
      final heavy = TargetCalculator.forProfile(profileOf(weightKg: 95));

      expect(light.protein, closeTo(55 * 1.8, 1));
      expect(heavy.protein, closeTo(95 * 1.8, 1));
      expect(heavy.fat, greaterThan(light.fat));
    });

    test('an incomplete profile falls back to the shared default', () {
      // No activity level, which is one of the two things the quiz exists to
      // collect. Falling back rather than throwing keeps every screen free of
      // "targets unknown" handling.
      expect(
        TargetCalculator.forProfile(profileOf(activity: null)),
        UserProfile.defaultTargets,
      );
      expect(
        TargetCalculator.forProfile(profileOf(goal: null)),
        UserProfile.defaultTargets,
      );
    });
  });

  group('goalDate', () {
    test('is the distance divided by the rate', () {
      final from = DateTime(2026, 1, 1);
      final date = TargetCalculator.goalDate(
        profileOf(weightKg: 90, goal: WeightGoal.lose, goalWeightKg: 80),
        from: from,
      );
      // 10 kg at 0.5 kg/week = 20 weeks = 140 days.
      expect(date, DateTime(2026, 1, 1).add(const Duration(days: 140)));
    });

    test('is null when maintaining, or already there', () {
      expect(TargetCalculator.goalDate(profileOf()), isNull);
      expect(
        TargetCalculator.goalDate(
          profileOf(weightKg: 80, goal: WeightGoal.lose, goalWeightKg: 80),
        ),
        isNull,
      );
    });
  });
}
