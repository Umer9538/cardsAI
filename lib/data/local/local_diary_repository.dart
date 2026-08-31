import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';
import 'seed_data.dart';

/// The diary, held in memory and mirrored to [JsonStore].
///
/// Reads are served from the in-memory list because every screen that wants
/// meals wants them synchronously on the first frame; the store is written
/// through on each mutation. When Firestore lands it takes over both roles and
/// this class goes away.
class LocalDiaryRepository implements DiaryRepository {
  LocalDiaryRepository(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now {
    _load();
  }

  final JsonStore _store;

  /// Injectable so tests can pin "today" instead of racing midnight.
  final DateTime Function() _now;

  final _controller = StreamController<List<Meal>>.broadcast();
  List<Meal> _meals = const [];
  bool _loaded = false;

  void _load() {
    final stored = _store.readList(StoreKeys.meals);
    // Null means never written — seed it. Empty means the user cleared their
    // diary, which must survive a restart.
    _meals = stored == null
        ? SeedData.diary(_now())
        : stored.map(Meal.fromJson).toList();
    if (stored == null) unawaited(_persist());
    _loaded = true;
    _controller.add(_meals);
  }

  Future<void> _persist() =>
      _store.writeList(StoreKeys.meals, _meals.map((m) => m.toJson()).toList());

  Future<void> _ready() async {
    while (!_loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  List<Meal> _onDay(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _meals.where((meal) => meal.day == day).toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Stream<List<Meal>> watchDay(DateTime date) async* {
    await _ready();
    yield _onDay(date);
    // Re-filter on every mutation rather than keeping a per-day controller —
    // one meal can move between days when its time is edited.
    yield* _controller.stream.map((_) => _onDay(date));
  }

  @override
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to) async {
    await _ready();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _meals
        .where((meal) =>
            !meal.eatenAt.isBefore(start) && !meal.eatenAt.isAfter(end))
        .toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Future<Meal> addMeal(Meal meal) async {
    await _ready();
    _meals = [..._meals, meal];
    await _persist();
    _controller.add(_meals);
    return meal;
  }

  @override
  Future<Meal> updateMeal(Meal meal) async {
    await _ready();
    final index = _meals.indexWhere((m) => m.id == meal.id);
    if (index < 0) {
      throw RepositoryException('No meal ${meal.id}', code: 'not-found');
    }
    _meals = [..._meals]..[index] = meal;
    await _persist();
    _controller.add(_meals);
    return meal;
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _ready();
    _meals = _meals.where((meal) => meal.id != id).toList();
    await _persist();
    _controller.add(_meals);
  }

  @override
  Future<int> currentStreak() async {
    await _ready();
    final counts = <DateTime, int>{};
    for (final meal in _meals) {
      counts.update(meal.day, (n) => n + 1, ifAbsent: () => 1);
    }

    final now = _now();
    var day = DateTime(now.year, now.month, now.day);
    var streak = 0;

    // Today not yet qualifying does not break a streak that is otherwise
    // running — it has not finished yet. Start the count at yesterday instead.
    if ((counts[day] ?? 0) < 2) day = day.subtract(const Duration(days: 1));

    while ((counts[day] ?? 0) >= 2) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void dispose() => _controller.close();
}
