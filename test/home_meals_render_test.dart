import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('home shows the selected day\'s meals', (tester) async {
    // The seeded diary puts one meal on today, so this exercises the list
    // rather than the empty state.
    await renderScreen(
      tester,
      const HomeScreen(),
      outputName: 'home_meals_actual.png',
    );
  });
}
