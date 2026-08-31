import 'package:carbsai/features/scan/presentation/scan_result_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('scan result matches the design artboard', (tester) async {
    await renderScreen(tester, const ScanResultScreen(),
        outputName: 'scanres32_actual.png');
  });
}
