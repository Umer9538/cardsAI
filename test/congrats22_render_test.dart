import 'package:carbsai/features/premium/presentation/review_summary_screen.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('congrats22 matches the design artboard', (tester) async {
    await renderScreen(
      tester,
      ReviewSummaryScreen(
        plan: SubscriptionPlan.catalogue[0],
        showSuccessInitially: true,
      ),
      outputName: 'congrats22_actual.png',
    );
  });
}
