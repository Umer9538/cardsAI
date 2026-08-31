import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/data/local/seed_data.dart';
import 'package:carbsai/features/scan/presentation/scan_result_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('scan result renders its portion controls', (tester) async {
    await renderScreen(
      tester,
      ScanResultScreen(
        result: ScanResult(
          id: 'preview',
          capturedAt: DateTime(2026, 8, 27, 13),
          items: SeedData.scannedFoods,
          photoPath: 'assets/images/app/scan_food.png',
          confidence: FoodConfidence.high,
        ),
      ),
      outputName: 'scanres_edit_actual.png',
    );
  });
}
