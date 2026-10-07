import 'package:carbsai/core/models/barcode.dart';
import 'package:carbsai/data/food/open_food_facts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tester typed `8888888888888` and got a product called "Motorcycle" with
/// 100 kcal beside "Protein 0g · Carbs 0g · Fat 0g", presented as a label
/// reading. `2222222222222` returned a French biscuit.
///
/// The check digit cannot catch either: for a repeated digit *d* the twelve
/// EAN-13 weights sum to 24, so the body sums to 24d and the required check
/// digit often lands on d itself. Both of those strings are arithmetically
/// perfect GTINs. The defence has to be the *record*, not the number.
void main() {
  group('the barcode itself', () {
    test('the reported codes really are valid GTINs', () {
      // Pinning the premise. If this ever fails the repdigit rule below has
      // become redundant rather than wrong, and the comment needs rewriting.
      expect(Barcode.checkDigitFor('888888888888'), 8);
      expect(Barcode.checkDigitFor('222222222222'), 2);
    });

    test('a repeated digit is refused anyway', () {
      expect(Barcode.isValid('8888888888888'), isFalse);
      expect(Barcode.isValid('2222222222222'), isFalse);
      expect(Barcode.isValid('0000000000000'), isFalse);
      expect(Barcode.isValid('00000000'), isFalse);
    });

    test('real products still pass', () {
      // Nutella, and a Coca-Cola UPC-A.
      expect(Barcode.isValid('3017620422003'), isTrue);
      expect(Barcode.isValid('049000028911'), isTrue);
    });

    test('a wrong check digit is still a wrong check digit', () {
      expect(Barcode.isValid('3017620422004'), isFalse);
      expect(Barcode.isValid('1111111111111'), isFalse);
    });
  });

  group('the record behind it', () {
    OpenFoodFactsRepository repo() => OpenFoodFactsRepository();

    test('energy with no macros at all is not a food', () {
      // "Motorcycle": 100 kcal, every macro field empty. The pre-existing
      // guard only fired when energy was zero too, so this walked through it.
      expect(
        repo().parseProduct({
          'product_name': 'Motorcycle',
          'nutriments': {'energy-kcal_100g': 100},
        }),
        isNull,
      );
    });

    test('a label that contradicts its own macros is refused', () {
      // 15.7g protein + 33.4g carbs + 30.5g fat is 471 kcal by Atwater; the
      // record claims 147. Out by 3.2x is not uncertainty to flag, it is a
      // bad record — and a "Check this" chip asks someone to verify four
      // invented numbers against a packet they will believe over us.
      expect(
        repo().parseProduct({
          'product_name': 'Galette Maca Omega',
          'nutriments': {
            'energy-kcal_100g': 147,
            'proteins_100g': 15.7,
            'carbohydrates_100g': 33.4,
            'fat_100g': 30.5,
          },
        }),
        isNull,
      );
    });

    test('a mild disagreement is kept, but flagged low', () {
      // Rounding and water content put real labels a little off their own
      // macros all the time. Refusing those would empty the database.
      final item = repo().parseProduct({
        'product_name': 'Plain yogurt',
        'nutriments': {
          'energy-kcal_100g': 61,
          'proteins_100g': 3.5,
          'carbohydrates_100g': 4.7,
          'fat_100g': 3.3,
        },
      });
      expect(item, isNotNull);
      expect(item!.name, contains('Plain yogurt'));
    });

    test('a well-formed label comes back intact', () {
      final item = repo().parseProduct({
        'product_name': 'Peanut butter',
        'brands': 'Acme',
        'nutriments': {
          'energy-kcal_100g': 598,
          'proteins_100g': 25,
          'carbohydrates_100g': 20,
          'fat_100g': 50,
        },
      });
      expect(item, isNotNull);
      expect(item!.nutrition.calories, 598);
      expect(item.name, 'Peanut butter (Acme)');
    });
  });
}
