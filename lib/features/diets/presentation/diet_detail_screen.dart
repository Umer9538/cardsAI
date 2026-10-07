import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../scan/presentation/scan_result_screen.dart';
import '../../../core/design/app_toast.dart';

/// Diet details — Figma frame `28_Diet details` (2002:1196).
///
/// Same shape as the scan result: a 351pt hero with the sheet overlapping its
/// lower third, then the 2x2 macro grid. It reuses that screen's `MacroStat`
/// rather than defining a parallel model.
class DietDetailScreen extends ConsumerWidget {
  const DietDetailScreen({
    super.key,
    required this.plan,
    this.onBack,
    this.onAdd,
    this.onRebuild,
  });

  final DietPlan plan;
  final VoidCallback? onBack;
  final VoidCallback? onAdd;

  /// Builds another plan from the same answers.
  ///
  /// Null on a catalogue plan, which was not built from anybody's answers, and
  /// null when nothing is stored to rebuild from.
  final VoidCallback? onRebuild;

  /// The plan's macros as a share of its own calorie total, by the standard
  /// Atwater factors — 4 kcal/g for protein and carbohydrate, 9 for fat.
  ///
  /// This is the one place a percentage is of the plan rather than of the
  /// day: the artboard's captions read "100%", and a plan's macro split is
  /// conventionally expressed against its own energy.
  static List<MacroStat> macrosOf(Nutrition n) {
    final energy = n.calories <= 0 ? 1.0 : n.calories;
    return [
      MacroStat(
        label: 'Calories',
        colour: AppColors.lilac,
        value: NutritionFormat.calories(n.calories),
      ),
      MacroStat(
        label: 'Protein',
        colour: AppColors.accentGreen,
        percent: n.protein * 4 / energy,
      ),
      MacroStat(
        label: 'Carbs',
        colour: AppColors.planYellow,
        percent: n.carbs * 4 / energy,
      ),
      MacroStat(
        label: 'Fat',
        colour: AppColors.accentOrange,
        percent: n.fat * 9 / energy,
      ),
    ];
  }

  /// The goal card ends at 835 on the artboard. Everything below is ours, and
  /// it is laid out as one column rather than as absolutely positioned blocks.
  ///
  /// The first attempt gave each section a guessed height and stacked them by
  /// arithmetic. The "Eat" and "Keep low" chips wrap to two rows on a narrow
  /// phone and to one on a wide one, so the guess was wrong immediately and
  /// the day's heading was drawn straight through the chips. Nothing here has
  /// a knowable height; a Column measures instead of assuming.
  static const double _bodyTop = 855;

  /// The column is 388 wide: the artboard's 20pt margins off 428.
  static const double _column = 388;

  /// Room reserved on the canvas below the CTA, so the last control clears
  /// the bottom edge rather than touching it.
  static const double _bottomSlack = 40;

  /// The canvas height, measured from what the column below will draw.
  ///
  /// This used to be a constant — 1100 for the body, plus 120 for "Built for
  /// you" — and the constant was wrong in the normal case. A fully answered
  /// quiz produces eight chips (a cuisine, five leanings, the avoidances and
  /// a cook time), and under them the CTA landed at 2181 on a 2075 canvas —
  /// clipped by 106pt at 1.0x text, and at 2278 on the tallest seed day at
  /// 1.15x; a catalogue plan with no chips was already 40pt short at 1.15x.
  /// The canvas is a fixed-height `Stack` with hard clipping inside a scroll
  /// view, so anything past `height` is unreachable at any scroll position —
  /// not a cosmetic gap but a control that cannot be tapped.
  ///
  /// So it is measured: every text in the column through a `TextPainter` at
  /// the ambient text scale, the chip rows by replaying `Wrap`'s own packing
  /// rule, the meal cards from their real contents. Honest rather than
  /// generous — [_bottomSlack] is the only margin — because a canvas taller
  /// than its content is empty space under the button on every phone.
  /// `diet_detail_reserve_test` asserts the CTA's bottom sits inside it.
  double _contentHeight(BuildContext context) {
    // The canvas clamps the OS scale at [DesignCanvas.maxTextScale], so the
    // measurement must too, or a 3.0x request books room for text the canvas
    // will never draw that large.
    final measure = _Measure(
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: DesignCanvas.maxTextScale),
    );
    final chips = AppTypography.meta();

    var height = _bodyTop;

    if (plan.builtFor.isNotEmpty) {
      height += measure.line('Built for you', AppTypography.sectionTitle()) +
          12 +
          measure.chipRows(plan.builtFor, chips) +
          24;
    }

    double ruleRow(List<String> values) => values.isEmpty
        ? 0
        : measure.line('Eat', AppTypography.label()) +
            6 +
            measure.chipRows(values, chips);
    height += measure.line('How It Works', AppTypography.sectionTitle()) +
        12 +
        ruleRow(plan.eat) +
        10 +
        ruleRow(plan.limit) +
        24;

    height += measure.line('A Day on This Plan', AppTypography.sectionTitle()) +
        4 +
        measure.height(_ExampleDay.caption(plan), chips) +
        12;
    for (final meal in plan.day) {
      height += _PlannedMealCard.heightFor(meal, measure) + 12;
    }

    // The CTA, and "Something else" above it when there is one. The canvas is
    // a fixed-height Stack with hard clipping inside a scroll view, so a
    // control past `height` cannot be tapped at any scroll position — an extra
    // button that is not measured here is an extra button nobody can press.
    return height + 20 + 50 + (onRebuild == null ? 0 : 12 + 48) + _bottomSlack;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Owns its bars. This screen is pushed straight over the cream taste quiz,
    // and a system-bar style only holds while the widget that set it is on
    // screen — so without one here the quiz's nav bar colour stayed behind on
    // the plan it produced.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final contentHeight = _contentHeight(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        height: contentHeight,
        children: [
          // A raw Positioned rather than DesignImage, because DesignImage
          // hard-codes `BoxFit.fill`.
          //
          // That is correct for what it was built for — flat illustrations
          // exported at exactly the box they are drawn into — and wrong for a
          // photograph. These assets are 388x204 logical (keto) up to 388x110
          // (detox), and forcing them into 428x351 stretched keto vertically
          // by 1.7x against 1.1x horizontally: a 56% distortion, and 189% on
          // detox. `cover` crops instead, which is what the diets list card
          // and the scan result's own 428x351 hero both already do.
          Positioned(
            left: 0,
            top: 0,
            width: 428,
            height: 351,
            child: Image.asset(
              plan.image,
              width: 428,
              height: 351,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          ),
          Positioned(
            left: 0,
            top: 320,
            width: 428,
            height: contentHeight - 320,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 71,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                'assets/images/auth/back_button.png',
                width: 40,
                height: 40,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 340,
            width: 388,
            height: 36,
            // One line. The box is the artboard's, and a generated name —
            // "Your Indian Vegetarian Weight Loss" — wrapped into it and
            // lost its second line with no ellipsis to say so.
            child: Text(
              plan.name,
              style: AppTypography.topBarTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            left: 20,
            top: 388,
            width: 388,
            child: Text(
              plan.description,
              style: AppTypography.socialLabel(color: AppColors.placeholder),
            ),
          ),
          // 2x2 macro grid, 184pt columns 20 apart, 100pt rows 12 apart.
          for (final (i, macro) in macrosOf(plan.nutrition).indexed)
            Positioned(
              left: 20 + (i.isOdd ? 204 : 0),
              top: 496 + (i >= 2 ? 112 : 0),
              width: 184,
              height: 100,
              child: MacroTile(stat: macro),
            ),
          // Goal card: a 44pt icon disc at (40, 760) beside the copy at x=96.
          Positioned(
            left: 20,
            top: 728,
            width: 388,
            height: 107,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.inkMuted,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const DesignImage(
            asset: 'assets/images/app/icon_goal.png',
            left: 40,
            top: 760,
            width: 44,
            height: 44,
          ),
          Positioned(
            left: 96,
            top: 752,
            width: 292,
            height: 30,
            child: Text('Goal', style: AppTypography.sectionTitle()),
          ),
          Positioned(
            left: 96,
            top: 786,
            width: 292,
            height: 25,
            child: Text(
              plan.goal,
              style: AppTypography.body(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // What the plan actually is. Everything above this point is a
          // target; this is the diet.
          Positioned(
            left: 20,
            top: _bodyTop,
            width: 388,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only a plan someone built carries this. A catalogue plan
                // was built for nobody in particular, and saying so would
                // make the chips below it look like they mean less.
                if (plan.builtFor.isNotEmpty) ...[
                  _BuiltFor(chips: plan.builtFor),
                  const SizedBox(height: 24),
                ],
                _Rules(plan: plan),
                const SizedBox(height: 24),
                _ExampleDay(plan: plan),
                const SizedBox(height: 20),
                // Above the primary action, outlined rather than filled: it is
                // the way out of a plan someone does not want, not the thing
                // the screen is for.
                if (onRebuild != null) ...[
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: _SomethingElseButton(onTap: onRebuild!),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: PrimaryButton(
                    label: plan.isMine
                        ? 'Remove from My Diet'
                        : 'Add to My Diet',
                    onPressed: () {
                      ref
                          .read(dietRepositoryProvider)
                          .setMine(plan.id, mine: !plan.isMine);
                      onAdd?.call();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a generated plan was built *for* — the taste quiz's answers, frozen on
/// the plan as chips.
///
/// Sits above "How It Works" because it is the answer to the first question
/// anyone asks of a plan with their name on it: what did you actually take
/// from me. The chips are `_RuleRow`'s shape in the brand colour, so they
/// read as the same vocabulary but as the person's own, not the plan's.
class _BuiltFor extends StatelessWidget {
  const _BuiltFor({required this.chips});

  /// Every chip on this screen is this shape, and [_Measure.chipRows]
  /// reproduces it — change one and change the other.
  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: 11, vertical: 6);
  static const double chipBorder = 1;
  static const double chipSpacing = 8;

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Built for you', style: AppTypography.sectionTitle()),
        const SizedBox(height: 12),
        Wrap(
          spacing: _BuiltFor.chipSpacing,
          runSpacing: _BuiltFor.chipSpacing,
          children: [
            for (final chip in chips)
              Container(
                padding: _BuiltFor.chipPadding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary,
                    width: _BuiltFor.chipBorder,
                  ),
                ),
                child: Text(
                  chip,
                  style: AppTypography.meta(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// What the plan is built on, and what it keeps low.
///
/// The part people scan before deciding. "Can I actually eat like this" is
/// answered by seeing the food, not by reading about metabolic pathways.
class _Rules extends StatelessWidget {
  const _Rules({required this.plan});

  final DietPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How It Works', style: AppTypography.sectionTitle()),
        const SizedBox(height: 12),
        _RuleRow(label: 'Eat', colour: AppColors.accentGreen, values: plan.eat),
        const SizedBox(height: 10),
        _RuleRow(
          label: 'Keep low',
          colour: AppColors.accentOrange,
          values: plan.limit,
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.label,
    required this.colour,
    required this.values,
  });

  final String label;
  final Color colour;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(color: colour)),
        const SizedBox(height: 6),
        Wrap(
          spacing: _BuiltFor.chipSpacing,
          runSpacing: _BuiltFor.chipSpacing,
          children: [
            for (final value in values)
              Container(
                padding: _BuiltFor.chipPadding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.outline,
                    width: _BuiltFor.chipBorder,
                  ),
                ),
                child: Text(
                  value,
                  style: AppTypography.meta(color: AppColors.placeholder),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A day on the plan, meal by meal, each one loggable.
///
/// The log button is the point. Without it this is a brochure: a list of foods
/// someone would have to retype into the search box one at a time. With it, the
/// plan and the diary are the same thing.
class _ExampleDay extends ConsumerWidget {
  const _ExampleDay({required this.plan});

  final DietPlan plan;

  static String caption(DietPlan plan) =>
      'About ${NutritionFormat.calories(plan.day.fold(0.0, (s, m) => s + m.nutrition.calories))} '
      'as written — scale the portions to your own day.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A Day on This Plan', style: AppTypography.sectionTitle()),
        const SizedBox(height: 4),
        // Its own total, stated. The macro cards above are the user's target;
        // this is an example of the pattern, and pretending the two are the
        // same number would mean rescaling portions whose names spell them
        // out.
        Text(
          caption(plan),
          style: AppTypography.meta(color: AppColors.placeholder),
        ),
        const SizedBox(height: 12),
        for (final meal in plan.day) ...[
          _PlannedMealCard(meal: meal),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PlannedMealCard extends ConsumerStatefulWidget {
  const _PlannedMealCard({required this.meal});

  final PlannedMeal meal;

  /// The card never draws shorter than this, whatever it holds.
  static const double minHeight = 108;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(15, 13, 15, 13);
  static const double border = 1;
  static const double buttonHeight = 34;

  /// Lines the items line may take before it ellipsises.
  static const int itemLines = 2;

  /// What the card will measure, from the same texts, styles and gaps
  /// `build` draws — the two must move together.
  static double heightFor(PlannedMeal meal, _Measure measure) {
    final inner = DietDetailScreen._column -
        padding.horizontal -
        2 * border;
    final content = measure.line(meal.slot.label, AppTypography.label()) +
        4 +
        measure.line(meal.title, AppTypography.body()) +
        4 +
        measure.height(
          meal.items.map((i) => i.name).join(' · '),
          AppTypography.meta(),
          width: inner,
          maxLines: itemLines,
        ) +
        10 +
        buttonHeight;
    return math.max(minHeight, content + padding.vertical + 2 * border);
  }

  @override
  ConsumerState<_PlannedMealCard> createState() => _PlannedMealCardState();
}

class _PlannedMealCardState extends ConsumerState<_PlannedMealCard> {
  bool _logged = false;
  static const _uuid = Uuid();

  Future<void> _log() async {
    final messenger = ScaffoldMessenger.of(context);
    final meal = widget.meal;
    final now = DateTime.now();
    try {
      await ref
          .read(diaryRepositoryProvider)
          .addMeal(
            Meal(
              id: _uuid.v4(),
              eatenAt: now,
              items: meal.items,
              // The plan's own slot, not the clock's: a plan's breakfast is
              // breakfast whenever you get to it.
              slot: meal.slot,
              title: meal.title,
            ),
          );
      unawaited(ref.read(mealRemindersProvider).mealLogged());
      if (!mounted) return;
      setState(() => _logged = true);
      messenger.showSnackBar(
        appToast('${meal.title} logged.', tone: ToastTone.success),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        appToast(
          'That could not be logged. Try again.',
          tone: ToastTone.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Container(
      constraints: const BoxConstraints(minHeight: _PlannedMealCard.minHeight),
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outline,
          width: _PlannedMealCard.border,
        ),
      ),
      padding: _PlannedMealCard.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meal.slot.label,
                  style: AppTypography.label(color: AppColors.placeholder),
                ),
              ),
              Text(
                NutritionFormat.calories(meal.nutrition.calories),
                style: AppTypography.label(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meal.title,
            style: AppTypography.body(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            meal.items.map((i) => i.name).join(' · '),
            style: AppTypography.meta(color: AppColors.muted),
            maxLines: _PlannedMealCard.itemLines,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _PlannedMealCard.buttonHeight,
            child: GestureDetector(
              onTap: _logged ? null : _log,
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _logged ? AppColors.accentGreen : AppColors.outline,
                  ),
                ),
                child: Text(
                  _logged ? 'Added to today' : 'Log this meal',
                  style: AppTypography.meta(
                    color: _logged
                        ? AppColors.accentGreen
                        : AppColors.placeholder,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Measures text the way the column below the goal card will lay it out, so
/// the canvas can be sized from its contents rather than from a guess.
class _Measure {
  const _Measure(this.scaler);

  final TextScaler scaler;

  /// The laid-out size of [text] in [style] within [width].
  Size size(
    String text,
    TextStyle style, {
    double width = DietDetailScreen._column,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double height(
    String text,
    TextStyle style, {
    double width = DietDetailScreen._column,
    int? maxLines,
  }) =>
      size(text, style, width: width, maxLines: maxLines).height;

  /// One line of [style] — for text that is given `maxLines: 1` or cannot
  /// wrap at this width.
  double line(String text, TextStyle style) =>
      height(text, style, maxLines: 1);

  /// The height of a `Wrap` of chips in the column, packed the way
  /// `RenderWrap` packs them: a chip goes on the current row if it fits with
  /// its spacing, else starts the next; a row is as tall as its tallest chip;
  /// rows are [_BuiltFor.chipSpacing] apart.
  double chipRows(List<String> labels, TextStyle style) {
    if (labels.isEmpty) return 0;
    const pad = _BuiltFor.chipPadding;
    const border = _BuiltFor.chipBorder;
    const gap = _BuiltFor.chipSpacing;
    const column = DietDetailScreen._column;

    var total = 0.0;
    var rowWidth = 0.0;
    var rowHeight = 0.0;
    for (final label in labels) {
      // The chip's text can take the column less its own padding, which is
      // what a Wrap hands a child that is wider than a word.
      final text = size(label, style, width: column - pad.horizontal - 2 * border);
      final width = text.width + pad.horizontal + 2 * border;
      final height = text.height + pad.vertical + 2 * border;
      if (rowWidth > 0 && rowWidth + gap + width > column) {
        total += rowHeight + gap;
        rowWidth = 0;
        rowHeight = 0;
      }
      rowWidth += (rowWidth > 0 ? gap : 0) + width;
      rowHeight = math.max(rowHeight, height);
    }
    return total + rowHeight;
  }
}


/// "Something else" — another plan from the same answers.
///
/// Outlined rather than filled, because it sits above the screen's actual CTA
/// and two filled buttons in a column read as a choice between equals. It also
/// says what it costs: a generation is capped at three a day and the slot is
/// reserved before the model call and never refunded, so a tap here is one of
/// those three whether or not the result is liked any better.
class _SomethingElseButton extends StatelessWidget {
  const _SomethingElseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Build a different plan from the same answers',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Something else',
                  style: AppTypography.socialLabel(color: AppColors.primary),
                ),
                Text(
                  'Same answers, a different day',
                  style: AppTypography.meta(color: AppColors.placeholder),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
