import 'package:carbsai/features/splash/presentation/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('splash matches the design artboard size', (tester) async {
    await renderScreen(
      tester,
      const SplashScreen(),
      outputName: 'splash_actual3x.png',
    );
  });
}
