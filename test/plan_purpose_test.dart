import 'dart:io' as io;

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/plan_purpose.dart';
import 'package:flutter_test/flutter_test.dart';

/// The purpose is derived from two stored answers and shown before the plan
/// is built, so the mapping has to be total over what a profile can hold and
/// agree with `purposeFor` in `workers/src/planPrompt.ts`, which is the copy
/// that steers the model. Change one, change both, and change this.
void main() {
  test('every goal and motivation resolves to one of the five purposes',
      () {
    for (final goal in WeightGoal.values) {
      for (final motivation in [...Motivation.values, null]) {
        final purpose = PlanPurpose.from(goal: goal, motivation: motivation);
        expect(purpose, isNotNull,
            reason: 'goal $goal with motivation $motivation has no purpose');
        expect(PlanPurpose.values, contains(purpose));
        expect(purpose!.label, isNotEmpty);
      }
    }
    expect(
      PlanPurpose.values.map((p) => p.label),
      equals([
        'Building muscle',
        'Weight loss',
        'Weight gain',
        'Eating better',
        'Maintenance',
      ]),
    );
  });

  test('building muscle wins whatever the goal', () {
    for (final goal in [...WeightGoal.values, null]) {
      expect(
        PlanPurpose.from(goal: goal, motivation: Motivation.muscle),
        equals(PlanPurpose.muscle),
        reason: 'goal $goal',
      );
    }
  });

  test('otherwise the goal decides, and motivation only colours maintenance',
      () {
    for (final motivation in [
      Motivation.lose,
      Motivation.healthier,
      Motivation.understand,
      null,
    ]) {
      expect(PlanPurpose.from(goal: WeightGoal.lose, motivation: motivation),
          equals(PlanPurpose.loss));
      expect(PlanPurpose.from(goal: WeightGoal.gain, motivation: motivation),
          equals(PlanPurpose.gain));
    }
    for (final motivation in [Motivation.healthier, Motivation.understand]) {
      expect(
        PlanPurpose.from(goal: WeightGoal.maintain, motivation: motivation),
        equals(PlanPurpose.eatBetter),
      );
    }
    for (final motivation in [Motivation.lose, null]) {
      expect(
        PlanPurpose.from(goal: WeightGoal.maintain, motivation: motivation),
        equals(PlanPurpose.maintenance),
      );
    }
  });

  test('no goal is no purpose, and a profile is read the same way', () {
    // The default target is neither a deficit nor a surplus; claiming
    // "weight loss" over it would claim something the numbers do not do.
    for (final motivation in [
      Motivation.lose,
      Motivation.healthier,
      Motivation.understand,
      null,
    ]) {
      expect(PlanPurpose.from(goal: null, motivation: motivation), isNull);
    }
    expect(PlanPurpose.of(null), isNull);

    const profile = UserProfile(
      id: 'u1',
      name: 'Test',
      email: 't@example.com',
      goal: WeightGoal.maintain,
      motivation: Motivation.healthier,
    );
    expect(PlanPurpose.of(profile), equals(PlanPurpose.eatBetter));
    expect(PlanPurpose.of(profile.copyWith(goal: WeightGoal.gain)),
        equals(PlanPurpose.gain));
  });

  test('the labels match what the Worker returns', () {
    // `workers/src/planPrompt.ts` carries the same five labels; the Worker
    // returns them as `purpose` and the app puts that string first in
    // `builtFor`. Read the TypeScript as text, as `dish_taxonomy_test` does,
    // so a relabel on one side fails here rather than on a phone.
    final ts = _readWorker('planPrompt.ts');
    for (final purpose in PlanPurpose.values) {
      expect(ts, contains('label: "${purpose.label}"'),
          reason: '${purpose.name} is not labelled "${purpose.label}" on the Worker');
    }
  });
}

String _readWorker(String file) =>
    // `flutter test` runs with the package root as the working directory.
    (io.File('workers/src/$file')).readAsStringSync();
