import 'package:flutter/foundation.dart';

/// One weight reading.
///
/// Calories are the input; weight is the outcome, and the outcome is the only
/// thing that tells someone whether any of this is working. The quiz collects a
/// goal weight and the plan screen renders "On track for X kg by DATE" — so the
/// app has been making a falsifiable prediction with no way for anyone to
/// falsify it.
///
/// Stored in kilograms, like every other body measurement here. `UnitSystem`
/// decides how it is shown.
@immutable
class WeightEntry {
  const WeightEntry({required this.id, required this.at, required this.kg});

  final String id;
  final DateTime at;
  final double kg;

  /// The calendar day this belongs to, so one day holds one reading.
  DateTime get day => DateTime(at.year, at.month, at.day);

  WeightEntry copyWith({String? id, DateTime? at, double? kg}) =>
      WeightEntry(id: id ?? this.id, at: at ?? this.at, kg: kg ?? this.kg);

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'kg': kg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        kg: (json['kg'] as num?)?.toDouble() ?? 0,
      );
}

/// Readings in order, with the arithmetic the screens need.
///
/// A separate type rather than helpers on a list, because every one of these is
/// a decision about how to read a noisy signal, and they should be made once.
@immutable
class WeightHistory {
  const WeightHistory(this.entries);

  /// Oldest first.
  final List<WeightEntry> entries;

  static const WeightHistory empty = WeightHistory([]);

  bool get isEmpty => entries.isEmpty;

  WeightEntry? get latest => entries.isEmpty ? null : entries.last;

  /// The **trend**, not the last reading.
  ///
  /// Body weight swings a kilo or more day to day on water alone, so the last
  /// number is the worst available estimate of where someone actually is — and
  /// it is the number that makes people give up on a working plan. A seven-day
  /// mean is what every serious tracker shows instead.
  double? get trendKg {
    if (entries.isEmpty) return null;
    final since = entries.last.at.subtract(const Duration(days: 7));
    final window =
        entries.where((e) => !e.at.isBefore(since)).toList();
    if (window.isEmpty) return entries.last.kg;
    return window.fold(0.0, (sum, e) => sum + e.kg) / window.length;
  }

  /// Change over the window, trend to trend rather than reading to reading.
  ///
  /// Null until there is enough history for the comparison to mean anything —
  /// "you lost 1.4 kg" from two readings a day apart is noise presented as
  /// progress.
  double? changeOver(Duration window) {
    if (entries.length < 2) return null;
    final end = entries.last.at;
    final cutoff = end.subtract(window);
    final before = entries.where((e) => e.at.isBefore(cutoff)).toList();
    if (before.isEmpty) return null;

    final earlier = before.length > 7
        ? before.sublist(before.length - 7)
        : before;
    final earlierMean =
        earlier.fold(0.0, (sum, e) => sum + e.kg) / earlier.length;
    final now = trendKg;
    if (now == null) return null;
    return now - earlierMean;
  }
}
