import 'dart:async';

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/app/presentation/notifications_screen.dart';
import 'package:carbsai/features/app/presentation/widgets/activity_card.dart';
import 'package:carbsai/features/app/presentation/widgets/water_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Three bugs that all shared one shape: the app had the information and threw
/// it away before anyone could see it.
///
/// Water and activity were reported three separate times — "not implemented",
/// "very slow", "not working properly" — because a `permission-denied` on a
/// subcollection whose rules were never deployed arrived as a stream error,
/// every consumer read `.value ?? const []`, and the cards rendered a normal
/// empty day. There was nothing on screen and nothing in the console to tell
/// a refused read from a day nobody logged.
///
/// The notification list had the opposite problem: it *did* know which rows
/// were new and erased that knowledge in a post-frame callback before the
/// first paint the person ever saw.

class _FailingWater implements WaterRepository {
  @override
  Stream<List<WaterEntry>> watchDay(DateTime day) =>
      Stream<List<WaterEntry>>.error(
        Exception('permission-denied'),
      );

  @override
  Future<Map<DateTime, double>> totalsBetween(DateTime f, DateTime t) async =>
      const {};

  @override
  Future<void> log(double ml, {DateTime? at}) async {}

  @override
  Future<void> removeLast(DateTime day) async {}
}

class _FailingActivity implements ActivityRepository {
  @override
  Stream<List<ActivityEntry>> watchDay(DateTime day) =>
      Stream<List<ActivityEntry>>.error(
        Exception('permission-denied'),
      );

  @override
  Future<Map<DateTime, ActivityLog>> logsBetween(DateTime f, DateTime t) async =>
      const {};

  @override
  Future<void> log(ActivityEntry entry) async {}

  @override
  Future<void> remove(String id) async {}
}

/// Riverpod does not export `Override`, so the override list's type cannot be
/// written down — only inferred. Same reason `designScopeBuilder` returns a
/// closure rather than a list.
Future<Widget Function(Widget)> _scopeWater() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();
  final overrides = [
    jsonStoreProvider.overrideWithValue(store),
    waterRepositoryProvider.overrideWithValue(_FailingWater()),
  ];
  return (child) => ProviderScope(overrides: overrides, child: child);
}

Future<Widget Function(Widget)> _scopeActivity() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();
  final overrides = [
    jsonStoreProvider.overrideWithValue(store),
    activityRepositoryProvider.overrideWithValue(_FailingActivity()),
  ];
  return (child) => ProviderScope(overrides: overrides, child: child);
}

Future<Widget Function(Widget)> _scopePlain() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();
  final overrides = [jsonStoreProvider.overrideWithValue(store)];
  return (child) => ProviderScope(overrides: overrides, child: child);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a refused water read says so instead of reading as an empty day',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final wrap = await _scopeWater();
    await tester.pumpWidget(wrap(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 428,
          height: 926,
          child: Stack(children: [WaterCard(top: 0)]),
        ),
      ),
    )));
    await _settle(tester);

    expect(find.text('Could not load'), findsOneWidget);
    // The one that mattered: a zeroed readout beside working quick-add
    // buttons is what "the water feature is very slow" actually was.
    expect(find.textContaining('0 / '), findsNothing);
  });

  testWidgets('a refused activity read does not claim nothing was logged',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final wrap = await _scopeActivity();
    await tester.pumpWidget(wrap(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 428,
          height: 926,
          child: Stack(children: [ActivityCard(top: 0)]),
        ),
      ),
    )));
    await _settle(tester);

    expect(find.text("Today's activity could not be loaded."), findsOneWidget);
    // Saying "Nothing logged today." straight after someone pressed Save is
    // what made a read failure look like a write failure.
    expect(find.text('Nothing logged today.'), findsNothing);
  });

  testWidgets('an unread notification is distinguishable from a read one',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    final at = DateTime(2026, 10, 7, 9);
    final wrap = await _scopePlain();
    await tester.pumpWidget(wrap(MaterialApp(
      home: NotificationsScreen(
        items: [
          AppNotification(id: 'a', body: 'An unread one.', createdAt: at, read: false),
          AppNotification(id: 'b', body: 'A read one.', createdAt: at, read: true),
        ],
      ),
    )));
    await _settle(tester);

    Text textOf(String data) => tester.widget<Text>(find.text(data));

    // Weight, not only colour: three identical cards with nothing but a hue
    // between them is what was reported, and a hue alone excludes anyone who
    // cannot separate orange from grey.
    expect(textOf('An unread one.').style?.fontWeight, FontWeight.w600);
    expect(
      textOf('A read one.').style?.fontWeight,
      isNot(FontWeight.w600),
    );
    expect(
      textOf('An unread one.').style?.color,
      isNot(textOf('A read one.').style?.color),
    );

    // And it is spoken, since the whole distinction is otherwise visual.
    expect(find.bySemanticsLabel('Unread. An unread one.'), findsOneWidget);
  });
}
