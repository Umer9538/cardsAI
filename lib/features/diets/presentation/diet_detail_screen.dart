import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
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
            height: 606,
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
              child: Image.asset('assets/images/auth/back_button.png',
                  width: 40, height: 40, filterQuality: FilterQuality.high),
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
            child: Text(plan.description,
                style: AppTypography.socialLabel(color: AppColors.placeholder)),
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
          // Below the goal card, not across it. The artboard puts the CTA at
          // y=810 and the goal card spans 728-835, so the button was drawn over
          // the bottom quarter of the card.
          Positioned(
            left: 20,
            top: 855,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: plan.isMine ? 'Remove from My Diet' : 'Add to My Diet',
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
    );
  }
}
