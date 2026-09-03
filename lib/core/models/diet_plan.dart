import 'package:flutter/foundation.dart';

import 'nutrition.dart';
import 'planned_meal.dart';

/// A published diet plan, as shown on the Diets and Favorites screens.
@immutable
class DietPlan {
  const DietPlan({
    required this.id,
    required this.name,
    required this.image,
    required this.nutrition,
    this.description = '',
    this.goal = '',
    this.eat = const [],
    this.limit = const [],
    this.day = const [],
    this.isFavorite = false,
    this.isMine = false,
    this.imageHeight = cardImageHeight,
  });

  /// Height the card reserves for its photo, in artboard points.
  static const double cardImageHeight = 220;

  final String id;
  final String name;

  /// Asset path today; a Storage URL once plans come from the backend.
  final String image;

  final Nutrition nutrition;
  final String description;

  /// What following this plan is *for*.
  ///
  /// On the plan itself, because it is a property of the plan. The detail
  /// screen used to carry it as a constructor default, so every plan in the
  /// catalogue was described as "Heart Health, Weight Maintenance" — including
  /// the ketogenic one, which is neither.
  final String goal;

  /// What the plan is built on, and what it keeps low.
  ///
  /// Two short lists rather than prose, because this is the part people scan
  /// before deciding — "can I actually eat like this" is answered by seeing the
  /// food, not by reading a paragraph about metabolic pathways.
  final List<String> eat;
  final List<String> limit;

  /// An example day. The thing that makes this a diet rather than a target.
  final List<PlannedMeal> day;

  /// Saved to Favorites.
  final bool isFavorite;

  /// Added to "My Diets".
  final bool isMine;

  /// Height of the artwork actually available.
  ///
  /// Figma clips exports at the frame edge, and some of these cards sit partly
  /// below it in every artboard they appear on, so their photos come back short.
  /// The card still reserves the full [cardImageHeight]; the shortfall shows as
  /// background rather than a stretched image. Drop this override once the
  /// source photos are available at full height.
  final double imageHeight;

  /// This plan, expressed against [targets].
  ///
  /// A diet plan is a **pattern**, not a promise of a particular calorie count:
  /// Mediterranean is a ratio of fat to carbohydrate, keto is a carbohydrate
  /// ceiling. The catalogue stores each one at a representative size, and
  /// showing that raw is what made the section feel like decoration — the app
  /// computes a personal target of 2,413 kcal, then offers a "2,000 kcal" plan
  /// beside it with no explanation, and both numbers stop being believable.
  ///
  /// So the macro *proportions* are preserved and the energy is the user's own.
  /// Grams are recovered with the Atwater factors the rest of the app uses
  /// (4/4/9), which is also why this cannot simply scale each macro by a
  /// ratio of calories: the stored figures do not always add up to their own
  /// stated total, and the user's target must be the number that holds.
  ///
  /// Returns the plan unchanged when either side has no energy to work from —
  /// a zero target means the profile has not been through the quiz yet, and
  /// inventing a split for it would be worse than showing the pattern's own.
  DietPlan scaledTo(Nutrition targets) {
    final energy = nutrition.protein * 4 + nutrition.carbs * 4 + nutrition.fat * 9;
    if (energy <= 0 || targets.calories <= 0) return this;

    final factor = targets.calories / energy;
    return copyWith(
      // The day is deliberately **not** scaled.
      //
      // Each item's name carries its own portion — "Walnuts, 20 g", "Roti, 2
      // medium" — so multiplying the numbers while leaving the name alone
      // produces a card that contradicts itself. The macro cards above are the
      // user's target; the day is an illustration of what eating this way looks
      // like, and the screen shows its own total so nothing is implied.
      nutrition: Nutrition(
        calories: targets.calories,
        protein: (nutrition.protein * factor).roundToDouble(),
        carbs: (nutrition.carbs * factor).roundToDouble(),
        fat: (nutrition.fat * factor).roundToDouble(),
        fiber: nutrition.fiber * factor,
        sugar: nutrition.sugar * factor,
      ),
    );
  }

  DietPlan copyWith({
    String? id,
    String? name,
    String? image,
    Nutrition? nutrition,
    String? description,
    String? goal,
    List<String>? eat,
    List<String>? limit,
    List<PlannedMeal>? day,
    bool? isFavorite,
    bool? isMine,
    double? imageHeight,
  }) =>
      DietPlan(
        id: id ?? this.id,
        name: name ?? this.name,
        image: image ?? this.image,
        nutrition: nutrition ?? this.nutrition,
        description: description ?? this.description,
        goal: goal ?? this.goal,
        eat: eat ?? this.eat,
        limit: limit ?? this.limit,
        day: day ?? this.day,
        isFavorite: isFavorite ?? this.isFavorite,
        isMine: isMine ?? this.isMine,
        imageHeight: imageHeight ?? this.imageHeight,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'nutrition': nutrition.toJson(),
        'description': description,
        'goal': goal,
        'eat': eat,
        'limit': limit,
        'day': [for (final meal in day) meal.toJson()],
        'isFavorite': isFavorite,
        'isMine': isMine,
        'imageHeight': imageHeight,
      };

  factory DietPlan.fromJson(Map<String, dynamic> json) => DietPlan(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        nutrition: Nutrition.fromJson(
          (json['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        description: json['description'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        eat: [
          for (final v in (json['eat'] as List? ?? const [])) v as String,
        ],
        limit: [
          for (final v in (json['limit'] as List? ?? const [])) v as String,
        ],
        day: [
          for (final v in (json['day'] as List? ?? const []))
            PlannedMeal.fromJson((v as Map).cast<String, dynamic>()),
        ],
        isFavorite: json['isFavorite'] as bool? ?? false,
        isMine: json['isMine'] as bool? ?? false,
        imageHeight:
            (json['imageHeight'] as num?)?.toDouble() ?? cardImageHeight,
      );

  @override
  bool operator ==(Object other) =>
      other is DietPlan &&
      other.id == id &&
      other.isFavorite == isFavorite &&
      other.isMine == isMine;

  @override
  int get hashCode => Object.hash(id, isFavorite, isMine);
}
