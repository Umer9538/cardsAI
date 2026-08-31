import 'package:carbsai/features/settings/presentation/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('prof34 matches the design artboard', (tester) async {
    await renderScreen(tester, const ProfileScreen(), outputName: 'prof34_actual.png');
  });
}
