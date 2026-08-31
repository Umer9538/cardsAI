import 'package:carbsai/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('login default state matches the design artboard',
      (tester) async {
    await renderScreen(
      tester,
      const LoginScreen(),
      outputName: 'login_default_actual.png',
    );
  });
}
