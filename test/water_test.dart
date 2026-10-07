import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/data/local/local_water_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Water is arithmetic over a list, so it is tested exactly rather than
/// rendered — the same split as [TargetCalculator] and [ReminderSchedule].
void main() {
  WaterEntry drink(double ml, DateTime at) =>
      WaterEntry(id: at.toIso8601String(), at: at, ml: ml);

  final today = DateTime(2026, 9, 22, 9);

  group('a day totals up', () {
    test('an empty day is zero, not a division by it', () {
      const log = WaterLog.empty;
      expect(log.totalMl, 0);
      expect(log.progress, 0);
      expect(log.glasses, 0);
      expect(log.isEmpty, isTrue);
    });

    test('entries add rather than replace — water is not weight', () {
      final log = WaterLog(
        entries: [drink(250, today), drink(500, today.add(const Duration(hours: 2)))],
        targetMl: 2000,
      );
      expect(log.totalMl, 750);
      expect(log.glasses, 3);
    });

    test('progress clamps at full so the bar cannot draw past its track', () {
      final log = WaterLog(entries: [drink(3000, today)], targetMl: 2000);
      expect(log.progress, 1.0);
      // The caption still shows the real figure.
      expect(log.totalMl, 3000);
    });

    test('a zero target does not divide by it', () {
      expect(WaterLog(entries: [drink(250, today)], targetMl: 0).progress, 0);
    });

    test('last is what undo removes', () {
      final later = today.add(const Duration(hours: 3));
      final log = WaterLog(
        entries: [drink(250, today), drink(500, later)],
        targetMl: 2000,
      );
      expect(log.last!.at, later);
    });
  });

  group('targets', () {
    test('scale with bodyweight', () {
      expect(WaterTargets.fromWeight(70), 70 * 35);
    });

    test('clamp at both ends, so neither is a silly number on a card', () {
      expect(WaterTargets.fromWeight(30), 1500);
      expect(WaterTargets.fromWeight(200), 4000);
    });

    test('an unknown weight falls back to the default', () {
      expect(WaterTargets.fromWeight(null), WaterTargets.defaultMl);
      expect(WaterTargets.fromWeight(0), WaterTargets.defaultMl);
    });

    test('the default divides into whole glasses', () {
      expect(WaterTargets.defaultMl % WaterTargets.glassMl, 0);
    });
  });

  group('units', () {
    test('metric shows millilitres unchanged', () {
      expect(UnitSystem.metric.volumeWithUnit(250), '250 ml');
    });

    test('imperial shows US fluid ounces', () {
      expect(UnitSystem.imperial.volumeWithUnit(250), '8 fl oz');
    });

    test('the conversion round-trips', () {
      final oz = UnitSystem.imperial.toDisplayVolume(2000);
      expect(UnitSystem.imperial.fromDisplayVolume(oz), closeTo(2000, 0.001));
    });
  });

  group('the local repository', () {
    late LocalWaterRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = LocalWaterRepository(JsonStore(await SharedPreferences.getInstance()));
    });

    tearDown(() => repo.dispose());

    test('logging accumulates within a day', () async {
      await repo.log(250, at: today);
      await repo.log(500, at: today.add(const Duration(hours: 1)));
      expect((await repo.watchDay(today).first).length, 2);
    });

    test('a non-positive amount is not a drink', () async {
      await repo.log(0, at: today);
      await repo.log(-250, at: today);
      expect(await repo.watchDay(today).first, isEmpty);
    });

    test('undo removes the most recent, not the first', () async {
      await repo.log(250, at: today);
      await repo.log(500, at: today.add(const Duration(hours: 1)));
      await repo.removeLast(today);
      final left = await repo.watchDay(today).first;
      expect(left.single.ml, 250);
    });

    test('undo on an empty day does nothing rather than throwing', () async {
      await repo.removeLast(today);
      expect(await repo.watchDay(today).first, isEmpty);
    });

    test('a day sees only its own drinks', () async {
      await repo.log(250, at: today);
      await repo.log(250, at: today.subtract(const Duration(days: 1)));
      expect((await repo.watchDay(today).first).single.ml, 250);
    });

    test('totals come back keyed by midnight', () async {
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.log(250, at: today);
      await repo.log(500, at: today.add(const Duration(hours: 2)));
      await repo.log(750, at: yesterday);

      final totals = await repo.totalsBetween(
        yesterday.subtract(const Duration(days: 1)),
        today.add(const Duration(days: 1)),
      );
      expect(totals[DateTime(2026, 9, 22)], 750);
      expect(totals[DateTime(2026, 9, 21)], 750);
    });
  });
}
