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

/// Counted nouns, so the app stops saying "1 days".
///
/// Small, but it is the kind of thing a reader notices immediately and reads as
/// carelessness — and this app's whole argument is that its numbers are looked
/// after. English only, which is what the app ships in; a real localisation
/// would replace this with ICU plural rules rather than extend it.
abstract final class Plural {
  /// "1 day", "3 days". [plural] defaults to [singular] + "s".
  static String of(int count, String singular, [String? plural]) =>
      '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';

  /// Just the noun, for when the number is rendered separately.
  static String word(int count, String singular, [String? plural]) =>
      count == 1 ? singular : (plural ?? '${singular}s');
}
