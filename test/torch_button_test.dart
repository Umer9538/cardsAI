import 'package:carbsai/core/theme/app_colors.dart';
import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A barcode is read off a printed label and a plate is photographed wherever
/// it was cooked — both are exactly what a dim kitchen defeats. The first
/// report of this was a screenshot of a viewfinder that was almost entirely
/// black, with no way to light it.
void main() {
  Future<int> pump(WidgetTester tester, {required bool on}) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: TorchButton(on: on, onTap: () => taps++),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  Finder labelled(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );

  testWidgets('off, it offers to turn the light on', (tester) async {
    await pump(tester, on: false);
    expect(labelled('Turn the flashlight on'), findsOneWidget);
  });

  testWidgets('on, it offers to turn it off', (tester) async {
    await pump(tester, on: true);
    // A bare glyph with no text near it: without the label the control does
    // not exist for a screen reader at all.
    expect(labelled('Turn the flashlight off'), findsOneWidget);
  });

  testWidgets('the bolt is drawn, not a font glyph', (tester) async {
    await pump(tester, on: false);
    // Material's icon font is tree-shaken in release and not loaded under
    // `flutter test`, so an `Icon` here renders as a tofu box in every render
    // test — the same trap the toast marks fell into.
    expect(
      find.descendant(
        of: find.byType(TorchButton),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(TorchButton),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping it reports once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: TorchButton(on: false, onTap: () => taps++),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TorchButton));
    await tester.pump();
    expect(taps, 1);
  });
}
