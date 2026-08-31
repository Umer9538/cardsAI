import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Space Grotesk ships from Google as a single variable font whose default
/// instance is wght=300. Bundling it directly made the engine synthesise a
/// fake bold to reach SemiBold (~20% too much ink vs the Figma reference), so
/// the project bundles static instances cut at 400/500/600/700 instead and
/// selects them with a plain [TextStyle.fontWeight].
abstract final class AppTypography {
  static const String fontFamily = 'SpaceGrotesk';

  static TextStyle _grotesk({
    required double fontSize,
    required double height,
    required int weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: height / fontSize,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Splash headline — Figma: Space Grotesk SemiBold 24 / 36.
  static TextStyle headline({Color color = Colors.white}) =>
      _grotesk(fontSize: 24, height: 36, weight: 600, color: color);

  /// Onboarding headline — Figma: Space Grotesk SemiBold 28 / 42.
  static TextStyle onboardingTitle({Color color = AppColors.ink}) =>
      _grotesk(fontSize: 28, height: 42, weight: 600, color: color);

  /// Onboarding body copy — Figma: Space Grotesk Regular 17 / 25.
  static TextStyle onboardingBody({Color color = AppColors.inkMuted}) =>
      _grotesk(fontSize: 17, height: 25, weight: 400, color: color);

  /// Round-button label — Figma: Space Grotesk SemiBold 18 / 27.
  static TextStyle buttonLabel({Color color = AppColors.white}) =>
      _grotesk(fontSize: 18, height: 27, weight: 600, color: color);

  /// Screen heading on auth screens — Figma: Space Grotesk SemiBold 28 / 42.
  static TextStyle authTitle({Color color = AppColors.white}) =>
      _grotesk(fontSize: 28, height: 42, weight: 600, color: color);

  /// Field labels, field text, and body links — Figma: Space Grotesk 17 / 25.
  static TextStyle body({Color color = AppColors.white}) =>
      _grotesk(fontSize: 17, height: 25, weight: 400, color: color);

  /// Social-button labels — Figma: Space Grotesk Regular 15 / 22.
  static TextStyle socialLabel({Color color = AppColors.white}) =>
      _grotesk(fontSize: 15, height: 22, weight: 400, color: color);

  /// Divider "Or" — Figma: Space Grotesk Regular 13 / 19.
  static TextStyle divider({Color color = AppColors.white}) =>
      _grotesk(fontSize: 13, height: 19, weight: 400, color: color);

  /// Inline validation message — Figma uses Satoshi 15 / 18 here, the only
  /// place in the file that leaves Space Grotesk. Substituted rather than
  /// bundling a second family for one string; see the screen doc comment.
  static TextStyle errorMessage({Color color = AppColors.error}) =>
      _grotesk(fontSize: 15, height: 18, weight: 400, color: color);

  /// Dialog heading — Figma: Space Grotesk SemiBold 24 / 36.
  static TextStyle cardTitle({Color color = AppColors.white}) =>
      _grotesk(fontSize: 24, height: 36, weight: 600, color: color);

  /// Screen title in the top bar — Figma: Space Grotesk SemiBold 24 / 36.
  static TextStyle topBarTitle({Color color = AppColors.white}) =>
      _grotesk(fontSize: 24, height: 36, weight: 600, color: color);

  /// Section and card headings — Figma: Space Grotesk SemiBold 20 / 30.
  static TextStyle sectionTitle({Color color = AppColors.white}) =>
      _grotesk(fontSize: 20, height: 30, weight: 600, color: color);

  /// Plan price — Figma: Space Grotesk SemiBold 34 / 51, with the period
  /// suffix ("/Month") overridden to 18 / 27 by a character-level style run.
  static TextStyle planPrice({Color color = AppColors.ink}) =>
      _grotesk(fontSize: 34, height: 51, weight: 600, color: color);

  static TextStyle planPeriod({Color color = AppColors.ink}) =>
      _grotesk(fontSize: 18, height: 27, weight: 600, color: color);

  /// Calendar day/date and greeting — Figma: Space Grotesk Medium 15 / 22.
  static TextStyle label({Color color = AppColors.white}) =>
      _grotesk(fontSize: 15, height: 22, weight: 500, color: color);

  /// Card list titles — Figma: Space Grotesk SemiBold 18 / 27.
  static TextStyle cardHeading({Color color = AppColors.white}) =>
      _grotesk(fontSize: 18, height: 27, weight: 600, color: color);

  /// Dense metadata rows — Figma: Space Grotesk Regular 13 / 19.
  static TextStyle meta({Color color = AppColors.white}) =>
      _grotesk(fontSize: 13, height: 19, weight: 400, color: color);

  /// Collage card labels — Figma: Space Grotesk SemiBold 18 / 22.
  static TextStyle cardLabel({Color color = Colors.white}) =>
      _grotesk(fontSize: 18, height: 22, weight: 600, color: color);
}
