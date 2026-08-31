import 'package:carbsai/features/premium/presentation/plan_detail_screen.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('annual19 matches the design artboard', (tester) async {
    await renderScreen(tester, PlanDetailScreen(plan: SubscriptionPlan.catalogue[1]), outputName: 'annual19_actual.png');
  });
}
