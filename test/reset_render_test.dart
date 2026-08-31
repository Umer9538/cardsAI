import 'package:carbsai/features/auth/presentation/reset_password_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('reset matches the design artboard', (tester) async {
    await renderScreen(
      tester,
      const ResetPasswordScreen(),
      outputName: 'reset11_actual.png',
    );
  });
}
