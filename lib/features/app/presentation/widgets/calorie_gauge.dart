import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The semicircular calorie gauge on Home.
///
/// Replaces `assets/images/app/calorie_gauge.png`, which could not be driven by
/// data: the artboard's export bakes in both the arc's fill fraction *and* the
/// "1672 / Left / 0 / 100" labels. The screen was drawing those same labels on
/// top of the raster, so every number rendered twice, slightly offset — which a
/// pixel diff against that same export could never reveal.
///
/// Geometry is measured off the export's alpha channel, in its own 652px (3x)
/// space: centre (326, 338), centreline radius 236, stroke 82. Divided by three
/// those are the artboard points below.
class CalorieGauge extends StatelessWidget {
  const CalorieGauge({super.key, required this.progress});

  /// 0..1 of the day's calorie goal consumed.
  final double progress;

  /// The export's own box, so the widget drops into the artboard position the
  /// raster used.
  static const double size = 217.33;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GaugePainter(progress: progress.clamp(0.0, 1.0)),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress});

  final double progress;

  /// Artboard points, from the 3x export divided by three.
  static const Offset _centre = Offset(108.67, 112.67);
  static const double _radius = 78.67;
  static const double _stroke = 27.33;

  /// The soft haze behind the arc — Figma's 48pt glow, which the export carries
  /// as a low-alpha disc rather than a blur.
  static const double _glowRadius = 60.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: _centre, radius: _radius);

    canvas.drawCircle(
      _centre,
      _glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.ink.withValues(alpha: 0.10),
            AppColors.ink.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: _centre, radius: _glowRadius)),
    );

    Paint band(Color colour) => Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    // A half turn, left to right over the top. Round caps extend the ends by
    // half a stroke, which is what puts the cap bottoms level with y=379 in the
    // export.
    canvas.drawArc(rect, math.pi, math.pi, false,
        band(AppColors.ink.withValues(alpha: 0.10)));

    if (progress > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress,
        false,
        band(AppColors.ink),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The macro progress bar on the Carbs and Protein cards.
///
/// Replaces `bar_carbs.png` / `bar_protein.png` for the same reason as the
/// gauge: both the fill fraction and the two figures are baked into the export.
///
/// Geometry from that export (456x93 at 3x): a 6pt fully-rounded track across
/// the full 152pt, and the label row starting 16.67pt down.
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.progress,
    required this.consumed,
    required this.target,
  });

  final double progress;

  /// Already formatted — "140g".
  final String consumed;
  final String target;

  static const double width = 152;
  static const double height = 31;
  static const double _trackHeight = 6;
  static const double _labelTop = 16.67;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: width,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(_trackHeight / 2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: width * progress.clamp(0.0, 1.0),
            height: _trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(_trackHeight / 2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: _labelTop,
            width: width,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(consumed, style: _labelStyle),
                Text(target, style: _labelStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontSize: 13,
    height: 19 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
