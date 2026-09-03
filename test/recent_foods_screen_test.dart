import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/recent_foods.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/features/scan/presentation/food_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// Search used to open on an empty box with the keyboard over it. It now opens
/// on the foods this person actually logs, which is the shortest path to a
/// logged meal in the app — no camera, no model, no quota, one tap.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('search opens on the foods you log', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final scope = await designScopeBuilder();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentFoodsProvider.overrideWith(
            (ref) async => [
              FrequentFood(
                item: const FoodItem(
                  id: 'a',
                  name: 'Porridge with berries',
                  nutrition: Nutrition(
                    calories: 320,
                    protein: 12,
                    carbs: 48,
                    fat: 8,
                  ),
                  portionGrams: 250,
                  source: FoodSource.database,
                ),
                count: 9,
                lastEaten: DateTime(2026, 6, 14, 8),
              ),
            ],
          ),
        ],
        child: scope(const MaterialApp(home: FoodSearchScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Porridge with berries'), findsOneWidget);
    expect(find.textContaining('Foods you log often'), findsOneWidget);

    // And one tap adds it — the whole point of the list being there.
    await tester.tap(find.text('Porridge with berries'));
    await tester.pump();
    expect(find.text('Add 1 to My Diet'), findsOneWidget);
  });
}
