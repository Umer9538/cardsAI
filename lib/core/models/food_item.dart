import 'package:flutter/foundation.dart';

import 'nutrition.dart';

/// Where a food's figures came from. Drives the "AI estimate" labelling and
/// tells the eval pipeline which numbers a person corrected.
enum FoodSource { ai, barcode, database, manual }

/// How sure the scan pipeline is about one identified item.
enum FoodConfidence { high, medium, low, unknown }

/// One identified food inside a meal or a scan result.
@immutable
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.nutrition,
    this.portionDescription = '',
    this.portionGrams,
    this.source = FoodSource.ai,
    this.confidence = FoodConfidence.unknown,
    this.userEdited = false,
  });

  final String id;
  final String name;

  /// Figures for the portion actually eaten, not per 100g.
  final Nutrition nutrition;

  /// Household description of the portion — "1 cup", "2 slices".
  final String portionDescription;

  /// Estimated weight, when the source provides one.
  final double? portionGrams;

  final FoodSource source;
  final FoodConfidence confidence;

  /// Set once someone changes a value, so an edit is never silently overwritten
  /// by a re-analysis, and so the edit rate can be measured.
  final bool userEdited;

  /// True when the item should render a "check this" affordance.
  bool get needsReview =>
      confidence == FoodConfidence.low && !userEdited;

  /// Re-scales the figures to [factor] times the current portion.
  FoodItem scaledBy(double factor) => copyWith(
        nutrition: nutrition * factor,
        portionGrams: portionGrams == null ? null : portionGrams! * factor,
        userEdited: true,
      );

  FoodItem copyWith({
    String? id,
    String? name,
    Nutrition? nutrition,
    String? portionDescription,
    double? portionGrams,
    FoodSource? source,
    FoodConfidence? confidence,
    bool? userEdited,
  }) =>
      FoodItem(
        id: id ?? this.id,
        name: name ?? this.name,
        nutrition: nutrition ?? this.nutrition,
        portionDescription: portionDescription ?? this.portionDescription,
        portionGrams: portionGrams ?? this.portionGrams,
        source: source ?? this.source,
        confidence: confidence ?? this.confidence,
        userEdited: userEdited ?? this.userEdited,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nutrition': nutrition.toJson(),
        'portionDescription': portionDescription,
        'portionGrams': portionGrams,
        'source': source.name,
        'confidence': confidence.name,
        'userEdited': userEdited,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        nutrition: Nutrition.fromJson(
          (json['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        portionDescription: json['portionDescription'] as String? ?? '',
        portionGrams: (json['portionGrams'] as num?)?.toDouble(),
        source: _enumOf(FoodSource.values, json['source'], FoodSource.ai),
        confidence: _enumOf(
          FoodConfidence.values,
          json['confidence'],
          FoodConfidence.unknown,
        ),
        userEdited: json['userEdited'] as bool? ?? false,
      );

  /// Unknown names fall back to [fallback] rather than throwing, so a value
  /// added server-side cannot crash an older build.
  static T _enumOf<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) => other is FoodItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
