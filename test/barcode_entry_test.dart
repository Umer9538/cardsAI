import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:carbsai/features/scan/presentation/widgets/barcode_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// Barcode detection is continuous, so the mode has no shutter — which left it
/// as the only mode with no control at all, and no way forward when a code will
/// not read: a scuffed label, a curved tin, shrink wrap, a camera that cannot
/// focus that close. The digits are printed under the bars for this exact
/// reason.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('barcode mode offers a way to type the number', (tester) async {
    await renderScreen(
      tester,
      const ScanningScreen(),
      outputName: 'barcode_entry_actual.png',
      before: (t) async {
        await t.tap(find.text('AI Barcode'));
        // Inside the camera handoff window, which is where the live scanner is
        // deliberately not mounted — it has no platform side in a test.
        await t.pump(const Duration(milliseconds: 50));

        expect(find.text('Type the number'), findsOneWidget);
        expect(find.text('Starting the reader…'), findsOneWidget);
      },
    );
  });

  testWidgets('the sheet refuses anything that is not a product code',
      (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showBarcodeEntrySheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Too short to be EAN-8. Looking it up would spend a request to be told so.
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    await tester.tap(find.text('Look it up'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(BarcodeEntrySheet), findsOneWidget,
        reason: 'a 3-digit code should not be accepted');

    // Letters are not a barcode either.
    await tester.enterText(find.byType(TextField), 'nutella');
    await tester.pump();
    await tester.tap(find.text('Look it up'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(BarcodeEntrySheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), '5000112637922');
    await tester.pump();
    await tester.tap(find.text('Look it up'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, '5000112637922');
  });
}
