import 'package:carbsai/features/diets/presentation/diets_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('mydietsempty29 matches the design artboard', (tester) async {
    await renderScreen(tester, const DietsScreen(tab: DietsTab.mine, myPlans: []), outputName: 'mydietsempty29_actual.png');
  });
}
