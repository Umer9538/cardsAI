import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('scanning matches the design artboard', (tester) async {
    await renderScreen(tester, const ScanningScreen(),
        outputName: 'scanning31_actual.png');
  });
}
