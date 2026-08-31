import 'package:carbsai/features/settings/presentation/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('out47 matches the design artboard', (tester) async {
    await renderScreen(tester, const SettingsScreen(showLogOutConfirm: true), outputName: 'out47_actual.png');
  });
}
