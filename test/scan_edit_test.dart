import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/scan/presentation/scan_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Correction friction, not error rate, is what earns a one-star review in this
/// category. These are the behaviours that make a correction trustworthy.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    container = ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(AppBackend.local),
      ],
    );
    addTearDown(container.dispose);
  });

  ScanController controller() =>
      container.read(scanControllerProvider.notifier);

  Future<FoodItem> firstItem() async {
    await controller().describe('two eggs on toast');
    return container.read(scanControllerProvider).value!.items.first;
  }

  test('an edit replaces the numbers and clears the review flag', () async {
    final food = await firstItem();
    controller().applyEdit(
      itemId: food.id,
      name: 'Chicken karahi',
      nutrition: const Nutrition(calories: 420, protein: 33, carbs: 9, fat: 28),
      portionGrams: 250,
    );

    final edited =
        container.read(scanControllerProvider).value!.items.first;
    expect(edited.name, 'Chicken karahi');
    expect(edited.nutrition.calories, 420);
    expect(edited.portionGrams, 250);
    expect(edited.userEdited, isTrue);
    // "Check this" must go once a human has confirmed the number.
    expect(edited.needsReview, isFalse);
  });

  test('the edit becomes the baseline, so a later ½x halves the correction',
      () async {
    final food = await firstItem();
    controller().applyEdit(
      itemId: food.id,
      name: food.name,
      nutrition: const Nutrition(calories: 400, protein: 30, carbs: 10, fat: 20),
      portionGrams: 200,
    );
    controller().adjustPortion(food.id, 0.5);

    final scaled =
        container.read(scanControllerProvider).value!.items.first;
    // 200 of the corrected 400, not half of whatever the model first guessed.
    expect(scaled.nutrition.calories, 200);
    expect(scaled.portionGrams, 100);
  });

  test('a portion factor is reset by an edit rather than reapplied', () async {
    final food = await firstItem();
    controller().adjustPortion(food.id, 2);
    controller().applyEdit(
      itemId: food.id,
      name: food.name,
      nutrition: const Nutrition(calories: 300),
      portionGrams: 150,
    );

    expect(controller().portionOf(food.id), 1);
    expect(
      container.read(scanControllerProvider).value!.items.first.nutrition
          .calories,
      300,
    );
  });

  test('editing one item leaves the others alone', () async {
    await controller().describe('two eggs on toast');
    final items = container.read(scanControllerProvider).value!.items;
    if (items.length < 2) return;
    final untouched = items[1];

    controller().applyEdit(
      itemId: items.first.id,
      name: 'Changed',
      nutrition: const Nutrition(calories: 1),
    );

    final after = container.read(scanControllerProvider).value!.items[1];
    expect(after.name, untouched.name);
    expect(after.nutrition.calories, untouched.nutrition.calories);
  });
}
