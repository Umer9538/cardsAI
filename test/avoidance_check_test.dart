import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/avoidance_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cases the client matcher and `violations()` in `workers/src/planner.ts`
/// must agree on. Every line here was a real miss or a real false refusal in
/// review, so a change to either list that flips one is a regression, not a
/// tidy-up.
void main() {
  bool hit(String text, Avoidance a) => AvoidanceCheck.mentions(text, a);

  test('safe compounds are not the excluded food', () {
    for (final name in [
      'Oat milk, 200 ml',
      'Almond milk, 200 ml',
      'Soy milk',
      'Coconut milk, 100 ml',
      'Peanut butter, 1 tbsp',
      'Cocoa butter',
      'Coconut yoghurt, 100 g',
      'Butternut squash, 150 g',
      'Bean curd, 100 g',
      'Dairy-free spread, 10 g',
      'Non-dairy milk, 200 ml',
      'Dairy-free cheese, 30 g',
    ]) {
      expect(hit(name, Avoidance.dairy), isFalse, reason: name);
    }
    for (final name in [
      'Tuna steak, 150 g',
      'Chicken burger, 1',
      'Lamb mince, 100 g',
      'Turkey burger, 1',
    ]) {
      expect(hit(name, Avoidance.beef), isFalse, reason: name);
    }
    for (final name in [
      'Gluten-free bread, 2 slices',
      'Gluten free pasta, 80 g',
      'Corn tortillas, 2',
      'Rice noodles, 150 g',
      'Lettuce wrap, 2',
      'Toasted almonds, 10 g',
      'Rice paper rolls, 3',
    ]) {
      expect(hit(name, Avoidance.gluten), isFalse, reason: name);
    }
    expect(hit('Chicken sausage, 2', Avoidance.pork), isFalse);
    expect(hit('Hamburger, 1', Avoidance.pork), isFalse);
    expect(hit('Hammered yam, 100 g', Avoidance.pork), isFalse);
    expect(hit('Eggplant, 150 g', Avoidance.eggs), isFalse);
    expect(hit('Avocado, half', Avoidance.seafood), isFalse);
    for (final name in ['Nutmeg, 1 tsp', 'Nutritional yeast, 10 g']) {
      expect(hit(name, Avoidance.nuts), isFalse, reason: name);
    }
    for (final name in ['Minced garlic, 2 cloves', 'Minced ginger, 1 tsp']) {
      expect(hit(name, Avoidance.beef), isFalse, reason: name);
    }
  });

  test('derived forms and compounds of the excluded food are caught', () {
    for (final name in [
      'Creamy chicken korma, 200 g',
      'Buttermilk pancakes, 2',
      'Cheesy omelette',
      'Buttered toast, 2 slices',
      'Cheeseburger, 1',
      'Paneer tikka, 100 g',
      'Raita, 50 g',
      'Ice cream, 1 scoop',
    ]) {
      expect(hit(name, Avoidance.dairy), isTrue, reason: name);
    }
    for (final name in ['Hamburger, 1', 'Cheeseburger, 1', 'Beef steak, 150 g', 'Minced beef, 100 g']) {
      expect(hit(name, Avoidance.beef), isTrue, reason: name);
    }
    for (final name in ['Flatbread, 1', 'Breadcrumbs, 20 g', 'Breaded chicken, 150 g']) {
      expect(hit(name, Avoidance.gluten), isTrue, reason: name);
    }
    for (final name in ['Shellfish platter', 'Swordfish, 150 g', 'Fishcakes, 2', 'Fish sauce, 1 tsp']) {
      expect(hit(name, Avoidance.seafood), isTrue, reason: name);
    }
    expect(hit('Eggs, 2 large', Avoidance.eggs), isTrue);
    // The bare category word. Both of these reached a plate that excluded
    // them: neither "nuts" nor "seafood" was in its own word list.
    expect(hit('Mixed nuts, 30 g', Avoidance.nuts), isTrue);
    expect(hit('Nut butter, 1 tbsp', Avoidance.nuts), isTrue);
    expect(hit('Seafood platter', Avoidance.seafood), isTrue);
    expect(hit('Bacon, 2 rashers', Avoidance.pork), isTrue);
  });

  test('violations lists each hit avoidance once, in the asked order', () {
    final plan = ['Beef steak, 150 g', 'Paneer tikka, 100 g', 'Rice, 200 g'];
    expect(
      AvoidanceCheck.violations(plan, [Avoidance.dairy, Avoidance.beef, Avoidance.nuts]),
      [Avoidance.dairy, Avoidance.beef],
    );
    expect(AvoidanceCheck.violations(['Beef, 100 g'], const []), isEmpty);
    expect(AvoidanceCheck.violations(const [], Avoidance.values), isEmpty);
  });

  test('every avoidance word is lowercase and every exception contains a word', () {
    for (final a in Avoidance.values) {
      for (final w in a.words) {
        expect(w, w.toLowerCase(), reason: '${a.name}: $w');
      }
      for (final e in a.except) {
        expect(e, e.toLowerCase(), reason: '${a.name}: $e');
        // An exception that no word could ever match is dead weight, and
        // usually a typo — unless it is a qualifier, which earns its place
        // by voiding the word after it.
        expect(
          AvoidanceCheck.isQualifier(e) || a.words.any((w) => e.contains(w)),
          isTrue,
          reason: '${a.name}: "$e" contains none of its words',
        );
      }
    }
  });
}
