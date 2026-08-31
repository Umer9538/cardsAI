import 'package:carbsai/data/local/seed_data.dart';
import 'package:carbsai/features/diets/presentation/diet_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('dietdet28 matches the design artboard', (tester) async {
    // The artboard shows Mediterranean Lifestyle, which is the first seeded
    // plan; the screen takes the plan rather than loose strings now.
    await renderScreen(
      tester,
      DietDetailScreen(plan: SeedData.dietPlans.first),
      outputName: 'dietdet28_actual.png',
    );
  });
}
