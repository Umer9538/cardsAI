import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The planner writes a day against the user's own targets. Those targets are
/// TargetCalculator's output, which is where the deficit cap and the calorie
/// floors live — so on the server they are read from the profile rather than
/// accepted from the client, and here the same rule shows up as: a plan is
/// always built for the targets, never for whatever was asked.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    container = ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(AppBackend.local),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the plan hits the targets it was built for', () async {
    // Warm the catalogue, which the local planner composes from. Through the
    // repository rather than the provider's future: a StreamProvider's future
    // waits on a broadcast stream that has already emitted.
    await container.read(dietRepositoryProvider).watchAll().first;
    final targets = container.read(targetsProvider);

    final plan = await container.read(plannerRepositoryProvider).generate(
          notes: 'vegetarian',
        );

    expect(plan.nutrition.calories, closeTo(targets.calories, 1));
    expect(plan.isMine, isTrue, reason: 'a plan you asked for is yours');
    expect(plan.day, isNotEmpty, reason: 'a plan with no meals is a target');
    expect(plan.id, startsWith('plan-mine-'));
  });

  test('a generated plan is saved and survives a reload', () async {
    await container.read(dietRepositoryProvider).watchAll().first;
    final plan =
        await container.read(plannerRepositoryProvider).generate(notes: '');
    await container.read(dietRepositoryProvider).add(plan);

    final mine = await container.read(dietRepositoryProvider).watchMine().first;
    expect(mine.map((p) => p.id), contains(plan.id));

    // A relaunch. Eight seconds of waiting must not be lost to a restart.
    final again = ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(await JsonStore.open()),
        backendProvider.overrideWithValue(AppBackend.local),
      ],
    );
    addTearDown(again.dispose);
    final reloaded =
        await again.read(dietRepositoryProvider).watchMine().first;
    expect(reloaded.map((p) => p.id), contains(plan.id));
  });

  test('it refuses rather than inventing a target', () async {
    // No profile, so no targets: the one number the plan must not make up.
    final bare = ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(await JsonStore.open()),
        backendProvider.overrideWithValue(AppBackend.local),
        targetsProvider.overrideWithValue(const Nutrition()),
      ],
    );
    addTearDown(bare.dispose);
    await bare.read(dietRepositoryProvider).watchAll().first;

    expect(
      () => bare.read(plannerRepositoryProvider).generate(),
      throwsA(isA<RepositoryException>()),
    );
  });
}
