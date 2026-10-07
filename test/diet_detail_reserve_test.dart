import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/dish_taxonomy.dart';
import 'package:carbsai/data/local/seed_data.dart';
import 'package:carbsai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:carbsai/features/diets/presentation/diet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The detail screen's canvas is a fixed-height `Stack` with hard clipping
/// inside a scroll view, so anything drawn past its height is unreachable at
/// any scroll position — and the last thing drawn is the Add / Remove button.
///
/// The height used to be a constant, and the constant was wrong in the normal
/// case: the eight chips a fully answered quiz produces put the CTA 106pt past
/// the canvas at 1.0x text, and a catalogue plan with no chips was already
/// 40pt over at 1.15x. Now it is measured from the content, and this test
/// asserts the measurement the same way the reviewers found the bug: pump the
/// screen at the artboard size and compare the button's bottom edge with the
/// canvas height, in canvas units.
///
/// No image capture, so several pumps in one file are fine.
void main() {
  setUpAll(loadDesignFonts);

  // Every question answered, with the widest pole on each axis. Eight chips:
  // a cuisine pair, five leanings, the avoidance, the cook time.
  const full = TasteProfile(
    liked: ['chicken-karahi', 'greek-salad'],
    leaning: {
      TasteAxis.spice: TastePole.mild,
      TasteAxis.starch: TastePole.bread,
      TasteAxis.protein: TastePole.plants,
      TasteAxis.breakfast: TastePole.lightBreakfast,
      TasteAxis.prep: TastePole.assembled,
    },
    avoid: {Avoidance.dairy},
    cookTime: CookTime.under15,
  );

  /// The CTA's bottom edge and the canvas height, both in canvas units — at
  /// a 428-wide viewport the canvas draws at 1:1 and nothing has scrolled,
  /// so a widget's global y *is* its artboard y.
  Future<({double button, double canvas})> measure(
    WidgetTester tester,
    Widget Function(Widget) scope,
    DietPlan plan,
    double textScale,
  ) async {
    await tester.pumpWidget(
      scope(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: DietDetailScreen(plan: plan),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);

    final canvas = tester.widget<DesignCanvas>(find.byType(DesignCanvas));
    final button = find.byType(PrimaryButton);
    expect(button, findsOneWidget);
    return (button: tester.getBottomLeft(button).dy, canvas: canvas.height);
  }

  testWidgets('the CTA sits inside the canvas for every plan and scale',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    expect(full.summary, hasLength(8), reason: full.summary.join(' | '));

    final scope = await designScopeBuilder();

    final cases = <(String, DietPlan)>[
      // A catalogue plan, built for nobody: no chips.
      ('catalogue', SeedData.dietPlans.first),
      // Every seed day under the full set of chips. Whichever day is the
      // tallest is covered by construction rather than by picking it.
      for (final plan in SeedData.dietPlans)
        (
          'built ${plan.id}',
          plan.copyWith(
            name: 'Your ${plan.name}',
            isMine: true,
            builtFor: full.summary,
          ),
        ),
    ];

    for (final scale in const [1.0, DesignCanvas.maxTextScale]) {
      for (final (name, plan) in cases) {
        final m = await measure(tester, scope, plan, scale);
        final slack = m.canvas - m.button;
        expect(
          m.button,
          lessThanOrEqualTo(m.canvas),
          reason: '$name at ${scale}x: CTA bottom ${m.button.toStringAsFixed(1)} '
              'on a ${m.canvas.toStringAsFixed(1)} canvas',
        );
        // Honest, not generous. The measurement leaves a fixed 40 under the
        // button; a canvas much taller than that is empty space the person
        // scrolls through under the last control on every phone.
        expect(
          slack,
          lessThan(80),
          reason: '$name at ${scale}x: ${slack.toStringAsFixed(1)} of empty '
              'canvas under the CTA',
        );
      }
    }
  });
}
