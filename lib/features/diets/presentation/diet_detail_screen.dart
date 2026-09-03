import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../scan/presentation/scan_result_screen.dart';

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
  });

  final DietPlan plan;
  final VoidCallback? onBack;
  final VoidCallback? onAdd;

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

  /// Room reserved on the canvas, which scrolls — so over-reserving costs a
  /// little empty space and under-reserving clips the last control.
  static double get _contentHeight => _bodyTop + 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        height: _contentHeight,
        children: [
          DesignImage(
            asset: plan.image,
            left: 0,
            top: 0,
            width: 428,
            height: 351,
          ),
          Positioned(
            left: 0,
            top: 320,
            width: 428,
            height: _contentHeight - 320,
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
            child: Text(plan.name, style: AppTypography.topBarTitle()),
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
                _Rules(plan: plan),
                const SizedBox(height: 24),
                _ExampleDay(plan: plan),
                const SizedBox(height: 20),
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
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
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
          'About ${NutritionFormat.calories(plan.day.fold(0.0, (s, m) => s + m.nutrition.calories))} '
          'as written — scale the portions to your own day.',
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

  static const double height = 108;

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
      if (!mounted) return;
      setState(() => _logged = true);
      messenger.showSnackBar(SnackBar(content: Text('${meal.title} logged.')));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That could not be logged. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Container(
      constraints: const BoxConstraints(minHeight: _PlannedMealCard.height),
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
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
