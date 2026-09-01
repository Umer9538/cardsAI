import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The quiz's controls, in a sticker-book idiom.
///
/// ---------------------------------------------------------------------------
/// Why it looks like this
/// ---------------------------------------------------------------------------
/// This screen has now been three things. It borrowed the onboarding artboards'
/// white-on-lilac, which read as a marketing page bolted to the front of a black
/// app. It was then rebuilt in the app's own dark surfaces, which was coherent
/// and completely characterless.
///
/// The app already has a voice and neither attempt used it: the onboarding
/// illustrations are 1930s rubber-hose cartoons — heavy uniform black linework,
/// pie-cut eyes, white gloves, sparkles — and the app icon is a gloved avocado.
/// So the controls are drawn the same way the artwork is: flat colour, a thick
/// black outline, and a hard offset shadow with no blur, like something peeled
/// off a sticker sheet. Selecting one presses it into the page — the shadow
/// collapses and the card moves into where it was.
///
/// The accent changes per question rather than staying fixed, so moving through
/// the quiz is visibly moving rather than the same screen with new words.
abstract final class QuizPalette {
  /// Warm paper rather than white. White makes black linework look like a
  /// wireframe; a cream ground makes it look printed.
  static const Color ground = Color(0xFFFFF4E4);

  static const Color ink = AppColors.ink;
  static const Color card = AppColors.white;

  /// Uniform, and thick enough to match the weight of the illustrations.
  static const double stroke = 2.5;

  /// No blur. A blurred shadow is depth; a hard one is a cut-out.
  static const Offset lift = Offset(5, 5);

  /// One per question, cycled. All four are already in the design's palette.
  static const List<Color> accents = [
    AppColors.primary,
    AppColors.accentGreen,
    AppColors.lilac,
    AppColors.planYellow,
  ];

  static Color accentFor(int step) => accents[step % accents.length];

  /// Ink on yellow and lilac, white on orange and green.
  static Color onAccent(Color accent) =>
      accent == AppColors.planYellow || accent == AppColors.lilac
      ? ink
      : AppColors.white;

  static List<BoxShadow> get shadow => const [
    BoxShadow(color: ink, offset: lift, blurRadius: 0),
  ];
}

/// How far through. Chunky and outlined, like everything else here.
class QuizProgress extends StatelessWidget {
  const QuizProgress({super.key, required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: QuizPalette.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: QuizPalette.ink, width: QuizPalette.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        // heightFactor: 1 is load-bearing. A FractionallySizedBox that is a
        // non-positioned Stack child gets loose vertical constraints, so its
        // fill takes the smallest height allowed — zero. The track draws, the
        // fill does not, and the bar never appears to move. That has shipped
        // twice in this codebase already.
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          widthFactor: fraction.clamp(0.03, 1),
          heightFactor: 1,
          alignment: Alignment.centerLeft,
          child: ColoredBox(color: accent),
        ),
      ),
    );
  }
}

/// A single-choice list that sizes its own cards and deals them in.
class QuizOptions<T> extends StatefulWidget {
  const QuizOptions({
    super.key,
    required this.value,
    required this.options,
    required this.accent,
    required this.onChanged,
  });

  final T? value;
  final List<(T, String, String?)> options;
  final Color accent;
  final ValueChanged<T> onChanged;

  static const double gap = 14;
  static const double maxHeight = 76;
  static const double minHeight = 54;

  @override
  State<QuizOptions<T>> createState() => _QuizOptionsState<T>();
}

class _QuizOptionsState<T> extends State<QuizOptions<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 280 + 45 * widget.options.length),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = widget.options.length;

        // The gap gives way before the cards do.
        //
        // Six options in the shorter box — the one left when the running
        // estimate is on screen — do not fit at the full gap, and clamping the
        // card height to a minimum without also tightening the gap is how this
        // overflowed by exactly 20pt. Cards below about 50pt stop fitting two
        // lines of text, so the spacing is what yields.
        //
        // The shadow sits outside the box, so the last card needs room for it.
        double fit(double gap) =>
            (constraints.maxHeight - gap * (n - 1) - QuizPalette.lift.dy) / n;

        var gap = QuizOptions.gap;
        if (fit(gap) < QuizOptions.minHeight) gap = 8;

        final height = fit(
          gap,
        ).clamp(QuizOptions.minHeight, QuizOptions.maxHeight).toDouble();

        return Column(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(height: gap),
              _Entering(
                controller: _entrance,
                index: i,
                child: StickerCard(
                  label: widget.options[i].$2,
                  detail: widget.options[i].$3,
                  height: height,
                  accent: widget.accent,
                  selected: widget.options[i].$1 == widget.value,
                  onTap: () => widget.onChanged(widget.options[i].$1),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Slides and fades one card in, offset from its neighbours.
class _Entering extends StatelessWidget {
  const _Entering({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Each card owns a window of one shared controller, opening after the one
    // above it. One controller rather than one per card: this rebuilds on every
    // step change, and a dozen controllers is a lot of teardown for a third of
    // a second of motion.
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        (index * 0.11).clamp(0.0, 0.62),
        1,
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(22 * (1 - animation.value), 0),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

/// A card that looks peeled off a sticker sheet, and presses into the page when
/// chosen.
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.label,
    required this.detail,
    required this.height,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final double height;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = QuizPalette.onAccent(accent);

    // Choosing presses the card down onto its own shadow: the offset goes to
    // zero and the card moves by exactly that much, so it lands where the
    // shadow was. It is the whole reason for a hard shadow rather than a soft
    // one — a blurred shadow cannot be pressed into.
    // One translation, not two. An AnimatedSlide here as well pushed the card
    // roughly 24pt right — it takes a *fraction* of the child's width, not
    // logical pixels — and the selected card ran off the edge of the canvas.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      transform: selected
          ? Matrix4.translationValues(
              QuizPalette.lift.dx,
              QuizPalette.lift.dy,
              0,
            )
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: selected ? accent : QuizPalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QuizPalette.ink, width: QuizPalette.stroke),
        boxShadow: selected ? const [] : QuizPalette.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.body(
                          color: selected ? on : QuizPalette.ink,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: AppTypography.socialLabel(
                            color: selected
                                ? on.withValues(alpha: 0.8)
                                : AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: _Tick(on: on),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final Color on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: on,
        shape: BoxShape.circle,
        border: Border.all(color: QuizPalette.ink, width: 2),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 17,
        color: on == AppColors.white ? QuizPalette.ink : AppColors.white,
      ),
    );
  }
}

/// The chunky CTA. Same sticker treatment, and it presses when tapped.
class StickerButton extends StatefulWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.accent,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final Color accent;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<StickerButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final on = QuizPalette.onAccent(widget.accent);
    final pressed = _down && enabled;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 58,
          transform: pressed
              ? Matrix4.translationValues(
                  QuizPalette.lift.dx,
                  QuizPalette.lift.dy,
                  0,
                )
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: pressed ? const [] : QuizPalette.shadow,
          ),
          alignment: Alignment.center,
          child: widget.busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(on),
                  ),
                )
              : Text(
                  widget.label,
                  style: AppTypography.buttonLabel(
                    color: on,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

/// A big number over a slider.
class QuizNumberSlider extends StatelessWidget {
  const QuizNumberSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.accent,
    required this.format,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final Color accent;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        // The number sits on its own sticker, so it reads as the answer rather
        // than as a label above a control.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: QuizPalette.shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                format(value),
                style: AppTypography.onboardingTitle(
                  color: QuizPalette.onAccent(accent),
                ).copyWith(fontSize: 42, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                unit,
                style: AppTypography.body(
                  color: QuizPalette.onAccent(accent).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            activeTrackColor: accent,
            inactiveTrackColor: AppColors.white,
            thumbColor: AppColors.white,
            overlayColor: QuizPalette.ink.withValues(alpha: 0.06),
            thumbShape: const _OutlinedThumb(),
            trackShape: const _OutlinedTrack(),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// A slider track with the same black outline as everything else.
class _OutlinedTrack extends RoundedRectSliderTrackShape {
  const _OutlinedTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = QuizPalette.ink,
    );
  }
}

class _OutlinedThumb extends SliderComponentShape {
  const _OutlinedThumb();

  static const double _radius = 15;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas
      ..drawCircle(center, _radius, Paint()..color = AppColors.white)
      ..drawCircle(
        center,
        _radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = QuizPalette.stroke
          ..color = QuizPalette.ink,
      );
  }
}

/// The running estimate, shown once there is enough to compute one.
///
/// The number moves while you answer, so the plan visibly assembles out of your
/// own answers instead of arriving at the end as an assertion.
class QuizLiveTarget extends StatelessWidget {
  const QuizLiveTarget({super.key, required this.calories});

  final double calories;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      // Off-square on purpose. It is the one element that is not part of the
      // question, and a slight tilt says so more clearly than a caption.
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: QuizPalette.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: QuizPalette.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'so far ',
              style: AppTypography.socialLabel(color: AppColors.inkMuted),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: calories),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                '${value.round()} kcal',
                style: AppTypography.socialLabel(
                  color: QuizPalette.ink,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four-point sparkles the illustrations are scattered with.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, this.size = 22, this.colour = QuizPalette.ink});

  final double size;
  final Color colour;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparklePainter(colour));
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // A four-point star drawn as two cubics, so the waist is concave rather
    // than a straight-sided diamond.
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + (i + 1) * math.pi / 2;
      path.quadraticBezierTo(
        c.dx,
        c.dy,
        c.dx + r * math.cos(a),
        c.dy + r * math.sin(a),
      );
    }
    canvas.drawPath(path..close(), Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.colour != colour;
}
