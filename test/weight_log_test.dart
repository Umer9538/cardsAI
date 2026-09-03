import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/data/local/local_weight_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('one reading per day, and the last one wins', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = LocalWeightRepository(await JsonStore.open());
    addTearDown(repo.dispose);

    final morning = DateTime(2026, 3, 20, 7);
    await repo.log(81.2, at: morning);
    // Same day, after lunch. Two readings hours apart are the same measurement
    // taken twice; keeping both would weight that day double in the trend.
    await repo.log(82.0, at: morning.add(const Duration(hours: 6)));

    final history = await repo.watch().first;
    expect(history.entries.length, 1);
    expect(history.entries.single.kg, 82.0);
  });

  test('readings persist and come back oldest first', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    final repo = LocalWeightRepository(store);
    addTearDown(repo.dispose);

    await repo.log(80, at: DateTime(2026, 3, 18));
    await repo.log(79.4, at: DateTime(2026, 3, 20));
    await repo.log(79.8, at: DateTime(2026, 3, 19));

    final again = LocalWeightRepository(await JsonStore.open());
    addTearDown(again.dispose);
    final history = await again.watch().first;

    expect(history.entries.map((e) => e.kg).toList(), [80, 79.8, 79.4]);
    expect(history.latest!.kg, 79.4);
  });
}
