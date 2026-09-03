import 'package:carbsai/data/local/json_store.dart';
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
}
