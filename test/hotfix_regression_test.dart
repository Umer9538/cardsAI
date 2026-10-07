import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two fixes whose failure mode is silence: both produced a screen that looked
/// perfectly plausible and was showing the wrong thing.
class _Diets implements DietRepository {
  _Diets(this.plans);
  final List<DietPlan> plans;

  @override
  Stream<List<DietPlan>> watchAll() => Stream.value(plans);
  @override
  Stream<List<DietPlan>> watchMine() =>
      Stream.value([for (final p in plans) if (p.isMine) p]);
  @override
  Stream<List<DietPlan>> watchFavorites() =>
      Stream.value([for (final p in plans) if (p.isFavorite) p]);
  @override
  Future<DietPlan> add(DietPlan plan) async => plan;
  @override
  Future<DietPlan> setMine(String id, {required bool mine}) async =>
      plans.firstWhere((p) => p.id == id);
  @override
  Future<DietPlan> setFavorite(String id, {required bool favorite}) async =>
      plans.firstWhere((p) => p.id == id);
}

DietPlan _plan(String id, {DateTime? at, bool mine = true}) => DietPlan(
      id: id,
      name: id,
      image: 'assets/images/app/diet_keto.webp',
      nutrition: const Nutrition(calories: 2000, protein: 100, carbs: 200, fat: 60),
      isMine: mine,
      createdAt: at,
    );

Future<List<DietPlan>> _firstValue(ProviderContainer container) async {
  final sub = container.listen(myDietsProvider, (_, _) {});
  for (var i = 0; i < 8 && sub.read().value == null; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sub.read().value ?? (throw StateError('myDietsProvider never emitted'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the diary has no forward direction', () {
    test('a future date is clamped to today', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedDateProvider.notifier);

      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);

      notifier.select(midnight.add(const Duration(days: 3)));
      // The week strip greyed future days and left them tappable, so tapping
      // tomorrow opened an empty day that looked like a day with nothing
      // logged rather than a day that cannot exist yet.
      expect(container.read(selectedDateProvider), midnight);

      notifier.select(midnight.add(const Duration(days: 400)));
      expect(container.read(selectedDateProvider), midnight);
    });

    test('the past is still reachable, to the day', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedDateProvider.notifier);

      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);
      final back = midnight.subtract(const Duration(days: 9));

      notifier.select(back);
      expect(container.read(selectedDateProvider), back);
    });

    test('today itself is not clamped away', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(selectedDateProvider.notifier);

      final today = DateTime.now();
      final midnight = DateTime(today.year, today.month, today.day);
      // Mid-afternoon today is still today, not tomorrow.
      notifier.select(today);
      expect(container.read(selectedDateProvider), midnight);
    });
  });

  group('My Diets puts the plan you just built first', () {
    Future<ProviderContainer> harness(List<DietPlan> plans) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final container = ProviderContainer(overrides: [
        jsonStoreProvider.overrideWithValue(await JsonStore.open()),
        dietRepositoryProvider.overrideWithValue(_Diets(plans)),
        // Pinned, or the list provider waits on the profile stream, which
        // waits on auth. The rescale is not what these tests are about.
        targetsProvider.overrideWithValue(
          const Nutrition(calories: 2200, protein: 120, carbs: 250, fat: 70),
        ),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('newest generated plan comes first', () async {
      final container = await harness([
        _plan('older', at: DateTime(2026, 1, 1)),
        _plan('newest', at: DateTime(2026, 9, 30)),
        _plan('middle', at: DateTime(2026, 5, 5)),
      ]);

      final plans = await _firstValue(container);
      // Firestore streamed these with no orderBy, so they arrived ordered by
      // document id — `plan-mine-<uuid4>` is random, so a plan someone had just
      // waited fifteen seconds for landed anywhere in the list.
      expect(plans.map((p) => p.name), ['newest', 'middle', 'older']);
    });

    test('a plan stored before createdAt existed sorts with the catalogue',
        () async {
      final container = await harness([
        _plan('legacy'),
        _plan('built', at: DateTime(2026, 9, 30)),
      ]);

      final plans = await _firstValue(container);
      // Null sorts last rather than vanishing or throwing: the sort is on the
      // client precisely so nothing has to be migrated.
      expect(plans.map((p) => p.name), ['built', 'legacy']);
    });

    test('the order is stable when nothing carries a date', () async {
      final container = await harness([
        _plan('a'),
        _plan('b'),
        _plan('c'),
      ]);

      final plans = await _firstValue(container);
      // mergeSort, not List.sort: every catalogue plan compares equal, and an
      // unstable sort would reshuffle the whole screen on each rebuild.
      expect(plans.map((p) => p.name), ['a', 'b', 'c']);
    });

    test('createdAt survives the JSON round trip and the target rescale', () {
      final at = DateTime(2026, 9, 30, 14, 22);
      final plan = _plan('built', at: at);

      expect(DietPlan.fromJson(plan.toJson()).createdAt, at);
      // scaledTo goes through copyWith, so the stamp must ride along — the
      // provider rescales every plan before it sorts them.
      expect(
        plan
            .scaledTo(const Nutrition(calories: 2500, protein: 0, carbs: 0, fat: 0))
            .createdAt,
        at,
      );
    });
  });
}
