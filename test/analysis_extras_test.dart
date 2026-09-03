import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/analysis/presentation/analysis_controller.dart';
import 'package:carbsai/features/analysis/presentation/widgets/analysis_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// This codebase has now shipped the same bug three times: a box with no child,
/// given loose constraints, takes the smallest size it is allowed — which is
/// zero. Twice inside a Stack, once inside a Row. It never throws, the screen
/// looks plausible, and the fill simply never appears.
///
/// So the rule from CLAUDE.md applies here: assert the rendered height.
void main() {
  setUpAll(loadDesignFonts);

  final summary = AnalysisSummary(
    period: AnalysisPeriod.daily,
    points: const [],
    total: const Nutrition(calories: 4000, protein: 100, carbs: 400, fat: 150),
    targets: const Nutrition(calories: 2000, protein: 120, carbs: 250, fat: 65),
    loggedDays: 3,
    daysUnderGoal: 2,
    daysOverBudget: 0,
    windowDays: 7,
    daysLoggedTwice: 3,
    bySlot: const {
      MealSlot.breakfast: 900,
      MealSlot.lunch: 1400,
      MealSlot.dinner: 1700,
    },
    bySource: const {FoodSource.ai: 6, FoodSource.database: 2},
  );

  Future<void> pump(WidgetTester tester, Widget card) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 388, child: card)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the consistency segments actually have height', (tester) async {
    await pump(tester, ConsistencyCard(summary: summary));

    expect(find.text('3'), findsOneWidget);
    expect(find.text('of 7'), findsOneWidget);

    final boxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .length;
    expect(boxes, greaterThan(1));

    // Seven segments, each 8pt tall. Zero is what the bug produced.
    final segment = tester.getSize(
      find.descendant(
        of: find.byType(ConsistencyCard),
        matching: find.byType(DecoratedBox),
      ).at(1),
    );
    expect(segment.height, 8, reason: 'the segment collapsed to nothing');
  });

  testWidgets('the meal split bar actually has height', (tester) async {
    await pump(tester, HabitsCard(summary: summary));

    // Dinner is the largest share and sorts first.
    expect(find.textContaining('Dinner'), findsOneWidget);
    expect(find.textContaining('Photo'), findsOneWidget);

    final slice = tester.getSize(
      find.descendant(
        of: find.byType(HabitsCard),
        matching: find.byType(ColoredBox),
      ).first,
    );
    expect(slice.height, 12, reason: 'the slice collapsed to nothing');
  });

  test('the breakdowns are shares of what was actually logged', () {
    final slots = summary.slotBreakdown;
    expect(slots.first.slot, MealSlot.dinner);
    expect(
      slots.fold(0.0, (sum, row) => sum + row.share),
      closeTo(1.0, 0.001),
    );

    final methods = summary.methodBreakdown;
    expect(methods.first.source, FoodSource.ai);
    expect(methods.first.share, closeTo(0.75, 0.001));
  });
}
