import 'dart:async';
import 'dart:math' as math;

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
import 'widgets/quiz_controls.dart';

/// The steps, in order. `goalWeight` is skipped when maintaining.
enum _Step {
  motivation,
  gender,
  age,
  height,
  weight,
  activity,
  goal,
  goalWeight,
  diet,
  meals,
  obstacle,
  reminders,
  building,
  plan,
}

/// Personalisation quiz — **not in the Figma file**.
///
/// The design has three marketing onboarding pages and no quiz, but the app
/// cannot do its central job without one: every profile was getting
/// [UserProfile.defaultTargets], so a 22-year-old athlete and a sedentary
/// 55-year-old saw the same 2000 kcal ring on Home.
///
/// Built entirely from what the design does define — the onboarding artboard's
/// canvas, palette, type ramp, `blob.png` and the round CTA — so it reads as
/// the next stretch of onboarding rather than something bolted on.
///
/// ---------------------------------------------------------------------------
/// Why this many questions
/// ---------------------------------------------------------------------------
/// Five of them feed the arithmetic. The rest are context, and each one changes
/// something the person actually sees: the plan Home features, the tip the plan
/// screen closes with, whether meal reminders are on. A quiz question whose
/// answer goes nowhere is drop-off bought for nothing, so there are none of
/// those here.
///
/// Every step is skippable. Skipping leaves [UserProfile.defaultTargets], which
/// is what the app showed before this screen existed.
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

  /// Which way the step transition slides, so going back reads as going back.
  bool _forward = true;

  List<_Step> get _steps => [
        _Step.motivation,
        _Step.gender,
        _Step.age,
        _Step.height,
        _Step.weight,
        _Step.activity,
        _Step.goal,
        // Maintaining has no goal weight to ask about, so the step disappears
        // rather than showing a slider with nothing to set.
        if (_answers.goal != null && _answers.goal != WeightGoal.maintain)
          _Step.goalWeight,
        _Step.diet,
        _Step.meals,
        _Step.obstacle,
        _Step.reminders,
        _Step.building,
        _Step.plan,
      ];

  _Step get _step => _steps[_index.clamp(0, _steps.length - 1)];

  /// One colour per question, cycled, so moving through the quiz is visibly
  /// moving rather than the same screen with new words.
  Color get _accent => QuizPalette.accentFor(_index);

  UserProfile get _draft =>
      _answers.applyTo(ref.read(profileProvider).value ?? _blankProfile);

  static final _blankProfile = UserProfile(id: 'draft', name: '', email: '');

  bool get _canAdvance => switch (_step) {
        _Step.motivation => _answers.motivation != null,
        _Step.gender => _answers.gender != null,
        _Step.activity => _answers.activity != null,
        _Step.goal => _answers.goal != null,
        _Step.diet => _answers.dietPreference != null,
        _Step.obstacle => _answers.obstacle != null,
        _ => true,
      };

  void _set(QuizAnswers next) => setState(() => _answers = next);

  void _advance() {
    if (_step == _Step.plan) {
      _finish();
      return;
    }
    setState(() {
      _forward = true;
      _index = (_index + 1).clamp(0, _steps.length - 1);
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _forward = false;
      _index -= 1;
    });
  }

  /// Saves the answers, the targets computed from them, and the one preference
  /// the quiz collects on another screen's behalf.
  ///
  /// A failure must not strand someone on the quiz, so this falls through to
  /// [onFinished] either way.
  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).save(_draft);
      await ref
          .read(notificationSettingsRepositoryProvider)
          .setEnabled('mealReminders', enabled: _answers.wantsReminders);
    } catch (error) {
      debugPrint('could not save quiz answers: $error');
    }
    if (mounted) widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isPlan = _step == _Step.plan;
    final isBuilding = _step == _Step.building;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: QuizPalette.ground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: QuizPalette.ground,
        body: DesignCanvas(
          background: QuizPalette.ground,
          children: [
            Positioned(
              left: 20,
              top: 71,
              width: 388,
              height: 16,
              child: QuizProgress(
                fraction: (_index + 1) / _steps.length,
                accent: _accent,
              ),
            ),
            if (_index > 0 && !isBuilding)
              Positioned(
                left: 20,
                top: 96,
                child: _TextButton(label: 'Back', onTap: _back),
              ),
            if (!isPlan && !isBuilding)
              Positioned(
                right: 20,
                top: 96,
                child: _TextButton(label: 'Skip', onTap: widget.onFinished),
              ),
            // The question moves with its answers rather than snapping while
            // the cards slide, which made the two read as separate screens.
            Positioned(
              left: 20,
              top: 148,
              width: 388,
              height: 84,
              child: _Fading(
                step: _step,
                child: Text(
                  _title,
                  style: AppTypography.authTitle(color: QuizPalette.ink),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 238,
              width: 388,
              height: 50,
              child: _Fading(
                step: _step,
                child: Text(
                  _subtitle,
                  style: AppTypography.body(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                  // The box is two lines tall, inside a hard-clipped Stack, so
                  // without this a longer string is cut off mid-word and simply
                  // loses its ending.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // The running estimate. It moves while you answer, so the plan
            // assembles out of your own answers rather than arriving at the end
            // as an assertion.
            if (_answers.canEstimate && !isPlan && !isBuilding)
              Positioned(
                left: 0,
                right: 0,
                top: 296,
                child: Center(
                  child: QuizLiveTarget(calories: _draft.targets.calories),
                ),
              ),
            Positioned(
              left: 20,
              top: _answers.canEstimate && !isPlan && !isBuilding ? 348 : 312,
              width: 388,
              height: _answers.canEstimate && !isPlan && !isBuilding ? 374 : 410,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: Offset(_forward ? 0.12 : -0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _body()),
              ),
            ),
            // The app's own CTA rather than the onboarding artboard's round
            // button on its white blob. That pairing belongs to the marketing
            // pages; here it sat on a dark ground looking like a sticker, and
            // this is the same button the auth screens end on.
            if (!isBuilding)
              Positioned(
                left: 20,
                top: 796,
                width: 388,
                height: 58,
                child: StickerButton(
                  label: isPlan ? "Let's go" : 'Continue',
                  accent: _accent,
                  busy: _saving,
                  onPressed: _canAdvance && !_saving ? _advance : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_step) {
        _Step.motivation => 'What brings you here?',
        _Step.gender => 'Tell us about you',
        _Step.age => 'How old are you?',
        _Step.height => 'How tall are you?',
        _Step.weight => 'What do you weigh?',
        _Step.activity => 'How active are you?',
        _Step.goal => 'What is your goal?',
        _Step.goalWeight => 'Where are you heading?',
        _Step.diet => 'How do you eat?',
        _Step.meals => 'How many meals a day?',
        _Step.obstacle => 'What trips you up?',
        _Step.reminders => 'Want a nudge?',
        _Step.building => 'Building your plan',
        _Step.plan => 'Your daily plan',
      };

  String get _subtitle => switch (_step) {
        _Step.motivation => 'So the plan we build answers the thing you '
            'actually came for.',
        _Step.gender => 'Your body uses energy differently, so this changes '
            'the number.',
        _Step.age => 'Energy needs fall gradually with age.',
        _Step.height => 'Used only to work out your daily energy.',
        _Step.weight => 'You can change this any time in your profile.',
        _Step.activity => 'Be honest rather than optimistic — this sets '
            'your whole target.',
        _Step.goal => 'This decides whether your target sits above or below '
            'what you burn.',
        _Step.goalWeight => 'A steady pace is easier to keep than a fast one.',
        _Step.diet => 'We will lead with a plan that suits how you eat.',
        _Step.meals => 'Used to space out reminders, not to police anything.',
        _Step.obstacle => 'Everyone has one. Yours decides the tip we leave '
            'you with.',
        _Step.reminders => 'A quiet reminder around mealtimes. Off is fine.',
        _Step.building => 'Working out what you burn, and what to eat.',
        _Step.plan => 'From your height, weight, age and how much you move.',
      };

  /// Flipping units mid-quiz is deliberate: the height and weight steps are
  /// exactly where someone realises the app is asking in the wrong unit, and
  /// making them hunt for a setting at that moment is how you lose them.
  void _toggleUnits() => ref.read(unitSystemProvider.notifier).toggle();

  Widget _body() {
    final units = ref.watch(unitSystemProvider);
    return switch (_step) {
        _Step.motivation => QuizOptions<Motivation>(
            accent: _accent,
            value: _answers.motivation,
            options: [
              for (final m in Motivation.values) (m, m.label, m.detail),
            ],
            onChanged: (v) => _set(_answers.copyWith(motivation: v)),
          ),
        _Step.gender => QuizOptions<Gender>(
            accent: _accent,
            value: _answers.gender,
            options: const [
              (Gender.female, 'Female', null),
              (Gender.male, 'Male', null),
              (Gender.unspecified, 'Prefer not to say', 'We use an average'),
            ],
            onChanged: (v) => _set(_answers.copyWith(gender: v)),
          ),
        _Step.age => QuizNumberSlider(
            accent: _accent,
            value: _answers.age.toDouble(),
            min: 13,
            max: 90,
            divisions: 77,
            unit: 'years',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(age: v.round())),
          ),
        // The slider stays metric on both sides — its range, its divisions and
        // the value it hands back. Only the caption changes, so nothing
        // downstream has to know which units were on screen.
        _Step.height => QuizNumberSlider(
            accent: _accent,
            value: _answers.heightCm,
            min: 120,
            max: 220,
            divisions: 100,
            unit: units.heightUnit,
            format: units.formatHeight,
            onChanged: (v) => _set(_answers.copyWith(heightCm: v)),
            onToggleUnits: _toggleUnits,
            unitsLabel: units.isMetric ? 'Use feet & pounds' : 'Use cm & kg',
          ),
        _Step.weight => QuizNumberSlider(
            accent: _accent,
            value: _answers.weightKg,
            min: 35,
            max: 200,
            divisions: 330,
            unit: units.weightUnit,
            format: units.formatWeight,
            onChanged: (v) => _set(_answers.copyWith(weightKg: v)),
            onToggleUnits: _toggleUnits,
            unitsLabel: units.isMetric ? 'Use feet & pounds' : 'Use cm & kg',
          ),
        _Step.activity => QuizOptions<ActivityLevel>(
            accent: _accent,
            value: _answers.activity,
            options: [
              for (final level in ActivityLevel.values)
                (level, level.label, level.detail),
            ],
            onChanged: (v) => _set(_answers.copyWith(activity: v)),
          ),
        _Step.goal => QuizOptions<WeightGoal>(
            accent: _accent,
            value: _answers.goal,
            options: const [
              (WeightGoal.lose, 'Lose weight', null),
              (WeightGoal.maintain, 'Maintain weight', null),
              (WeightGoal.gain, 'Gain weight', null),
            ],
            onChanged: (v) => _set(
              _answers.copyWith(
                goal: v,
                goalWeightKg: _answers.goalWeightKg ??
                    (v == WeightGoal.lose
                        ? _answers.weightKg - 5
                        : _answers.weightKg + 5),
              ),
            ),
          ),
        _Step.goalWeight => _GoalWeight(
            accent: _accent,
            answers: _answers,
            onWeight: (v) => _set(_answers.copyWith(goalWeightKg: v)),
            onRate: (v) => _set(_answers.copyWith(weeklyRateKg: v)),
          ),
        _Step.diet => QuizOptions<DietPreference>(
            accent: _accent,
            value: _answers.dietPreference,
            options: [
              for (final d in DietPreference.values) (d, d.label, null),
            ],
            onChanged: (v) => _set(_answers.copyWith(dietPreference: v)),
          ),
        _Step.meals => QuizNumberSlider(
            accent: _accent,
            value: _answers.mealsPerDay.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            unit: 'a day',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(mealsPerDay: v.round())),
          ),
        _Step.obstacle => QuizOptions<Obstacle>(
            accent: _accent,
            value: _answers.obstacle,
            options: [for (final o in Obstacle.values) (o, o.label, null)],
            onChanged: (v) => _set(_answers.copyWith(obstacle: v)),
          ),
        _Step.reminders => QuizOptions<bool>(
            accent: _accent,
            value: _answers.wantsReminders,
            options: const [
              (true, 'Yes, remind me', 'Around your mealtimes'),
              (false, 'No thanks', 'You can turn this on later'),
            ],
            onChanged: (v) => _set(_answers.copyWith(wantsReminders: v)),
          ),
        _Step.building => _Building(
            accent: _accent,
            profile: _draft,
            onDone: _advance,
          ),
        _Step.plan => _Plan(profile: _draft, answers: _answers, accent: _accent),
    };
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// Crossfades its child whenever the step changes.
///
/// The question and its answers used to move independently — the cards slid in
/// while the title snapped — which read as two screens sharing a background
/// rather than one screen changing.
class _Fading extends StatelessWidget {
  const _Fading({required this.step, required this.child});

  final Object step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(step), child: child),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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

/// Goal weight, plus how fast to get there.
class _GoalWeight extends StatelessWidget {
  const _GoalWeight({
    required this.accent,
    required this.answers,
    required this.onWeight,
    required this.onRate,
  });

  final Color accent;
  final QuizAnswers answers;
  final ValueChanged<double> onWeight;
  final ValueChanged<double> onRate;

  @override
  Widget build(BuildContext context) {
    final rate = answers.weeklyRateKg;

    // The floor moves with height rather than being a constant, because a
    // healthy weight does. This slider used to start at 35 kg for everyone.
    final floor = TargetCalculator.healthyGoalFloorKg(answers.heightCm);
    final value = math.max(floor, answers.goalWeightKg ?? answers.weightKg);

    return Column(
      children: [
        QuizNumberSlider(
          accent: accent,
          value: math.min(value, 200),
          min: floor,
          max: 200,
          divisions: ((200 - floor) * 2).round(),
          unit: 'kg goal',
          format: (v) => v.toStringAsFixed(1),
          onChanged: onWeight,
        ),
        const SizedBox(height: 8),
        // Say the floor out loud. A slider that silently refuses to go lower
        // reads as broken; one that explains itself reads as looking after you.
        Text(
          "We won't set a goal below ${floor.toStringAsFixed(0)} kg — that's the "
          'bottom of the healthy range for your height.',
          style: AppTypography.meta(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // 0.25 to 0.75 kg a week. Nothing faster is offered: the deficit
            // cap would quietly override it, and a control that does not do
            // what it says is worse than one that is not there.
            for (final option in const [0.25, 0.5, 0.75]) ...[
              Expanded(
                child: _RateChip(
                  accent: accent,
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
    required this.accent,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final Color accent;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 64,
      decoration: BoxDecoration(
        color: selected ? accent : QuizPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? accent : QuizPalette.ink,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.socialLabel(color: QuizPalette.ink),
              ),
              Text(
                detail,
                style: AppTypography.divider(
                  color: selected
                      ? const Color(0xCCFFFFFF)
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

/// The beat between the last answer and the plan.
///
/// A spinner says "waiting". This says "working", because it shows the working:
/// each stage resolves to the number it actually produced — resting burn, then
/// the same figure scaled by movement, then the target after the goal is
/// applied, then the split. Those are the four steps [TargetCalculator]
/// performs, in order, with its real intermediate values.
///
/// It is still theatre — all four are arithmetic and take no time at all — but
/// theatre that is true. A number that appears instantly reads as a lookup; one
/// you watch being derived reads as a plan.
class _Building extends StatefulWidget {
  const _Building({
    required this.accent,
    required this.profile,
    required this.onDone,
  });

  final Color accent;
  final UserProfile profile;
  final VoidCallback onDone;

  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building>
    with SingleTickerProviderStateMixin {
  static const Duration _run = Duration(milliseconds: 2600);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _run,
  )
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      HapticFeedback.mediumImpact();
      widget.onDone();
    })
    ..forward();

  /// One tick per stage as it lands, so the sequence is felt as well as seen.
  int _tapped = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The real intermediate values, in the order they are computed.
  List<(String, String)> get _stages {
    final p = widget.profile;
    if (!p.canPersonaliseTargets) {
      return const [
        ('Reading your answers', ''),
        ('Working out your burn', ''),
        ('Setting your target', ''),
        ('Splitting the macros', ''),
      ];
    }
    final t = p.targets;
    return [
      ('Burn at rest', '${TargetCalculator.basalRate(
        weightKg: p.weightKg!,
        heightCm: p.heightCm!,
        age: p.age!,
        gender: p.gender,
      ).round()} kcal'),
      ('With how you move',
          '${TargetCalculator.maintenance(p).round()} kcal'),
      ('Your daily target', '${t.calories.round()} kcal'),
      ('Protein · carbs · fat',
          '${t.protein.round()} · ${t.carbs.round()} · ${t.fat.round()} g'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;

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
                painter: _RingPainter(
                  progress: progress,
                  accent: widget.accent,
                ),
                child: Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: AppTypography.onboardingTitle(color: QuizPalette.ink)
                        .copyWith(fontSize: 34, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            for (var i = 0; i < stages.length; i++)
              _StageRow(
                label: stages[i].$1,
                value: stages[i].$2,
                accent: widget.accent,
                // Each row owns a quarter of the sweep.
                progress: ((progress * stages.length) - i).clamp(0.0, 1.0),
              ),
          ],
        );
      },
    );
  }
}

/// One line of the working, revealing its value as the sweep passes it.
class _StageRow extends StatelessWidget {
  const _StageRow({
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
              // The value counts up rather than appearing, so the figure looks
              // arrived at.
              if (value.isNotEmpty)
                Opacity(
                  opacity: progress,
                  child: Text(
                    value,
                    style: AppTypography.socialLabel(color: QuizPalette.ink)
                        .copyWith(fontWeight: FontWeight.w700),
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
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.accent});

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
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}

/// The payoff: the number the whole quiz was for.
class _Plan extends StatelessWidget {
  const _Plan({
    required this.profile,
    required this.answers,
    required this.accent,
  });

  final UserProfile profile;
  final QuizAnswers answers;
  final Color accent;

  /// The tip is chosen by the obstacle they named, and every one of them points
  /// at something the app can actually do.
  String get _tip => switch (answers.obstacle) {
        Obstacle.snacking =>
          'Log the snack before you eat it — that is the one that gets '
              'forgotten.',
        Obstacle.portions =>
          'Use the portion buttons on a scan. An estimate you correct beats '
              'one you accept.',
        Obstacle.eatingOut =>
          'No photo? Describe the meal instead — same result, no camera.',
        Obstacle.consistency =>
          'Two meals logged keeps your streak. Missing one does not end it.',
        null => 'Scan a meal to get started.',
      };

  @override
  Widget build(BuildContext context) {
    final targets = profile.targets;
    final goalDate = TargetCalculator.goalDate(profile);

    return Column(
      children: [
        // The mascot turns up for the payoff and nowhere else, which is the
        // only way a mascot stays likeable.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Sparkle(size: 16),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/brand/mascot.png',
              width: 76,
              height: 76,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 8),
            const Sparkle(size: 22),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: targets.calories),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            NutritionFormat.calories(value),
            style: AppTypography.authTitle(color: QuizPalette.ink)
                .copyWith(fontSize: 46),
          ),
        ),
        Text(
          'calories a day',
          style: AppTypography.body(color: AppColors.inkMuted),
        ),
        const SizedBox(height: 16),
        // The same three colours the macro cards on Home use, so the plan and
        // the screen it hands over to are visibly the same numbers.
        Row(
          children: [
            _Macro(
              label: 'Protein',
              grams: targets.protein,
              colour: AppColors.accentGreen,
            ),
            _Macro(
              label: 'Carbs',
              grams: targets.carbs,
              colour: AppColors.planYellow,
            ),
            _Macro(
              label: 'Fat',
              grams: targets.fat,
              colour: AppColors.accentOrange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (goalDate != null)
          Text(
            'On track for ${profile.goalWeightKg!.toStringAsFixed(0)} kg by '
            '${DateFormat('d MMMM y').format(goalDate)}.',
            style: AppTypography.socialLabel(color: AppColors.inkMuted),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: QuizPalette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuizPalette.ink),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tip,
                  style: AppTypography.socialLabel(color: QuizPalette.ink),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'An estimate, not medical advice.',
          style: AppTypography.divider(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({
    required this.label,
    required this.grams,
    required this.colour,
  });

  final String label;
  final double grams;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            NutritionFormat.grams(grams),
            style: AppTypography.cardTitle(color: colour),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.socialLabel(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
