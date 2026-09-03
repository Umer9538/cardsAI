import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';

/// The planner on `BACKEND=local`, where there is no model to call.
///
/// It builds a real plan rather than returning a canned one: the catalogue plan
/// closest to the user's own macro split, rescaled to their calories. That is
/// not what the AI planner does, but it is honest — the day it returns is food
/// that adds up to the right numbers — and it keeps the whole flow walkable
/// with no network, which is what this backend is for.
class LocalPlannerRepository implements PlannerRepository {
  LocalPlannerRepository(this._diets, this._targets);

  /// Read through the repository rather than a provider's cached value: the
  /// planner may be the first thing to ask for the catalogue, and a cache
  /// nobody has warmed is empty.
  final DietRepository _diets;
  final Nutrition Function() _targets;

  static const _uuid = Uuid();

  @override
  Future<DietPlan> generate({String? notes}) async {
    // The wait is deliberate: the real planner takes several seconds and the
    // UI's progress state has to be exercised somewhere.
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    final targets = _targets();
    final catalogue =
        (await _diets.watchAll().first).where((p) => p.day.isNotEmpty).toList();
    if (catalogue.isEmpty || targets.calories <= 0) {
      throw const RepositoryException(
        'Answer a few questions about yourself first, so the plan has a '
        'target to hit.',
        code: 'failed-precondition',
      );
    }

    final closest = catalogue.reduce(
      (a, b) => _distance(a, targets) <= _distance(b, targets) ? a : b,
    );
    final scaled = closest.scaledTo(targets);

    return scaled.copyWith(
      id: 'plan-mine-${_uuid.v4()}',
      name: 'Your ${closest.name}',
      description: 'Built from your targets. ${closest.description}',
      isMine: true,
    );
  }

  /// How far a plan's macro split is from the user's, in share-of-energy terms
  /// rather than grams — grams would just pick whichever plan is largest.
  static double _distance(DietPlan plan, Nutrition targets) {
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
