import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/analysis/presentation/analysis_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Macro Distribution line used to test only "protein low" and "fat high"
/// and say "your split is close to your plan" for everything else. Seen on a
/// device: 0% carbohydrate against an 18% target, congratulated as close.
AnalysisSummary _summary({required Nutrition eaten, required Nutrition target}) =>
    AnalysisSummary(
      period: AnalysisPeriod.daily,
      points: const [],
      total: eaten,
      targets: target,
      loggedDays: 3,
      daysUnderGoal: 0,
      daysOverBudget: 0,
    );

// 59 g carbs, 126 g protein, 63 g fat — a real target from the quiz.
const _target = Nutrition(calories: 1306, protein: 126, carbs: 59, fat: 63);

void main() {
  test('a split that matches the plan is called close', () {
    final insight = _summary(
      eaten: const Nutrition(calories: 1306, protein: 126, carbs: 59, fat: 63),
      target: _target,
    ).macroInsight;

    expect(insight, 'Your split is close to your plan.');
  });

  test('missing carbohydrate entirely is not "close to your plan"', () {
    // Chicken breast and nothing else: 0% carbs against an 18% target, which
    // is the same fact as 18 points over on protein. Either naming is honest;
    // calling it close is not, and that is what it used to do.
    final insight = _summary(
      eaten: const Nutrition(calories: 181, protein: 24.7, carbs: 0, fat: 8.3),
      target: _target,
    ).macroInsight;

    expect(insight, isNot(contains('close to your plan')));
    expect(insight, matches(RegExp(r'\d+ points (under|over)')));
    expect(insight, anyOf(contains('carbs'), contains('protein')));
  });

  test('too much fat is named as fat, and as over', () {
    final insight = _summary(
      eaten: const Nutrition(calories: 900, protein: 20, carbs: 20, fat: 80),
      target: _target,
    ).macroInsight;

    expect(insight, contains('fat'));
    expect(insight, contains('over'));
  });

  test('only one macro is named, not all three', () {
    final insight = _summary(
      eaten: const Nutrition(calories: 400, protein: 38, carbs: 0, fat: 19),
      target: _target,
    ).macroInsight;

    // A paragraph listing every deviation is one nobody reads.
    final named = ['protein', 'carbs', 'fat']
        .where((macro) => insight.contains(macro))
        .length;
    expect(named, 1);
  });

  test('an empty window asks for meals rather than judging', () {
    final insight = AnalysisSummary.empty(AnalysisPeriod.daily, _target).macroInsight;
    expect(insight, 'Log a few meals to see your split.');
  });
}
