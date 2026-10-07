import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:carbsai/features/app/presentation/widgets/meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The diet card used to be positioned from a bare artboard number while its
/// own heading carried the shift for the fat/fibre row and the weight card. It
/// was therefore drawn 212 units too high — directly over the meals section —
/// so a meal you had just logged disappeared under the plan photograph. Found
/// on a device; nothing in the suite could see it, because two `Positioned`
/// children overlapping is not an error.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('the diet card never overlaps the meals section', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(const MaterialApp(home: HomeScreen())),
    );
    await tester.pump();

    // Swept over the activity count too, because the card above the diary now
    // grows with the day's bouts — so the shift is a function, and a constant
    // there would draw the diary over a second logged walk.
    for (var meals = 0; meals <= 4; meals++) {
      for (var bouts = 0; bouts <= 4; bouts++) {
        // The section starts at a computed y and grows downward; the card
        // follows it. Both come from the same functions the screen uses, so
        // this asserts the relationship rather than restating the arithmetic.
        final sectionTop = HomeScreen.mealsTop(bouts);
        final sectionBottom = sectionTop + HomeScreen.mealsHeight(meals);
        final cardTop = HomeScreen.dietCardTop(meals, bouts);

        expect(
          cardTop,
          greaterThanOrEqualTo(sectionBottom),
          reason: 'with $meals meals and $bouts bouts the plan card is drawn '
              'over the diary',
        );
      }
    }
  });

  test('the canvas is tall enough to hold everything it positions', () {
    for (var meals = 0; meals <= 6; meals++) {
      for (var bouts = 0; bouts <= 4; bouts++) {
        final lastRowBottom = HomeScreen.dietCardTop(meals, bouts) + 220 + 46;
        expect(
          HomeScreen.contentHeightFor(meals, bouts),
          greaterThan(lastRowBottom),
          reason: 'with $meals meals and $bouts bouts the plan card runs past '
              'the canvas',
        );
      }
    }
  });

  test('one more bout moves everything below it down by one row', () {
    final step = HomeScreen.mealsTop(2) - HomeScreen.mealsTop(1);
    expect(step, greaterThan(0));
    expect(HomeScreen.mealsTop(3) - HomeScreen.mealsTop(2), step);
    // And the diary and the plan card move together with it.
    expect(HomeScreen.dietCardTop(1, 2) - HomeScreen.dietCardTop(1, 1), step);
  });

  test('one more meal moves the card down by exactly one card', () {
    expect(
      HomeScreen.dietCardTop(2) - HomeScreen.dietCardTop(1),
      MealCard.height + 12,
    );
  });
}
