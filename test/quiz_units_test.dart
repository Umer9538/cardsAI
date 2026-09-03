import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/onboarding/presentation/widgets/quiz_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_render.dart';

/// 'cm' and 'kg' were hardcoded inside the quiz — the app's highest drop-off
/// surface. Someone who thinks in pounds being asked for kilograms is a reason
/// to close the app, and a switch buried in Settings does not help at the
/// moment they notice.
void main() {
  setUpAll(loadDesignFonts);

  Future<ProviderContainer> containerOverStore() async {
    final store = await JsonStore.open();
    return ProviderContainer(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(AppBackend.local),
      ],
    );
  }

  test('the choice survives a relaunch', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final first = await containerOverStore();
    addTearDown(first.dispose);
    first.read(unitSystemProvider.notifier).set(UnitSystem.imperial);
    expect(first.read(unitSystemProvider), UnitSystem.imperial);

    // A fresh container over the same preferences is what a relaunch looks
    // like. Without persistence an American is put back on centimetres every
    // time they open the app.
    final again = await containerOverStore();
    addTearDown(again.dispose);
    expect(again.read(unitSystemProvider), UnitSystem.imperial);
  });

  testWidgets('the slider captions the value in the chosen units',
      (tester) async {
    var toggled = 0;

    Widget slider(UnitSystem units) => MaterialApp(
          home: Scaffold(
            body: QuizNumberSlider(
              accent: const Color(0xFFFF5A16),
              value: 172.72,
              min: 120,
              max: 220,
              divisions: 100,
              unit: units.heightUnit,
              format: units.formatHeight,
              onChanged: (_) {},
              onToggleUnits: () => toggled++,
              unitsLabel: 'Use feet & pounds',
            ),
          ),
        );

    await tester.pumpWidget(slider(UnitSystem.metric));
    await tester.pump();
    expect(find.text('173'), findsOneWidget);
    expect(find.text('cm'), findsOneWidget);

    await tester.tap(find.text('Use feet & pounds'));
    expect(toggled, 1, reason: 'the switch has to be reachable from here');

    await tester.pumpWidget(slider(UnitSystem.imperial));
    await tester.pump();
    // 172.72 cm is exactly 68 inches.
    expect(find.text('5′ 8″'), findsOneWidget);
    expect(find.text('cm'), findsNothing);
  });
}
