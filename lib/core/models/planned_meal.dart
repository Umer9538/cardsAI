import 'package:flutter/foundation.dart';

import 'food_item.dart';
import 'meal.dart';
import 'nutrition.dart';

/// One meal of a diet plan's example day.
///
/// A plan used to be four numbers — calories and three macros — which is a
/// *target*, not a diet. Nothing on the screen said what to actually eat, so
/// "Keto Kickstart" and "Vegan Vitality" differed only in their bar lengths.
///
/// The items are [FoodItem]s rather than a list of strings on purpose: that is
/// what the diary already accepts, so a planned meal can be logged in one tap
/// instead of being copy typed into the search box. A plan you can follow with
/// the app is the difference between a diet and a brochure.
@immutable
class PlannedMeal {
  const PlannedMeal({
    required this.slot,
    required this.title,
    required this.items,
  });

  final MealSlot slot;

  /// What the meal is called on the plan — "Greek yoghurt and berries".
  final String title;

  final List<FoodItem> items;

  Nutrition get nutrition => Nutrition.sum(items.map((i) => i.nutrition));

  /// The same meal at [factor] of its size, for [DietPlan.scaledTo].
  PlannedMeal scaledBy(double factor) => PlannedMeal(
        slot: slot,
        title: title,
        items: [for (final item in items) item.scaledBy(factor)],
      );

  Map<String, dynamic> toJson() => {
        'slot': slot.name,
        'title': title,
        'items': [for (final item in items) item.toJson()],
      };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
        slot: MealSlot.values.firstWhere(
          (s) => s.name == json['slot'],
          orElse: () => MealSlot.snack,
        ),
        title: json['title'] as String? ?? '',
        items: [
          for (final item in (json['items'] as List? ?? const []))
            FoodItem.fromJson((item as Map).cast<String, dynamic>()),
        ],
      );
}
