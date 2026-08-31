import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';
import 'seed_data.dart';

/// The plan catalogue plus this user's favourite / saved flags.
///
/// Catalogue and flags live in one record today because both are local. Against
/// Firebase they split: the catalogue is a shared read-only collection and the
/// flags become a per-user subcollection.
class LocalDietRepository implements DietRepository {
  LocalDietRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<List<DietPlan>>.broadcast();

  List<DietPlan> _plans = const [];
  bool _loaded = false;

  void _load() {
    final stored = _store.readList(StoreKeys.plans);
    _plans =
        stored == null ? SeedData.dietPlans : stored.map(DietPlan.fromJson).toList();
    if (stored == null) unawaited(_persist());
    _loaded = true;
    _controller.add(_plans);
  }

  Future<void> _persist() =>
      _store.writeList(StoreKeys.plans, _plans.map((p) => p.toJson()).toList());

  Future<void> _ready() async {
    while (!_loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Stream<List<DietPlan>> _watch(bool Function(DietPlan) where) async* {
    await _ready();
    yield _plans.where(where).toList();
    yield* _controller.stream.map((plans) => plans.where(where).toList());
  }

  /// Every published plan, saved or not — the "All Diets" tab.
  @override
  Stream<List<DietPlan>> watchAll() => _watch((_) => true);

  @override
  Stream<List<DietPlan>> watchMine() => _watch((plan) => plan.isMine);

  @override
  Stream<List<DietPlan>> watchFavorites() => _watch((plan) => plan.isFavorite);

  @override
  Future<DietPlan> setFavorite(String id, {required bool favorite}) =>
      _update(id, (plan) => plan.copyWith(isFavorite: favorite));

  @override
  Future<DietPlan> setMine(String id, {required bool mine}) =>
      _update(id, (plan) => plan.copyWith(isMine: mine));

  Future<DietPlan> _update(
    String id,
    DietPlan Function(DietPlan) change,
  ) async {
    await _ready();
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index < 0) {
      throw RepositoryException('No plan $id', code: 'not-found');
    }
    final updated = change(_plans[index]);
    _plans = [..._plans]..[index] = updated;
    await _persist();
    _controller.add(_plans);
    return updated;
  }

  void dispose() => _controller.close();
}
