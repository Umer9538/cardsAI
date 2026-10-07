import 'dart:async';

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/app/presentation/widgets/water_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tester reported the water feature as "not implemented". The client half
/// is what these pin: a tap must write, and the card must show the result.
class _Water implements WaterRepository {
  final List<WaterEntry> entries = [];
  final _controller = StreamController<List<WaterEntry>>.broadcast();

  @override
  Stream<List<WaterEntry>> watchDay(DateTime day) async* {
    yield List.of(entries);
    yield* _controller.stream;
  }

  @override
  Future<Map<DateTime, double>> totalsBetween(DateTime from, DateTime to) async =>
      const {};

  @override
  Future<void> log(double ml, {DateTime? at}) async {
    final entry = WaterEntry(
      id: 'e${entries.length}',
      ml: ml,
      at: at ?? DateTime.now(),
    );
    entries.add(entry);
    _controller.add(List.of(entries));
  }

  @override
  Future<void> removeLast(DateTime day) async {
    if (entries.isNotEmpty) entries.removeLast();
    _controller.add(List.of(entries));
  }
}

Future<_Water> _pump(WidgetTester tester, {bool metric = true}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(428, 926);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{
    StoreKeys.units: metric ? 'metric' : 'imperial',
  });
  final store = await JsonStore.open();
  final repo = _Water();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        waterRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 428,
            height: 926,
            child: Stack(children: [WaterCard(top: 0)]),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return repo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a quick-add writes a glass and the card shows it',
      (tester) async {
    final repo = await _pump(tester);

    expect(find.textContaining('0 / '), findsOneWidget);
    await tester.tap(find.text('+250'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(repo.entries.single.ml, 250);
    expect(find.textContaining('250 / '), findsOneWidget);
  });

  testWidgets('undo takes the last one back', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('+500'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.entries, hasLength(1));

    await tester.tap(find.bySemanticsLabel('Undo last drink'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(repo.entries, isEmpty);
  });

  testWidgets('the whole row fits, in either unit', (tester) async {
    await _pump(tester, metric: false);
    expect(tester.takeException(), isNull);
    // "0 / 90 fl oz" is the figure the tester's screenshot showed, and it
    // renders whole — the card is 388 wide and the row needs about 160.
    expect(find.textContaining('fl oz'), findsOneWidget);
  });
}
