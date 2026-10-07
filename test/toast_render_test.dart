import 'package:carbsai/core/design/app_toast.dart';
import 'package:carbsai/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// One render per file — two `runAsync` passes in one file deadlock the second.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('the three tones, as they appear', (tester) async {
    await renderScreen(
      tester,
      Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (tone, message) in [
                  (ToastTone.success, 'Chicken biryani saved to favourites.'),
                  (ToastTone.error, 'Weight must be between 25 and 350 kg.'),
                  (ToastTone.info, 'Checking for previous purchases…'),
                ]) ...[
                  appToast(message, tone: tone).content,
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
      outputName: 'toasts_actual.png',
    );
    expect(tester.takeException(), isNull);
  });
}
