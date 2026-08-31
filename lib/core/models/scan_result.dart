import 'package:flutter/foundation.dart';

import 'food_item.dart';
import 'meal.dart';
import 'nutrition.dart';

/// How a scan was started. Photo is the hero path; the rest exist because
/// photos fail in restaurants and low light.
enum ScanInput { photo, barcode, gallery, text, search }

/// What the pipeline returned for one capture.
///
/// Holds the model's own output. Editing happens on the [Meal] built from it, so
/// the original estimate survives for the eval set even after someone corrects
/// a portion.
@immutable
class ScanResult {
  const ScanResult({
    required this.id,
    required this.capturedAt,
    required this.items,
    this.input = ScanInput.photo,
    this.photoPath,
    this.confidence = FoodConfidence.unknown,
    this.clarifyingQuestion,
    this.modelId,
    this.latencyMs,
  });

  final String id;
  final DateTime capturedAt;
  final List<FoodItem> items;
  final ScanInput input;

  /// Local file path of the capture, before any upload.
  final String? photoPath;

  /// The model's confidence in the scan as a whole.
  final FoodConfidence confidence;

  /// Set when the model could not identify the plate and needs a hint. The UI
  /// turns this into the "Help me out — what is this?" prompt.
  final String? clarifyingQuestion;

  /// Which model produced this, for cost and accuracy tracking. Server-side
  /// config, so it varies without an app release.
  final String? modelId;

  final int? latencyMs;

  Nutrition get nutrition =>
      Nutrition.sum(items.map((item) => item.nutrition));

  /// True when the scan should route to the "describe it" fallback rather than
  /// showing a result the user cannot trust.
  bool get needsClarification =>
      items.isEmpty || clarifyingQuestion != null;

  /// Turns the result into a loggable meal. The scan itself is unchanged, so
  /// later edits to the meal never rewrite the original estimate.
  Meal toMeal({
    required String id,
    DateTime? eatenAt,
    bool favourite = false,
  }) =>
      Meal(
        id: id,
        eatenAt: eatenAt ?? capturedAt,
        items: items,
        photoPath: photoPath,
        scanId: this.id,
        favourite: favourite,
      );

  ScanResult copyWith({List<FoodItem>? items}) => ScanResult(
        id: id,
        capturedAt: capturedAt,
        items: items ?? this.items,
        input: input,
        photoPath: photoPath,
        confidence: confidence,
        clarifyingQuestion: clarifyingQuestion,
        modelId: modelId,
        latencyMs: latencyMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'capturedAt': capturedAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'input': input.name,
        'photoPath': photoPath,
        'confidence': confidence.name,
        'clarifyingQuestion': clarifyingQuestion,
        'modelId': modelId,
        'latencyMs': latencyMs,
      };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        id: json['id'] as String,
        capturedAt:
            DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
                DateTime.now(),
        items: (json['items'] as List? ?? const [])
            .map((e) => FoodItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        input: ScanInput.values
                .where((i) => i.name == json['input'])
                .firstOrNull ??
            ScanInput.photo,
        photoPath: json['photoPath'] as String?,
        confidence: FoodConfidence.values
                .where((c) => c.name == json['confidence'])
                .firstOrNull ??
            FoodConfidence.unknown,
        clarifyingQuestion: json['clarifyingQuestion'] as String?,
        modelId: json['modelId'] as String?,
        latencyMs: (json['latencyMs'] as num?)?.toInt(),
      );
}
