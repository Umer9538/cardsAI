import 'package:carbsai/features/auth/presentation/verification_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('verify matches the design artboard', (tester) async {
    await renderScreen(
      tester,
      const VerificationScreen(email: 'janecooper@email.com', initialCode: '856346'),
      outputName: 'verify09_actual.png',
    );
  });
}
