import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/nutrition/avoidance_check.dart';
import '../../core/repositories/repositories.dart';

/// The planner on `BACKEND=local`, where there is no model to call.
///
/// It builds a real plan rather than returning a canned one: the catalogue plan
/// closest to the user's own macro split, rescaled to their calories. That is
/// not what the AI planner does, but it is honest — the day it returns is food
/// that adds up to the right numbers — and it keeps the whole flow walkable
/// with no network, which is what this backend is for.
///
/// It honours the taste quiz as far as a catalogue can. Avoidances are the
/// part that matters — a plan naming cheese after someone said "no dairy" is
/// the same failure offline as it is on the server — so those are enforced
/// with [AvoidanceCheck], the same matcher the Worker's `violations()` mirrors.
/// Cook time is a preference, so it only breaks ties. Liked dishes and
/// leanings are carried on the plan as `builtFor` chips but cannot steer
/// eight fixed plans.
class LocalPlannerRepository implements PlannerRepository {
  LocalPlannerRepository(this._diets, this._targets, {String? Function()? purpose})
      : _purpose = purpose ?? (() => null);

  /// Read through the repository rather than a provider's cached value: the
  /// planner may be the first thing to ask for the catalogue, and a cache
  /// nobody has warmed is empty.
  final DietRepository _diets;
  final Nutrition Function() _targets;

  /// `PlanPurpose.of(profile)?.label` — what the day is for. The catalogue
  /// cannot be steered by it, but the plan carries it, leading `builtFor`
  /// exactly as the Worker's plans do.
  final String? Function() _purpose;

  static const _uuid = Uuid();

  /// Every plan this planner writes carries this prefix, and it is what keeps
  /// them out of the pool: `watchAll` returns the user's generated plans
  /// alongside the catalogue, so without the filter the second build would
  /// compose from the first and come back as "Your Your Vegan Vitality".
  /// `isMine` is not the test — a catalogue plan added to My Diets carries it
  /// too, and that one is still fair to build from.
  static const String idPrefix = 'plan-mine-';

  /// Plans this close to the best split are interchangeable on macros, so a
  /// second criterion may choose between them.
  @visibleForTesting
  static const double tieBand = 0.05;

  @override
  Future<DietPlan> generate({TasteProfile? taste, String? notes}) async {
    // The wait is deliberate: the real planner takes several seconds and the
    // UI's progress state has to be exercised somewhere.
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    final targets = _targets();
    final catalogue = (await _diets.watchAll().first)
        .where((p) => p.day.isNotEmpty && !p.id.startsWith(idPrefix))
        .toList();
    if (catalogue.isEmpty || targets.calories <= 0) {
      throw const RepositoryException(
        'Answer a few questions about yourself first, so the plan has a '
        'target to hit.',
        code: 'failed-precondition',
      );
    }

    final avoid = taste?.avoid ?? const <Avoidance>{};

    // A plan that names something the person excluded is out before the
    // macro arithmetic looks at it. Only if *every* plan is out does the
    // closest one come back with the offending foods stripped — on the
    // offline backend a smaller plan beats a refusal.
    final clean = catalogue.where((p) => !violates(p, avoid)).toList();
    final stripped = clean.isEmpty;
    final pool = stripped ? catalogue : clean;

    final closest = pool.reduce(
      (a, b) => distance(a, targets) <= distance(b, targets) ? a : b,
    );

    // With no time to cook, the plan with the fewest things per meal is the
    // one that gets eaten. Only among plans that are already as good a fit on
    // macros, though: prep is a proxy and the split is the target.
    var chosen = closest;
    final cookTime = taste?.cookTime;
    if (cookTime == CookTime.eatingOut || cookTime == CookTime.under15) {
      final best = distance(closest, targets);
      final near = pool.where((p) => distance(p, targets) - best <= tieBand);
      // Fewest things per meal, and on a tie the closer split — otherwise a
      // tie fell to catalogue order, which let a worse fit win on a criterion
      // that did not distinguish them.
      chosen = near.reduce((a, b) {
        final ia = itemsPerMeal(a), ib = itemsPerMeal(b);
        if (ia != ib) return ia < ib ? a : b;
        return distance(a, targets) <= distance(b, targets) ? a : b;
      });
    }

    final day = stripped ? strip(chosen.day, avoid) : chosen.day;
    final scaled = chosen.scaledTo(targets);
    final purpose = _purpose()?.trim();

    return scaled.copyWith(
      id: '$idPrefix${_uuid.v4()}',
      name: 'Your ${chosen.name}',
      description: 'Built from your targets. ${chosen.description}',
      day: day,
      isMine: true,
      // The purpose first, then the taste: "Built for you" should lead with
      // what the day is for before saying what is in it.
      builtFor: [
        if (purpose != null && purpose.isNotEmpty) purpose,
        ...?taste?.summary,
      ],
    );
  }

  /// How much is on the plate, on average — the cook-time tie-break.
  static double itemsPerMeal(DietPlan plan) =>
      plan.day.fold<int>(0, (n, m) => n + m.items.length) / plan.day.length;

  /// Whether anything on the plan's day — a meal's title as much as an item's
  /// name — names something in [avoid].
  ///
  /// Titles too, because a title is what "Log this meal" writes into the
  /// diary. Scanning names alone let the Vegan day through under "No dairy"
  /// with its breakfast still called "Oats with soy milk and peanut butter";
  /// that is safe under the shared matcher, but the class of miss was not.
  static bool violates(DietPlan plan, Set<Avoidance> avoid) =>
      avoid.isNotEmpty &&
      AvoidanceCheck.violations(_texts(plan.day), avoid).isNotEmpty;

  /// The day without the offending foods.
  ///
  /// An item whose name hits is dropped. A meal left with nothing in it is
  /// dropped rather than shown empty. A meal whose *title* hits keeps its
  /// surviving items and is renamed after them — the portion suffix ("Oats,
  /// 80 g dry") stripped, because a title is a dish and not a shopping list.
  static List<PlannedMeal> strip(List<PlannedMeal> day, Set<Avoidance> avoid) {
    bool hits(String text) =>
        AvoidanceCheck.violations([text], avoid).isNotEmpty;

    return [
      for (final meal in day)
        if (meal.items.where((i) => !hits(i.name)).toList() case final kept
            when kept.isNotEmpty)
          PlannedMeal(
            slot: meal.slot,
            title: hits(meal.title)
                ? kept.map((i) => i.name.split(',').first.trim()).join(', ')
                : meal.title,
            items: kept,
          ),
    ];
  }

  static Iterable<String> _texts(List<PlannedMeal> day) sync* {
    for (final meal in day) {
      yield meal.title;
      for (final item in meal.items) {
        yield item.name;
      }
    }
  }

  /// How far a plan's macro split is from the user's, in share-of-energy terms
  /// rather than grams — grams would just pick whichever plan is largest.
  @visibleForTesting
  static double distance(DietPlan plan, Nutrition targets) {
    ({double p, double c, double f}) share(Nutrition n) {
      final energy = n.protein * 4 + n.carbs * 4 + n.fat * 9;
      if (energy <= 0) return (p: 0, c: 0, f: 0);
      return (
        p: n.protein * 4 / energy,
        c: n.carbs * 4 / energy,
        f: n.fat * 9 / energy,
      );
    }

    final a = share(plan.nutrition);
    final b = share(targets);
    return (a.p - b.p).abs() + (a.c - b.c).abs() + (a.f - b.f).abs();
  }
}
