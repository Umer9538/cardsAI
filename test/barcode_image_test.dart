import 'package:carbsai/data/food/open_food_facts_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// `fields` on the Open Food Facts API is an allow-list: a key not named in it
/// is simply absent from the response. The parser was reading
/// `image_front_url` out of a document that could never contain it, so every
/// barcode scan fell back to the artboard's stock plate of food.
void main() {
  test('the request asks for the product photograph', () {
    const fields = OpenFoodFactsRepository.debugFields;
    for (final key in const [
      'image_front_url',
      'image_url',
      'image_front_small_url',
    ]) {
      expect(fields, contains(key), reason: '$key is not requested');
    }
  });

  test('and still asks for everything the nutrition parser reads', () {
    const fields = OpenFoodFactsRepository.debugFields;
    for (final key in const [
      'product_name',
      'brands',
      'nutriments',
      'serving_quantity',
      'serving_size',
    ]) {
      expect(fields, contains(key));
    }
  });
}
