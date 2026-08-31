import 'package:carbsai/features/settings/presentation/payment_method_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('pay38 matches the design artboard', (tester) async {
    await renderScreen(tester, const PaymentMethodScreen(), outputName: 'pay38_actual.png');
  });
}
