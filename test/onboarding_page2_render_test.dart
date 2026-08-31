import 'package:carbsai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('onboarding page 2 matches the design artboard size',
      (tester) async {
    await renderScreen(
      tester,
      const OnboardingScreen(initialPage: 1),
      outputName: 'ob2_actual.png',
    );
  });
}
