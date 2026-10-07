import 'package:flutter/foundation.dart';

import 'unit_system.dart';

/// One drink, recorded at the moment it was drunk.
///
/// Unlike a weight reading, water **accumulates** through the day: a second
/// entry is a second glass, not a correction of the first. So there is no
/// one-per-day rule here — the day's total is the sum, and removing the last
/// entry is how a mistap is undone.
///
/// Stored in millilitres, like every other measurement in this app.
/// [UnitSystem] decides how it is shown; storing whatever the person preferred
/// would put a conversion on every arithmetic site and guarantee one of them
/// eventually forgets.
@immutable
class WaterEntry {
  const WaterEntry({required this.id, required this.at, required this.ml});

  final String id;
  final DateTime at;
  final double ml;

  DateTime get day => DateTime(at.year, at.month, at.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'ml': ml,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        id: json['id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        ml: (json['ml'] as num?)?.toDouble() ?? 0,
      );
}

/// A day's drinks and what they add up to.
@immutable
class WaterLog {
  const WaterLog({required this.entries, required this.targetMl});

  /// Oldest first, within one calendar day.
  final List<WaterEntry> entries;
  final double targetMl;

  static const WaterLog empty =
      WaterLog(entries: [], targetMl: WaterTargets.defaultMl);

  double get totalMl {
    var sum = 0.0;
    for (final entry in entries) {
      sum += entry.ml;
    }
    return sum;
  }

  /// 0..1 for the ring. Clamped, because the arc cannot draw past full — the
  /// caption still shows the real total, so drinking more than the goal is
  /// visible without the geometry breaking.
  double get progress {
    if (targetMl <= 0) return 0;
    return (totalMl / targetMl).clamp(0.0, 1.0);
  }

  bool get isEmpty => entries.isEmpty;

  /// Whole glasses of [WaterTargets.glassMl], rounded down — what the card
  /// counts, because "6 glasses" is what someone remembers drinking.
  int get glasses => (totalMl / WaterTargets.glassMl).floor();

  WaterEntry? get last => entries.isEmpty ? null : entries.last;
}

/// How much water a day should hold, and in what units it is offered.
abstract final class WaterTargets {
  /// One glass. 250 ml is the cup most of the world pictures, and it divides
  /// the default target into a round eight.
  static const double glassMl = 250;

  /// The familiar "eight glasses". It is a rule of thumb rather than a
  /// clinical figure — hence [fromWeight] below, which at least scales with
  /// the person — and it is presented as this app's own default, never as
  /// advice, for the same reason the calorie floors are.
  static const double defaultMl = 2000;

  /// A weight-scaled target, 35 ml per kilogram.
  ///
  /// Closer to how intake actually varies between a 50 kg and a 100 kg person
  /// than one number for everyone. Clamped so neither end produces a figure
  /// that would be silly to put on a ring.
  static double fromWeight(double? kg) {
    if (kg == null || kg <= 0) return defaultMl;
    final scaled = kg * 35;
    return scaled.clamp(1500.0, 4000.0);
  }

  /// Quick-add amounts offered on the card, in millilitres.
  ///
  /// A glass, a small bottle and a large one — the three containers people
  /// actually drink from. Anything finer belongs in a manual entry, and
  /// anything coarser cannot describe a normal day.
  static const List<double> quickAddMl = [250, 500, 750];
}

/// Water-specific display, kept beside [UnitSystem] rather than inside it
/// because volume is the only place these two systems disagree about the
/// *unit* rather than just the number.
extension WaterUnits on UnitSystem {
  /// US customary fluid ounces. The imperial fluid ounce is a different size,
  /// but [UnitSystem.imperial] here means the US convention — it is chosen for
  /// the US, Liberia and Myanmar in `MealClock`'s sibling table.
  static const double _mlPerFlOz = 29.5735;

  String get volumeUnit => isMetric ? 'ml' : 'fl oz';

  double toDisplayVolume(double ml) => isMetric ? ml : ml / _mlPerFlOz;

  double fromDisplayVolume(double value) =>
      isMetric ? value : value * _mlPerFlOz;

  /// The number alone, rounded the way each unit is normally spoken.
  String formatVolume(double ml) =>
      toDisplayVolume(ml).round().toString();

  String volumeWithUnit(double ml) => '${formatVolume(ml)} $volumeUnit';
}
