import 'package:carbsai/features/analysis/presentation/analysis_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('analysis matches the design artboard', (tester) async {
    await renderScreen(tester, const AnalysisScreen(),
        outputName: 'analysis26_actual.png');
  });
}
