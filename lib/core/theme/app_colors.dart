import 'package:flutter/material.dart';

/// Colour tokens lifted verbatim from the Figma file (channel `jisthivv`).
/// Values are the exact sRGB conversions of the design's fill colours —
/// do not "tidy" them, they are matched against the source of truth.
abstract final class AppColors {
  /// Splash / app canvas background.
  static const Color background = Color(0xFF121212);

  /// Brand green — the `Healthy` card and primary accent (Figma style 2002:361).
  static const Color accentGreen = Color(0xFF45C588);

  /// Highlight pill behind the word "healthy" in the splash headline.
  static const Color accentOrange = Color(0xFFFF6F43);

  /// Dark ink used for text sitting on light/accent surfaces (Figma style 2002:104).
  static const Color inkOnAccent = Color(0xFF2F2F2F);

  /// Onboarding page 1 background.
  static const Color lilac = Color(0xFFDDC0FF);

  /// Headline ink on light surfaces. Same value as [background]; kept separate
  /// because it carries a different meaning and may diverge later.
  static const Color ink = Color(0xFF121212);

  /// Body copy on light surfaces.
  static const Color inkMuted = Color(0xFF232220);

  /// Primary CTA fill (Log In / Sign Up buttons).
  static const Color primary = Color(0xFFFF5A16);

  /// Field borders, dividers, and secondary button fills on dark surfaces.
  static const Color outline = Color(0xFF2F2F2F);

  /// Placeholder text inside form fields.
  static const Color placeholder = Color(0xFFC3C3C3);

  /// Validation error border and message text.
  static const Color error = Color(0xFFC93838);

  /// Premium plan card fill.
  static const Color planYellow = Color(0xFFF5F378);

  /// Disabled / de-emphasised action label ("Skip").
  static const Color muted = Color(0xFF474747);

  static const Color white = Color(0xFFFFFFFF);
}
