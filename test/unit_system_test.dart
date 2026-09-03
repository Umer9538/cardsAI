import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 'cm' and 'kg' were hardcoded inside the onboarding quiz — the app's highest
/// drop-off surface — and roughly half the paying audience for a calorie
/// tracker measures in pounds.
void main() {
  test('metric reads as the stored value', () {
    expect(UnitSystem.metric.formatHeight(173), '173');
    expect(UnitSystem.metric.formatWeight(72.5), '72.5');
    expect(UnitSystem.metric.formatWeight(80), '80.0');
    expect(UnitSystem.metric.heightUnit, 'cm');
    expect(UnitSystem.metric.weightUnit, 'kg');
  });

  test('imperial height converts to feet and inches', () {
    // 5 ft 8 in = 68 in = 172.72 cm
    expect(UnitSystem.imperial.formatHeight(172.72), '5′ 8″');
    expect(UnitSystem.imperial.formatHeight(152.4), '5′ 0″');
  });

  test('and never says 12 inches', () {
    // 5 ft 11.6 in rounds to 72 inches, which is 6 ft 0 in — not 5 ft 12 in.
    // Taking the feet before rounding the inches is how that bug happens.
    for (var cm = 120.0; cm <= 220.0; cm += 0.1) {
      final label = UnitSystem.imperial.formatHeight(cm);
      final inches = int.parse(label.split('′ ')[1].replaceAll('″', ''));
      expect(inches, lessThan(12), reason: '$cm cm rendered $label');
    }
  });

  test('imperial weight converts to whole pounds', () {
    expect(UnitSystem.imperial.formatWeight(70), '154');
    expect(UnitSystem.imperial.weightWithUnit(70), '154 lb');
  });

  test('an unknown stored name falls back rather than throwing', () {
    // A value written by a newer build must not crash an older one.
    expect(UnitSystem.fromName('metric'), UnitSystem.metric);
    expect(UnitSystem.fromName('imperial'), UnitSystem.imperial);
    expect(() => UnitSystem.fromName('furlongs'), returnsNormally);
  });
}
