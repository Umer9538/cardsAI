import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/data/food/open_food_facts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Open Food Facts is crowd-sourced, and the barcode path presented whatever
/// it held as a measured label. A tester scanned a Bordeaux reported as 292
/// kcal with 41.9g protein and 28g fat — wine has essentially neither, and by
/// the Atwater factors those macros are 560 kcal, not 292.
void main() {
  final repo = OpenFoodFactsRepository();

  Map<String, dynamic> product({
    String name = 'Thing',
    double? kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) =>
      {
        'product_name': name,
        'nutriments': {
          'energy-kcal_100g': ?kcal,
          'proteins_100g': protein,
          'carbohydrates_100g': carbs,
          'fat_100g': fat,
        },
      };

  test('a record whose macros contradict its calories is flagged', () {
    final item = repo.parseProduct(product(
      name: 'CHÂTEAU CLERC MILON',
      kcal: 292,
      protein: 41.9,
      carbs: 35,
      fat: 28,
    ));

    expect(item, isNotNull);
    // Not "fixed" silently — flagged, so the result screen's "Check this"
    // chip appears over the row that corrects it. Same treatment `sanitize()`
    // gives a gross mismatch on the AI path.
    expect(item!.confidence, FoodConfidence.low);
  });

  test('a record that adds up is trusted as a label', () {
    // Coca-Cola: 42 kcal, 10.6g carbs, nothing else. 10.6 * 4 = 42.4.
    final item = repo.parseProduct(product(kcal: 42, carbs: 10.6));

    expect(item!.confidence, FoodConfidence.medium);
    expect(item.source, FoodSource.database);
  });

  test('a record with no nutrition at all is not a result', () {
    // These exist in quantity — a name and a photograph, figures never filled
    // in. Returning one as a 0 kcal food logs a real meal as free, silently.
    expect(repo.parseProduct(product()), isNull);
    expect(repo.parseProduct(product(kcal: 0)), isNull);
  });

  test('a nameless record is still refused', () {
    expect(repo.parseProduct({'product_name': '   '}), isNull);
  });

  test('a small mismatch is tolerated', () {
    // Rounding on a label, and fibre and polyols that the four factors do not
    // account for, routinely put a real product a few percent out. Only a
    // gross disagreement means somebody typed it in wrong.
    final item = repo.parseProduct(product(kcal: 100, carbs: 23, protein: 1));
    expect(item!.confidence, FoodConfidence.medium);
  });
}
