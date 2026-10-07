import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How a [DesignCanvas] maps its fixed artboard onto the viewport.
enum DesignFit {
  /// Scale by whichever axis needs more so the artboard reaches every edge,
  /// then crop whatever that pushes out — but never past [safeHeight].
  ///
  /// For screens whose artwork is meant to bleed: the splash, onboarding and
  /// the camera. What it crops is the *bottom*, on every viewport that is
  /// proportionally taller than the 428x926 artboard — which is all of them.
  /// [DesignCanvas.coverVisibleHeight] is the arithmetic, and it is brutal:
  /// 926 units on the artboard, 761 on an iPhone SE, 571 on a 13" iPad.
  ///
  /// The comment here used to say "never for a screen with a bottom-anchored
  /// control", and that was a convention nothing enforced. Onboarding's Next
  /// button sits at y=788 and the scanning shutter at y=789, so both were
  /// already off the display on an iPhone SE, and on an iPad the whole app
  /// stopped at the first onboarding page with no tappable node anywhere in the
  /// accessibility tree. A rule that is only a comment is a rule that has
  /// already been broken. [safeHeight] is the same rule as arithmetic.
  cover,

  /// Scale by width, cap the scale on large displays, and scroll if the
  /// result is taller than the viewport.
  ///
  /// The default, and the right choice for anything with form fields or a
  /// bottom-anchored button. Horizontal fidelity is exact at every width; the
  /// vertical axis degrades to a scroll rather than to clipping.
  fit,
}

/// Lays children out on the Figma artboard's own coordinate system and maps
/// that canvas onto the device.
///
/// Every screen in this app is designed on a 428 x 926 artboard. Rather than
/// converting each measurement into a responsive expression — which loses the
/// link back to the design file — children are positioned with the raw Figma
/// numbers inside a fixed canvas, and this widget handles the device mapping.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.children,
    required this.background,
    this.fit = DesignFit.fit,
    this.width = designWidth,
    this.height = designHeight,
    this.maxScale = defaultMaxScale,
    this.safeHeight = designHeight,
  });

  static const double designWidth = 428;
  static const double designHeight = 926;

  /// Ceiling on the width-derived scale.
  ///
  /// Without a cap, an 834pt iPad would scale the artboard 1.95x — tapping
  /// targets and type balloon, and the layout reads as a blown-up phone. Above
  /// this the canvas keeps its size and centres, which is how phone-designed
  /// apps normally present on tablets.
  static const double defaultMaxScale = 1.15;

  final List<Widget> children;
  final Color background;
  final DesignFit fit;
  final double width;
  final double height;
  final double maxScale;

  /// The artboard height [DesignFit.cover] must keep on screen.
  ///
  /// Defaults to the full artboard, so cover crops nothing it was not told it
  /// may crop. That default is the point: the old behaviour cropped by however
  /// much the viewport's aspect ratio demanded and told nobody, so the cost
  /// landed on whichever control happened to sit lowest. A screen that is
  /// genuinely pure bleed — artwork with nothing to reach — can lower this and
  /// say why.
  ///
  /// It has no effect under [DesignFit.fit], which degrades to a scroll instead
  /// of to a crop and therefore never strands anything.
  final double safeHeight;

  /// How much of the artboard's height [DesignFit.cover] can show in [viewport].
  ///
  /// Exposed because it is the number that explains every bug of this class,
  /// and it is not obvious from reading the branch below: cover scales by
  /// `max(viewport.width / 428, viewport.height / 926)`, so on anything
  /// proportionally taller than the artboard the width wins and the visible
  /// height collapses to `428 / aspect`.
  static double coverVisibleHeight(Size viewport) =>
      viewport.height /
      math.max(viewport.width / designWidth, viewport.height / designHeight);

  /// The largest OS text scale this artboard can absorb without breaking.
  ///
  /// Every child here is a `Positioned` at a fixed y with a fixed height, so
  /// text that grows does not push the next element down — it overlaps it, or
  /// overflows its own box. That is a property of drawing a design file
  /// literally, and it is the honest cost of the fidelity this canvas buys.
  ///
  /// The scale is therefore clamped rather than ignored: everything up to this
  /// ceiling is honoured exactly, and past it the app stops growing instead of
  /// coming apart. `responsive_overflow_test` renders every screen *at* this
  /// ceiling, so the number is a tested guarantee rather than a hope.
  ///
  /// **This is a limitation, not a feature.** Someone who has asked their phone
  /// for 200% text gets 115%. Fixing it properly means letting the screens
  /// reflow, which means giving up the artboard convention on each one. Until
  /// then, do not raise this without re-running the overflow suite.
  static const double maxTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final canvas = MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: background,
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        ),
      ),
    );

    if (fit == DesignFit.cover) {
      // Scaled by hand rather than with FittedBox(BoxFit.cover).
      //
      // FittedBox sizes itself to its child and then scales within whatever it
      // was given, which on a viewport wider than the artboard left the canvas
      // at its natural width, pinned left, with a strip of bare [background]
      // down the right edge exactly (viewport - artboard) wide. That is
      // invisible on the splash and onboarding, whose background matches their
      // artwork, and glaring on the camera, where it reads as the preview
      // failing to fill the frame.
      //
      // The arithmetic below is the same shape as the `fit` branch: compute a
      // scale, build a box of that size, and let BoxFit.fill do a plain uniform
      // scale into it. OverflowBox is what allows the result to be larger than
      // the viewport so it can genuinely cover.
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : width;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : height;

          // Three ceilings, and the smallest wins.
          //
          // `fill` is what cover means: reach every edge, crop the rest.
          //
          // `reachable` is the fix for what cover costs. It is the scale at
          // which [safeHeight] exactly fills the display, so clamping to it
          // guarantees nothing above that line is ever cropped away. On an
          // iPad this is what puts the Next button back on screen — unclamped,
          // cover scaled the artboard 2.41x and showed its top 571 units, and
          // the button lives at 788.
          //
          // `maxScale` is the tablet ceiling the `fit` branch already applies,
          // and cover needs it for a reason of its own: without it onboarding
          // would scale 1.49x on a 13" iPad while the login screen behind it
          // scaled 1.15x, so consecutive screens would change size as you
          // moved between them. Matching the cap keeps one canvas width across
          // the whole app on a given device.
          final fill = math.max(
            availableWidth / width,
            availableHeight / height,
          );
          final reachable = availableHeight / safeHeight;
          final scale = math.min(math.min(fill, reachable), maxScale);
          final scaledWidth = width * scale;
          final scaledHeight = height * scale;

          // Top-aligned only while there is genuinely more canvas than display.
          //
          // Cover's crop has always come off the bottom, which is deliberate —
          // the artboards mock a status bar at y=0..47 and the content hangs
          // from the top. But once a ceiling above has made the canvas *shorter*
          // than the viewport there is nothing to crop, and topCenter would
          // then pin it to the status bar with all the slack in one band at the
          // bottom. Centred is what the `fit` branch does in the same position.
          final alignment = scaledHeight > availableHeight
              ? Alignment.topCenter
              : Alignment.center;

          return ColoredBox(
            color: background,
            child: ClipRect(
              child: OverflowBox(
                alignment: alignment,
                minWidth: scaledWidth,
                maxWidth: scaledWidth,
                minHeight: scaledHeight,
                maxHeight: scaledHeight,
                child: SizedBox(
                  width: scaledWidth,
                  height: scaledHeight,
                  child: FittedBox(fit: BoxFit.fill, child: canvas),
                ),
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : height;

        final scale = math.min(availableWidth / width, maxScale);
        final scaledHeight = height * scale;

        // Aspect ratio is preserved by construction, so BoxFit.fill here is a
        // uniform scale — it just avoids a second ratio calculation.
        final scaled = SizedBox(
          width: width * scale,
          height: scaledHeight,
          child: FittedBox(fit: BoxFit.fill, child: canvas),
        );

        // One shape, whether it scrolls or not.
        //
        // This used to return `Center(child: scaled)` when the canvas fitted
        // and `SingleChildScrollView(child: Center(child: scaled))` when it did
        // not — two different widget types in the same slot. Opening the
        // keyboard shrinks the viewport, which flips a screen from the first
        // shape to the second, and Flutter cannot reuse an element whose
        // widget type has changed: it unmounts everything below and builds it
        // again. The `TextField`'s `EditableTextState` goes with it, focus is
        // lost, and the keyboard closes in the same breath it opened.
        //
        // Reported on a Pixel 8 and reproduced there: 926 artboard units scale
        // to 890dp against a 914dp viewport, so the canvas fits with the
        // keyboard down and does not with it up. A Pixel 4a lands on the other
        // side of that boundary by about a point, which is why this looked
        // device-specific rather than structural — it is one `if` away on every
        // device, and every screen with a text field is exposed to it.
        //
        // The scroll view is always there now. `minHeight` keeps the canvas
        // centred when it fits, which is what the non-scrolling branch did;
        // when it does not fit there is nothing to centre and the extra
        // constraint costs nothing. A scroll view with no overflow has zero
        // scroll extent, so nothing moves and no overscroll glow appears.
        return ColoredBox(
          color: background,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Center(child: scaled),
            ),
          ),
        );
      },
    );
  }
}

/// A raster asset exported from Figma at 3x, placed at its artboard position.
///
/// [width] and [height] must be the exported pixel dimensions divided by 3,
/// not the node's bounding box: Figma clips exports at the frame edge and
/// grows them to include drop shadows, so the two disagree often enough that
/// using the bounding box silently misplaces artwork.
class DesignImage extends StatelessWidget {
  const DesignImage({
    super.key,
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.opacity = 1,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Node opacity from the design file.
  ///
  /// Exposed here rather than left to the caller because this widget returns a
  /// [Positioned], which must be a direct child of the [Stack]. Wrapping it in
  /// an [Opacity] instead detaches it and throws "Incorrect use of
  /// ParentDataWidget" — an error that still renders plausibly, so it survives
  /// a pixel diff.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: width,
      height: height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: opacity == 1 ? image : Opacity(opacity: opacity, child: image),
    );
  }
}
