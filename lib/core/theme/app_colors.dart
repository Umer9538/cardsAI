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
  /// The blue from the splash collage's card artwork.
  ///
  /// An exact Figma fill like the rest, taken from the one place the design
  /// uses a blue — water needed a colour and inventing one would have been
  /// the first value in this file that came from nowhere.
  static const Color accentBlue = Color(0xFF1894E0);

  static const Color planYellow = Color(0xFFF5F378);

  /// Disabled / de-emphasised action label ("Skip").
  ///
  /// **This is a fill, not a text colour, and it is only legible on a light
  /// surface.** It survives on the week strip, where the ground is [lilac] or
  /// the calendar card; on the app's own dark ground it lands at 2.0:1. Reach
  /// for [textSecondary] or [controlMuted] for anything on a dark surface.
  static const Color muted = Color(0xFF474747);

  /// Secondary copy on dark surfaces — captions, explanatory lines, the body
  /// of a sheet, the items under a planned meal.
  ///
  /// **Not a Figma fill, and the only colour here that is not.** The design
  /// file names no secondary text colour for its dark surfaces, so [muted] was
  /// pressed into the role — and [muted] is a *disabled control* value, which
  /// puts body copy at 2.0:1 on [background] and 1.7:1 on an [inkMuted] sheet.
  /// Testers reported the AI disclosure and a plan's meal lines as unreadable
  /// and they were right: WCAG AA asks 4.5:1 of body text and those were a
  /// third of it.
  ///
  /// This clears the bar on every surface the app actually draws — 6.99:1 on
  /// [background], 6.36:1 on a card, 5.93:1 on the lightest sheet — while
  /// staying visibly dimmer than [white], so the hierarchy the design intended
  /// survives the fix. `colour_contrast_test.dart` holds it to those numbers.
  static const Color textSecondary = Color(0xFF9E9E9E);

  /// Hairline rules, sheet drag handles, and the outline of an *unselected*
  /// control — the portion chips on a scanned food, for one.
  ///
  /// Also not a Figma fill, and for the same reason: WCAG asks 3:1 of the
  /// boundary of a UI component, which is what makes a control findable, and
  /// [muted] gives 1.8:1 on a sheet. Non-text, so 3:1 rather than 4.5:1 is the
  /// bar; this clears it everywhere (3.67:1 on [background], 3.12:1 on a
  /// sheet) without pulling a hairline up to the weight of real content.
  static const Color controlMuted = Color(0xFF6E6E6E);

  static const Color white = Color(0xFFFFFFFF);
}
