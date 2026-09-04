import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How a [DesignCanvas] maps its fixed artboard onto the viewport.
enum DesignFit {
  /// Scale by whichever axis needs more and crop the overflow.
  ///
  /// Only for screens whose artwork is meant to bleed off the edges and whose
  /// content sits comfortably inside the middle of the frame — the splash and
  /// onboarding artboards. Never for a screen with a bottom-anchored control:
  /// at 375x667 this pushes anything below y≈760 off the bottom of the display.
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
          final availableWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : width;
          final availableHeight =
              constraints.maxHeight.isFinite ? constraints.maxHeight : height;

          final scale = math.max(availableWidth / width, availableHeight / height);
          final scaledWidth = width * scale;
          final scaledHeight = height * scale;

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
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
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : width;
        final availableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : height;

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
