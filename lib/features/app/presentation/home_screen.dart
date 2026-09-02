import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/calorie_gauge.dart';
import 'widgets/meal_card.dart';
import 'widgets/meal_sheet.dart';

/// Home — Figma frame `23_Home` (2002:1388).
///
/// The first screen whose content runs past the artboard: the Diet Plan
/// section ends at y=1109 against a 926 frame, so the artboard shows it cut
/// off. It is therefore built on a 1109-tall canvas that scrolls, with the tab
/// bar floating over it rather than scrolling away.
///
/// Every figure here is now derived from the diary. The artboard's own numbers
/// were mock values and not self-consistent — 1672 kcal remaining of a 2000
/// goal is 328 consumed, which cannot also be 140g of carbs and 60g of protein
/// (that is 800 kcal on its own). A render diff against that artboard will
/// therefore differ in the numbers, and should.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onTabSelected,
    this.onPremium,
    this.onNotifications,
  });

  final ValueChanged<AppTab>? onTabSelected;
  final VoidCallback? onPremium;
  final VoidCallback? onNotifications;

  /// Bottom edge of the two macro cards: they sit at y=574 and are 173 tall.
  static const double _macroCardsBottom = 747;

  /// A slim row carrying the two figures the artboard has no card for.
  ///
  /// Fat is in the target and in every scan and appeared nowhere on this
  /// screen; fibre is the second most-requested number in this category and had
  /// been computed and discarded since the pipeline was built. Neither warrants
  /// a 173pt card, and there is a 24pt gap under the two that do.
  static const double _extrasTop = _macroCardsBottom + 6;
  static const double _extrasHeight = 22;

  /// Everything below the macro cards moves down by the row's height.
  static const double _extrasShift = _extrasHeight + 8;

  /// Where the artboard puts the Diet Plan heading, before the meals list is
  /// inserted above it.
  static const double _dietPlanTop = 771 + _extrasShift;

  /// Top of the meals section, immediately below the two macro cards.
  static const double _mealsTop = 771 + _extrasShift;

  static const double _mealGap = 12;
  static const double _sectionTitleHeight = 48;

  /// Height the meals section takes for [count] meals, including its heading.
  ///
  /// A day with nothing logged still shows its heading and a line explaining
  /// how to change that — an empty diary is the state most people see first,
  /// and a blank gap explains nothing.
  static double _mealsHeight(int count) {
    if (count == 0) return _sectionTitleHeight + 44;
    return _sectionTitleHeight +
        count * MealCard.height +
        (count - 1) * _mealGap;
  }

  /// Full height of the content, which grows with the day's meals.
  ///
  /// The artboard's own content ends at 1109, with the diet card's macro row
  /// flush against it. The floating tab bar is pinned to the viewport rather
  /// than to this canvas, so without trailing room that row can never be
  /// scrolled out from under it — see [AppBottomNav.clearance]. That part is
  /// not design.
  static double contentHeightFor(int mealCount) =>
      1109 +
      _extrasShift +
      _mealsHeight(mealCount) +
      24 +
      AppBottomNav.clearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(dailyLogProvider);
    final profile = ref.watch(profileProvider).value;
    final plan = _featuredPlan(ref);

    final meals = log.meals;
    // Everything below the meals section shifts down by whatever it occupies.
    final shift = _mealsHeight(meals.length) + 24;

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
              height: contentHeightFor(meals.length),
              children: [
                _Header(
                  profile: profile,
                  onPremium: onPremium,
                  onNotifications: onNotifications,
                ),
                _CalendarCard(
                  selected: ref.watch(selectedDateProvider),
                  onSelect: (date) =>
                      ref.read(selectedDateProvider.notifier).select(date),
                ),
                _StreakChip(streak: ref.watch(streakProvider).value ?? 0),
                const _SectionTitle(
                  text: 'Count Your Daily Calories',
                  top: 269,
                ),
                _CaloriesCard(log: log),
                _MacroCard(
                  left: 20,
                  colour: AppColors.planYellow,
                  label: 'Carbs',
                  consumed: log.consumed.carbs,
                  target: log.targets.carbs,
                ),
                _MacroCard(
                  left: 224,
                  colour: AppColors.accentGreen,
                  label: 'Protein',
                  consumed: log.consumed.protein,
                  target: log.targets.protein,
                ),
                _SecondaryMacros(
                  top: _extrasTop,
                  height: _extrasHeight,
                  consumed: log.consumed,
                  targets: log.targets,
                ),
                _MealsSection(
                  top: _mealsTop,
                  date: log.date,
                  meals: meals,
                  onTap: (meal) => showMealSheet(context, ref, meal),
                  onDelete: (meal) => _confirmDelete(context, ref, meal),
                ),
                _SectionTitle(text: 'Diet Plan', top: _dietPlanTop + shift),
                if (plan != null) _DietCard(plan: plan, top: 827 + shift),
              ],
            ),
            // Floats above the scrolling content, pinned to the viewport.
            Positioned(
              left: 0,
              right: 0,
              bottom: 926 - AppBottomNav.top - AppBottomNav.height,
              child: Center(
                child: AppBottomNav(
                  current: AppTab.home,
                  onSelect: onTabSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Deleting a meal changes the day's totals, so it is confirmed rather than
  /// done on a long press alone.
  void _confirmDelete(BuildContext context, WidgetRef ref, Meal meal) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: DesignCanvas(
          background: Colors.transparent,
          children: [
            ConfirmDialog(
              title: 'Remove this meal?',
              body: '${meal.name} will be taken off '
                  '${_isToday(meal.day) ? "today's" : "that day's"} total.',
              secondaryLabel: 'Keep',
              primaryLabel: 'Remove',
              onSecondary: () => Navigator.of(dialogContext).pop(),
              onPrimary: () {
                Navigator.of(dialogContext).pop();
                ref.read(diaryRepositoryProvider).deleteMeal(meal.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day == DateTime(now.year, now.month, now.day);
  }

  /// The plan to feature: one the user has saved, else one that matches how
  /// they said they eat, else the first in the catalogue.
  ///
  /// The diet preference the quiz collects is spent here. It is a small thing,
  /// but it is the difference between asking a question and using the answer —
  /// someone who said "keto" should not be shown a vegan plan on their first
  /// screen.
  DietPlan? _featuredPlan(WidgetRef ref) {
    final mine = ref.watch(myDietsProvider).value ?? const [];
    if (mine.isNotEmpty) return mine.first;

    final all = ref.watch(allDietsProvider).value ?? const [];
    if (all.isEmpty) return null;

    final match = ref.watch(profileProvider).value?.dietPreference?.planMatch;
    if (match != null) {
      for (final plan in all) {
        if (plan.name.toLowerCase().contains(match)) return plan;
      }
    }
    return all.first;
  }
}

class _Header extends StatelessWidget {
  const _Header({this.profile, this.onPremium, this.onNotifications});

  final UserProfile? profile;
  final VoidCallback? onPremium;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DesignImage(
          asset: profile?.avatar ?? 'assets/images/app/avatar.png',
          left: 20,
          top: 71,
          width: 40,
          height: 40,
        ),
        const Positioned(
          left: 72,
          top: 80,
          width: 240,
          height: 22,
          child: _Greeting(),
        ),
        _OutlineIconButton(
          left: 316,
          icon: 'assets/images/app/icon_crown.png',
          onTap: onPremium,
        ),
        _OutlineIconButton(
          left: 368,
          icon: 'assets/images/app/icon_bell.png',
          onTap: onNotifications,
        ),
      ],
    );
  }
}

/// The artboard reads "Good Morning" because it was drawn in the morning. The
/// greeting follows the clock; the boundaries are the conventional ones.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    return Text(greeting, style: AppTypography.label());
  }
}

/// 40pt disc with a 1pt #232220 outline and a 20pt glyph — the crown and bell
/// affordances in the header.
class _OutlineIconButton extends StatelessWidget {
  const _OutlineIconButton({
    required this.left,
    required this.icon,
    this.onTap,
  });

  final double left;
  final String icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 71,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.inkMuted),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            icon,
            width: 20,
            height: 20,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.top});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: top,
      width: 388,
      height: 36,
      child: Text(text, style: AppTypography.topBarTitle()),
    );
  }
}

/// The week around [selected], Monday first, on a white card. The selected day
/// gets a lilac pill and a dark disc behind its date; days after today are
/// dimmed to #474747.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.selected, this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime>? onSelect;

  static const List<String> _names = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday is 1..7 with Monday at 1, so this lands on the Monday of
    // the selected week without a special case for Sunday.
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Positioned(
      left: 20,
      top: 135,
      width: 388,
      height: 110,
      child: GestureDetector(
        // Swipe the card to change week — the app's only way back into
        // history, and the gesture people already try on a week strip.
        // Constants, not the drag distance: a week per swipe, either way.
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 100) return;
          final step = velocity > 0 ? -7 : 7;
          final target = selected.add(Duration(days: step));
          // There is nothing to see in the future; the diary only goes back.
          if (target.isAfter(today)) {
            onSelect?.call(today);
          } else {
            onSelect?.call(target);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Builder(
                  builder: (context) {
                    final date = monday.add(Duration(days: i));
                    return _DayColumn(
                      day: _names[i],
                      date: date.day.toString().padLeft(2, '0'),
                      selected: date == selected,
                      // A future day has nothing logged against it yet.
                      dimmed: date.isAfter(today),
                      onTap: () => onSelect?.call(date),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logging streak, beside the greeting.
///
/// Computed by `streakProvider` since the diary existed and shown nowhere,
/// which wasted the one number in the app that actually pulls people back. The
/// design has no slot for it, so it takes the empty run between the greeting
/// and the crown, and disappears entirely below two days — "1 day streak" is a
/// nag, not an achievement.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    if (streak < 2) return const SizedBox.shrink();

    return Positioned(
      left: 72,
      top: 104,
      width: 240,
      height: 22,
      child: Text(
        '$streak day streak',
        style: AppTypography.meta(color: AppColors.accentGreen),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.date,
    required this.selected,
    required this.dimmed,
    this.onTap,
  });

  final String day;
  final String date;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colour = dimmed ? AppColors.muted : AppColors.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: selected
          ? Container(
              width: 44,
              height: 79,
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(50),
              ),
              // Vertical only. The artboard's 8pt inset all round leaves 28pt
              // for the day label, which is enough for the "Thu" it happened to
              // be drawn on but not for "Wed" — that wrapped to two lines and
              // overflowed the pill. Children are centred anyway, so dropping
              // the horizontal inset changes nothing else.
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    day,
                    style: AppTypography.label(color: AppColors.ink),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  const SizedBox(height: 13),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(date, style: AppTypography.label()),
                  ),
                ],
              ),
            )
          : SizedBox(
              width: 44,
              height: 60,
              child: Column(
                children: [
                  Text(day, style: AppTypography.label(color: colour)),
                  const SizedBox(height: 16),
                  Text(date, style: AppTypography.label(color: colour)),
                ],
              ),
            ),
    );
  }
}

/// Calorie ring on a lilac card.
///
/// The gauge is drawn by [CalorieGauge] rather than placed as the artboard's
/// raster — see that class for why. Its box is the raster's, so the position
/// below is still the export's bounds (its own, minus the glow) rather than the
/// node's (125, 387).
class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({required this.log});

  final DailyLog log;

  @override
  Widget build(BuildContext context) {
    // Negative once the goal is passed. The artboard has no over-budget state,
    // so it reads as "Over" with the overage as a positive number.
    final remaining = log.caloriesRemaining;
    final over = remaining < 0;

    return Positioned(
      left: 20,
      top: 325,
      width: 388,
      height: 229,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.lilac,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 14,
            child: Text(
              'Calories',
              style: AppTypography.sectionTitle(color: AppColors.ink),
            ),
          ),
          // Offsets below are artboard coordinates minus the card origin.
          Positioned(
            left: 104.67 - 20,
            top: 366.93 - 325,
            child: CalorieGauge(progress: log.calorieProgress),
          ),
          Positioned(
            left: 176.6 - 20,
            top: 447.6 - 325,
            width: 73.1,
            child: Column(
              children: [
                Text(
                  remaining.abs().round().toString(),
                  style: AppTypography.planPrice().copyWith(
                    fontSize: 23.07,
                    height: 34.61 / 23.07,
                  ),
                ),
                Text(
                  over ? 'Over' : 'Left',
                  style: AppTypography.body(
                    color: AppColors.ink,
                  ).copyWith(fontSize: 14.42, height: 21.15 / 14.42),
                ),
              ],
            ),
          ),
          Positioned(
            left: 133.3 - 20,
            top: 480.2 - 325,
            child: Text(
              '0',
              style: AppTypography.meta(
                color: AppColors.ink,
              ).copyWith(fontSize: 12.5, height: 18.26 / 12.5),
            ),
          ),
          Positioned(
            left: 277.5 - 20,
            top: 480.2 - 325,
            child: Text(
              NutritionFormat.calories(log.targets.calories).split(' ').first,
              style: AppTypography.meta(
                color: AppColors.ink,
              ).copyWith(fontSize: 12.5, height: 18.26 / 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// The selected day's meals — the diary, which the design has no screen for.
///
/// Without it the app can log a meal and never show it again, and tapping a day
/// in the calendar changes nothing you can see. It sits between the macro cards
/// and Diet Plan, and everything below it shifts down by its height.
class _MealsSection extends StatelessWidget {
  const _MealsSection({
    required this.top,
    required this.date,
    required this.meals,
    this.onTap,
    this.onDelete,
  });

  final double top;
  final DateTime date;
  final List<Meal> meals;
  final ValueChanged<Meal>? onTap;
  final ValueChanged<Meal>? onDelete;

  static final DateFormat _heading = DateFormat('EEEE d MMMM');

  String get _title {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _heading.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: top,
      width: 388,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: HomeScreen._sectionTitleHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(_title, style: AppTypography.topBarTitle()),
            ),
          ),
          if (meals.isEmpty)
            SizedBox(
              height: 44,
              child: Text(
                'Nothing logged yet. Tap the scan button to add a meal.',
                style: AppTypography.socialLabel(color: AppColors.placeholder),
              ),
            )
          else
            for (final (i, meal) in meals.indexed) ...[
              if (i > 0) const SizedBox(height: HomeScreen._mealGap),
              MealCard(
                meal: meal,
                onTap: onTap == null ? null : () => onTap!(meal),
                onDelete: onDelete == null ? null : () => onDelete!(meal),
              ),
            ],
        ],
      ),
    );
  }
}

/// Fat and fibre, on one line under the two macro cards.
///
/// Deliberately a line rather than two more cards. Fat is the macro the
/// artboard leaves out, and fibre is the number people ask for most after
/// health-app sync — almost always phrased as "put it on the home screen"
/// rather than "give me the micronutrients". Both are already computed; neither
/// is important enough to compete with calories for attention.
class _SecondaryMacros extends StatelessWidget {
  const _SecondaryMacros({
    required this.top,
    required this.height,
    required this.consumed,
    required this.targets,
  });

  final double top;
  final double height;
  final Nutrition consumed;
  final Nutrition targets;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: top,
      width: 388,
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _Pair(
              label: 'Fat',
              consumed: consumed.fat,
              target: targets.fat,
            ),
          ),
          const SizedBox(
            width: 1,
            height: 14,
            child: ColoredBox(color: AppColors.muted),
          ),
          Expanded(
            child: _Pair(
              label: 'Fibre',
              consumed: consumed.fiber,
              target: targets.fiber,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.consumed,
    required this.target,
  });

  final String label;
  final double consumed;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        target <= 0
            ? '$label ${NutritionFormat.grams(consumed)}'
            : '$label ${NutritionFormat.grams(consumed)}'
                ' / ${NutritionFormat.grams(target)}',
        style: AppTypography.meta(color: AppColors.placeholder),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// One of the two half-width macro cards below the calorie ring.
class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.left,
    required this.colour,
    required this.label,
    required this.consumed,
    required this.target,
  });

  final double left;
  final Color colour;
  final String label;
  final double consumed;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 574,
      width: 184,
      height: 173,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 84,
            child: Text(
              label,
              style: AppTypography.sectionTitle(color: AppColors.ink),
            ),
          ),
          Positioned(
            left: 16,
            top: 126,
            child: MacroBar(
              progress: target <= 0 ? 0 : consumed / target,
              consumed: NutritionFormat.grams(consumed),
              target: NutritionFormat.grams(target),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diet plan card: a 220pt image over a title and a divided macro row.
class _DietCard extends StatelessWidget {
  const _DietCard({required this.plan, required this.top});

  final DietPlan plan;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      top: top,
      width: 388,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              plan.image,
              width: 388,
              height: 220,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
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

/// The divided macro row under a diet or food card: four figures separated by
/// 1pt rules. Shared by the diet cards and the scan result.
class NutritionRow extends StatelessWidget {
  const NutritionRow({
    super.key,
    required this.nutrition,
    this.colour = AppColors.outline,
  });

  final Nutrition nutrition;

  /// The rule colour. #2F2F2F on diet cards, #474747 inside a food item.
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, item) in NutritionFormat.macroRow(nutrition).indexed) ...[
          if (i > 0) ...[
            const SizedBox(width: 8),
            SizedBox(width: 1, height: 16, child: ColoredBox(color: colour)),
            const SizedBox(width: 8),
          ],
          Text(item, style: AppTypography.meta()),
        ],
      ],
    );
  }
}
