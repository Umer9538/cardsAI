import 'dart:async';

import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/dish_taxonomy.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/data/local/local_diet_repository.dart';
import 'package:carbsai/features/diets/presentation/taste_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_render.dart';
import 'support/fake_reminder_service.dart';

/// A planner the test completes by hand, so the screen can be caught in the
/// states the local planner's fixed 1.4s sleep never leaves it in: still
/// waiting after the sweep, and answering after the screen is gone.
class _HandPlanner implements PlannerRepository {
  final completer = Completer<DietPlan>();
  int calls = 0;

  static const plan = DietPlan(
    id: 'plan-mine-hand',
    name: 'A day, by hand',
    image: '',
    nutrition: Nutrition(calories: 2000, protein: 120, carbs: 220, fat: 70),
    builtFor: ['No dairy'],
  );

  @override
  Future<DietPlan> generate({TasteProfile? taste, String? notes}) {
    calls++;
    return completer.future;
  }
}

/// The real local repository, with a count of saves and a way to make the
/// next one fail — a full disk, a Firestore that is briefly unhappy.
class _CountingDiets implements DietRepository {
  _CountingDiets(this._inner);

  final LocalDietRepository _inner;
  int adds = 0;
  int failNext = 0;

  @override
  Future<DietPlan> add(DietPlan plan) {
    adds++;
    if (failNext > 0) {
      failNext--;
      throw Exception('disk full');
    }
    return _inner.add(plan);
  }

  @override
  Stream<List<DietPlan>> watchAll() => _inner.watchAll();
  @override
  Stream<List<DietPlan>> watchMine() => _inner.watchMine();
  @override
  Stream<List<DietPlan>> watchFavorites() => _inner.watchFavorites();
  @override
  Future<DietPlan> setFavorite(String id, {required bool favorite}) =>
      _inner.setFavorite(id, favorite: favorite);
  @override
  Future<DietPlan> setMine(String id, {required bool mine}) =>
      _inner.setMine(id, mine: mine);
}

/// Walks the taste quiz as a person would, against the local planner.
///
/// Bounded pumps throughout: the pair steps advance on a timer, the build
/// step runs a sweep that never settles, and the local planner sleeps 1.4s
/// before composing a plan — `pumpAndSettle` would hang on any of them.
void main() {
  setUpAll(loadDesignFonts);

  Future<void> pumpQuiz(
    WidgetTester tester, {
    ValueChanged<DietPlan>? onCreated,
    VoidCallback? onBack,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          home: TasteQuizScreen(onCreated: onCreated, onBack: onBack),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// [designScope] with the planner and the diet repository swapped for the
  /// test's own. Built here rather than nested inside it: an override in a
  /// child scope is a scoped provider, which is a different thing.
  Future<Widget> handScope(
    Widget child, {
    required _HandPlanner planner,
    required _CountingDiets diets,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    return ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(AppBackend.local),
        reminderServiceProvider.overrideWithValue(FakeReminderService()),
        plannerRepositoryProvider.overrideWithValue(planner),
        dietRepositoryProvider.overrideWithValue(diets),
      ],
      child: child,
    );
  }

  Future<_CountingDiets> countingDiets() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final inner = LocalDietRepository(await JsonStore.open());
    addTearDown(inner.dispose);
    return _CountingDiets(inner);
  }

  Future<void> next(WidgetTester tester, [String label = 'Next']) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Pumps in half-second steps until [done] or six seconds have passed —
  /// enough for the planner's sleep and the build sweep, with room to spare.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 12 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('a full walk builds a plan carrying what was answered', (
    tester,
  ) async {
    DietPlan? created;
    await pumpQuiz(tester, onCreated: (plan) => created = plan);

    // Grid A: two tiles.
    await tester.tap(find.text('Chicken karahi'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Greek salad'));
    await tester.pump(const Duration(milliseconds: 200));
    await next(tester);

    // Grid B: nothing — an empty grid is an answer.
    expect(find.text('And these?'), findsOneWidget);
    await next(tester);

    // Five pairs: the left card each time. Each advances itself after a beat.
    for (final axis in TasteAxis.values) {
      final left = DishTaxonomy.byId(axis.left)!.name;
      expect(
        find.text(left),
        findsOneWidget,
        reason: 'expected the ${axis.name} pair on screen',
      );
      await tester.tap(find.text(left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Anything to leave out?'), findsOneWidget);
    await tester.tap(find.text('Dairy'));
    await tester.pump(const Duration(milliseconds: 200));
    await next(tester);

    expect(find.text('How much time to cook?'), findsOneWidget);
    await tester.tap(find.text('Under 15 min'));
    await tester.pump(const Duration(milliseconds: 200));
    await next(tester);

    expect(find.text('Anything else?'), findsOneWidget);
    await next(tester, 'Build my plan');
    expect(find.text('Building your plan'), findsOneWidget);
    expect(find.text('Adding up to'), findsOneWidget);

    await waitFor(tester, () => created != null);

    expect(created, isNotNull, reason: 'onCreated never fired');
    expect(created!.isMine, isTrue);
    expect(created!.builtFor, contains('No dairy'));
    expect(created!.builtFor, contains('Under 15 min'));
    // The left card on every axis is the left pole.
    expect(created!.builtFor, contains(TastePole.hot.chip));
    expect(created!.builtFor, contains(TastePole.bigBreakfast.chip));
  });

  testWidgets('skipping every step still produces a plan', (tester) async {
    DietPlan? created;
    await pumpQuiz(tester, onCreated: (plan) => created = plan);

    // Two grids, five pairs, avoid, cook time, notes.
    for (var i = 0; i < 10; i++) {
      expect(find.text('Skip'), findsOneWidget, reason: 'step $i has no Skip');
      await next(tester, 'Skip');
    }
    expect(find.text('Building your plan'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Open to anything'), findsOneWidget);

    await waitFor(tester, () => created != null);

    expect(created, isNotNull);
    expect(created!.isMine, isTrue);
    expect(
      created!.builtFor,
      isEmpty,
      reason: 'nothing was answered, so nothing should be claimed',
    );
  });

  testWidgets('Back on the first step leaves the quiz', (tester) async {
    var left = false;
    await pumpQuiz(tester, onBack: () => left = true);

    expect(find.text('Tap what looks good'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(left, isTrue);

    // And on any later step it is one step back, not out.
    await next(tester);
    expect(find.text('And these?'), findsOneWidget);
    left = false;
    await tester.tap(find.text('Back'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(left, isFalse);
    expect(find.text('Tap what looks good'), findsOneWidget);
  });

  testWidgets('every tile is a labelled, selectable button', (tester) async {
    // Disposed at the end of the body, not via addTearDown: the framework
    // checks for leaked handles before tear-downs run.
    final handle = tester.ensureSemantics();
    await pumpQuiz(tester);
    await tester.pump(const Duration(milliseconds: 400));

    for (final dish in DishTaxonomy.grid(DishTaxonomy.gridA)) {
      expect(
        find.bySemanticsLabel(dish.name),
        findsOneWidget,
        reason: '${dish.id} is unlabelled',
      );
    }
    handle.dispose();
  });

  testWidgets('no copy is cut off on any step at the text-scale ceiling', (
    tester,
  ) async {
    // The title and subtitle sit in fixed boxes inside a hard-clipped Stack,
    // so copy that runs long is silently truncated rather than overflowing.
    // The overflow suite only ever sees the first grid; this walks the rest,
    // at the largest text the artboard admits.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    // A planner that answers only when told, so the "still writing" caption
    // is actually on screen for the last check — the local planner answers
    // at 1.4s, well inside the 2.6s sweep, and never shows it.
    final planner = _HandPlanner();
    final diets = await countingDiets();
    DietPlan? created;
    await tester.pumpWidget(
      await handScope(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(DesignCanvas.maxTextScale),
            ),
            child: child!,
          ),
          home: TasteQuizScreen(onCreated: (plan) => created = plan),
        ),
        planner: planner,
        diets: diets,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    void checkCopy(String step) {
      for (final element in find.byType(Text).evaluate()) {
        final text = (element.widget as Text).data;
        if (text == null || text.isEmpty) continue;
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(text).first,
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'On "$step", this is cut off: "$text"',
        );
      }
      expect(tester.takeException(), isNull, reason: '"$step" overflowed');
    }

    // Answer as we go so the pressed states are on screen too.
    await tester.tap(find.text('Greek salad'));
    await tester.pump(const Duration(milliseconds: 200));
    checkCopy('grid A');
    await next(tester);
    checkCopy('grid B');
    await next(tester);
    for (final axis in TasteAxis.values) {
      checkCopy('pair ${axis.name}');
      await tester.tap(find.text(axis.neitherLabel));
      await tester.pump();
      // The beat before advancing, then the slide, as two pumps: the slide
      // starts on the frame after the timer fires, and four axes share the
      // same "Either way", so the outgoing pair has to be gone before the
      // next tap.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }
    await tester.tap(find.text('Seafood'));
    await tester.pump(const Duration(milliseconds: 200));
    checkCopy('avoid');
    await next(tester);
    await tester.tap(find.text('I like cooking'));
    await tester.pump(const Duration(milliseconds: 200));
    checkCopy('cook time');
    await next(tester);
    checkCopy('notes');
    await next(tester, 'Build my plan');
    checkCopy('building');
    // Past the sweep, with the plan still pending: the caption is on screen.
    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.text('Writing your day — usually 15 to 20 seconds.'), findsOneWidget);
    checkCopy('building, late');

    planner.completer.complete(_HandPlanner.plan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(created?.id, _HandPlanner.plan.id);
  });

  testWidgets('a plan that outlasts the sweep is still handed over', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final planner = _HandPlanner();
    final diets = await countingDiets();
    DietPlan? created;
    await tester.pumpWidget(
      await handScope(
        MaterialApp(home: TasteQuizScreen(onCreated: (plan) => created = plan)),
        planner: planner,
        diets: diets,
      ),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await next(tester, 'Skip');
    }
    expect(find.text('Building your plan'), findsOneWidget);
    expect(find.text('Writing your day — usually 15 to 20 seconds.'), findsNothing);

    // The sweep is 2.6s. Past it the screen says so, and holds.
    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.text('Writing your day — usually 15 to 20 seconds.'), findsOneWidget);
    expect(created, isNull);
    expect(planner.calls, 1);

    planner.completer.complete(_HandPlanner.plan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(created?.id, _HandPlanner.plan.id);
    expect(created!.isMine, isTrue);
    expect(diets.adds, 1);
  });

  testWidgets('a plan that lands after the screen was left is still saved', (
    tester,
  ) async {
    // A generate is a quota unit — three a day, not refunded. Backing out
    // while the model is still writing used to throw the answer away with
    // the unit spent; the plan belongs in My Diets whether or not anyone is
    // still looking at the screen that asked for it.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final planner = _HandPlanner();
    final diets = await countingDiets();
    DietPlan? created;
    await tester.pumpWidget(
      await handScope(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TasteQuizScreen(onCreated: (plan) => created = plan),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        planner: planner,
        diets: diets,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 10; i++) {
      await next(tester, 'Skip');
    }
    expect(find.text('Building your plan'), findsOneWidget);
    expect(planner.calls, 1);

    // Leave, while the planner is still out.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    // The page transition, with room to spare, then the frame on which the
    // navigator drops the finished route.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(find.byType(TasteQuizScreen), findsNothing);

    planner.completer.complete(_HandPlanner.plan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(diets.adds, 1, reason: 'the plan was not saved');
    final all = await diets.watchAll().first;
    expect(all.map((p) => p.id), contains(_HandPlanner.plan.id));
    expect(all.firstWhere((p) => p.id == _HandPlanner.plan.id).isMine, isTrue);
    expect(created, isNull, reason: 'nobody is there to open it');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Try again after a failed save re-saves rather than re-builds', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final planner = _HandPlanner();
    final diets = await countingDiets()
      ..failNext = 1;
    DietPlan? created;
    await tester.pumpWidget(
      await handScope(
        MaterialApp(home: TasteQuizScreen(onCreated: (plan) => created = plan)),
        planner: planner,
        diets: diets,
      ),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await next(tester, 'Skip');
    }
    planner.completer.complete(_HandPlanner.plan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(diets.adds, 1);
    expect(
      find.text('The plan was built but could not be saved. Try again.'),
      findsOneWidget,
    );
    expect(created, isNull);

    // The plan is in hand; only the write failed. A second quota unit for a
    // local write that failed would be the wrong thing to spend.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(planner.calls, 1, reason: 'Try again re-ran the generate');
    expect(diets.adds, 2, reason: 'Try again did not re-run the save');
    expect(find.text('Building your plan'), findsOneWidget);

    await waitFor(tester, () => created != null);
    expect(created?.id, _HandPlanner.plan.id);
    final mine = await diets.watchMine().first;
    expect(mine.where((p) => p.id == _HandPlanner.plan.id), hasLength(1));
  });
}
