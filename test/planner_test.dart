import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/avoidance_check.dart';
import 'package:carbsai/core/nutrition/dish_taxonomy.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/data/local/local_planner_repository.dart';
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

  /// A fresh app over the same preferences, with [targets] pinned if given
  /// and [profile] signed in if given.
  Future<ProviderContainer> open({
    Nutrition? targets,
    UserProfile? profile,
  }) async {
    final c = ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(await JsonStore.open()),
        backendProvider.overrideWithValue(AppBackend.local),
        if (targets != null) targetsProvider.overrideWithValue(targets),
        if (profile != null)
          profileProvider.overrideWith((ref) => Stream.value(profile)),
      ],
    );
    addTearDown(c.dispose);
    // Warm the catalogue, which the local planner composes from. Through the
    // repository rather than the provider's future: a StreamProvider's future
    // waits on a broadcast stream that has already emitted.
    await c.read(dietRepositoryProvider).watchAll().first;
    // And the profile, which the planner reads for its purpose. Listened to,
    // not merely read: a Riverpod 3 stream provider with no listener never
    // runs, so its future never resolves — in the app, Home is the listener.
    if (profile != null) {
      final sub = c.listen(profileProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(profileProvider.future);
    }
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    container = await open();
  });

  /// Every string on the day a person reads or logs: the titles "Log this
  /// meal" writes to the diary as much as the item names.
  List<String> textsOf(DietPlan plan) => [
        for (final meal in plan.day) ...[
          meal.title,
          for (final item in meal.items) item.name,
        ],
      ];

  /// The catalogue as the planner sees it — no generated plans, no plans
  /// without a day.
  Future<List<DietPlan>> catalogueOf(ProviderContainer c) async =>
      (await c.read(dietRepositoryProvider).watchAll().first)
          .where((p) =>
              p.day.isNotEmpty &&
              !p.id.startsWith(LocalPlannerRepository.idPrefix))
          .toList();

  // Every question answered: two cuisines, all five leanings, avoidances
  // and a cook time — the profile a person who finished the quiz sends.
  const full = TasteProfile(
    liked: ['chicken-karahi', 'greek-salad'],
    leaning: {
      TasteAxis.spice: TastePole.hot,
      TasteAxis.starch: TastePole.rice,
      TasteAxis.protein: TastePole.plants,
      TasteAxis.breakfast: TastePole.skipBreakfast,
      TasteAxis.prep: TastePole.assembled,
    },
    avoid: {Avoidance.dairy, Avoidance.eggs},
    cookTime: CookTime.under15,
    notes: 'extra coriander',
  );

  test('the plan hits the targets it was built for', () async {
    final targets = container.read(targetsProvider);

    final plan = await container.read(plannerRepositoryProvider).generate(
          notes: 'vegetarian',
        );

    expect(plan.nutrition.calories, closeTo(targets.calories, 1));
    expect(plan.isMine, isTrue, reason: 'a plan you asked for is yours');
    expect(plan.day, isNotEmpty, reason: 'a plan with no meals is a target');
    expect(plan.id, startsWith(LocalPlannerRepository.idPrefix));
  });

  test('a generated plan is saved and survives a reload, chips and all',
      () async {
    final plan = await container
        .read(plannerRepositoryProvider)
        .generate(taste: full, notes: full.notes);
    expect(plan.builtFor, isNotEmpty);
    await container.read(dietRepositoryProvider).add(plan);

    final mine = await container.read(dietRepositoryProvider).watchMine().first;
    expect(mine.map((p) => p.id), contains(plan.id));

    // A relaunch. Eight seconds of waiting must not be lost to a restart —
    // and neither may what the plan was built for, which is the only record
    // of the answers that produced it. Ids alone would pass with the chips
    // dropped on the way through JSON.
    final again = await open();
    final reloaded = (await again.read(dietRepositoryProvider).watchMine().first)
        .where((p) => p.id == plan.id)
        .toList();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.builtFor, equals(plan.builtFor));
    expect(reloaded.single.builtFor, equals(full.summary));
    expect(reloaded.single.name, equals(plan.name));
    expect(
      reloaded.single.day.map((m) => m.title),
      equals(plan.day.map((m) => m.title)),
    );
  });

  test('the purpose leads what the plan was built for', () async {
    // What the plan is for is read off the profile, never asked by the quiz
    // and never sent — the same rule as the targets. Goal `lose` with no
    // motivation is a weight-loss plan; and it comes first, ahead of the
    // taste chips, because "Built for you" should say what the day is for
    // before what is in it.
    final c = await open(
      profile: const UserProfile(
        id: 'u1',
        name: 'Test',
        email: 't@example.com',
        goal: WeightGoal.lose,
      ),
    );

    final plan = await c
        .read(plannerRepositoryProvider)
        .generate(taste: full, notes: full.notes);

    expect(plan.builtFor.first, equals('Weight loss'));
    expect(plan.builtFor.sublist(1), equals(full.summary));

    // Muscle outranks the goal: cutting while training is still a plan that
    // needs its protein spread across the day.
    final gym = await open(
      profile: const UserProfile(
        id: 'u1',
        name: 'Test',
        email: 't@example.com',
        goal: WeightGoal.lose,
        motivation: Motivation.muscle,
      ),
    );
    final bulk = await gym.read(plannerRepositoryProvider).generate();
    expect(bulk.builtFor, equals(['Building muscle']));

    // And no goal is no purpose: the default target is neither a deficit
    // nor a surplus, so the chips are the taste alone — which is what the
    // reload test above relies on.
    final none = await container
        .read(plannerRepositoryProvider)
        .generate(taste: full);
    expect(none.builtFor, equals(full.summary));
  });

  test('it refuses rather than inventing a target', () async {
    // No profile, so no targets: the one number the plan must not make up.
    final bare = await open(targets: const Nutrition());

    expect(
      () => bare.read(plannerRepositoryProvider).generate(),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('an avoidance is a rule, not a hint', () async {
    final plan = await container.read(plannerRepositoryProvider).generate(
          taste: const TasteProfile(avoid: {Avoidance.dairy}),
        );

    // The shared matcher — the same one the Worker's `violations()` mirrors
    // — over every title and every name, since both reach the diary.
    final texts = textsOf(plan);
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(
        AvoidanceCheck.mentions(text, Avoidance.dairy),
        isFalse,
        reason: '"$text" is dairy',
      );
    }
    expect(plan.builtFor, contains('No dairy'));
  });

  test('a meal title is scanned as hard as its items', () async {
    // {dairy, eggs} leaves exactly one catalogue plan standing — Vegan —
    // whose breakfast is titled "Oats with soy milk and peanut butter". The
    // shared matcher knows both compounds are safe; the old one only ever
    // looked at item names, so a title it would have caught went through
    // to the diary under a "No dairy" chip.
    const avoid = {Avoidance.dairy, Avoidance.eggs};
    final plan = await container.read(plannerRepositoryProvider).generate(
          taste: const TasteProfile(avoid: avoid),
        );

    expect(plan.day, isNotEmpty);
    for (final meal in plan.day) {
      expect(meal.title, isNotEmpty);
      expect(meal.items, isNotEmpty, reason: 'an empty meal is not a meal');
      expect(
        AvoidanceCheck.violations([meal.title], avoid),
        isEmpty,
        reason: 'title "${meal.title}"',
      );
      for (final item in meal.items) {
        expect(
          AvoidanceCheck.violations([item.name], avoid),
          isEmpty,
          reason: 'item "${item.name}" in "${meal.title}"',
        );
      }
    }
    expect(plan.builtFor, contains('No dairy, eggs'));
  });

  test('when every plan is out, the closest comes back stripped and renamed',
      () async {
    // Nuts on top of dairy and eggs takes out the Vegan breakfast too —
    // "peanut butter" is not dairy but it is a nut — so nothing in the
    // catalogue is clean and the planner has to strip. A meal whose title
    // names the dropped food is renamed after what survived, or the diary
    // gets a title promising peanut butter over a bowl with none in it.
    const avoid = {Avoidance.dairy, Avoidance.eggs, Avoidance.nuts};
    final catalogue = await catalogueOf(container);
    expect(
      catalogue.every((p) => LocalPlannerRepository.violates(p, avoid)),
      isTrue,
      reason: 'the case relies on every plan violating',
    );

    final plan = await container.read(plannerRepositoryProvider).generate(
          taste: const TasteProfile(avoid: avoid),
        );

    expect(plan.day, isNotEmpty);
    for (final meal in plan.day) {
      expect(meal.items, isNotEmpty);
      expect(meal.title, isNotEmpty);
    }
    for (final text in textsOf(plan)) {
      expect(
        AvoidanceCheck.violations([text], avoid),
        isEmpty,
        reason: '"$text"',
      );
    }

    // The rename itself, on the day the strip rule was written for.
    final vegan = catalogue.singleWhere((p) => p.id == 'plan-vegan');
    final stripped = LocalPlannerRepository.strip(vegan.day, avoid);
    expect(stripped.first.slot, MealSlot.breakfast);
    expect(stripped.first.title, 'Oats, Soy milk');
    expect(stripped.first.items.map((i) => i.name), ['Oats, 80 g dry', 'Soy milk, 200 ml']);
    // Titles that never hit are left alone.
    expect(stripped[1].title, vegan.day[1].title);
  });

  test('cook time is carried on the plan', () async {
    final plan = await container.read(plannerRepositoryProvider).generate(
          taste: const TasteProfile(cookTime: CookTime.under15),
        );

    expect(plan.builtFor, contains('Under 15 min'));
    expect(plan.day, isNotEmpty);
  });

  test('with no time to cook, the tie goes to the plan with less on it',
      () async {
    // Under the default targets only one plan sits in the tie band, so the
    // tie-break has nothing to choose between. Build a target that puts two
    // plans with different plate counts in it: a point on the line between
    // Vegan (2.5 items a meal) and Indian Vegetarian (2.0), nearer Vegan —
    // so the closest plan is unambiguously the busier one, and only the
    // tie-break can pick the other.
    final seed = await catalogueOf(container);
    final vegan = seed.singleWhere((p) => p.id == 'plan-vegan');
    final indian = seed.singleWhere((p) => p.id == 'plan-indian-veg');
    expect(
      LocalPlannerRepository.itemsPerMeal(vegan),
      greaterThan(LocalPlannerRepository.itemsPerMeal(indian)),
    );

    ({double p, double c, double f}) share(Nutrition n) {
      final e = n.protein * 4 + n.carbs * 4 + n.fat * 9;
      return (p: n.protein * 4 / e, c: n.carbs * 4 / e, f: n.fat * 9 / e);
    }

    const w = 0.6; // weight on Vegan
    final a = share(vegan.nutrition);
    final b = share(indian.nutrition);
    const kcal = 2000.0;
    final targets = Nutrition(
      calories: kcal,
      protein: (a.p * w + b.p * (1 - w)) * kcal / 4,
      carbs: (a.c * w + b.c * (1 - w)) * kcal / 4,
      fat: (a.f * w + b.f * (1 - w)) * kcal / 9,
    );

    final c = await open(targets: targets);
    final catalogue = await catalogueOf(c);
    double d(DietPlan p) => LocalPlannerRepository.distance(p, targets);
    final closest = catalogue.reduce((x, y) => d(x) <= d(y) ? x : y);
    expect(closest.id, vegan.id, reason: 'the target is built nearer Vegan');
    final band = catalogue
        .where((p) => d(p) - d(closest) <= LocalPlannerRepository.tieBand)
        .toList();
    expect(band.map((p) => p.id), containsAll([vegan.id, indian.id]));

    final plan = await c.read(plannerRepositoryProvider).generate(
          taste: const TasteProfile(cookTime: CookTime.under15),
        );
    final chosen =
        catalogue.singleWhere((p) => 'Your ${p.name}' == plan.name);

    // Fewest things per meal of anything in the band…
    for (final other in band) {
      expect(
        LocalPlannerRepository.itemsPerMeal(chosen),
        lessThanOrEqualTo(LocalPlannerRepository.itemsPerMeal(other)),
        reason: '${other.id} has less on the plate than ${chosen.id}',
      );
    }
    // …and not simply the closest, which is what removing the tie-break
    // would return.
    expect(chosen.id, isNot(closest.id));
    expect(
      LocalPlannerRepository.itemsPerMeal(chosen),
      lessThan(LocalPlannerRepository.itemsPerMeal(closest)),
    );

    // Without a cook-time preference the closest plan is what comes back.
    final plain = await c.read(plannerRepositoryProvider).generate();
    expect(plain.name, 'Your ${closest.name}');
  });

  test('building twice does not build on the first build', () async {
    final planner = container.read(plannerRepositoryProvider);
    final diets = container.read(dietRepositoryProvider);

    final first = await planner.generate();
    await diets.add(first);
    expect(
      (await diets.watchAll().first).map((p) => p.id),
      contains(first.id),
      reason: 'the saved plan is in the pool the planner reads',
    );

    final second = await planner.generate();
    expect(second.name, startsWith('Your '));
    expect(second.name, isNot(startsWith('Your Your')));
    expect(second.description, isNot(contains('Built from your targets. Built')));
    expect(second.id, isNot(first.id));
  });
}
