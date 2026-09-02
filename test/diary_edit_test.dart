import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A logged meal could not be touched: the only way to fix a portion was to
/// delete it and scan again, which also spent another scan from the quota.
/// `updateMeal` was in the repository contract from the start and nothing ever
/// called it.
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

  DiaryRepository diary() => container.read(diaryRepositoryProvider);

  Meal mealOf(DateTime at) => Meal(
        id: 'm1',
        eatenAt: at,
        slot: MealSlot.forTime(at),
        title: 'Chicken karahi',
        items: const [
          FoodItem(
            id: 'f1',
            name: 'Chicken karahi',
            nutrition: Nutrition(calories: 500, protein: 40, carbs: 12, fat: 32),
          ),
          FoodItem(
            id: 'f2',
            name: 'Roti',
            nutrition: Nutrition(calories: 120, protein: 3, carbs: 25, fat: 1),
          ),
        ],
      );

  test('correcting an item persists to the same meal', () async {
    final now = DateTime.now();
    final saved = await diary().addMeal(mealOf(now));

    await diary().updateMeal(
      saved.copyWith(
        items: [
          saved.items.first.copyWith(
            nutrition: const Nutrition(calories: 300, protein: 40),
            portionGrams: 150,
            userEdited: true,
          ),
          saved.items.last,
        ],
      ),
    );

    final day = await diary()
        .watchDay(DateTime(now.year, now.month, now.day))
        .first;
    final reloaded = day.firstWhere((m) => m.id == saved.id);
    expect(reloaded.items.first.nutrition.calories, 300);
    expect(reloaded.items.first.portionGrams, 150);
    expect(reloaded.items.first.userEdited, isTrue);
    // The meal is corrected, not duplicated.
    expect(day.where((m) => m.id == saved.id).length, 1);
    // The untouched item is untouched.
    expect(reloaded.items.last.nutrition.calories, 120);
  });

  test('logging again creates a separate meal with no scan attached', () async {
    final now = DateTime.now();
    final saved = await diary().addMeal(mealOf(now));

    final again = await diary().addMeal(
      Meal(
        id: 'm2',
        eatenAt: now,
        items: saved.items,
        slot: MealSlot.forTime(now),
        title: saved.title,
      ),
    );

    final day = await diary()
        .watchDay(DateTime(now.year, now.month, now.day))
        .first;
    // Counted by id: the local backend seeds a day, so the diary is not empty
    // to begin with.
    expect(
      day.where((m) => m.id == saved.id || m.id == again.id).length,
      2,
    );
    expect(again.id, isNot(saved.id));
    // Two meals must never point at one scan record, or the cost log
    // overstates how many scans were actually run.
    expect(again.scanId, isNull);
  });
}
