import 'package:carbsai/features/scan/presentation/describe_meal_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('describe meal renders', (tester) async {
    await renderScreen(
      tester,
      const DescribeMealScreen(),
      outputName: 'describe_actual.png',
    );
  });
}
