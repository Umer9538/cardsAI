import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/core/theme/app_typography.dart';
import 'package:carbsai/features/diets/presentation/taste_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The taste quiz's copy against the boxes it is drawn in.
///
/// Title and subtitle sit in fixed `Positioned` boxes — 388 × 84 and 388 × 50
/// — inside a hard-clipped Stack, so copy that runs long is silently cut off
/// rather than overflowing. The subtitle box holds one line of 17/25 body at
/// the 1.15 text ceiling and not two (57.5 needed), and the title box holds
/// one line of 28/42 and not two (96.6 needed). This lays every string out
/// the way the screen does, at that ceiling, and fails on the first that
/// wraps — which the screen walk in `taste_quiz_test` cannot see, because
/// `didExceedMaxLines` is false for a second line that merely fell off the
/// bottom of its box.
void main() {
  setUpAll(loadDesignFonts);

  const scaler = TextScaler.linear(DesignCanvas.maxTextScale);
  const width = 388.0;

  ({double height, bool exceeded}) measure(
    String text,
    TextStyle style,
    int maxLines,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final result = (
      height: painter.height,
      exceeded: painter.didExceedMaxLines,
    );
    painter.dispose();
    return result;
  }

  test('every subtitle fits its 388 × 50 box at the text-scale ceiling', () {
    final subtitles = TasteQuizScreen.debugSubtitles;
    expect(subtitles, isNotEmpty);
    for (final subtitle in subtitles) {
      final m = measure(subtitle, AppTypography.body(), 2);
      expect(m.exceeded, isFalse, reason: 'cut off: "$subtitle"');
      expect(
        m.height,
        lessThanOrEqualTo(50),
        reason: 'wraps out of its box (${m.height}): "$subtitle"',
      );
    }
  });

  test('every title fits its 388 × 84 box at the text-scale ceiling', () {
    final titles = TasteQuizScreen.debugTitles;
    expect(titles, isNotEmpty);
    for (final title in titles) {
      final m = measure(title, AppTypography.authTitle(), 2);
      expect(m.exceeded, isFalse, reason: 'cut off: "$title"');
      expect(
        m.height,
        lessThanOrEqualTo(84),
        reason: 'wraps out of its box (${m.height}): "$title"',
      );
    }
  });
}
