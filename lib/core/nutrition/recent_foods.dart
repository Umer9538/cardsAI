import '../models/models.dart';

/// One food this person logs often, with the portion they usually log.
class FrequentFood {
  const FrequentFood({
    required this.item,
    required this.count,
    required this.lastEaten,
  });

  /// The most recent version of the food, so the portion is theirs.
  final FoodItem item;

  /// How many times it appears in the window.
  final int count;

  final DateTime lastEaten;
}

/// The foods someone actually eats, from the diary they already have.
///
/// No new collection and no new writes: every logged meal is already a record
/// of what this person eats and how much of it, so a "recents" list is a read
/// of the diary rather than a second thing to keep in sync. That also means it
/// works offline and survives a reinstall the moment the diary syncs.
///
/// This is the shortest path to a logged meal in the app — no camera, no model,
/// no quota, one tap — and the reason the search screen no longer opens on an
/// empty box. An empty search field is the main reason this kind of input goes
/// unused.
abstract final class RecentFoods {
  /// How far back to look.
  ///
  /// Four weeks: long enough that a weekly habit appears three or four times,
  /// short enough that a food someone has moved on from drops off rather than
  /// sitting at the top of the list for a year.
  static const Duration window = Duration(days: 28);

  /// Names are matched case- and space-insensitively, so "Greek Yogurt" logged
  /// by the model and "greek yogurt" typed by hand are one food.
  static String key(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Most-logged first, then most-recent.
  ///
  /// Frequency leads because that is what makes a shortcut worth having — the
  /// point is the food eaten every morning, not the one eaten once yesterday.
  /// Recency only breaks ties, and it also chooses **which** version of a food
  /// is returned: the last portion logged, not the first, so the list keeps up
  /// when someone changes how much they eat.
  static List<FrequentFood> from(
    List<Meal> meals, {
    DateTime? now,
    int limit = 12,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(window);

    final counts = <String, int>{};
    final latest = <String, ({FoodItem item, DateTime at})>{};

    for (final meal in meals) {
      if (meal.eatenAt.isBefore(cutoff)) continue;

      // One food counts once per meal however many rows it has. A plate
      // analysed as three helpings of rice is one instance of rice, and
      // counting rows would let a single messy scan dominate the list.
      final seen = <String>{};

      for (final item in meal.items) {
        final id = key(item.name);
        if (id.isEmpty) continue;

        if (seen.add(id)) counts[id] = (counts[id] ?? 0) + 1;

        final held = latest[id];
        if (held == null || meal.eatenAt.isAfter(held.at)) {
          latest[id] = (item: item, at: meal.eatenAt);
        }
      }
    }

    final foods = [
      for (final entry in counts.entries)
        if (latest[entry.key] case final held?)
          FrequentFood(
            // Reset to a plain database-style entry: the confidence and the
            // "check this" flag belonged to the scan that produced it, and
            // re-logging a food someone has already accepted should not ask
            // them to check it again.
            item: held.item.copyWith(
              confidence: FoodConfidence.unknown,
              userEdited: false,
            ),
            count: entry.value,
            lastEaten: held.at,
          ),
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.lastEaten.compareTo(a.lastEaten);
      });

    return foods.length > limit ? foods.sublist(0, limit) : foods;
  }
}
