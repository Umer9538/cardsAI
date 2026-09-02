import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/scan/presentation/food_search_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The empty state was the only one a test could reach, so a result row shipped
/// two pixels over its own box: 25 + 2 + 19 of text against exactly 46 of room.
/// A RenderFlex overflow throws in a test, so rendering the populated list is
/// the assertion.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('result rows fit their row', (tester) async {
    await renderScreen(
      tester,
      FoodSearchScreen(
        results: [
          const FoodItem(
            id: '1',
            name: 'Chicken breast, grilled without sauce',
            nutrition: Nutrition(calories: 165, protein: 31, carbs: 0, fat: 3.6),
            portionDescription: '100 g',
            source: FoodSource.database,
          ),
          const FoodItem(
            id: '2',
            name: 'Rice, white, long-grain, cooked',
            nutrition: Nutrition(calories: 130, protein: 2.7, carbs: 28, fat: 0.3),
            portionDescription: '100 g',
            source: FoodSource.database,
          ),
        ],
      ),
      outputName: 'search_results_actual.png',
    );

    expect(find.textContaining('Chicken breast'), findsOneWidget);
  });
}
