import 'dart:ui' show PlatformDispatcher;

/// Metric or imperial, for everything the user types or reads.
///
/// **Storage is always metric.** `UserProfile.heightCm` and `weightKg` are the
/// truth, `TargetCalculator` works in kilograms, and this only decides how a
/// number is shown and typed. Storing whatever the user happened to prefer
/// would put a unit on every arithmetic site in the app and guarantee that one
/// of them eventually forgets to convert.
///
/// This exists because `'cm'` and `'kg'` were hardcoded inside the onboarding
/// quiz — the app's highest drop-off surface — and roughly half the paying
/// audience for a calorie tracker measures in pounds. Being asked your weight
/// in a unit you do not think in is a reason to close the app.
enum UnitSystem {
  metric,
  imperial;

  /// The three countries that still use imperial for body measurements.
  ///
  /// Defaulting from the locale rather than asking is the point: an American
  /// should never see centimetres, and nobody else should have to find a
  /// setting. It stays overridable because the device locale is a guess about
  /// where someone is, not about how they think.
  static UnitSystem forLocale([PlatformDispatcher? dispatcher]) {
    final country = (dispatcher ?? PlatformDispatcher.instance)
        .locale
        .countryCode
        ?.toUpperCase();
    return const {'US', 'LR', 'MM'}.contains(country)
        ? UnitSystem.imperial
        : UnitSystem.metric;
  }

  static UnitSystem fromName(String? name) => UnitSystem.values.firstWhere(
        (u) => u.name == name,
        orElse: UnitSystem.forLocale,
      );

  bool get isMetric => this == UnitSystem.metric;

  /// Shown beside the number. Empty for imperial height, because feet and
  /// inches carry their own marks.
  String get heightUnit => isMetric ? 'cm' : '';
  String get weightUnit => isMetric ? 'kg' : 'lb';

  static const double _cmPerInch = 2.54;
  static const double _lbPerKg = 2.2046226218;

  /// Height as the user reads it: `173` or `5′ 8″`.
  ///
  /// The inches are rounded before the feet are taken, so 5 ft 11.6 in reads
  /// `6′ 0″` rather than `5′ 12″`.
  String formatHeight(double cm) {
    if (isMetric) return cm.round().toString();
    final totalInches = (cm / _cmPerInch).round();
    return '${totalInches ~/ 12}′ ${totalInches % 12}″';
  }

  /// Weight as the user reads it. One decimal in kilograms because half a kilo
  /// is a meaningful step; whole pounds because a tenth of a pound is not.
  String formatWeight(double kg) => isMetric
      ? kg.toStringAsFixed(1)
      : (kg * _lbPerKg).round().toString();

  /// Same as [formatWeight] but carrying the unit, for prose.
  String weightWithUnit(double kg) => '${formatWeight(kg)} $weightUnit';
}
