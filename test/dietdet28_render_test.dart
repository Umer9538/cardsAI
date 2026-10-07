import 'package:carbsai/data/local/seed_data.dart';
import 'package:carbsai/features/diets/presentation/diet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('dietdet28 matches the design artboard', (tester) async {
    // The artboard shows Mediterranean Lifestyle, which is the first seeded
    // plan; the screen takes the plan rather than loose strings now.
    await renderScreen(
      tester,
      DietDetailScreen(plan: SeedData.dietPlans.first),
      outputName: 'dietdet28_actual.png',
    );

    // A catalogue plan was built for nobody, and says nothing about it.
    expect(find.text('Built for you'), findsNothing);
    expect(find.text('How It Works'), findsOneWidget);
  });

  // No image capture here — one render per file, see design_render.dart.
  testWidgets('a built plan says what it was built for', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final plan = SeedData.dietPlans.first.copyWith(
      name: 'Your Mediterranean Lifestyle',
      isMine: true,
      builtFor: const ['South Asian & Mediterranean', 'Loves heat', 'No dairy'],
    );

    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: DietDetailScreen(plan: plan),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The section, its chips, and its place: above "How It Works", which is
    // pushed down rather than drawn through.
    final title = find.text('Built for you');
    expect(title, findsOneWidget);
    for (final chip in plan.builtFor) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    final rules = find.text('How It Works');
    expect(rules, findsOneWidget);
    final chipBottom = tester.getBottomLeft(find.text('No dairy')).dy;
    expect(tester.getTopLeft(rules).dy, greaterThan(chipBottom));
    expect(tester.getTopLeft(rules).dy, greaterThan(tester.getTopLeft(title).dy));
  });
}
