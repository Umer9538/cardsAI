import 'package:carbsai/features/settings/presentation/more_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('more42 matches the design artboard', (tester) async {
    await renderScreen(tester, const MoreScreen(), outputName: 'more42_actual.png');
  });
}
