import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The quiz's controls, in the onboarding artboard's own language: white cards
/// on a light field, ink for the selected state, the same ink the round CTA
/// uses.
///
/// They are here rather than in the screen because the screen is now a dozen
/// steps long, and because these are the pieces that carry the interaction —
/// the selection feedback, the haptics, the fitting — which is worth reading
/// separately from the question copy.

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
            color: Color(0x1F121212),
            child: SizedBox(width: 388, height: 6),
          ),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            widthFactor: fraction.clamp(0.02, 1),
            alignment: Alignment.centerLeft,
            child: const ColoredBox(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// A single-choice list that sizes its own cards to the space it is given.
///
/// Fixed card heights were how the five-option activity step ended up 10pt over
/// its box; with six options it would have been 34pt over. Measuring instead
/// means a step can take as many options as the question needs.
class QuizOptions<T> extends StatelessWidget {
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

  static const double _gap = 12;
  static const double _maxHeight = 74;
  static const double _minHeight = 52;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = options.length;
        final available = constraints.maxHeight - _gap * (n - 1);
        final height =
            (available / n).clamp(_minHeight, _maxHeight).toDouble();

        return Column(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              QuizOptionCard(
                label: options[i].$2,
                detail: options[i].$3,
                height: height,
                selected: options[i].$1 == value,
                onTap: () => onChanged(options[i].$1),
              ),
            ],
          ],
        );
      },
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
    // Animated rather than switched: the fill and the tick arriving over a
    // beat is most of what makes answering feel responsive rather than
    // transactional, and it costs nothing.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: height,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.ink : const Color(0x1F121212),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // The tick is small and the colour change is quick; the haptic is
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
                        style: AppTypography.body(
                          color: selected ? AppColors.white : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: AppTypography.socialLabel(
                            color: selected
                                ? const Color(0xB3FFFFFF)
                                : AppColors.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
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
      child: const Icon(Icons.check_rounded, size: 18, color: AppColors.ink),
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
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              format(value),
              style: AppTypography.onboardingTitle().copyWith(fontSize: 40),
            ),
            const SizedBox(width: 8),
            Text(unit, style: AppTypography.onboardingBody()),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: AppColors.ink,
            inactiveTrackColor: const Color(0x1F121212),
            thumbColor: AppColors.ink,
            overlayColor: const Color(0x14121212),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0x1F121212)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: calories),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        builder: (context, value, _) => Text(
          'Target so far  ${value.round()} kcal',
          style: AppTypography.socialLabel(color: AppColors.ink),
        ),
      ),
    );
  }
}
