import 'package:flutter/foundation.dart';

import 'nutrition.dart';

/// A published diet plan, as shown on the Diets and Favorites screens.
@immutable
class DietPlan {
  const DietPlan({
    required this.id,
    required this.name,
    required this.image,
    required this.nutrition,
    this.description = '',
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

  DietPlan copyWith({
    String? id,
    String? name,
    String? image,
    Nutrition? nutrition,
    String? description,
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
