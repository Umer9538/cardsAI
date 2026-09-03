import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/data/local/local_diet_repository.dart';
import 'package:carbsai/data/local/seed_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The catalogue used to be written once, when nothing was stored, and never
/// looked at again — so it was frozen at whatever it looked like the day the
/// app was first opened. A plan added later never appeared; a corrected
/// description never propagated.
void main() {
  test('a stored copy is reconciled against the catalogue, not trusted',
      () async {
    // An install from version 1: a plan that no longer exists, a stale
    // description, and the isMine flag that version shipped set.
    SharedPreferences.setMockInitialValues(<String, Object>{
      StoreKeys.plansVersion: '1',
      StoreKeys.plans: '''
[
  {"id":"plan-gone","name":"Retired","image":"","description":"old",
   "nutrition":{"calories":1},"isMine":true,"isFavorite":true},
  {"id":"plan-keto","name":"Stale Name","image":"","description":"stale",
   "nutrition":{"calories":1},"isMine":true,"isFavorite":true}
]''',
    });

    final repo = LocalDietRepository(await JsonStore.open());
    final all = await repo.watchAll().first;

    // Content is the catalogue's.
    expect(all.length, SeedData.dietPlans.length);
    expect(all.any((p) => p.id == 'plan-gone'), isFalse,
        reason: 'a retired plan should not survive');
    final keto = all.firstWhere((p) => p.id == 'plan-keto');
    expect(keto.name, isNot('Stale Name'));

    // And version 1's flags were never a user decision, so they are cleared.
    expect(await repo.watchMine().first, isEmpty);
    expect(await repo.watchFavorites().first, isEmpty);
  });

  test('but a real choice survives a reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();

    final first = LocalDietRepository(store);
    await first.watchAll().first;
    await first.setFavorite('plan-keto', favorite: true);

    // A relaunch. The flag is the user's, so it has to come back.
    final again = LocalDietRepository(await JsonStore.open());
    final favourites = await again.watchFavorites().first;
    expect(favourites.map((p) => p.id), ['plan-keto']);
  });

  test('every plan says what it is for', () {
    // The detail screen used to carry the goal as a constructor default, so
    // every plan in the catalogue read "Heart Health, Weight Maintenance" --
    // including the ketogenic one, which is neither.
    for (final plan in SeedData.dietPlans) {
      expect(plan.goal, isNotEmpty, reason: '${plan.id} has no goal');
    }

    final goals = SeedData.dietPlans.map((p) => p.goal).toSet();
    expect(
      goals.length,
      greaterThan(1),
      reason: 'one goal shared by every plan is the bug, not the fix',
    );

    final keto = SeedData.dietPlans.firstWhere((p) => p.id == 'plan-keto');
    expect(keto.goal.toLowerCase(), isNot(contains('heart health')));
  });

  test('every plan is an actual diet, not four numbers', () {
    // A plan used to be calories and three macros, which is a target. Nothing
    // said what to eat, so Keto and Vegan differed only in their bar lengths.
    for (final plan in SeedData.dietPlans) {
      expect(plan.eat, isNotEmpty, reason: '${plan.id} lists no foods');
      expect(plan.limit, isNotEmpty, reason: '${plan.id} limits nothing');
      expect(plan.day.length, 4, reason: '${plan.id} has no full day');
      for (final meal in plan.day) {
        expect(meal.items, isNotEmpty);
        expect(meal.nutrition.calories, greaterThan(0));
      }
    }
  });

  test("the plan's macros are its day's macros", () {
    // Derived rather than asserted: the plan used to state a round number that
    // its own example day did not add up to, which is the same class of
    // invention as the pre-favourited flags.
    for (final plan in SeedData.dietPlans) {
      final day = plan.day.fold(0.0, (sum, m) => sum + m.nutrition.calories);
      expect(day, closeTo(plan.nutrition.calories, 1));
    }
  });

  test('scaling a plan leaves its example day alone', () {
    final keto = SeedData.dietPlans.firstWhere((p) => p.id == 'plan-keto');
    final scaled = keto.scaledTo(const Nutrition(calories: 3000));

    // The targets move; the day does not. Every item name carries its own
    // portion, so scaling the numbers would contradict the words.
    expect(scaled.nutrition.calories, 3000);
    expect(
      scaled.day.fold(0.0, (s, m) => s + m.nutrition.calories),
      closeTo(keto.day.fold(0.0, (s, m) => s + m.nutrition.calories), 1),
    );
    expect(scaled.day.first.items.first.name, keto.day.first.items.first.name);
  });
}
