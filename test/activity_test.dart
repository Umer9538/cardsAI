import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/data/local/local_activity_repository.dart';
import 'package:carbsai/features/app/presentation/widgets/activity_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The energy figure is arithmetic over published MET values, so it is tested
/// exactly rather than rendered — the same split as [TargetCalculator].
void main() {
  final today = DateTime(2026, 9, 22, 7);

  ActivityEntry bout(
    String name,
    int minutes,
    double kcal, {
    DateTime? at,
  }) =>
      ActivityEntry(
        id: '$name-$minutes',
        at: at ?? today,
        name: name,
        minutes: minutes,
        kcal: kcal,
      );

  group('a day totals up', () {
    test('an empty day is zero, not a division by it', () {
      const log = ActivityLog.empty;
      expect(log.minutes, 0);
      expect(log.kcal, 0);
      expect(log.progress, 0);
      expect(log.isEmpty, isTrue);
    });

    test('bouts add — two walks are two walks', () {
      final log = ActivityLog(entries: [
        bout('Walking', 20, 80),
        bout('Cycling', 30, 250),
      ]);
      expect(log.minutes, 50);
      expect(log.kcal, 330);
    });

    test('progress clamps, so a long day cannot overdraw the bar', () {
      final log = ActivityLog(entries: [bout('Running', 180, 1800)]);
      expect(log.progress, 1.0);
      // The caption still shows the real minutes.
      expect(log.minutes, 180);
    });

    test('the daily target is the WHO week divided by seven', () {
      expect(ActivityCatalogue.dailyMinutesTarget, (150 / 7).round());
    });
  });

  group('the energy estimate', () {
    test('follows MET x 3.5 x kg / 200 per minute', () {
      // 30 minutes of walking (3.5 MET) at 70 kg.
      expect(
        ActivityCatalogue.kcalFor(met: 3.5, minutes: 30, weightKg: 70),
        closeTo(3.5 * 3.5 * 70 / 200 * 30, 0.001),
      );
    });

    test('scales with bodyweight — the same run is not the same cost', () {
      final light =
          ActivityCatalogue.kcalFor(met: 9.8, minutes: 30, weightKg: 50);
      final heavy =
          ActivityCatalogue.kcalFor(met: 9.8, minutes: 30, weightKg: 100);
      expect(heavy, closeTo(light * 2, 0.001));
    });

    test('an unknown weight falls back rather than returning zero', () {
      final fallback = ActivityCatalogue.kcalFor(met: 5, minutes: 30);
      expect(fallback, greaterThan(0));
      expect(
        fallback,
        ActivityCatalogue.kcalFor(met: 5, minutes: 30, weightKg: 70),
      );
      expect(
        ActivityCatalogue.kcalFor(met: 5, minutes: 30, weightKg: 0),
        fallback,
      );
    });

    test('no minutes is no energy', () {
      expect(ActivityCatalogue.kcalFor(met: 9.8, minutes: 0), 0);
      expect(ActivityCatalogue.kcalFor(met: 9.8, minutes: -10), 0);
    });

    test('harder activities cost more, in the order a person would expect',
        () {
      double kcal(String name) => ActivityCatalogue.kcalFor(
            met: ActivityCatalogue.byName(name)!.met,
            minutes: 30,
            weightKg: 70,
          );
      expect(kcal('Running'), greaterThan(kcal('Cycling')));
      expect(kcal('Cycling'), greaterThan(kcal('Walking')));
      expect(kcal('Walking'), greaterThan(kcal('Yoga')));
    });
  });

  group('the catalogue', () {
    test('names are unique, or two chips would select each other', () {
      final names = {for (final kind in ActivityCatalogue.kinds) kind.name};
      expect(names, hasLength(ActivityCatalogue.kinds.length));
    });

    test('every MET is a plausible one', () {
      for (final kind in ActivityCatalogue.kinds) {
        expect(kind.met, greaterThan(1.0), reason: kind.name);
        expect(kind.met, lessThan(20.0), reason: kind.name);
      }
    });

    test('an unknown name resolves to nothing rather than the first kind', () {
      expect(ActivityCatalogue.byName('Quidditch'), isNull);
    });
  });

  group('the card books room for what it draws', () {
    test('an empty card still reserves a readable height', () {
      expect(ActivityCard.reserveFor(0), greaterThan(100));
    });

    test('each bout adds exactly one row, whatever the count', () {
      final step = ActivityCard.reserveFor(2) - ActivityCard.reserveFor(1);
      for (var n = 2; n <= 6; n++) {
        expect(
          ActivityCard.reserveFor(n + 1) - ActivityCard.reserveFor(n),
          step,
          reason: 'the $n-bout card grows by a different amount',
        );
      }
    });

    test('more bouts never reserve less room', () {
      var previous = ActivityCard.reserveFor(0);
      for (var n = 1; n <= 6; n++) {
        final next = ActivityCard.reserveFor(n);
        expect(next, greaterThan(previous));
        previous = next;
      }
    });
  });

  group('the local repository', () {
    late LocalActivityRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = LocalActivityRepository(
        JsonStore(await SharedPreferences.getInstance()),
      );
    });

    tearDown(() => repo.dispose());

    test('bouts accumulate within a day', () async {
      await repo.log(bout('Walking', 20, 80));
      await repo.log(bout('Cycling', 30, 250, at: today.add(const Duration(hours: 4))));
      expect((await repo.watchDay(today).first).length, 2);
    });

    test('a bout of no minutes is not exercise', () async {
      await repo.log(bout('Walking', 0, 0));
      expect(await repo.watchDay(today).first, isEmpty);
    });

    test('logging the same id again edits rather than duplicating', () async {
      await repo.log(bout('Walking', 20, 80));
      await repo.log(bout('Walking', 20, 999));
      final entries = await repo.watchDay(today).first;
      expect(entries.single.kcal, 999);
    });

    test('remove takes the one named, not the last', () async {
      final first = bout('Walking', 20, 80);
      await repo.log(first);
      await repo.log(bout('Cycling', 30, 250, at: today.add(const Duration(hours: 4))));
      await repo.remove(first.id);
      expect((await repo.watchDay(today).first).single.name, 'Cycling');
    });

    test('a day sees only its own bouts', () async {
      await repo.log(bout('Walking', 20, 80));
      await repo.log(bout('Running', 20, 200,
          at: today.subtract(const Duration(days: 1))));
      expect((await repo.watchDay(today).first).single.name, 'Walking');
    });

    test('logs come back keyed by midnight', () async {
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.log(bout('Walking', 20, 80));
      await repo.log(bout('Running', 20, 200, at: yesterday));

      final logs = await repo.logsBetween(
        yesterday.subtract(const Duration(days: 1)),
        today.add(const Duration(days: 1)),
      );
      expect(logs[DateTime(2026, 9, 22)]!.minutes, 20);
      expect(logs[DateTime(2026, 9, 21)]!.kcal, 200);
    });
  });
}
