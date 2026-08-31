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

  @override
  Widget build(BuildContext context) {
    final canvas = SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: background,
        child: Stack(clipBehavior: Clip.hardEdge, children: children),
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

        // Taller than the viewport (short phones, and tablets once the scale
        // cap bites): scroll instead of hiding the bottom of the screen.
        if (scaledHeight > availableHeight) {
          return ColoredBox(
            color: background,
            child: SingleChildScrollView(
              child: Center(child: scaled),
            ),
          );
        }

        return ColoredBox(color: background, child: Center(child: scaled));
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
