import 'package:carbsai/features/premium/presentation/plan_detail_screen.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('month18 matches the design artboard', (tester) async {
    await renderScreen(tester, PlanDetailScreen(plan: SubscriptionPlan.catalogue[0]), outputName: 'month18_actual.png');
  });
}
