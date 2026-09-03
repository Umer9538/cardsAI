import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The barcode sweep is a continuously repeating movement over most of the
/// screen — precisely what "reduce motion" exists to stop. A setting the app
/// ignores is worse than one it never offered.
void main() {
  setUpAll(loadDesignFonts);

  Future<void> openBarcode(WidgetTester tester, {required bool still}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: const ScanningScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('AI Barcode'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the reader sweeps while it is live', (tester) async {
    await openBarcode(tester, still: false);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SweepPainter',
      ),
      findsOneWidget,
    );
    // A repeating animation is still running; leave the frame quiet for the
    // teardown rather than settling, which would never return.
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('and does not when the OS asks for reduced motion',
      (tester) async {
    await openBarcode(tester, still: true);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint &&
            w.painter.runtimeType.toString() == '_SweepPainter',
      ),
      findsNothing,
    );
  });
}
