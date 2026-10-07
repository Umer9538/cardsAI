import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/nutrition/dish_taxonomy.dart';
import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../onboarding/presentation/widgets/quiz_build_step.dart';
import '../../onboarding/presentation/widgets/quiz_controls.dart';
import 'widgets/taste_widgets.dart';

enum _Kind { gridA, gridB, pair, avoid, cookTime, notes, building }

/// One step. [axis] is set only for [_Kind.pair].
typedef _Step = ({_Kind kind, TasteAxis? axis});

/// The plan builder's quiz — **not in the Figma file**.
///
/// It replaces a text box. The box asked "what do you eat?" and, like every
/// empty text box, mostly went unused; this asks the same question as about
/// fifty seconds of tapping pictures, which in the one controlled study of the
/// idea (see `dish_taxonomy.dart`) produced plans people actually accepted.
///
/// Every question here is about the **food**, never the person. Calories,
/// goal, diet type and meals a day were answered in onboarding and are read
/// from the profile on the server — asking again would be a second quiz on
/// top of the first, and sending them would let a client name its own target.
/// The only thing that leaves this screen is a [TasteProfile].
///
/// Drawn the way the onboarding quiz is drawn, on the same artboard geometry,
/// so the two read as one instrument rather than two apps.
class TasteQuizScreen extends ConsumerStatefulWidget {
  const TasteQuizScreen({
    super.key,
    this.onBack,
    this.onCreated,
    this.rebuildFrom,
  });

  /// Answers to build from again, skipping every question.
  ///
  /// "Something else" on a plan someone did not like. The quiz is about fifty
  /// seconds of tapping and the answers do not change between one plan and the
  /// next — asking for them a second time to get a second plan is the surest
  /// way to make nobody ask for a second plan.
  ///
  /// It lands straight on the build step, so the sweep, the caption, the
  /// "taking longer than usual" line and the retry are the same ones the first
  /// build used rather than a second loading screen that has to be kept in
  /// step with them.
  final TasteProfile? rebuildFrom;

  /// Back from the first step. Elsewhere back goes one step.
  final VoidCallback? onBack;

  /// Fired with the saved plan, so the caller can open it.
  final ValueChanged<DietPlan>? onCreated;

  /// Every step's title and subtitle, in order, for the copy test — the
  /// boxes they sit in are fixed, so the copy has to be proven to fit.
  @visibleForTesting
  static List<String> get debugTitles => [
    for (final s in _TasteQuizScreenState._steps)
      _TasteQuizScreenState._titleFor(s),
  ];

  @visibleForTesting
  static List<String> get debugSubtitles => [
    for (final s in _TasteQuizScreenState._steps)
      _TasteQuizScreenState._subtitleFor(s.kind),
  ];

  @override
  ConsumerState<TasteQuizScreen> createState() => _TasteQuizScreenState();
}

class _TasteQuizScreenState extends ConsumerState<TasteQuizScreen> {
  static final List<_Step> _steps = [
    (kind: _Kind.gridA, axis: null),
    (kind: _Kind.gridB, axis: null),
    for (final axis in TasteAxis.values) (kind: _Kind.pair, axis: axis),
    (kind: _Kind.avoid, axis: null),
    (kind: _Kind.cookTime, axis: null),
    (kind: _Kind.notes, axis: null),
    (kind: _Kind.building, axis: null),
  ];

  TasteProfile _profile = TasteProfile.empty;
  int _index = 0;

  /// Which way the step transition slides, so going back reads as going back.
  bool _forward = true;

  final _notes = TextEditingController();

  /// The beat between answering a pair and moving on. Cancelled in [dispose]:
  /// a timer that outlives the screen fails every test that touches it.
  Timer? _advanceTimer;
  bool _neitherPressed = false;

  // The build step. The real call and the animation run side by side, and the
  // plan is handed over only once both have finished.
  int _attempt = 0;

  /// The plan the planner returned, saved or not, and the answers it was
  /// built from. Kept across a failed save and across Back, so "Try again"
  /// and a second "Build my plan" on the same answers re-run the *save* —
  /// a local write — rather than the generate, which is a quota unit.
  DietPlan? _plan;
  TasteProfile? _builtFrom;

  /// The saved copy, which is what [TasteQuizScreen.onCreated] receives.
  DietPlan? _saved;
  String? _error;
  bool _animationDone = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final again = widget.rebuildFrom;
    if (again == null) return;
    _profile = again;
    _index = _steps.length - 1;
    // After the first frame: _startBuild reads providers and calls setState,
    // and the build step's own animation has to be mounted to be driven.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startBuild();
    });
  }

  _Step get _step => _steps[_index.clamp(0, _steps.length - 1)];
  bool get _isBuilding => _step.kind == _Kind.building;

  /// One colour per question, cycled, like the onboarding quiz.
  Color get _accent => QuizPalette.accentFor(_index);

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _notes.dispose();
    super.dispose();
  }

  void _set(TasteProfile next) => setState(() => _profile = next);

  void _advance() {
    if (_isBuilding) return;
    _advanceTimer?.cancel();
    _advanceTimer = null;
    setState(() {
      _forward = true;
      _neitherPressed = false;
      _index = (_index + 1).clamp(0, _steps.length - 1);
    });
    if (_isBuilding) _startBuild();
  }

  void _back() {
    if (_index == 0) {
      widget.onBack?.call();
      return;
    }
    _advanceTimer?.cancel();
    _advanceTimer = null;
    setState(() {
      _forward = false;
      _neitherPressed = false;
      _index -= 1;
    });
  }

  /// Skip leaves the step unanswered — including undoing a half-answer, so a
  /// grid with two taps and a Skip sends nothing from that grid.
  void _skip() {
    final step = _step;
    switch (step.kind) {
      case _Kind.gridA:
        _profile = _profile.copyWith(
          liked: [
            for (final id in _profile.liked)
              if (!DishTaxonomy.gridA.contains(id)) id,
          ],
        );
      case _Kind.gridB:
        _profile = _profile.copyWith(
          liked: [
            for (final id in _profile.liked)
              if (!DishTaxonomy.gridB.contains(id)) id,
          ],
        );
      case _Kind.pair:
        _profile = _profile.copyWith(
          leaning: {..._profile.leaning}..remove(step.axis),
        );
      case _Kind.avoid:
        _profile = _profile.copyWith(avoid: const {});
      case _Kind.cookTime:
        _profile = _profile.copyWith(clearCookTime: true);
      case _Kind.notes:
        _notes.clear();
        _profile = _profile.copyWith(notes: '');
      case _Kind.building:
        return;
    }
    _advance();
  }

  void _toggleDish(Dish dish) {
    final liked = [..._profile.liked];
    if (!liked.remove(dish.id)) liked.add(dish.id);
    _set(_profile.copyWith(liked: liked));
  }

  /// A tap on a pair card is the answer; the step moves on by itself after a
  /// beat, so the press is seen before the card slides away.
  void _pickPole(TasteAxis axis, TastePole pole) {
    _advanceTimer?.cancel();
    _set(_profile.copyWith(leaning: {..._profile.leaning, axis: pole}));
    _advanceTimer = Timer(const Duration(milliseconds: 260), _advance);
  }

  void _pickNeither(TasteAxis axis) {
    _advanceTimer?.cancel();
    final leaning = {..._profile.leaning}..remove(axis);
    // On most axes "neither" means no leaning and the axis stays unanswered;
    // on breakfast it means "I skip it", which the plan needs to know.
    final neither = axis.neither;
    if (neither != null) leaning[axis] = neither;
    setState(() {
      _profile = _profile.copyWith(leaning: leaning);
      _neitherPressed = true;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 260), _advance);
  }

  // ---------------------------------------------------------------------------
  // Building
  // ---------------------------------------------------------------------------

  /// Generates, saves, then — once the sweep has also finished — hands over.
  ///
  /// The save happens the moment the planner answers, whatever the screen is
  /// doing by then. A generate is a quota unit (three a day, not refunded),
  /// so a plan that arrived after the person backed out used to be thrown
  /// away with the unit already spent; now it lands in My Diets either way.
  /// That is why the repositories are read *before* the await — `ref` cannot
  /// be read once the screen is disposed — and why the save is not gated on
  /// `mounted` or on the attempt still being current.
  /// A generate is in flight. The error card's "Try again" stays hit-testable
  /// for the 260 ms it takes to slide out, and a second tap in that window
  /// started a second generate — two quota units and two plans for one
  /// intent.
  bool _generating = false;

  Future<void> _startBuild() async {
    if (_generating) return;
    // A plan already in hand for these answers means only the save failed.
    // Re-run that, not the generate.
    final held = _plan;
    if (held != null && _builtFrom == _profile) {
      // The sweep runs again from the top, so the handoff happens the same
      // way it does the first time.
      setState(() {
        _error = null;
        _saved = null;
        _animationDone = false;
        _finishing = false;
      });
      await _save(
        held,
        attempt: _attempt,
        diets: ref.read(dietRepositoryProvider),
      );
      return;
    }

    final attempt = ++_attempt;
    setState(() {
      _plan = null;
      _builtFrom = null;
      _saved = null;
      _error = null;
      _animationDone = false;
      _finishing = false;
    });

    final planner = ref.read(plannerRepositoryProvider);
    final diets = ref.read(dietRepositoryProvider);
    // Captured before the await, like the two above: the generate outlives
    // this screen on purpose — a plan that lands after someone navigated away
    // is still saved — and `ref` throws once the state is disposed.
    final lastTaste = ref.read(lastTasteProvider.notifier);
    final profile = _profile;

    final DietPlan plan;
    _generating = true;
    try {
      plan = await planner.generate(taste: profile);
    } on RepositoryException catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = e.message);
      return;
    } catch (error, stack) {
      // Anything the repository did not translate. The message below is the
      // same for a Worker outage, a bad profile and a misconfigured build, so
      // without this line there is nothing on the device to tell them apart —
      // which is exactly how a missing WORKER_URL was read as the planner
      // being broken.
      debugPrint('plan generation failed: $error\n$stack');
      if (!mounted || attempt != _attempt) return;
      setState(
        () => _error = 'The plan could not be built. Try again in a moment.',
      );
      return;
    } finally {
      _generating = false;
    }

    if (mounted && attempt == _attempt) {
      setState(() {
        _plan = plan;
        _builtFrom = profile;
      });
    }
    // Kept so "Something else" can ask for another plan from the same answers.
    // Written after the generate rather than on the last question, because a
    // profile that never produced a plan is not one worth rebuilding from —
    // and unconditionally, for the same reason the save below is.
    lastTaste.remember(profile);
    await _save(plan, attempt: attempt, diets: diets);
  }

  /// Saves [plan], then lets [_maybeFinish] hand it over. Unconditional on
  /// the screen's state — see [_startBuild] — and only *reported* to a screen
  /// that is still on this attempt.
  ///
  /// Re-saving the same plan is safe: ids are fixed per generate and the
  /// repositories replace by id, so a retry cannot put two copies in My
  /// Diets.
  Future<void> _save(
    DietPlan plan, {
    required int attempt,
    required DietRepository diets,
  }) async {
    try {
      // Stamped here rather than in the planner repositories, because this
      // is the moment it becomes a stored record rather than a response. My
      // Diets orders on it, so without it a plan someone just waited fifteen
      // seconds for lands wherever its random uuid happens to sort.
      final saved = await diets.add(
        plan.createdAt == null
            ? plan.copyWith(createdAt: DateTime.now())
            : plan,
      );
      if (!mounted || attempt != _attempt) return;
      setState(() => _saved = saved);
      _maybeFinish();
    } on RepositoryException catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      setState(
        () => _error = 'The plan was built but could not be saved. Try again.',
      );
    }
  }

  void _onAnimationDone() {
    if (!mounted) return;
    setState(() => _animationDone = true);
    _maybeFinish();
  }

  /// Hands the plan over once the sweep has finished *and* it is saved.
  void _maybeFinish() {
    final saved = _saved;
    if (!_animationDone || saved == null || _finishing) return;
    _finishing = true;
    widget.onCreated?.call(saved);
  }

  /// Back from the error card returns to the notes step. A pending attempt
  /// is orphaned rather than cancelled: its plan is still saved when it
  /// lands, and only the screen stops listening.
  ///
  /// A plan that was generated but not saved is **kept**, with the answers it
  /// came from. The next "Build my plan" re-saves it if the answers are
  /// unchanged, and generates afresh if they are not — in which case the held
  /// plan was never saved, so there is nothing to double up.
  void _backFromError() {
    _attempt++;
    setState(() {
      _forward = false;
      _error = null;
      _saved = null;
      _index -= 1;
    });
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isBuilding = _isBuilding;
    final isNotes = _step.kind == _Kind.notes;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: QuizPalette.ground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: QuizPalette.ground,
        // The notes field sits above a bottom-anchored CTA; without this the
        // keyboard covers the button and the canvas has no reason to scroll.
        resizeToAvoidBottomInset: true,
        body: DesignCanvas(
          background: QuizPalette.ground,
          children: [
            // The bar is hidden on the build step, like onboarding's: the ring
            // is the progress there, and a full bar under a spinning ring says
            // "done" while the plan is still being written.
            if (!isBuilding)
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
            if (!isBuilding)
              Positioned(
                left: 20,
                top: 96,
                child: QuizTextButton(label: 'Back', onTap: _back),
              ),
            if (!isBuilding)
              Positioned(
                right: 20,
                top: 96,
                child: QuizTextButton(label: 'Skip', onTap: _skip),
              ),
            Positioned(
              left: 20,
              top: 148,
              width: 388,
              height: 84,
              child: QuizFade(
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
              child: QuizFade(
                step: _step,
                child: Text(
                  _subtitle,
                  style: AppTypography.body(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // The body runs to 782 rather than onboarding's 722: a 3×3 of
            // tiles with their shadows needs the room, and there is no running
            // estimate here to share it with. The CTA at 796 still clears it.
            Positioned(
              left: 20,
              top: 312,
              width: 388,
              height: 470,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                // Top, not centre. AnimatedSwitcher's default layout centres
                // its child in a Stack, which on a phone left the pair cards,
                // the chips and the build ring floating a third of the way
                // down a 470-unit box with a void under the subtitle.
                // Onboarding starts every step at the top of the body; so
                // does this.
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: Offset(_forward ? 0.12 : -0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey((_step, _error != null)),
                  child: _body(),
                ),
              ),
            ),
            if (!isBuilding)
              Positioned(
                left: 20,
                top: 796,
                width: 388,
                height: 58,
                child: StickerButton(
                  label: isNotes ? 'Build my plan' : 'Next',
                  accent: _accent,
                  onPressed: _advance,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _title => _titleFor(_step);
  String get _subtitle => _subtitleFor(_step.kind);

  static String _titleFor(_Step step) => switch (step) {
    (kind: _Kind.gridA, axis: _) => 'Tap what looks good',
    (kind: _Kind.gridB, axis: _) => 'And these?',
    (kind: _Kind.pair, axis: TasteAxis.spice) => 'Heat, or not?',
    (kind: _Kind.pair, axis: TasteAxis.starch) => 'Rice, or bread?',
    (kind: _Kind.pair, axis: TasteAxis.protein) => 'Meat, or plants?',
    (kind: _Kind.pair, axis: TasteAxis.breakfast) => 'Big breakfast, or light?',
    (kind: _Kind.pair, axis: _) => 'Cook it, or build it?',
    (kind: _Kind.avoid, axis: _) => 'Anything to leave out?',
    (kind: _Kind.cookTime, axis: _) => 'How much time to cook?',
    (kind: _Kind.notes, axis: _) => 'Anything else?',
    (kind: _Kind.building, axis: _) => 'Building your plan',
  };

  /// One line each, at the text-scale ceiling. The box under the title is
  /// 50 tall and two lines of body at 1.15x need 57.5, so a subtitle that
  /// wraps loses its second line to the clip. `taste_quiz_copy_test` lays
  /// every one of these out and fails on the first that wraps.
  static String _subtitleFor(_Kind kind) => switch (kind) {
    _Kind.gridA => 'Tap as many as you like.',
    _Kind.gridB => 'A different corner of the map.',
    _Kind.pair => "Tap the one you'd rather eat.",
    _Kind.avoid => 'The plan will never include these.',
    _Kind.cookTime => 'On a normal weekday.',
    _Kind.notes => 'Optional. What the pictures miss.',
    _Kind.building => 'From your taste, to your targets.',
  };

  Widget _body() {
    final step = _step;
    return switch (step.kind) {
      _Kind.gridA => _grid(DishTaxonomy.gridA),
      _Kind.gridB => _grid(DishTaxonomy.gridB),
      _Kind.pair => _Pair(
        axis: step.axis!,
        accent: _accent,
        chosen: _profile.leaning[step.axis],
        neitherPressed:
            _neitherPressed ||
            (step.axis!.neither != null &&
                _profile.leaning[step.axis] == step.axis!.neither),
        onPole: (pole) => _pickPole(step.axis!, pole),
        onNeither: () => _pickNeither(step.axis!),
      ),
      _Kind.avoid => _AvoidChips(
        accent: _accent,
        avoid: _profile.avoid,
        onChanged: (v) => _set(_profile.copyWith(avoid: v)),
      ),
      _Kind.cookTime => QuizOptions<CookTime>(
        accent: _accent,
        value: _profile.cookTime,
        options: [for (final t in CookTime.values) (t, t.label, t.detail)],
        onChanged: (v) => _set(_profile.copyWith(cookTime: v)),
      ),
      _Kind.notes => _Notes(
        accent: _accent,
        controller: _notes,
        onChanged: (v) => _profile = _profile.copyWith(notes: v),
      ),
      _Kind.building =>
        _error != null
            ? _ErrorCard(
                message: _error!,
                accent: _accent,
                onRetry: _startBuild,
                onBack: _backFromError,
              )
            : _Building(
                key: ValueKey(_attempt),
                accent: _accent,
                profile: _profile,
                calories: ref.read(targetsProvider).calories,
                purpose: ref.read(planPurposeProvider)?.label,
                waiting: _animationDone && _saved == null,
                onDone: _onAnimationDone,
              ),
    };
  }

  Widget _grid(List<String> ids) => Align(
    alignment: Alignment.topCenter,
    child: DishGrid(
      dishes: DishTaxonomy.grid(ids),
      liked: _profile.liked,
      accent: _accent,
      onToggle: _toggleDish,
    ),
  );
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// Two dishes that differ in one thing, and a way to say neither.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.axis,
    required this.accent,
    required this.chosen,
    required this.neitherPressed,
    required this.onPole,
    required this.onNeither,
  });

  final TasteAxis axis;
  final Color accent;
  final TastePole? chosen;
  final bool neitherPressed;
  final ValueChanged<TastePole> onPole;
  final VoidCallback onNeither;

  @override
  Widget build(BuildContext context) {
    final left = DishTaxonomy.byId(axis.left)!;
    final right = DishTaxonomy.byId(axis.right)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 236,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DishTile(
                      dish: left,
                      accent: accent,
                      selected: chosen == axis.leftPole,
                      onTap: () => onPole(axis.leftPole),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DishTile(
                      dish: right,
                      accent: accent,
                      selected: chosen == axis.rightPole,
                      onTap: () => onPole(axis.rightPole),
                    ),
                  ),
                ],
              ),
              // The "or" between them: a sticker over the seam, not a control.
              const Positioned.fill(
                child: IgnorePointer(child: Align(child: _OrBadge())),
              ),
            ],
          ),
        ),
        // Room for the tiles' shadow before the button.
        const SizedBox(height: 22),
        NeitherButton(
          label: axis.neitherLabel,
          pressed: neitherPressed,
          onTap: onNeither,
        ),
      ],
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: QuizPalette.card,
        shape: BoxShape.circle,
        border: Border.all(color: QuizPalette.ink, width: 2),
        boxShadow: const [
          BoxShadow(color: QuizPalette.ink, offset: Offset(2, 2)),
        ],
      ),
      child: Text(
        'or',
        style: AppTypography.meta(
          color: QuizPalette.ink,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Hard constraints, as chips. "Nothing" is a real chip rather than the
/// absence of a choice, so an empty set is visibly an answer.
class _AvoidChips extends StatelessWidget {
  const _AvoidChips({
    required this.accent,
    required this.avoid,
    required this.onChanged,
  });

  final Color accent;
  final Set<Avoidance> avoid;
  final ValueChanged<Set<Avoidance>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      // The shadow sits outside the chip, so the rows need room for it.
      runSpacing: 14,
      children: [
        TasteChip(
          label: 'Nothing',
          accent: accent,
          selected: avoid.isEmpty,
          onTap: () => onChanged(const {}),
        ),
        for (final a in Avoidance.values)
          TasteChip(
            label: a.label,
            accent: accent,
            selected: avoid.contains(a),
            onTap: () {
              final next = {...avoid};
              if (!next.remove(a)) next.add(a);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// The escape hatch: one line for whatever the pictures could not ask.
class _Notes extends StatelessWidget {
  const _Notes({
    required this.accent,
    required this.controller,
    required this.onChanged,
  });

  final Color accent;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: QuizPalette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: QuizPalette.shadow,
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 3,
            maxLength: 400,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.body(color: QuizPalette.ink),
            cursorColor: accent,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              // The ceiling is enforced, not advertised: a "0/400" under an
              // optional box makes it read as a form.
              counterText: '',
              hintText: 'e.g. no mushrooms · love Thai · big dinners',
              hintStyle: AppTypography.body(
                color: AppColors.inkMuted.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          // Said before they wait, not after. The model writes the plan; the
          // numbers it is hitting are the app's own.
          'Written for your targets. It is a suggestion, not medical advice.',
          style: AppTypography.meta(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    );
  }
}

/// The build step: the sweep ring over what is being sent, while the real
/// call runs underneath.
///
/// The four lines are the taste profile as the server will read it — not the
/// arithmetic, which is the server's, but the inputs, which are the person's.
/// The last line is the one number on the screen, and it is read from the
/// profile rather than asked, which is the whole point of this quiz — as is
/// the purpose beside it, which the server reads from the same profile.
class _Building extends StatelessWidget {
  const _Building({
    super.key,
    required this.accent,
    required this.profile,
    required this.calories,
    required this.purpose,
    required this.waiting,
    required this.onDone,
  });

  final Color accent;
  final TasteProfile profile;
  final double calories;

  /// `PlanPurpose.label`, or null when the profile has no goal.
  final String? purpose;

  /// The sweep has finished and the plan has not landed.
  final bool waiting;
  final VoidCallback onDone;

  List<(String, String)> get _stages {
    final cuisines = profile.cuisines.take(2).map((c) => c.label).join(' & ');
    final avoid = profile.avoid.map((a) => a.label).join(', ');
    return [
      ('Reading your taste', cuisines.isEmpty ? 'Open to anything' : cuisines),
      ('Leaving out', avoid.isEmpty ? 'Nothing' : avoid),
      ('Fitting your time', profile.cookTime?.label ?? 'No limit'),
      // "For weight loss — 1700 kcal": the label lower-cased mid-sentence,
      // since "For Weight loss" reads as a heading that lost its line break.
      (
        purpose == null ? 'Adding up to' : 'For ${purpose!.toLowerCase()}',
        '${calories.round()} kcal',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuizBuildStep(
          accent: accent,
          stages: _stages,
          onDone: onDone,
          // Four seconds, one line a second: the inputs are read out at a pace
          // that can be read, and the call underneath is well past that.
          duration: const Duration(seconds: 4),
          // No percentage: the sweep is the inputs, not the plan, and a
          // "100%" that then sat under "still writing" read as a stuck
          // screen on a phone. The centre is a sparkle that grows with the
          // sweep and a spinner while the model writes.
          showPercent: false,
          waiting: waiting,
          // Saying how long it usually takes is the one thing that makes a
          // wait feel shorter without lying about progress.
          waitingCaption: 'Writing your day — usually 15 to 20 seconds.',
          waitingLongCaption: 'Taking longer than usual. Still working.',
        ),
      ],
    );
  }
}

/// What went wrong, and the two ways out.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.accent,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final Color accent;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: QuizPalette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: QuizPalette.shadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 22, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body(color: QuizPalette.ink),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        StickerButton(label: 'Try again', accent: accent, onPressed: onRetry),
        const SizedBox(height: 12),
        QuizTextButton(label: 'Back', onTap: onBack),
      ],
    );
  }
}
