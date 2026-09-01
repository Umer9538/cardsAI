import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/nutrition/target_calculator.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'quiz_answers.dart';
import 'widgets/round_next_button.dart';

/// The steps, in order. The goal-weight step is skipped when maintaining.
enum _Step { gender, age, height, weight, activity, goal, goalWeight, plan }

/// Personalisation quiz — **not in the Figma file**.
///
/// The design has three marketing onboarding pages and no quiz, but the app
/// cannot do its central job without one: every profile was getting
/// [UserProfile.defaultTargets], so a 22-year-old athlete and a sedentary
/// 55-year-old saw the same 2000 kcal ring on Home. The PRD asks for this in
/// §5.1, and every comparable tracker asks the same six things.
///
/// Built entirely from what the design does define — the onboarding artboard's
/// canvas, palette, type ramp, `blob.png` and the round CTA — so it reads as
/// the next three screens of onboarding rather than as something bolted on.
/// Same approach as `DescribeMealScreen` and `FoodSearchScreen`.
///
/// Every step is skippable: skipping leaves [UserProfile.defaultTargets] in
/// place, which is the same number the app showed before this screen existed.
class OnboardingQuizScreen extends ConsumerStatefulWidget {
  const OnboardingQuizScreen({super.key, this.onFinished});

  /// Called once the answers are saved, or the quiz is skipped.
  final VoidCallback? onFinished;

  @override
  ConsumerState<OnboardingQuizScreen> createState() =>
      _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends ConsumerState<OnboardingQuizScreen> {
  QuizAnswers _answers = const QuizAnswers();
  int _index = 0;
  bool _saving = false;

  /// Maintaining has no goal weight to ask about, so that step disappears
  /// rather than showing a slider with nothing to do.
  List<_Step> get _steps => [
        _Step.gender,
        _Step.age,
        _Step.height,
        _Step.weight,
        _Step.activity,
        _Step.goal,
        if (_answers.goal != null && _answers.goal != WeightGoal.maintain)
          _Step.goalWeight,
        _Step.plan,
      ];

  _Step get _step => _steps[_index.clamp(0, _steps.length - 1)];

  /// The profile the plan screen previews, and the one that gets saved.
  UserProfile get _draft =>
      _answers.applyTo(ref.read(profileProvider).value ?? _blankProfile);

  static final _blankProfile =
      UserProfile(id: 'draft', name: '', email: '');

  bool get _canAdvance => switch (_step) {
        _Step.gender => _answers.gender != null,
        _Step.activity => _answers.activity != null,
        _Step.goal => _answers.goal != null,
        _ => true,
      };

  void _set(QuizAnswers next) => setState(() => _answers = next);

  Future<void> _advance() async {
    if (_step == _Step.plan) return _finish();
    setState(() => _index = (_index + 1).clamp(0, _steps.length - 1));
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index -= 1);
  }

  /// Saves the answers and the targets computed from them.
  ///
  /// The write is not awaited for its server round trip — `ProfileRepository`
  /// resolves locally and the SDK guarantees delivery — but a failure must not
  /// strand someone on the quiz, so it falls through to [onFinished] either way.
  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).save(_draft);
    } catch (error) {
      debugPrint('could not save quiz answers: $error');
    }
    if (mounted) widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isPlan = _step == _Step.plan;
    final background = isPlan ? AppColors.accentGreen : AppColors.lilac;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Both quiz backgrounds are light, like the onboarding pages.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: DesignCanvas(
          background: background,
          children: [
            _Progress(step: _index + 1, total: _steps.length),
            if (_index > 0)
              Positioned(
                left: 20,
                top: 96,
                child: _TextButton(label: 'Back', onTap: _back),
              ),
            Positioned(
              right: 20,
              top: 96,
              child: _TextButton(
                label: isPlan ? '' : 'Skip',
                onTap: isPlan ? null : widget.onFinished,
              ),
            ),
            Positioned(
              left: 20,
              top: 148,
              width: 388,
              height: 84,
              child: Text(
                _title,
                style: AppTypography.onboardingTitle(),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              left: 20,
              top: 238,
              width: 388,
              height: 50,
              child: Text(
                _subtitle,
                style: AppTypography.onboardingBody(),
                textAlign: TextAlign.center,
              ),
            ),
            Positioned(
              left: 20,
              top: 312,
              width: 388,
              height: 410,
              child: _body(),
            ),
            const DesignImage(
              asset: 'assets/images/onboarding/blob.png',
              left: 109,
              top: 738,
              width: 212,
              height: 188,
            ),
            Positioned(
              left: 165,
              top: 788,
              width: 100,
              height: 100,
              child: RoundNextButton(
                onTap: _advance,
                label: isPlan ? 'Start\nTracking' : 'Next',
                showArrow: !isPlan,
                enabled: _canAdvance && !_saving,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_step) {
        _Step.gender => 'Tell us about you',
        _Step.age => 'How old are you?',
        _Step.height => 'How tall are you?',
        _Step.weight => 'What do you weigh?',
        _Step.activity => 'How active are you?',
        _Step.goal => 'What is your goal?',
        _Step.goalWeight => 'Where are you heading?',
        _Step.plan => 'Your daily plan',
      };

  String get _subtitle => switch (_step) {
        _Step.gender => 'Your body uses energy differently, so this changes '
            'the number we work out.',
        _Step.age => 'Energy needs fall gradually with age.',
        _Step.height => 'Used only to work out your daily energy.',
        _Step.weight => 'You can change this any time in your profile.',
        _Step.activity => 'Be honest rather than optimistic — an overstated '
            'answer sets a goal you will not meet.',
        _Step.goal => 'This decides whether your target sits above or below '
            'what you burn.',
        _Step.goalWeight => 'A steady pace is easier to keep than a fast one.',
        _Step.plan => 'Worked out from your height, weight, age and how much '
            'you move.',
      };

  Widget _body() => switch (_step) {
        _Step.gender => _Options<Gender>(
            value: _answers.gender,
            options: const [
              (Gender.female, 'Female', null),
              (Gender.male, 'Male', null),
              (Gender.unspecified, 'Prefer not to say', 'We will use an average'),
            ],
            onChanged: (v) => _set(_answers.copyWith(gender: v)),
          ),
        _Step.age => _NumberSlider(
            value: _answers.age.toDouble(),
            min: 13,
            max: 90,
            divisions: 77,
            unit: 'years',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(age: v.round())),
          ),
        _Step.height => _NumberSlider(
            value: _answers.heightCm,
            min: 120,
            max: 220,
            divisions: 100,
            unit: 'cm',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(heightCm: v)),
          ),
        _Step.weight => _NumberSlider(
            value: _answers.weightKg,
            min: 35,
            max: 200,
            divisions: 330,
            unit: 'kg',
            format: (v) => v.toStringAsFixed(1),
            onChanged: (v) => _set(_answers.copyWith(weightKg: v)),
          ),
        _Step.activity => _Options<ActivityLevel>(
            value: _answers.activity,
            options: [
              for (final level in ActivityLevel.values)
                (level, level.label, level.detail),
            ],
            onChanged: (v) => _set(_answers.copyWith(activity: v)),
          ),
        _Step.goal => _Options<WeightGoal>(
            value: _answers.goal,
            options: const [
              (WeightGoal.lose, 'Lose weight', null),
              (WeightGoal.maintain, 'Maintain weight', null),
              (WeightGoal.gain, 'Gain weight', null),
            ],
            onChanged: (v) => _set(
              _answers.copyWith(
                goal: v,
                // Seed a sensible destination so the next step opens somewhere
                // near where they are rather than at the slider's floor.
                goalWeightKg: _answers.goalWeightKg ??
                    (v == WeightGoal.lose
                        ? _answers.weightKg - 5
                        : _answers.weightKg + 5),
              ),
            ),
          ),
        _Step.goalWeight => _GoalWeight(
            answers: _answers,
            onWeight: (v) => _set(_answers.copyWith(goalWeightKg: v)),
            onRate: (v) => _set(_answers.copyWith(weeklyRateKg: v)),
          ),
        _Step.plan => _Plan(profile: _draft),
      };
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// How far through, as a bar rather than a count.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: 71,
      width: 388,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            const ColoredBox(
              color: Color(0x1F121212),
              child: SizedBox(width: 388, height: 6),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              widthFactor: step / total,
              alignment: Alignment.centerLeft,
              child: const ColoredBox(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(
          label,
          style: AppTypography.socialLabel(color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

/// A single-choice list. Selected is the ink fill the round CTA uses, so the
/// two read as the same control family.
class _Options<T> extends StatelessWidget {
  const _Options({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T? value;

  /// (value, label, optional detail line)
  final List<(T, String, String?)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Gaps go BETWEEN cards, not after every one. A trailing gap put the
    // five-option activity step 10pt over its 410pt body — 5x72 + 5x12 — which
    // renders as the overflow stripes rather than as anything subtle.
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _OptionCard(
            label: options[i].$2,
            detail: options[i].$3,
            selected: options[i].$1 == value,
            onTap: () => onChanged(options[i].$1),
          ),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: detail == null ? 64 : 72,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.ink : const Color(0x1F121212),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.body(
                  color: selected ? AppColors.white : AppColors.ink,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: AppTypography.socialLabel(
                    color: selected
                        ? const Color(0xB3FFFFFF)
                        : AppColors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big number over a slider — no keyboard, which is the whole point.
class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
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
      children: [
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(format(value), style: AppTypography.onboardingTitle()),
            const SizedBox(width: 8),
            Text(unit, style: AppTypography.onboardingBody()),
          ],
        ),
        const SizedBox(height: 24),
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
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Goal weight, plus how fast to get there.
class _GoalWeight extends StatelessWidget {
  const _GoalWeight({
    required this.answers,
    required this.onWeight,
    required this.onRate,
  });

  final QuizAnswers answers;
  final ValueChanged<double> onWeight;
  final ValueChanged<double> onRate;

  @override
  Widget build(BuildContext context) {
    final rate = answers.weeklyRateKg;
    return Column(
      children: [
        _NumberSlider(
          value: answers.goalWeightKg ?? answers.weightKg,
          min: 35,
          max: 200,
          divisions: 330,
          unit: 'kg goal',
          format: (v) => v.toStringAsFixed(1),
          onChanged: onWeight,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // 0.25 to 0.75 kg a week. Nothing faster is offered: the arithmetic
            // would happily produce it and the deficit cap would then quietly
            // override it, which is a worse experience than not offering it.
            for (final option in const [0.25, 0.5, 0.75]) ...[
              Expanded(
                child: _RateChip(
                  label: '${option.toStringAsFixed(2)} kg',
                  detail: option == 0.5 ? 'Recommended' : 'per week',
                  selected: (rate - option).abs() < 0.01,
                  onTap: () => onRate(option),
                ),
              ),
              if (option != 0.75) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.ink : const Color(0x1F121212),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.socialLabel(
                  color: selected ? AppColors.white : AppColors.ink,
                ),
              ),
              Text(
                detail,
                style: AppTypography.divider(
                  color: selected
                      ? const Color(0xB3FFFFFF)
                      : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The payoff screen: the number the whole quiz was for.
///
/// It counts up rather than appearing, which is the one piece of theatre worth
/// keeping from how these apps do it — the plan visibly assembles itself out of
/// the answers just given, rather than arriving as a fact.
class _Plan extends StatelessWidget {
  const _Plan({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final targets = profile.targets;
    final goalDate = TargetCalculator.goalDate(profile);

    return Column(
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: targets.calories),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            NutritionFormat.calories(value),
            style: AppTypography.onboardingTitle().copyWith(fontSize: 44),
          ),
        ),
        Text('calories a day', style: AppTypography.onboardingBody()),
        const SizedBox(height: 28),
        Row(
          children: [
            _Macro(label: 'Protein', grams: targets.protein),
            _Macro(label: 'Carbs', grams: targets.carbs),
            _Macro(label: 'Fat', grams: targets.fat),
          ],
        ),
        const SizedBox(height: 28),
        if (goalDate != null)
          Text(
            'On track for ${profile.goalWeightKg!.toStringAsFixed(0)} kg by '
            '${DateFormat('d MMMM y').format(goalDate)}.',
            style: AppTypography.socialLabel(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        Text(
          'An estimate, not medical advice. You can change any of this later.',
          style: AppTypography.divider(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            NutritionFormat.grams(grams),
            style: AppTypography.cardTitle(color: AppColors.ink),
          ),
          Text(
            label,
            style: AppTypography.socialLabel(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
