import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'quiz_controls.dart';

/// The build step: a sweep ring, and a list of lines that resolve as it
/// passes them.
///
/// A spinner says "waiting". This says "working", because it shows the
/// working — each [stages] entry is a label and the value it resolves to, and
/// the value appears as the sweep reaches its share of the ring. Onboarding
/// hands it `TargetCalculator`'s real intermediates; the plan builder hands it
/// the taste profile it is about to send. Either way it is theatre that is
/// true: nothing here is invented, it is only paced.
///
/// [duration] is the whole sweep. The last stage holds the final value until
/// [onDone] fires, which is when the caller's real work — a navigation, or a
/// network call it was already waiting on — takes over.
class QuizBuildStep extends StatefulWidget {
  const QuizBuildStep({
    super.key,
    required this.accent,
    required this.stages,
    required this.onDone,
    this.duration = const Duration(milliseconds: 2600),
    this.showPercent = true,
    this.waiting = false,
    this.waitingCaption,
    this.waitingLongCaption,
    this.longAfter = const Duration(seconds: 30),
  });

  final Color accent;

  /// `(label, value)`. An empty value shows the label alone.
  final List<(String, String)> stages;
  final VoidCallback onDone;
  final Duration duration;

  /// A percentage in the centre while the sweep runs. True where the sweep
  /// *is* the work (onboarding: four sums, done when it ends). False where it
  /// is only the inputs being read out ahead of a slow call — there a "100%"
  /// that then sits under "still working" reads as a stuck screen, so the
  /// centre shows a sparkle growing with the sweep instead.
  final bool showPercent;

  /// The sweep has finished and the real result has not landed. The centre
  /// becomes an indeterminate spinner — motion that promises nothing about
  /// how far along the work is, because nothing here knows — and
  /// [waitingCaption] appears under the rows. After [longAfter] of waiting
  /// the caption switches to [waitingLongCaption], if one is given, so a slow
  /// call is acknowledged rather than silently outlasting its own copy.
  final bool waiting;
  final String? waitingCaption;
  final String? waitingLongCaption;
  final Duration longAfter;

  @override
  State<QuizBuildStep> createState() => _QuizBuildStepState();
}

class _QuizBuildStepState extends State<QuizBuildStep>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      HapticFeedback.mediumImpact();
      widget.onDone();
    })
    ..forward();

  /// The indeterminate spinner, running only while [QuizBuildStep.waiting].
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// One tick per stage as it lands, so the sequence is felt as well as seen.
  int _tapped = 0;

  /// Cancelled in [dispose]: a timer that outlives the screen fails every
  /// test that touches it.
  Timer? _longTimer;
  bool _long = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWaiting();
  }

  @override
  void didUpdateWidget(QuizBuildStep old) {
    super.didUpdateWidget(old);
    if (old.waiting != widget.waiting) _syncWaiting();
  }

  void _syncWaiting() {
    if (widget.waiting) {
      // A repeating sweep is exactly what "reduce motion" exists to stop.
      if (!MediaQuery.disableAnimationsOf(context) && !_spin.isAnimating) {
        _spin.repeat();
      }
      _longTimer ??= Timer(widget.longAfter, () {
        if (mounted) setState(() => _long = true);
      });
    } else {
      _spin.stop();
      _longTimer?.cancel();
      _longTimer = null;
      _long = false;
    }
  }

  @override
  void dispose() {
    _longTimer?.cancel();
    _spin.dispose();
    _c.dispose();
    super.dispose();
  }

  Widget _centre(double progress) {
    if (widget.waiting) {
      return AnimatedBuilder(
        animation: _spin,
        builder: (context, _) => CustomPaint(
          size: const Size(44, 44),
          painter: _SpinnerPainter(turn: _spin.value),
        ),
      );
    }
    if (widget.showPercent) {
      return Text(
        '${(progress * 100).round()}%',
        style: AppTypography.onboardingTitle(color: QuizPalette.ink)
            .copyWith(fontSize: 34, fontWeight: FontWeight.w700),
      );
    }
    return Sparkle(size: 18 + 30 * progress, colour: widget.accent);
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final progress = _c.value;
        // A stage is done once the sweep has passed its share of the ring.
        final done = (progress * stages.length).floor();
        if (done > _tapped && done <= stages.length) {
          _tapped = done;
          HapticFeedback.selectionClick();
        }

        return Column(
          children: [
            const SizedBox(height: 6),
            SizedBox(
              width: 148,
              height: 148,
              child: CustomPaint(
                painter: QuizRingPainter(
                  progress: progress,
                  accent: widget.accent,
                ),
                child: Center(child: _centre(progress)),
              ),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < stages.length; i++)
              QuizStageRow(
                label: stages[i].$1,
                value: stages[i].$2,
                accent: widget.accent,
                // Each row owns an equal share of the sweep.
                progress: ((progress * stages.length) - i).clamp(0.0, 1.0),
              ),
            if (widget.waiting && widget.waitingCaption != null) ...[
              const SizedBox(height: 12),
              Text(
                _long
                    ? (widget.waitingLongCaption ?? widget.waitingCaption!)
                    : widget.waitingCaption!,
                style: AppTypography.socialLabel(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One line of the working, revealing its value as the sweep passes it.
class QuizStageRow extends StatelessWidget {
  const QuizStageRow({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.progress,
  });

  final String label;
  final String value;
  final Color accent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final done = progress >= 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Opacity(
        // Pending rows are present but recede, so the list does not reflow as
        // each one lands.
        opacity: 0.25 + 0.75 * progress,
        child: Transform.translate(
          offset: Offset(14 * (1 - progress), 0),
          child: Row(
            children: [
              // The tick stamps in rather than fading: it is the moment the
              // step completed.
              AnimatedScale(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                scale: done ? 1 : 0.4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done ? accent : QuizPalette.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: QuizPalette.ink, width: 2),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded,
                          size: 14, color: QuizPalette.onAccent(accent))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.socialLabel(color: QuizPalette.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // The value fades in as its row lands, so the figure looks
              // arrived at rather than looked up.
              if (value.isNotEmpty)
                Opacity(
                  opacity: progress,
                  child: Text(
                    value,
                    style: AppTypography.socialLabel(color: QuizPalette.ink)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sweep. Outlined on both edges so it belongs with everything else here.
class QuizRingPainter extends CustomPainter {
  const QuizRingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  static const double _stroke = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2 - QuizPalette.stroke;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    const start = -math.pi / 2;

    // Track.
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = QuizPalette.card);

    // Filled sweep.
    if (progress > 0) {
      canvas.drawArc(rect, start, math.pi * 2 * progress, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _stroke
            ..strokeCap = StrokeCap.round
            ..color = accent);
    }

    // The two black edges of the band, drawn last so the fill cannot bleed
    // over them.
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = QuizPalette.stroke
      ..color = QuizPalette.ink;
    canvas
      ..drawCircle(centre, radius + _stroke / 2, outline)
      ..drawCircle(centre, radius - _stroke / 2, outline);
  }

  @override
  bool shouldRepaint(QuizRingPainter old) =>
      old.progress != progress || old.accent != accent;
}

/// An arc chasing its own tail: the honest shape for "working, no idea how
/// far". Ink on the card ground, outlined like everything else here.
class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.turn});

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 3,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = QuizPalette.card,
    );
    canvas.drawArc(
      rect,
      turn * math.pi * 2,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = QuizPalette.ink,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.turn != turn;
}
