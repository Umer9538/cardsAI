import 'package:flutter/foundation.dart';

import 'food_item.dart';
import 'nutrition.dart';

/// Which part of the day a meal belongs to. Assigned from the clock at capture
/// time and editable afterwards.
enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  /// The slot a meal logged at [time] falls into.
  ///
  /// Boundaries are the conventional ones; anything outside them is a snack
  /// rather than being forced into the nearest meal.
  static MealSlot forTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return MealSlot.breakfast;
    if (hour >= 11 && hour < 16) return MealSlot.lunch;
    if (hour >= 16 && hour < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }

  String get label => switch (this) {
        MealSlot.breakfast => 'Breakfast',
        MealSlot.lunch => 'Lunch',
        MealSlot.dinner => 'Dinner',
        MealSlot.snack => 'Snack',
      };
}

/// A logged meal: one or more foods eaten at a point in time.
@immutable
class Meal {
  Meal({
    required this.id,
    required this.eatenAt,
    required this.items,
    MealSlot? slot,
    this.photoPath,
    this.scanId,
    this.title,
    this.favourite = false,
  }) : slot = slot ?? MealSlot.forTime(eatenAt);

  final String id;
  final DateTime eatenAt;
  final List<FoodItem> items;
  final MealSlot slot;

  /// Local file path or remote URL of the capture, when there was one.
  final String? photoPath;

  /// Links back to the scan that produced this meal, for the eval pipeline.
  final String? scanId;

  /// Overrides the derived [name] when someone titles the meal themselves.
  final String? title;

  /// Kept for one-tap re-logging. People eat the same breakfast for months, and
  /// re-photographing it every morning is the fastest way to lose them.
  final bool favourite;

  /// Sum of every item — the figure the diary and the budget ring use.
  Nutrition get nutrition =>
      Nutrition.sum(items.map((item) => item.nutrition));

  /// A display name: the explicit title, else the items read out, else the slot.
  String get name {
    if (title != null && title!.isNotEmpty) return title!;
    if (items.isEmpty) return slot.label;
    if (items.length == 1) return items.first.name;
    return '${items.first.name} +${items.length - 1}';
  }

  /// Midnight local on the day this meal counts against. The diary groups on
  /// this, so a meal at 00:30 lands on the new day exactly as the clock says.
  DateTime get day => DateTime(eatenAt.year, eatenAt.month, eatenAt.day);

  Meal copyWith({
    String? id,
    DateTime? eatenAt,
    List<FoodItem>? items,
    MealSlot? slot,
    String? photoPath,
    String? scanId,
    String? title,
    bool? favourite,
  }) =>
      Meal(
        id: id ?? this.id,
        eatenAt: eatenAt ?? this.eatenAt,
        items: items ?? this.items,
        slot: slot ?? this.slot,
        photoPath: photoPath ?? this.photoPath,
        scanId: scanId ?? this.scanId,
        title: title ?? this.title,
        favourite: favourite ?? this.favourite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'eatenAt': eatenAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'slot': slot.name,
        'photoPath': photoPath,
        'scanId': scanId,
        'title': title,
        'favourite': favourite,
      };

  factory Meal.fromJson(Map<String, dynamic> json) {
    final eatenAt =
        DateTime.tryParse(json['eatenAt'] as String? ?? '') ?? DateTime.now();
    return Meal(
      id: json['id'] as String,
      eatenAt: eatenAt,
      items: (json['items'] as List? ?? const [])
          .map((e) => FoodItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      slot: MealSlot.values
          .where((s) => s.name == json['slot'])
          .firstOrNull,
      photoPath: json['photoPath'] as String?,
      scanId: json['scanId'] as String?,
      title: json['title'] as String?,
      favourite: json['favourite'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) => other is Meal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
