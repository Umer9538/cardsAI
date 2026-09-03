import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';

/// The three tabs on the Analysis screen.
enum AnalysisPeriod {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  const AnalysisPeriod(this.label);
  final String label;
}

/// One plotted point: a bucket of days and what was eaten across them.
@immutable
class AnalysisPoint {
  const AnalysisPoint({
    required this.label,
    required this.calories,
    required this.days,
  });

  /// The x-axis caption — "Mon", "W32", "Aug".
  final String label;

  /// Average calories per *day* in the bucket, so a part-week is not compared
  /// against a full one.
  final double calories;

  /// Days in the bucket that had anything logged. Zero means no bar, not a
  /// zero-calorie day — the difference matters for the averages below.
  final int days;
}

/// Everything the Analysis screen draws, for one period.
@immutable
class AnalysisSummary {
  const AnalysisSummary({
    required this.period,
    required this.points,
    required this.total,
    required this.targets,
    required this.loggedDays,
    required this.daysUnderGoal,
    required this.daysOverBudget,
    this.windowDays = 0,
    this.daysLoggedTwice = 0,
    this.bySlot = const {},
    this.bySource = const {},
  });

  final AnalysisPeriod period;

  /// Always seven points, so the chart's geometry is identical on every tab.
  final List<AnalysisPoint> points;

  /// Everything eaten in the window.
  final Nutrition total;
  final Nutrition targets;

  final int loggedDays;
  final int daysUnderGoal;

  /// Days over the calorie goal by more than [overBudgetThreshold].
  final int daysOverBudget;

  static const double overBudgetThreshold = 200;

  /// Calendar days the window covers, logged or not. The denominator for
  /// consistency — [loggedDays] alone cannot say what was missed.
  final int windowDays;

  /// Days with **at least two eating occasions** logged.
  ///
  /// This specific definition is the app's north star, not an arbitrary one.
  /// Turner-McGrievy's pooled RCTs found it the best adherence predictor of
  /// six-month weight loss, beating every alternative tested — and "Log Often,
  /// Lose More" found successful losers spent no more time logging, they simply
  /// logged more often. Frequency beats richness, so this is the number the
  /// screen should show and the one the product should optimise.
  final int daysLoggedTwice;

  /// Energy by meal, so "where does my day actually go" has an answer.
  final Map<MealSlot, double> bySlot;

  /// How each food got into the diary.
  ///
  /// Also the wedge test: text logging is meant to be the habit the app is
  /// built around, and if it is a small share of entries then the describe path
  /// is not landing in the UI, whatever its merits.
  final Map<FoodSource, int> bySource;

  static AnalysisSummary empty(AnalysisPeriod period, Nutrition targets) =>
      AnalysisSummary(
        period: period,
        points: const [],
        total: Nutrition.zero,
        targets: targets,
        loggedDays: 0,
        daysUnderGoal: 0,
        daysOverBudget: 0,
      );

  bool get isEmpty => loggedDays == 0;

  /// Share of the window's days that carried two or more eating occasions.
  double get consistency =>
      windowDays == 0 ? 0 : daysLoggedTwice / windowDays;

  /// The plain read on consistency. Descriptive, never scolding — this is the
  /// number most likely to be low, and a tracker that tells people off for
  /// missing days is the tracker they delete.
  String get consistencyInsight {
    if (windowDays == 0) return '';
    if (daysLoggedTwice == 0) return 'No days with a full picture yet.';
    if (consistency >= 0.75) {
      return 'Most days have a full picture. That is what makes the numbers '
          'worth reading.';
    }
    if (consistency >= 0.4) return 'A good half of the window is covered.';
    return 'Most days are missing meals, so the averages above run low.';
  }

  /// Energy split across meals, largest first, ignoring empty slots.
  List<({MealSlot slot, double calories, double share})> get slotBreakdown {
    final energy = bySlot.values.fold(0.0, (a, b) => a + b);
    if (energy <= 0) return const [];
    final rows = [
      for (final entry in bySlot.entries)
        if (entry.value > 0)
          (
            slot: entry.key,
            calories: entry.value,
            share: entry.value / energy,
          ),
    ]..sort((a, b) => b.calories.compareTo(a.calories));
    return rows;
  }

  /// How foods were logged, most used first.
  List<({FoodSource source, int count, double share})> get methodBreakdown {
    final total = bySource.values.fold(0, (a, b) => a + b);
    if (total == 0) return const [];
    final rows = [
      for (final entry in bySource.entries)
        if (entry.value > 0)
          (
            source: entry.key,
            count: entry.value,
            share: entry.value / total,
          ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return rows;
  }

  /// Fibre against its goal, or null when there is no goal to compare to.
  double? get fibreShare {
    if (targets.fiber <= 0 || loggedDays == 0) return null;
    return (total.fiber / loggedDays) / targets.fiber;
  }

  /// Mean calories across days that were actually logged. Averaging over the
  /// whole window instead would read as a collapse whenever someone skips a day.
  double get averageCalories =>
      loggedDays == 0 ? 0 : total.calories / loggedDays;

  /// Share of energy from each macro, by the Atwater factors — 4 kcal/g for
  /// protein and carbohydrate, 9 for fat.
  ///
  /// Derived from the macros rather than from [Nutrition.calories]: the two
  /// disagree slightly for most foods, and a distribution that does not sum to
  /// 100% looks broken.
  ({double fat, double carbs, double protein}) get macroShare {
    final fat = total.fat * 9;
    final carbs = total.carbs * 4;
    final protein = total.protein * 4;
    final energy = fat + carbs + protein;
    if (energy <= 0) return (fat: 0, carbs: 0, protein: 0);
    return (fat: fat / energy, carbs: carbs / energy, protein: protein / energy);
  }

  /// The one-line read under the Macro Distribution heading.
  ///
  /// Deliberately descriptive, never prescriptive — it reports what the numbers
  /// say and does not tell anyone what to eat.
  String get macroInsight {
    if (isEmpty) return 'Log a few meals to see your split.';

    final share = macroShare;
    final targetEnergy = targets.protein * 4 +
        targets.carbs * 4 +
        targets.fat * 9;
    if (targetEnergy <= 0) return 'Your macro split across this period.';

    final proteinTarget = targets.protein * 4 / targetEnergy;
    final fatTarget = targets.fat * 9 / targetEnergy;

    if (share.protein < proteinTarget - 0.05) {
      return 'You’re consistently low on protein.';
    }
    if (share.fat > fatTarget + 0.08) {
      return 'Fat is running higher than your plan.';
    }
    return 'Your split is close to your plan.';
  }
}

/// Which tab the Analysis screen is on.
class AnalysisPeriodNotifier extends Notifier<AnalysisPeriod> {
  @override
  AnalysisPeriod build() => AnalysisPeriod.daily;

  void select(AnalysisPeriod period) => state = period;
}

final analysisPeriodProvider =
    NotifierProvider<AnalysisPeriodNotifier, AnalysisPeriod>(
  AnalysisPeriodNotifier.new,
);

/// Buckets the diary into the seven points the chart draws.
final analysisSummaryProvider = FutureProvider<AnalysisSummary>((ref) async {
  final period = ref.watch(analysisPeriodProvider);
  final targets = ref.watch(targetsProvider);

  // Recompute whenever today's meals change, which is the only way the diary
  // moves while this screen is open.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  ref.watch(dayMealsProvider(today));

  final repository = ref.watch(diaryRepositoryProvider);

  // Seven buckets, oldest first, each a half-open [start, end) day range.
  final buckets = <({String label, DateTime start, DateTime end})>[];
  switch (period) {
    case AnalysisPeriod.daily:
      // The current week, Monday first — matching the artboard's Mon..Sun axis.
      final monday = today.subtract(Duration(days: today.weekday - 1));
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        buckets.add((
          label: DateFormat('E').format(day).substring(0, 3),
          start: day,
          end: day.add(const Duration(days: 1)),
        ));
      }
    case AnalysisPeriod.weekly:
      final thisMonday = today.subtract(Duration(days: today.weekday - 1));
      for (var i = 6; i >= 0; i--) {
        final start = thisMonday.subtract(Duration(days: 7 * i));
        buckets.add((
          label: DateFormat('d/M').format(start),
          start: start,
          end: start.add(const Duration(days: 7)),
        ));
      }
    case AnalysisPeriod.monthly:
      for (var i = 6; i >= 0; i--) {
        // Month arithmetic via DateTime's own normalisation: month 0 rolls back
        // to December of the previous year without a special case.
        final start = DateTime(today.year, today.month - i, 1);
        buckets.add((
          label: DateFormat('MMM').format(start),
          start: start,
          end: DateTime(start.year, start.month + 1, 1),
        ));
      }
  }

  final meals = await repository.mealsBetween(
    buckets.first.start,
    buckets.last.end.subtract(const Duration(days: 1)),
  );

  // Total per calendar day once, then roll days up into buckets.
  final byDay = <DateTime, Nutrition>{};
  for (final meal in meals) {
    byDay.update(
      meal.day,
      (n) => n + meal.nutrition,
      ifAbsent: () => meal.nutrition,
    );
  }

  final points = <AnalysisPoint>[];
  var total = Nutrition.zero;
  var loggedDays = 0;
  var under = 0;
  var over = 0;

  for (final bucket in buckets) {
    var bucketTotal = Nutrition.zero;
    var bucketDays = 0;

    for (final entry in byDay.entries) {
      if (entry.key.isBefore(bucket.start) || !entry.key.isBefore(bucket.end)) {
        continue;
      }
      bucketTotal += entry.value;
      bucketDays++;

      if (entry.value.calories < targets.calories) {
        under++;
      } else if (entry.value.calories >
          targets.calories + AnalysisSummary.overBudgetThreshold) {
        over++;
      }
    }

    points.add(
      AnalysisPoint(
        label: bucket.label,
        calories: bucketDays == 0 ? 0 : bucketTotal.calories / bucketDays,
        days: bucketDays,
      ),
    );
    total += bucketTotal;
    loggedDays += bucketDays;
  }

  // Consistency, meal split and logging method are computed from the meals
  // themselves rather than from the day totals, because all three ask about
  // *occasions* and a day total has already thrown those away.
  final occasions = <DateTime, int>{};
  final bySlot = <MealSlot, double>{};
  final bySource = <FoodSource, int>{};

  for (final meal in meals) {
    occasions.update(meal.day, (n) => n + 1, ifAbsent: () => 1);
    bySlot.update(
      meal.slot,
      (v) => v + meal.nutrition.calories,
      ifAbsent: () => meal.nutrition.calories,
    );
    for (final item in meal.items) {
      bySource.update(item.source, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  return AnalysisSummary(
    period: period,
    points: points,
    total: total,
    targets: targets,
    loggedDays: loggedDays,
    daysUnderGoal: under,
    daysOverBudget: over,
    windowDays: buckets.last.end.difference(buckets.first.start).inDays,
    daysLoggedTwice:
        occasions.values.where((count) => count >= 2).length,
    bySlot: bySlot,
    bySource: bySource,
  );
});
