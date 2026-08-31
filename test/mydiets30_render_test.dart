import 'package:carbsai/features/diets/presentation/diets_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('mydiets30 matches the design artboard', (tester) async {
    await renderScreen(tester, const DietsScreen(tab: DietsTab.mine), outputName: 'mydiets30_actual.png');
  });
}
