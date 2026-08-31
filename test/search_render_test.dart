import 'package:carbsai/features/scan/presentation/food_search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('food search renders its empty state', (tester) async {
    await renderScreen(
      tester,
      const FoodSearchScreen(),
      outputName: 'search_actual.png',
    );
  });
}
