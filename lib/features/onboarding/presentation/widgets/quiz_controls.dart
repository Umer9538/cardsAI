import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The quiz's controls.
///
/// ---------------------------------------------------------------------------
/// Why these are dark
/// ---------------------------------------------------------------------------
/// The quiz first borrowed the onboarding artboards' palette — white cards on
/// lilac — because it sits between those pages and the app. On a device that
/// read as a pale purple marketing screen bolted to the front of a black app,
/// and the seam showed at the moment the quiz handed over to Home.
///
/// It now uses the *app's* surface language instead: `#121212` ground,
/// `#232220` cards on a `#2F2F2F` outline, primary orange for anything chosen.
/// That is the same set Settings, Notifications and the scan result are built
/// from, so the quiz reads as the first screens of the product rather than the
/// last screens of the pitch — and walking out of it into Home is a change of
/// content, not of world.
abstract final class QuizPalette {
  static const Color ground = AppColors.background;

  /// The card fill every other list in the app uses.
  static const Color card = Color(0xFF232220);
  static const Color border = AppColors.outline;

  /// Chosen. The app's CTA colour, so selection and the button agree.
  static const Color selected = AppColors.primary;

  static const Color text = AppColors.white;
  static const Color muted = AppColors.placeholder;
}

/// How far through, as a bar rather than a count.
class QuizProgress extends StatelessWidget {
  const QuizProgress({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          const ColoredBox(
            color: QuizPalette.border,
            child: SizedBox(width: 388, height: 6),
          ),
          // heightFactor: 1 is load-bearing, not tidiness.
          //
          // A FractionallySizedBox that is a non-positioned Stack child is
          // given loose vertical constraints, so a ColoredBox inside it takes
          // the smallest height allowed — zero. The track draws, the fill does
          // not, and the bar sits there looking empty however far through you
          // are. Exactly the bug the Scan Result macro bars had.
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            widthFactor: fraction.clamp(0.02, 1),
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: const ColoredBox(color: QuizPalette.selected),
          ),
        ],
      ),
    );
  }
}

/// A single-choice list that sizes its own cards to the space it is given, and
/// deals them in one after another.
///
/// The stagger is the difference between a list that appears and a list that
/// arrives. It is 40ms apart and it is over in a third of a second, which is
/// long enough to read as motion and short enough that nobody waiting to answer
/// is kept waiting.
class QuizOptions<T> extends StatefulWidget {
  const QuizOptions({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T? value;

  /// (value, label, optional detail line)
  final List<(T, String, String?)> options;
  final ValueChanged<T> onChanged;

  static const double gap = 12;
  static const double maxHeight = 74;
  static const double minHeight = 52;

  @override
  State<QuizOptions<T>> createState() => _QuizOptionsState<T>();
}

class _QuizOptionsState<T> extends State<QuizOptions<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 260 + 40 * widget.options.length),
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
        final available =
            constraints.maxHeight - QuizOptions.gap * (n - 1);
        final height = (available / n)
            .clamp(QuizOptions.minHeight, QuizOptions.maxHeight)
            .toDouble();

        return Column(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(height: QuizOptions.gap),
              _Entering(
                controller: _entrance,
                index: i,
                count: n,
                child: QuizOptionCard(
                  label: widget.options[i].$2,
                  detail: widget.options[i].$3,
                  height: height,
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
    required this.count,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Each card owns a window of the shared controller, opening 40ms after the
    // one above it. One controller rather than one per card: this rebuilds on
    // every step change, and a dozen controllers per step is a lot of teardown
    // for an effect that lasts a third of a second.
    final start = (index * 0.10).clamp(0.0, 0.6);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

class QuizOptionCard extends StatelessWidget {
  const QuizOptionCard({
    super.key,
    required this.label,
    required this.detail,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Animated rather than switched: the fill and the tick arriving over a beat
    // is most of what makes answering feel responsive rather than transactional.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: height,
      decoration: BoxDecoration(
        color: selected ? QuizPalette.selected : QuizPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? QuizPalette.selected : QuizPalette.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // The colour change is quick and the tick is small; the haptic is
            // what actually confirms the tap landed.
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTypography.body(color: QuizPalette.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: AppTypography.socialLabel(
                            color: selected
                                ? const Color(0xCCFFFFFF)
                                : QuizPalette.muted,
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
                  child: const _Tick(),
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
  const _Tick();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 18,
        color: QuizPalette.selected,
      ),
    );
  }
}

/// A big number over a slider — no keyboard, which is the whole point.
class QuizNumberSlider extends StatelessWidget {
  const QuizNumberSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.format,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              format(value),
              style: AppTypography.authTitle(color: QuizPalette.text)
                  .copyWith(fontSize: 44),
            ),
            const SizedBox(width: 8),
            Text(unit, style: AppTypography.body(color: QuizPalette.muted)),
          ],
        ),
        const SizedBox(height: 20),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: QuizPalette.selected,
            inactiveTrackColor: QuizPalette.border,
            thumbColor: AppColors.white,
            overlayColor: const Color(0x22FF5A16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
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

/// The running estimate, shown once there is enough to compute one.
///
/// This is the mechanic worth borrowing from the trackers that do this well:
/// the number moves while you answer, so the plan visibly assembles out of your
/// own answers instead of arriving at the end as an assertion.
class QuizLiveTarget extends StatelessWidget {
  const QuizLiveTarget({super.key, required this.calories});

  final double calories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: QuizPalette.card,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: QuizPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded,
              size: 16, color: QuizPalette.selected),
          const SizedBox(width: 6),
          Text(
            'Target so far ',
            style: AppTypography.socialLabel(color: QuizPalette.muted),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: calories),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text(
              '${value.round()} kcal',
              style: AppTypography.socialLabel(color: QuizPalette.text),
            ),
          ),
        ],
      ),
    );
  }
}
