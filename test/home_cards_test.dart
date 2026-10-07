import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/app/presentation/widgets/activity_card.dart';
import 'package:carbsai/features/app/presentation/widgets/water_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The two cards onboarding's promise now rests on, rendered.
///
/// The water bar is a `DecoratedBox` with no child inside a `Stack`, which is
/// the shape this codebase has shipped collapsed to zero height three times —
/// it never throws and the card merely looks like it has a gap. So the rule
/// from CLAUDE.md applies: assert the rendered height.
///
/// Both take a `preview` override, which is the only way a test can reach a
/// populated card — the same convention that would have caught the search
/// result row shipping 2px over its box.
void main() {
  setUpAll(loadDesignFonts);

  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    double textScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
              ),
              // The cards are Positioned, so they need a Stack with a width.
              child: SizedBox(
                width: 428,
                height: 926,
                child: Stack(children: [card]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the water card', () {
    testWidgets('shows the day against the target', (tester) async {
      await pump(
        tester,
        WaterCard(
          top: 0,
          preview: WaterLog(
            entries: [
              WaterEntry(id: 'a', at: DateTime(2026, 9, 22, 9), ml: 500),
            ],
            targetMl: 2000,
          ),
        ),
      );

      expect(find.text('Water'), findsOneWidget);
      // Imperial, because the test harness reports a US locale — which is
      // the point of the conversion existing at all.
      expect(find.text('17 / 68 fl oz'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
    });

    testWidgets('the fill has height — the bug this file exists for',
        (tester) async {
      await pump(
        tester,
        WaterCard(
          top: 0,
          preview: WaterLog(
            entries: [
              WaterEntry(id: 'a', at: DateTime(2026, 9, 22, 9), ml: 1000),
            ],
            targetMl: 2000,
          ),
        ),
      );

      final fill = tester.getSize(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(fill.height, 8, reason: 'the fill collapsed to nothing');
      // Half the 388 card less its 19pt insets, either side.
      expect(fill.width, closeTo(175, 1));
    });

    testWidgets('fits its reserved room at the 1.15x text ceiling',
        (tester) async {
      await pump(
        tester,
        const WaterCard(top: 0, preview: WaterLog.empty),
        textScale: 1.15,
      );

      expect(
        tester.getSize(find.byType(WaterCard)).height,
        lessThanOrEqualTo(WaterCard.reserve),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the activity card', () {
    final log = ActivityLog(entries: [
      ActivityEntry(
        id: 'a',
        at: DateTime(2026, 9, 22, 7),
        name: 'Running',
        minutes: 30,
        kcal: 360,
      ),
    ]);

    testWidgets('lists what was done', (tester) async {
      await pump(tester, ActivityCard(top: 0, preview: log));

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('30 min'), findsNWidgets(1));
      expect(find.text('360 kcal'), findsOneWidget);
      expect(find.text('30 min · 360 kcal'), findsOneWidget);
    });

    testWidgets('says so when nothing has been logged', (tester) async {
      await pump(tester, const ActivityCard(top: 0, preview: ActivityLog.empty));

      expect(find.text('Nothing logged today.'), findsOneWidget);
      expect(find.text('Log activity'), findsOneWidget);
    });

    testWidgets('fits its reserved room at the 1.15x text ceiling',
        (tester) async {
      await pump(
        tester,
        ActivityCard(top: 0, preview: log),
        textScale: 1.15,
      );

      expect(
        tester.getSize(find.byType(ActivityCard)).height,
        lessThanOrEqualTo(ActivityCard.reserveFor(log.entries.length)),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
