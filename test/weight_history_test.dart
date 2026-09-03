import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Body weight swings a kilo or more day to day on water alone, so the last
/// reading is the worst available estimate of where someone is — and it is the
/// number that makes people abandon a plan that is working.
void main() {
  WeightEntry at(int daysAgo, double kg) => WeightEntry(
        id: '$daysAgo',
        at: DateTime(2026, 3, 20).subtract(Duration(days: daysAgo)),
        kg: kg,
      );

  test('the trend is a seven-day mean, not the last number', () {
    // A steady 80 kg with one 82.4 kg water day at the end.
    final history = WeightHistory([
      for (var d = 6; d >= 1; d--) at(d, 80),
      at(0, 82.4),
    ]);

    expect(history.latest!.kg, 82.4);
    expect(history.trendKg, closeTo(80.34, 0.01),
        reason: 'one heavy morning must not move the trend 2.4 kg');
  });

  test('change is refused until there is enough history to mean anything', () {
    // Two readings a day apart. "You lost 1.4 kg" here is noise presented as
    // progress, which is worse than saying nothing.
    final young = WeightHistory([at(1, 81.4), at(0, 80)]);
    expect(young.changeOver(const Duration(days: 28)), isNull);

    expect(WeightHistory.empty.trendKg, isNull);
    expect(WeightHistory.empty.latest, isNull);
  });

  test('change compares trend to trend, not reading to reading', () {
    final history = WeightHistory([
      for (var d = 27; d >= 21; d--) at(d, 84),
      for (var d = 6; d >= 0; d--) at(d, 80),
    ]);

    expect(history.changeOver(const Duration(days: 14)), closeTo(-4, 0.01));
  });

  test('one reading is its own trend', () {
    final history = WeightHistory([at(0, 77.5)]);
    expect(history.trendKg, 77.5);
    expect(history.changeOver(const Duration(days: 7)), isNull);
  });
}
