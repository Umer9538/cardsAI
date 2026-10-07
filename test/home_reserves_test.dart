import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/app/presentation/widgets/activity_card.dart';
import 'package:carbsai/features/app/presentation/widgets/water_card.dart';
import 'package:carbsai/features/app/presentation/widgets/weight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// Home books a fixed strip of canvas for each of the three extras and then
/// positions the next one under it. So each card owes two things, and both
/// used to be broken on the weight card at once:
///
///   * it must **fit** its reserve, or it draws over the card below — and two
///     overlapping `Positioned` children throw nothing, so nothing catches it;
///   * it must not be much *smaller* than its reserve, or the leftover shows
///     as dead space. Home's gaps are 14, so 49pt of slack reads as a gap four
///     times the size of its neighbours. A tester reported exactly that.
void main() {
  setUpAll(loadDesignFonts);

  Future<double> render(
    WidgetTester tester,
    Widget card,
    Type type, {
    double scale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
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
    await tester.pump(const Duration(milliseconds: 60));
    return tester.getRect(find.byType(type)).height;
  }

  /// A fortnight of readings — the state that carries a sparkline, and the
  /// taller of the two by 97pt.
  final populated = WeightHistory([
    for (var d = 13; d >= 0; d--)
      WeightEntry(
        id: 'w$d',
        kg: 80 - d * 0.1,
        at: DateTime(2026, 10, 6).subtract(Duration(days: d)),
      ),
  ]);

  /// The reserve has to cover the **1.15x** case or the card overlaps, so at
  /// 1.0 it necessarily carries the difference between the two scales. The
  /// ceiling is therefore where the fit is checked tightly; 1.0 only has to
  /// stay far away from the 49pt that started this.
  void check(String what, double rendered, double reserve, double scale) {
    expect(rendered, lessThanOrEqualTo(reserve),
        reason: '$what overflows its reserve by ${rendered - reserve}pt '
            'and draws over the card below it');
    final maxSlack = scale > 1 ? 6.0 : 22.0;
    expect(reserve - rendered, lessThanOrEqualTo(maxSlack),
        reason: '$what leaves ${reserve - rendered}pt of dead space at '
            '${scale}x, which shows as a gap wider than the 14 between every '
            'other card');
  }

  for (final scale in [1.0, 1.15]) {
    testWidgets('the weight card fits its reserve, empty, at ${scale}x',
        (tester) async {
      final h = await render(
        tester,
        const WeightCard(top: 0, preview: WeightHistory([])),
        WeightCard,
        scale: scale,
      );
      check('weight (empty)', h, WeightCard.reserveFor(hasReadings: false), scale);
    });

    testWidgets('the weight card fits its reserve, populated, at ${scale}x',
        (tester) async {
      final h = await render(
        tester,
        WeightCard(top: 0, preview: populated),
        WeightCard,
        scale: scale,
      );
      // This is the one that was 48pt over. Nothing could render it before —
      // WeightCard had no `preview`, so the only reachable state was empty.
      check('weight (populated)', h, WeightCard.reserveFor(hasReadings: true),
          scale);
    });

    testWidgets('the water card fits its reserve at ${scale}x', (tester) async {
      final h = await render(
        tester,
        const WaterCard(top: 0, preview: WaterLog(entries: [], targetMl: 2660)),
        WaterCard,
        scale: scale,
      );
      check('water', h, WaterCard.reserve, scale);
    });

    testWidgets('the activity card fits its reserve at ${scale}x',
        (tester) async {
      final h = await render(
        tester,
        const ActivityCard(top: 0, preview: ActivityLog(entries: [])),
        ActivityCard,
        scale: scale,
      );
      check('activity', h, ActivityCard.reserveFor(0), scale);
    });
  }
}
