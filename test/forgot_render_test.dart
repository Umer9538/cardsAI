import 'package:carbsai/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('forgot matches the design artboard', (tester) async {
    await renderScreen(
      tester,
      const ForgotPasswordScreen(),
      outputName: 'forgot10_actual.png',
    );
  });
}
