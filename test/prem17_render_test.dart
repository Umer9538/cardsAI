import 'package:carbsai/features/premium/presentation/premium_plans_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('prem17 matches the design artboard', (tester) async {
    await renderScreen(tester, const PremiumPlansScreen(), outputName: 'prem17_actual.png');
  });
}
