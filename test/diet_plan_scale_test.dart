import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A plan is a pattern, not a calorie count. Shown raw, a "2,000 kcal" plan
/// sitting beside a personal target of 2,413 makes both numbers look invented.
void main() {
  const keto = DietPlan(
    id: 'keto',
    name: 'Keto',
    image: '',
    description: '',
    // 70*4 + 30*4 + 105*9 = 1,345 kcal of macros.
    nutrition: Nutrition(calories: 1800, protein: 70, carbs: 30, fat: 105),
  );

  test('the energy becomes the user\'s own', () {
    final scaled = keto.scaledTo(const Nutrition(calories: 2400));
    expect(scaled.nutrition.calories, 2400);
  });

  test('and the pattern survives the scaling', () {
    const target = Nutrition(calories: 2400);
    final scaled = keto.scaledTo(target);

    double fatShare(Nutrition n) =>
        n.fat * 9 / (n.protein * 4 + n.carbs * 4 + n.fat * 9);

    // Keto is a fat ratio. If that does not hold, it is not keto any more.
    expect(
      fatShare(scaled.nutrition),
      closeTo(fatShare(keto.nutrition), 0.01),
    );
    // And the macros now actually account for the calories shown, which the
    // stored figures did not.
    final energy = scaled.nutrition.protein * 4 +
        scaled.nutrition.carbs * 4 +
        scaled.nutrition.fat * 9;
    expect(energy, closeTo(2400, 12));
  });

  test('a profile with no target keeps the pattern untouched', () {
    // Before the quiz there is nothing to scale to, and inventing a split
    // would be worse than showing the catalogue's own figures.
    final scaled = keto.scaledTo(const Nutrition());
    expect(scaled.nutrition, keto.nutrition);
  });

  test('nothing else about the plan changes', () {
    final scaled = keto.scaledTo(const Nutrition(calories: 2400));
    expect(scaled.id, keto.id);
    expect(scaled.name, keto.name);
    expect(scaled.isMine, keto.isMine);
    expect(scaled.isFavorite, keto.isFavorite);
  });
}
