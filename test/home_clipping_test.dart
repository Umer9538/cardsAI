import 'package:carbsai/features/app/presentation/widgets/calorie_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clipping that removes a *descender* does not look like a layout bug.
///
/// `MacroBar` reserved 31pt and placed a 19pt label at 16.67, so the bottom
/// 4.67pt of every figure on both macro cards was cut off by the Stack. What
/// that removed was the tail of the "g": "250g" rendered as "250a" and "0g" as
/// "0a", so the cards looked like they were showing a unit nobody uses rather
/// than like they were broken. It survived every render diff and a tester
/// reported it as "clipping issues" with no idea what was wrong.
void main() {
  Future<Rect> labelRect(WidgetTester tester, String text) async {
    final box = tester.renderObject<RenderBox>(find.text(text));
    final top = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(top.dx, top.dy, box.size.width, box.size.height);
  }

  Future<void> pumpBar(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const Scaffold(
            body: Center(
              child: MacroBar(progress: 0.4, consumed: '57g', target: '250g'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the label fits inside the bar it is drawn in', (tester) async {
    await pumpBar(tester);

    final bar = tester.getRect(find.byType(MacroBar));
    for (final text in ['57g', '250g']) {
      final label = await labelRect(tester, text);
      expect(
        label.bottom,
        lessThanOrEqualTo(bar.bottom + 0.01),
        reason: '$text is cut off by ${label.bottom - bar.bottom}pt',
      );
    }
  });

  testWidgets('and at the text-scale ceiling it spills rather than clips',
      (tester) async {
    await pumpBar(tester, scale: 1.15);

    // DesignCanvas.maxTextScale. The box is fixed, so the only two outcomes
    // are "spills into the room the card has" and "loses the descender again";
    // Clip.none is what picks the first.
    final stack = tester.widget<Stack>(
      find.descendant(of: find.byType(MacroBar), matching: find.byType(Stack)),
    );
    expect(stack.clipBehavior, Clip.none);
  });

  testWidgets('a taller box than the label needs, with room to grow',
      (tester) async {
    // 16.67 top + 19 line = 35.67. The export said 31.
    expect(MacroBar.height, greaterThanOrEqualTo(35.67));
    // And it still fits the 47pt the macro card leaves below the bar's origin.
    expect(MacroBar.height, lessThanOrEqualTo(47));
  });
}
