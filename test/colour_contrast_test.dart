import 'dart:math' as math;

import 'package:carbsai/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds the palette to WCAG AA.
///
/// This exists because the app shipped body copy at **2.0:1** — [AppColors.muted]
/// on the app's own ground — and nothing caught it. `flutter analyze` cannot see
/// a colour pairing, the overflow suite renders in Ahem and never looks at one,
/// and the render harness writes a PNG nobody diffs for contrast. Testers found
/// it, on three separate screens, which is the most expensive way to find
/// anything.
///
/// The numbers are the WCAG 2.1 contrast formula, which is arithmetic over the
/// two colours and therefore exactly the kind of thing a unit test can pin.
void main() {
  /// Relative luminance, WCAG 2.1 §dfn-relative-luminance.
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Every ground the app actually draws text on, dark side.
  ///
  /// `inkMuted` is in here as a *surface* — it is the fill of every bottom
  /// sheet and of the Analysis cards — which is the thing that made the AI
  /// disclosure the worst case in the app: the lightest surface under the
  /// darkest text.
  const darkSurfaces = <String, Color>{
    'background': AppColors.background,
    'card / sheet (inkMuted)': AppColors.inkMuted,
  };

  /// Colours the app puts *words* in, on those grounds.
  const bodyTextOnDark = <String, Color>{
    'white': AppColors.white,
    'placeholder': AppColors.placeholder,
    'textSecondary': AppColors.textSecondary,
    'accentGreen': AppColors.accentGreen,
  };

  group('text on dark surfaces clears WCAG AA (4.5:1)', () {
    for (final surface in darkSurfaces.entries) {
      for (final text in bodyTextOnDark.entries) {
        test('${text.key} on ${surface.key}', () {
          final ratio = contrast(text.value, surface.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${text.key} on ${surface.key} is ${ratio.toStringAsFixed(2)}:1. '
                'Body text needs 4.5:1. This is the exact check that would '
                'have caught AppColors.muted being used for the AI disclosure.',
          );
        });
      }
    }
  });

  group('UI component boundaries clear WCAG AA (3:1)', () {
    for (final surface in darkSurfaces.entries) {
      test('controlMuted on ${surface.key}', () {
        final ratio = contrast(AppColors.controlMuted, surface.value);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              'controlMuted on ${surface.key} is ${ratio.toStringAsFixed(2)}:1. '
              'A drag handle, a hairline and an unselected chip outline are what '
              'make a control findable, and WCAG asks 3:1 of them.',
        );
      });
    }
  });

  test('error text is readable on both dark grounds', () {
    for (final surface in darkSurfaces.entries) {
      final ratio = contrast(AppColors.error, surface.value);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason:
            'error on ${surface.key} is ${ratio.toStringAsFixed(2)}:1 — the one '
            'message someone has to be able to read.',
      );
    }
  });

  test('ink reads on the light surfaces it is meant for', () {
    for (final ground in <String, Color>{
      'lilac': AppColors.lilac,
      'planYellow': AppColors.planYellow,
      'accentGreen': AppColors.accentGreen,
    }.entries) {
      final ratio = contrast(AppColors.ink, ground.value);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'ink on ${ground.key} is ${ratio.toStringAsFixed(2)}:1',
      );
    }
  });

  /// The regression itself, stated as a fact rather than a rule.
  ///
  /// [AppColors.muted] is kept — the week strip uses it correctly on a light
  /// ground — so the guard that matters is that nobody puts it back on a dark
  /// one. This test documents *why* it may not be used as text there.
  test('muted is unusable as text on dark, which is why it is not used there',
      () {
    expect(contrast(AppColors.muted, AppColors.background), lessThan(3.0));
    expect(contrast(AppColors.muted, AppColors.inkMuted), lessThan(3.0));

    // And it is fine where it is still used — dimmed days on the week strip,
    // which sit on the lilac pill / light calendar card.
    expect(
      contrast(AppColors.muted, AppColors.lilac),
      greaterThanOrEqualTo(4.5),
    );
  });
}
