import 'package:carbsai/features/settings/presentation/legal_page_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('priv44 matches the design artboard', (tester) async {
    await renderScreen(tester, LegalPageScreen.privacy(), outputName: 'priv44_actual.png');
  });
}
