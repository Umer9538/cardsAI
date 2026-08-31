import 'package:carbsai/features/settings/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('set33 matches the design artboard', (tester) async {
    await renderScreen(tester, const SettingsScreen(), outputName: 'set33_actual.png');
  });
}
