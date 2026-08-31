import 'package:carbsai/features/auth/presentation/sign_up_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('signup matches the design artboard', (tester) async {
    await renderScreen(
      tester,
      const SignUpScreen(),
      outputName: 'signup13_actual.png',
    );
  });
}
