import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  // Selecting AI Gallery used to change the tile and nothing else: the picker
  // only opened on a later shutter press, which reads as a dead tile. And when
  // it did open, it was the photo picker alone — no route to a file the phone
  // holds outside the camera roll.
  testWidgets('the gallery tile opens a chooser that offers files',
      (tester) async {
    await renderScreen(
      tester,
      const ScanningScreen(),
      outputName: 'scan_source_actual.png',
      before: (t) async {
        await t.tap(find.text('AI Gallery'));
        await t.pump(const Duration(milliseconds: 300));
      },
    );

    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Downloads, folders, SD card'), findsOneWidget);
  });
}
