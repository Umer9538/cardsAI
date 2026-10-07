import 'package:carbsai/features/diets/presentation/taste_quiz_screen.dart';
import 'package:carbsai/features/diets/presentation/widgets/taste_widgets.dart';
import 'package:carbsai/features/onboarding/presentation/widgets/quiz_controls.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The first grid step of the taste quiz, at artboard size.
///
/// One render per file — see `design_render.dart`. Beyond the PNG, this
/// asserts the one geometric fact the step depends on: nine tiles with their
/// shadows fit between the subtitle and the CTA. A grid that ran under the
/// button would not throw; the button would simply cover the last row.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('taste quiz grid renders clear of the CTA', (tester) async {
    await renderScreen(
      tester,
      const TasteQuizScreen(),
      outputName: 'taste_quiz_actual.png',
    );

    final tiles = find.byType(DishTile);
    expect(tiles, findsNWidgets(9));

    final ctaTop = tester.getTopLeft(find.byType(StickerButton)).dy;
    for (final tile in tiles.evaluate()) {
      final bottom = tester.getBottomLeft(find.byWidget(tile.widget)).dy;
      expect(
        // The hard shadow hangs below the box by the lift.
        bottom + QuizPalette.lift.dy,
        lessThan(ctaTop),
        reason: 'a tile runs under the CTA (bottom=$bottom, cta=$ctaTop)',
      );
    }
  });
}
