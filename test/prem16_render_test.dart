import 'package:carbsai/features/premium/presentation/premium_offer_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('prem16 matches the design artboard', (tester) async {
    await renderScreen(tester, const PremiumOfferScreen(), outputName: 'prem16_actual.png');
  });
}
