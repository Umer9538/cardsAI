import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/theme/app_typography.dart';
import '../../app/presentation/home_screen.dart' show NutritionRow;
import '../../app/presentation/widgets/bottom_nav.dart';
import '../../app/presentation/widgets/segmented_tabs.dart';

/// Which tab of the Diets screen is showing.
enum DietsTab { all, mine }

/// Diets — Figma frames `27_Diets` (2002:1247), `29_My Diets-Empty`
/// (2002:1132) and `30_My Diets` (2002:1122).
///
/// One screen with two tabs. The "All Diets" tab carries a lilac header card
/// and a section title; "My Diets" drops both and starts its list higher, and
/// shows an empty state when there is nothing saved.
class DietsScreen extends ConsumerWidget {
  const DietsScreen({
    super.key,
    this.tab = DietsTab.all,
    this.allPlans,
    this.myPlans,
    this.onBuildPlan,
    this.onTabChanged,
    this.onNavSelected,
    this.onPlanTap,
  });

  final DietsTab tab;

  /// Overrides the repository, for tests that need a fixed list. Null means
  /// "read the real one".
  final List<DietPlan>? allPlans;
  final List<DietPlan>? myPlans;

  /// Opens the planner.
  final VoidCallback? onBuildPlan;

  final ValueChanged<DietsTab>? onTabChanged;
  final ValueChanged<AppTab>? onNavSelected;
  final ValueChanged<DietPlan>? onPlanTap;

  static const double _cardHeight = 282;
  static const double _cardGap = 20;

  /// "All Diets" starts its list at y=420 under the header card; "My Diets"
  /// starts at y=212 with neither header nor section title.
  double get _listTop => tab == DietsTab.all ? 420 : 290;

  double _contentHeight(List<DietPlan> plans) {
    if (plans.isEmpty) return DesignCanvas.designHeight;
    // The floating tab bar is pinned to the viewport, so the last card needs
    // room to scroll clear of it rather than stopping underneath.
    final bottom = _listTop +
        plans.length * _cardHeight +
        (plans.length - 1) * _cardGap +
        AppBottomNav.clearance;
    return bottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : bottom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = tab == DietsTab.all
        ? allPlans ?? ref.watch(allDietsProvider).value ?? const []
        : myPlans ?? ref.watch(myDietsProvider).value ?? const [];

    // Only "My Diets" has an empty state; the catalogue is never empty in
    // practice, and the artboard gives it no empty treatment.
    final isEmpty = tab == DietsTab.mine && plans.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            DesignCanvas(
              background: AppColors.background,
              height: _contentHeight(plans),
              children: [
                Positioned(
                  left: 20,
                  top: 71,
                  width: 300,
                  height: 36,
                  child: Text('Diets', style: AppTypography.topBarTitle()),
                ),
                Positioned(
                  left: 20,
                  top: 143,
                  width: 387,
                  height: 49,
                  child: SegmentedTabs(
                    labels: const ['All Diets', 'My Diets'],
                    selected: tab.index,
                    onChanged: onTabChanged == null
                        ? null
                        : (i) => onTabChanged!(DietsTab.values[i]),
                  ),
                ),

                if (tab == DietsTab.all) ...[
                  const _HeaderCard(),
                  Positioned(
                    left: 20,
                    top: 364,
                    width: 388,
                    height: 36,
                    child: Text('Diets', style: AppTypography.topBarTitle()),
                  ),
                ],

                // Only on My Diets. On the catalogue tab it would compete
                // with eight plans someone has not looked at yet; here it is
                // the answer to an empty list, and to "none of these are me".
                if (tab == DietsTab.mine)
                  // No height: two lines of text in a fixed box is how the
                  // hero cards, the analytics cards and the plan detail each
                  // went over their own edges at a raised text scale.
                  Positioned(
                    left: 20,
                    top: 212,
                    width: 388,
                    child: _BuildPlanCard(onTap: onBuildPlan),
                  ),

                if (isEmpty)
                  const _EmptyState()
                else
                  for (final (i, plan) in plans.indexed)
                    Positioned(
                      left: 20,
                      top: _listTop + i * (_cardHeight + _cardGap),
                      width: 388,
                      child: DietCard(
                        plan: plan,
                        showFavourite: tab == DietsTab.mine,
                        onTap: onPlanTap == null ? null : () => onPlanTap!(plan),
                        onFavourite: () => ref
                            .read(dietRepositoryProvider)
                            .setFavorite(plan.id, favorite: !plan.isFavorite),
                      ),
                    ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 926 - AppBottomNav.top - AppBottomNav.height,
              child: Center(
                child: AppBottomNav(
                  current: AppTab.diets,
                  onSelect: onNavSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: 216,
      width: 388,
      height: 128,
      child: const HeroCard(
        colour: AppColors.lilac,
        ink: AppColors.ink,
        title: 'Explore Diet Plans',
        body: 'Personalized plans to match your goals and lifestyle.',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        DesignImage(
          asset: 'assets/images/app/illus_no_notifications.png',
          left: 87,
          top: 289,
          width: 254,
          height: 216,
        ),
        Positioned(
          left: 87,
          top: 545,
          width: 254,
          height: 36,
          child: _EmptyTitle(),
        ),
        Positioned(
          left: 87,
          top: 593,
          width: 254,
          height: 44,
          child: _EmptySubtitle(),
        ),
      ],
    );
  }
}

class _EmptyTitle extends StatelessWidget {
  const _EmptyTitle();
  @override
  Widget build(BuildContext context) => Text('No Diet Plans Yet.',
      style: AppTypography.cardTitle(), textAlign: TextAlign.center);
}

class _EmptySubtitle extends StatelessWidget {
  const _EmptySubtitle();
  @override
  Widget build(BuildContext context) => Text(
      'Start a personalized diet to make tracking even easier.',
      style: AppTypography.socialLabel(),
      textAlign: TextAlign.center);
}

/// Figma `Diet Card`: a 220pt photo at radius 24, 12pt gap, then the title and
/// a divided macro row. The My Diets tab adds a heart at (364, top+20).
///
/// Shared with the Favorites screen, which uses the same component.
class DietCard extends StatelessWidget {
  const DietCard({
    super.key,
    required this.plan,
    required this.showFavourite,
    this.onTap,
    this.onFavourite,
  });

  final DietPlan plan;
  final bool showFavourite;
  final VoidCallback? onTap;
  final VoidCallback? onFavourite;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    // Fill the card, cropping as needed.
                    //
                    // Two of these photos come back short because Figma clipped
                    // the export at the frame edge. Drawing them at their own
                    // height, as the artboard implies, leaves a black void
                    // filling most of the card — obvious the moment there is a
                    // real photo in it. Cropping a slightly-scaled photo is the
                    // lesser evil until the full-height assets exist.
                    child: Image.asset(
                      plan.image,
                      width: 388,
                      height: 220,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                if (showFavourite)
                  Positioned(
                    left: 344,
                    top: 20,
                    width: 24,
                    height: 24,
                    child: GestureDetector(
                      onTap: onFavourite,
                      behavior: HitTestBehavior.opaque,
                      child: Opacity(
                        // The artboard only draws the saved state. Un-saved
                        // dims the same glyph rather than needing a second one.
                        opacity: plan.isFavorite ? 1 : 0.4,
                        child: Image.asset(
                          'assets/images/app/fav_button.png',
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(plan.name, style: AppTypography.cardHeading()),
          const SizedBox(height: 4),
          SizedBox(height: 19, child: NutritionRow(nutrition: plan.nutrition)),
        ],
      ),
    );
  }
}


/// The way into the planner.
///
/// Deliberately a row rather than another photo card: it is not a plan, and
/// dressing it as one would put it in competition with the eight real ones.
class _BuildPlanCard extends StatelessWidget {
  const _BuildPlanCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Build my own plan', style: AppTypography.cardTitle()),
                  const SizedBox(height: 2),
                  Text(
                    'From your targets, in your food',
                    style: AppTypography.meta(color: AppColors.placeholder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.placeholder,
            ),
          ],
        ),
      ),
    );
  }
}
