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

  /// Plans the user generated. Held apart from the catalogue because `_load`
  /// rebuilds that from [SeedData] and would otherwise delete them.
  List<DietPlan> _mine = const [];
  bool _loaded = false;

  /// Bumped when the catalogue changes in a way that must reach an install
  /// that already has a stored copy.
  static const int catalogueVersion = 4;

  /// Rebuilds the list from the catalogue, keeping this user's own flags.
  ///
  /// It used to read the stored copy verbatim and only ever seed when nothing
  /// was stored — so the catalogue was frozen at whatever it looked like the
  /// day the app was first opened. A plan added later never appeared, and a
  /// corrected description never propagated. Content comes from [SeedData] now;
  /// `isMine` and `isFavorite` come from what was stored, because those are the
  /// user's and the catalogue has no opinion about them.
  ///
  /// **Except once.** Version 1 of the catalogue shipped three plans with
  /// `isMine` and `isFavorite` already true, so every install seeded under it
  /// opened onto a My Diets tab full of choices nobody had made. Those flags
  /// were never a decision, so they are cleared on the way to version 2 — and
  /// exactly once, or it would wipe the real choices made afterwards.
  void _load() {
    final stored = _store.readList(StoreKeys.plans);
    final version =
        int.tryParse(_store.readString(StoreKeys.plansVersion) ?? '') ?? 1;
    final keepFlags = stored != null && version >= catalogueVersion;

    final flags = <String, ({bool mine, bool favourite})>{};
    if (keepFlags) {
      for (final json in stored) {
        final plan = DietPlan.fromJson(json);
        flags[plan.id] = (mine: plan.isMine, favourite: plan.isFavorite);
      }
    }

    _mine = [
      for (final json in _store.readList(StoreKeys.myPlans) ?? const [])
        DietPlan.fromJson(json),
    ];

    _plans = [
      ..._mine,
      for (final plan in SeedData.dietPlans)
        plan.copyWith(
          isMine: flags[plan.id]?.mine ?? false,
          isFavorite: flags[plan.id]?.favourite ?? false,
        ),
    ];

    unawaited(_persist());
    unawaited(
      _store.writeString(StoreKeys.plansVersion, '$catalogueVersion'),
    );
    _loaded = true;
    _controller.add(_plans);
  }

  Future<void> _persistMine() => _store.writeList(
        StoreKeys.myPlans,
        _mine.map((p) => p.toJson()).toList(),
      );

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

  /// A generated plan, kept alongside the catalogue.
  ///
  /// It survives `_load`'s reconcile because that walks [SeedData] and would
  /// drop anything not in it — so user plans are held separately and merged
  /// back in.
  @override
  Future<DietPlan> add(DietPlan plan) async {
    await _ready();
    final saved = plan.copyWith(isMine: true);
    _plans = [saved, ..._plans.where((p) => p.id != saved.id)];
    _mine = [saved, ..._mine.where((p) => p.id != saved.id)];
    await _persistMine();
    await _persist();
    _controller.add(_plans);
    return saved;
  }

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
