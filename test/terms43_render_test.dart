import 'package:carbsai/features/settings/presentation/legal_page_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('terms43 matches the design artboard', (tester) async {
    await renderScreen(tester, LegalPageScreen.terms(), outputName: 'terms43_actual.png');
  });
}
