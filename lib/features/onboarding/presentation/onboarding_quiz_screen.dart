import 'dart:async';

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
import '../../auth/presentation/widgets/auth_widgets.dart';
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
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: QuizPalette.ground,
        systemNavigationBarIconBrightness: Brightness.light,
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
              height: 6,
              child: QuizProgress(fraction: (_index + 1) / _steps.length),
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
                  style: AppTypography.authTitle(color: QuizPalette.text),
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
                  style: AppTypography.body(color: QuizPalette.muted),
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
                top: 800,
                width: 388,
                height: 50,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _canAdvance ? 1 : 0.4,
                  child: PrimaryButton(
                    label: isPlan ? 'Start tracking' : 'Continue',
                    busy: _saving,
                    onPressed: _canAdvance && !_saving ? _advance : null,
                  ),
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

  Widget _body() => switch (_step) {
        _Step.motivation => QuizOptions<Motivation>(
            value: _answers.motivation,
            options: [
              for (final m in Motivation.values) (m, m.label, m.detail),
            ],
            onChanged: (v) => _set(_answers.copyWith(motivation: v)),
          ),
        _Step.gender => QuizOptions<Gender>(
            value: _answers.gender,
            options: const [
              (Gender.female, 'Female', null),
              (Gender.male, 'Male', null),
              (Gender.unspecified, 'Prefer not to say', 'We use an average'),
            ],
            onChanged: (v) => _set(_answers.copyWith(gender: v)),
          ),
        _Step.age => QuizNumberSlider(
            value: _answers.age.toDouble(),
            min: 13,
            max: 90,
            divisions: 77,
            unit: 'years',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(age: v.round())),
          ),
        _Step.height => QuizNumberSlider(
            value: _answers.heightCm,
            min: 120,
            max: 220,
            divisions: 100,
            unit: 'cm',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(heightCm: v)),
          ),
        _Step.weight => QuizNumberSlider(
            value: _answers.weightKg,
            min: 35,
            max: 200,
            divisions: 330,
            unit: 'kg',
            format: (v) => v.toStringAsFixed(1),
            onChanged: (v) => _set(_answers.copyWith(weightKg: v)),
          ),
        _Step.activity => QuizOptions<ActivityLevel>(
            value: _answers.activity,
            options: [
              for (final level in ActivityLevel.values)
                (level, level.label, level.detail),
            ],
            onChanged: (v) => _set(_answers.copyWith(activity: v)),
          ),
        _Step.goal => QuizOptions<WeightGoal>(
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
            answers: _answers,
            onWeight: (v) => _set(_answers.copyWith(goalWeightKg: v)),
            onRate: (v) => _set(_answers.copyWith(weeklyRateKg: v)),
          ),
        _Step.diet => QuizOptions<DietPreference>(
            value: _answers.dietPreference,
            options: [
              for (final d in DietPreference.values) (d, d.label, null),
            ],
            onChanged: (v) => _set(_answers.copyWith(dietPreference: v)),
          ),
        _Step.meals => QuizNumberSlider(
            value: _answers.mealsPerDay.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            unit: 'a day',
            format: (v) => v.round().toString(),
            onChanged: (v) => _set(_answers.copyWith(mealsPerDay: v.round())),
          ),
        _Step.obstacle => QuizOptions<Obstacle>(
            value: _answers.obstacle,
            options: [for (final o in Obstacle.values) (o, o.label, null)],
            onChanged: (v) => _set(_answers.copyWith(obstacle: v)),
          ),
        _Step.reminders => QuizOptions<bool>(
            value: _answers.wantsReminders,
            options: const [
              (true, 'Yes, remind me', 'Around your mealtimes'),
              (false, 'No thanks', 'You can turn this on later'),
            ],
            onChanged: (v) => _set(_answers.copyWith(wantsReminders: v)),
          ),
        _Step.building => _Building(onDone: _advance),
        _Step.plan => _Plan(profile: _draft, answers: _answers),
      };
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
          style: AppTypography.socialLabel(color: QuizPalette.muted),
        ),
      ),
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
        QuizNumberSlider(
          value: answers.goalWeightKg ?? answers.weightKg,
          min: 35,
          max: 200,
          divisions: 330,
          unit: 'kg goal',
          format: (v) => v.toStringAsFixed(1),
          onChanged: onWeight,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 64,
      decoration: BoxDecoration(
        color: selected ? QuizPalette.selected : QuizPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? QuizPalette.selected : QuizPalette.border,
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
                style: AppTypography.socialLabel(color: QuizPalette.text),
              ),
              Text(
                detail,
                style: AppTypography.divider(
                  color: selected
                      ? const Color(0xCCFFFFFF)
                      : QuizPalette.muted,
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
/// It is theatre, and it is deliberate: the work behind it is a few
/// multiplications, but arriving at a number instantly reads as a lookup, while
/// watching it be worked out reads as a plan. The steps named are the ones
/// actually being performed.
class _Building extends StatefulWidget {
  const _Building({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building> {
  static const _stages = [
    'Working out what you burn at rest',
    'Adding what you burn moving',
    'Setting your daily target',
    'Splitting it into protein, carbs and fat',
  ];

  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 550), (t) {
      if (!mounted) return;
      if (_stage == _stages.length - 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        widget.onDone();
        return;
      }
      setState(() => _stage++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 5,
            valueColor: AlwaysStoppedAnimation(QuizPalette.selected),
            backgroundColor: QuizPalette.border,
          ),
        ),
        const SizedBox(height: 32),
        for (var i = 0; i < _stages.length; i++)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: i <= _stage ? 1 : 0.25,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    i < _stage ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: i < _stage
                        ? QuizPalette.selected
                        : QuizPalette.muted,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _stages[i],
                      style: AppTypography.socialLabel(color: QuizPalette.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The payoff: the number the whole quiz was for.
class _Plan extends StatelessWidget {
  const _Plan({required this.profile, required this.answers});

  final UserProfile profile;
  final QuizAnswers answers;

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
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: targets.calories),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            NutritionFormat.calories(value),
            style: AppTypography.authTitle(color: QuizPalette.text)
                .copyWith(fontSize: 46),
          ),
        ),
        Text(
          'calories a day',
          style: AppTypography.body(color: QuizPalette.muted),
        ),
        const SizedBox(height: 26),
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
        const SizedBox(height: 22),
        if (goalDate != null)
          Text(
            'On track for ${profile.goalWeightKg!.toStringAsFixed(0)} kg by '
            '${DateFormat('d MMMM y').format(goalDate)}.',
            style: AppTypography.socialLabel(color: QuizPalette.muted),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: QuizPalette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: QuizPalette.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: QuizPalette.selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tip,
                  style: AppTypography.socialLabel(color: QuizPalette.text),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'An estimate, not medical advice.',
          style: AppTypography.divider(color: QuizPalette.muted),
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
            style: AppTypography.socialLabel(color: QuizPalette.muted),
          ),
        ],
      ),
    );
  }
}
