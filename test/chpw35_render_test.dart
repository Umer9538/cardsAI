import 'package:carbsai/features/settings/presentation/change_password_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('chpw35 matches the design artboard', (tester) async {
    await renderScreen(tester, const ChangePasswordScreen(), outputName: 'chpw35_actual.png');
  });
}
