import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/diets/presentation/diet_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_render.dart';

/// "Something else": another plan from the answers already given.
///
/// The quiz is about fifty seconds of tapping, and the answers do not change
/// between one plan and the next — asking for them again to get a second plan
/// is the surest way to make nobody ask for a second plan. `DietPlan.builtFor`
/// is only the frozen *summary*, so the profile itself has to be kept.
void main() {
  setUpAll(loadDesignFonts);

  const taste = TasteProfile(
    liked: ['biryani'],
    leaning: {},
    avoid: {},
    notes: '',
  );

  DietPlan plan({bool mine = true, List<String> builtFor = const ['South Asian']}) =>
      DietPlan(
        id: 'p1',
        name: 'Spiced Muscle Gain',
        image: 'assets/images/app/diet_keto.webp',
        nutrition: const Nutrition(
          calories: 2576,
          protein: 148,
          carbs: 354,
          fat: 77,
        ),
        isMine: mine,
        builtFor: builtFor,
      );

  Future<void> pump(WidgetTester tester, {VoidCallback? onRebuild}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      await designScope(
        MaterialApp(
          home: DietDetailScreen(plan: plan(), onRebuild: onRebuild),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  testWidgets('the button is offered, and says what it does', (tester) async {
    await pump(tester, onRebuild: () {});

    expect(find.text('Something else'), findsOneWidget);
    expect(find.text('Same answers, a different day'), findsOneWidget);
  });

  testWidgets('tapping it asks for another plan', (tester) async {
    var asked = 0;
    await pump(tester, onRebuild: () => asked++);

    await tester.ensureVisible(find.text('Something else'));
    await tester.pump();
    await tester.tap(find.text('Something else'), warnIfMissed: false);
    await tester.pump();

    expect(asked, 1);
  });

  testWidgets('a plan with nothing to rebuild from does not offer it',
      (tester) async {
    await pump(tester);

    // A catalogue plan was not built from anybody's answers, and a fresh
    // install has none stored — in both cases the shell passes null.
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('the answers survive storage so the button has something to use',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    final container = ProviderContainer(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(lastTasteProvider), isNull);
    container.read(lastTasteProvider.notifier).remember(taste);
    expect(container.read(lastTasteProvider), taste);

    // And back from disk, which is the path that matters — the button is
    // offered on a screen opened long after the quiz was answered.
    final second = ProviderContainer(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    expect(second.read(lastTasteProvider), taste);
  });

  testWidgets('a stored blob from another build costs nobody the button',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      StoreKeys.lastTaste: '{"liked":["biryani"],"somethingNew":true}',
    });
    final container = ProviderContainer(
      overrides: [jsonStoreProvider.overrideWithValue(await JsonStore.open())],
    );
    addTearDown(container.dispose);

    expect(container.read(lastTasteProvider)?.liked, ['biryani']);
  });
}
