import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The `hint` field was plumbed through the Worker, the repositories and the
/// controller from the day the pipeline was built, and no screen ever offered a
/// way to type into it. `prompt.ts` calls it "the cheapest accuracy win
/// available on a mixed dish".
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('the camera offers a note, and it reaches onCaptured',
      (tester) async {
    String? captured;

    await renderScreen(
      tester,
      ScanningScreen(
        onCaptured: (mode, path, hint) => captured = hint,
      ),
      outputName: 'scan_note_actual.png',
      before: (t) async {
        expect(find.textContaining('Add a note'), findsOneWidget);

        await t.tap(find.textContaining('Add a note'));
        // Two pumps: the first inserts the sheet route, the second runs its
        // entry animation. One pump does both in a single frame and leaves the
        // sheet still parked below the viewport.
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));

        // The examples exist because an empty text box is the main reason this
        // kind of input goes unused.
        await t.tap(find.text('Fried in 2 tbsp oil'));
        await t.pump();
        await t.tap(find.text('Done'));
        // Likewise on the way out — the barrier is gone only once the exit
        // transition has actually run.
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));

        // The note is now visible on the camera, before committing a scan.
        expect(find.text('Fried in 2 tbsp oil'), findsOneWidget);

        final shutter = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ShutterButton',
        );
        expect(shutter, findsOneWidget);
        await t.tap(shutter);
        await t.pump(const Duration(milliseconds: 300));
      },
    );

    expect(captured, 'Fried in 2 tbsp oil');
  });
}
