import 'package:intl/intl.dart';

import 'nutrition.dart';

/// Turns [Nutrition] into the exact strings the artboards show.
///
/// The screens used to carry these pre-formatted ("2,000 kcal", "Protein: 125g")
/// because there was no data behind them. Centralising the formatting here keeps
/// those strings identical now that they are computed, so the render tests still
/// match the design.
abstract final class NutritionFormat {
  static final NumberFormat _grouped = NumberFormat('#,##0');

  /// Grams, dropping a trailing ".0" so 30.0 reads "30" but 0.3 stays "0.3".
  ///
  /// The design shows both — "Protein: 30g" and "Fat: 0.3g" — so a fixed
  /// precision is wrong in one direction or the other.
  static String grams(double value) {
    final rounded = (value * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? _grouped.format(rounded)
        : rounded.toStringAsFixed(1);
    return '${text}g';
  }

  /// "2,000 kcal"
  static String calories(double value) =>
      '${_grouped.format(value.round())} kcal';

  /// The divided macro row under a diet card or a scanned food:
  /// `2,000 kcal · Protein: 125g · Carbs: 300g · Fat: 55g`.
  ///
  /// Returned as parts, not a joined string — the design draws a 1pt rule
  /// between them rather than a separator character.
  static List<String> macroRow(Nutrition n) => [
        calories(n.calories),
        'Protein: ${grams(n.protein)}',
        'Carbs: ${grams(n.carbs)}',
        'Fat: ${grams(n.fat)}',
      ];
}
