import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../analysis_controller.dart';

/// Calorie Trends — replaces `assets/images/app/chart_calorie_trends.png`.
///
/// The artboard draws two coloured curves whose legend counts days under and
/// over goal. Two independent calorie series have no real meaning, so this
/// keeps the card's language — lilac, dashed gridlines, a smooth curve, day
/// captions, a two-item legend — and plots what is actually true: daily
/// calories as the curve, the goal as a dashed reference, and the two legend
/// figures computed from the diary.
class CalorieTrendsCard extends StatelessWidget {
  const CalorieTrendsCard({super.key, required this.summary});

  final AnalysisSummary summary;

  static const double width = 388;
  static const double height = 273;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lilac,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorie Trends',
            style: AppTypography.sectionTitle(color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: summary.isEmpty
                ? const _NoData()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _TrendPainter(summary: summary),
                  ),
          ),
          const SizedBox(height: 10),
          _Legend(summary: summary),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Nothing logged in this period yet.',
          style: AppTypography.socialLabel(color: AppColors.inkMuted),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.summary});

  final AnalysisSummary summary;

  @override
  Widget build(BuildContext context) {
    final unit = summary.period == AnalysisPeriod.daily ? 'days' : 'periods';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LegendItem(
            colour: AppColors.accentOrange,
            text: '${summary.daysUnderGoal} $unit under goal',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LegendItem(
            colour: AppColors.ink,
            text: '${summary.daysOverBudget} $unit over by more than '
                '${AnalysisSummary.overBudgetThreshold.round()} kcal',
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.colour, required this.text});

  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.meta(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.summary});

  final AnalysisSummary summary;

  /// Room for the y-axis captions on the left and the day captions below.
  static const double _axisWidth = 40;
  static const double _captionHeight = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final points = summary.points;
    if (points.isEmpty) return;

    final plot = Rect.fromLTRB(
      _axisWidth,
      0,
      size.width,
      size.height - _captionHeight,
    );
    if (plot.height <= 0 || plot.width <= 0) return;

    // Scale to whichever is higher, the biggest day or the goal, so the goal
    // line is always on the chart. Rounded up to a clean step so the captions
    // are round numbers.
    final peak = points.map((p) => p.calories).fold(0.0, math.max);
    final ceiling = math.max(peak, summary.targets.calories) * 1.15;
    final step = _niceStep(ceiling / 4);
    final top = step * 4;

    double y(double calories) =>
        plot.bottom - (calories / top).clamp(0.0, 1.0) * plot.height;
    double x(int i) => points.length == 1
        ? plot.center.dx
        : plot.left + plot.width * i / (points.length - 1);

    _drawGrid(canvas, plot, step, top, y);
    _drawGoal(canvas, plot, y(summary.targets.calories));
    _drawCurve(canvas, points, x, y);
    _drawCaptions(canvas, points, plot, x, size);
  }

  void _drawGrid(
    Canvas canvas,
    Rect plot,
    double step,
    double top,
    double Function(double) y,
  ) {
    final line = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (var value = step; value <= top + 0.5; value += step) {
      final at = y(value);
      _dashedLine(canvas, Offset(plot.left, at), Offset(plot.right, at), line);
      _label(
        canvas,
        value.round().toString(),
        Offset(0, at - 9),
        _axisWidth - 8,
        TextAlign.right,
      );
    }
  }

  void _drawGoal(Canvas canvas, Rect plot, double at) {
    if (at < plot.top || at > plot.bottom) return;
    _dashedLine(
      canvas,
      Offset(plot.left, at),
      Offset(plot.right, at),
      Paint()
        ..color = AppColors.accentOrange
        ..strokeWidth = 2,
      dash: 8,
      gap: 6,
    );
  }

  /// A Catmull-Rom spline through the points, converted to cubic Béziers.
  ///
  /// The artboard's curve is visibly smoothed rather than a polyline, and a
  /// spline through the actual values keeps that look without inventing data:
  /// every point is still on the curve.
  void _drawCurve(
    Canvas canvas,
    List<AnalysisPoint> points,
    double Function(int) x,
    double Function(double) y,
  ) {
    final positions = [
      for (final (i, p) in points.indexed) Offset(x(i), y(p.calories)),
    ];

    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (var i = 0; i < positions.length - 1; i++) {
      final p0 = positions[i == 0 ? 0 : i - 1];
      final p1 = positions[i];
      final p2 = positions[i + 1];
      final p3 = positions[i + 2 >= positions.length ? i + 1 : i + 2];

      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // A dot on every bucket that actually had something logged, so an empty
    // day reads as absent rather than as a zero-calorie day.
    for (final (i, point) in points.indexed) {
      if (point.days == 0) continue;
      canvas.drawCircle(
        positions[i],
        4,
        Paint()..color = AppColors.ink,
      );
    }
  }

  void _drawCaptions(
    Canvas canvas,
    List<AnalysisPoint> points,
    Rect plot,
    double Function(int) x,
    Size size,
  ) {
    for (final (i, point) in points.indexed) {
      _label(
        canvas,
        point.label,
        Offset(x(i) - 24, plot.bottom + 6),
        48,
        TextAlign.center,
      );
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double dash = 6,
    double gap = 5,
  }) {
    var at = from.dx;
    while (at < to.dx) {
      final end = math.min(at + dash, to.dx);
      canvas.drawLine(Offset(at, from.dy), Offset(end, to.dy), paint);
      at = end + gap;
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    double width,
    TextAlign align,
  ) {
    TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.meta(color: AppColors.ink),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )
      ..layout(minWidth: width, maxWidth: width)
      ..paint(canvas, at);
  }

  /// Rounds a raw axis step up to 1, 2 or 5 times a power of ten, so the
  /// captions read 200 / 400 rather than 187 / 374.
  static double _niceStep(double raw) {
    if (raw <= 0) return 100;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalised = raw / magnitude;
    final factor = normalised <= 1
        ? 1.0
        : normalised <= 2
            ? 2.0
            : normalised <= 5
                ? 5.0
                : 10.0;
    return factor * magnitude;
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.summary != summary;
}

/// Macro Distribution — replaces `assets/images/app/chart_summary.png`.
///
/// Geometry measured off that export: tiles 108 wide and 88 tall at y=96, 8.3pt
/// apart, inset 24 from each edge. Inside a tile the label's line starts ~10pt
/// down and the percentage follows immediately, which is what puts its ink at
/// 48-65 — matching the raster.
class MacroDistributionCard extends StatelessWidget {
  const MacroDistributionCard({super.key, required this.summary});

  final AnalysisSummary summary;

  static const double width = 388;
  static const double height = 198;
  static const double _tileTop = 96;
  static const double _tileHeight = 88;
  static const double _tileGap = 8.3;
  static const double _inset = 24;

  @override
  Widget build(BuildContext context) {
    final share = summary.macroShare;
    const tileWidth = (width - _inset * 2 - _tileGap * 2) / 3;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.planYellow,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: _inset,
            top: 20,
            width: width - _inset * 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Macro Distribution',
                  style: AppTypography.sectionTitle(color: AppColors.ink),
                ),
                Text(
                  summary.macroInsight,
                  style: AppTypography.body(color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          for (final (i, tile) in const [
            ('Fats', AppColors.lilac),
            ('Carbs', AppColors.accentGreen),
            ('Protein', AppColors.accentOrange),
          ].indexed)
            Positioned(
              left: _inset + i * (tileWidth + _tileGap),
              top: _tileTop,
              width: tileWidth,
              height: _tileHeight,
              child: _MacroTile(
                label: tile.$1,
                colour: tile.$2,
                share: switch (i) {
                  0 => share.fat,
                  1 => share.carbs,
                  _ => share.protein,
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.share,
    required this.colour,
  });

  final String label;
  final double share;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.body(color: AppColors.ink),
            maxLines: 1,
          ),
          Text(
            '${(share * 100).round()}%',
            style: AppTypography.cardTitle(color: AppColors.ink),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
