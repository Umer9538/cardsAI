import 'package:carbsai/features/settings/presentation/more_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('del46 matches the design artboard', (tester) async {
    await renderScreen(tester, const MoreScreen(showDeleteConfirm: true), outputName: 'del46_actual.png');
  });
}
