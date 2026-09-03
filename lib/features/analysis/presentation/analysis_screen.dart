import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/hero_card.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/providers.dart';
import '../../app/presentation/widgets/bottom_nav.dart';
import '../../app/presentation/widgets/segmented_tabs.dart';
import 'analysis_controller.dart';
import 'widgets/analysis_charts.dart';
import 'widgets/analysis_extras.dart';

/// Analysis — Figma frame `26_Analysis` (2002:1262).
///
/// Both charts are drawn from the diary now; the artboard's two rasters are no
/// longer used. See `widgets/analysis_charts.dart` for where the drawn versions
/// depart from the exports and why.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, this.onNavSelected});

  final ValueChanged<AppTab>? onNavSelected;

  /// Taller than the 926 artboard so the screen scrolls.
  ///
  /// The Macro Distribution card ends at y=863 and the floating tab bar covers
  /// 806-872, so on the artboard the percentages sit *behind* the bar. That is
  /// invisible in the design, where the card is a raster of mock numbers, and
  /// obvious the moment it holds figures someone needs to read. Giving the
  /// canvas room to scroll lets the card clear the bar, which is the same
  /// treatment Home already uses for its Diet Plan section.
  static const double _gap = 20;

  /// The two cards the artboard has no room for, below the ones it does.
  static const double _consistencyTop =
      _macroCardTop + MacroDistributionCard.height + _gap;
  static const double _habitsTop =
      _consistencyTop + ConsistencyCard.reserve + _gap;

  static const double contentHeight =
      _habitsTop + HabitsCard.reserve + AppBottomNav.clearance;

  /// Where the Macro Distribution card starts — the lowest thing on the screen.
  static const double _macroCardTop = 665;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(analysisSummaryProvider).value ??
        AnalysisSummary.empty(period, ref.watch(targetsProvider));

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
              height: contentHeight,
              children: [
                Positioned(
                  left: 20,
                  top: 71,
                  width: 300,
                  height: 36,
                  child: Text('Analysis', style: AppTypography.topBarTitle()),
                ),
                Positioned(
                  left: 20,
                  top: 143,
                  width: 388,
                  height: 128,
                  child: HeroCard(
                    colour: AppColors.accentGreen,
                    ink: AppColors.white,
                    title: 'Your Nutrition Analysis',
                    body: summary.isEmpty
                        ? 'Track trends. Spot patterns. Crush your goals.'
                        : '${summary.averageCalories.round()} kcal a day '
                            'across ${summary.loggedDays} logged '
                            '${summary.loggedDays == 1 ? "day" : "days"}.',
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 295,
                  width: 388,
                  height: SegmentedTabs.height,
                  child: SegmentedTabs(
                    labels: [
                      for (final p in AnalysisPeriod.values) p.label,
                    ],
                    selected: period.index,
                    onChanged: (i) => ref
                        .read(analysisPeriodProvider.notifier)
                        .select(AnalysisPeriod.values[i]),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 368,
                  width: CalorieTrendsCard.width,
                  height: CalorieTrendsCard.height,
                  child: CalorieTrendsCard(summary: summary),
                ),
                Positioned(
                  left: 20,
                  top: _macroCardTop,
                  width: MacroDistributionCard.width,
                  height: MacroDistributionCard.height,
                  child: MacroDistributionCard(summary: summary),
                ),

                // Not on the artboard. The design has three cards and no way
                // to answer "is any of this a full picture" or "where does my
                // day actually go" — both of which the diary already knew.
                Positioned(
                  left: 20,
                  top: _consistencyTop,
                  width: ConsistencyCard.width,
                  child: ConsistencyCard(summary: summary),
                ),
                Positioned(
                  left: 20,
                  top: _habitsTop,
                  width: HabitsCard.width,
                  child: HabitsCard(summary: summary),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 926 - AppBottomNav.top - AppBottomNav.height,
              child: Center(
                child: AppBottomNav(
                  current: AppTab.analysis,
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
