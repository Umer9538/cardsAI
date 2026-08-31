import 'package:flutter/foundation.dart';

/// Nutrition figures for a single food, a meal, or a whole day.
///
/// One type covers all three scales because they compose by addition: a meal is
/// the sum of its items, a day is the sum of its meals. Everything is stored as
/// a `double` — the model returns fractional grams ("Fat: 0.3g" on the scan
/// result artboard) and rounding only happens at the point of display.
@immutable
class Nutrition {
  const Nutrition({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
  });

  /// Energy, kcal.
  final double calories;

  /// Grams.
  final double protein;
  final double carbs;
  final double fat;

  /// Grams. Not shown anywhere in the current design, but the scan pipeline
  /// returns them and [netCarbs] needs fibre — cheaper to carry than to bolt on.
  final double fiber;
  final double sugar;

  static const Nutrition zero = Nutrition();

  /// Carbs less fibre, floored at zero.
  ///
  /// Unused by the current calorie-first UI; kept because the scan schema
  /// already produces the inputs.
  double get netCarbs {
    final net = carbs - fiber;
    return net < 0 ? 0 : net;
  }

  Nutrition operator +(Nutrition other) => Nutrition(
        calories: calories + other.calories,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        fiber: fiber + other.fiber,
        sugar: sugar + other.sugar,
      );

  /// Every figure multiplied by [factor] — how a portion adjustment (½×, 2×)
  /// is applied to an item.
  Nutrition operator *(double factor) => Nutrition(
        calories: calories * factor,
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
        fiber: fiber * factor,
        sugar: sugar * factor,
      );

  /// Sums an arbitrary run of figures. `Iterable.reduce` throws on empty, and
  /// an empty day is the normal starting state.
  static Nutrition sum(Iterable<Nutrition> parts) =>
      parts.fold(zero, (total, part) => total + part);

  Nutrition copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
  }) =>
      Nutrition(
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        fiber: fiber ?? this.fiber,
        sugar: sugar ?? this.sugar,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sugar': sugar,
      };

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
        calories: _num(json['calories']),
        protein: _num(json['protein']),
        carbs: _num(json['carbs']),
        fat: _num(json['fat']),
        fiber: _num(json['fiber']),
        sugar: _num(json['sugar']),
      );

  /// Tolerates ints, doubles, numeric strings and nulls — the model's JSON and
  /// Firestore both vary on which they hand back for a whole number.
  static double _num(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0,
      };

  @override
  bool operator ==(Object other) =>
      other is Nutrition &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat &&
      other.fiber == fiber &&
      other.sugar == sugar;

  @override
  int get hashCode =>
      Object.hash(calories, protein, carbs, fat, fiber, sugar);

  @override
  String toString() =>
      'Nutrition(${calories}kcal P$protein C$carbs F$fat)';
}
