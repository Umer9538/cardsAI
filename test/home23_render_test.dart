import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('home matches the design artboard', (tester) async {
    await renderScreen(tester, const HomeScreen(),
        outputName: 'home23_actual.png');
  });
}
