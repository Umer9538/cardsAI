import 'package:flutter/foundation.dart';

/// One bout of exercise, as the person recorded it.
///
/// **Logged by hand, not read off a phone or a watch.** A step count from
/// `health`/HealthKit/Health Connect would need a plugin, two platform
/// permission flows, and a privacy disclosure for a second category of health
/// data leaving nothing but the device — and it answers a different question:
/// steps are a background total, while this is "I went for a run". Manual
/// logging also works identically on `BACKEND=local`. Reading the platform is
/// the obvious next step, not a thing this replaces.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.at,
    required this.name,
    required this.minutes,
    required this.kcal,
  });

  final String id;
  final DateTime at;

  /// What was done, in the person's own words or an [ActivityCatalogue] name.
  final String name;
  final int minutes;

  /// Energy spent. Estimated from [ActivityCatalogue] unless it was typed, in
  /// which case it is taken literally — a figure off a treadmill or a watch
  /// beats anything derived from a table.
  final double kcal;

  /// The calendar day this belongs to. Activity **accumulates**, like water
  /// and unlike weight: two walks are two walks.
  DateTime get day => DateTime(at.year, at.month, at.day);

  ActivityEntry copyWith({
    String? id,
    DateTime? at,
    String? name,
    int? minutes,
    double? kcal,
  }) =>
      ActivityEntry(
        id: id ?? this.id,
        at: at ?? this.at,
        name: name ?? this.name,
        minutes: minutes ?? this.minutes,
        kcal: kcal ?? this.kcal,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'name': name,
        'minutes': minutes,
        'kcal': kcal,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        name: json['name'] as String? ?? 'Activity',
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      );
}

/// A day's exercise and what it adds up to.
@immutable
class ActivityLog {
  const ActivityLog({required this.entries});

  /// Oldest first, within one calendar day.
  final List<ActivityEntry> entries;

  static const ActivityLog empty = ActivityLog(entries: []);

  bool get isEmpty => entries.isEmpty;

  int get minutes {
    var total = 0;
    for (final entry in entries) {
      total += entry.minutes;
    }
    return total;
  }

  double get kcal {
    var total = 0.0;
    for (final entry in entries) {
      total += entry.kcal;
    }
    return total;
  }

  /// Progress against the WHO's 150 minutes of moderate activity a week, as
  /// the daily share of it. Clamped, like every other progress figure here.
  double get progress =>
      (minutes / ActivityCatalogue.dailyMinutesTarget).clamp(0.0, 1.0);
}

/// One thing a person can log, and how hard it is.
@immutable
class ActivityKind {
  const ActivityKind({required this.name, required this.met});

  final String name;

  /// Metabolic equivalent of task — the multiple of resting energy this costs.
  /// Values are the *Compendium of Physical Activities* (Ainsworth et al.)
  /// figures for the moderate version of each, rounded to one decimal.
  final double met;
}

/// The list offered when logging, and the arithmetic behind the estimate.
abstract final class ActivityCatalogue {
  /// The WHO recommends 150 minutes of moderate activity a week; this is that
  /// spread over seven days, rounded to a number a card can show. Presented as
  /// this app's own default like the calorie floors — a target, never advice.
  static const int dailyMinutesTarget = 21;

  /// A bout shorter than this is not exercise, it is walking to the kitchen.
  static const int minimumMinutes = 1;

  /// Offered on the sheet, commonest first. Deliberately short: a list of
  /// three hundred activities is a search problem, and anything missing can be
  /// typed with its own name and minutes.
  static const List<ActivityKind> kinds = [
    ActivityKind(name: 'Walking', met: 3.5),
    ActivityKind(name: 'Running', met: 9.8),
    ActivityKind(name: 'Cycling', met: 7.5),
    ActivityKind(name: 'Gym / weights', met: 5.0),
    ActivityKind(name: 'Swimming', met: 5.8),
    ActivityKind(name: 'Football', met: 7.0),
    ActivityKind(name: 'Cricket', met: 4.8),
    ActivityKind(name: 'Yoga', met: 3.0),
    ActivityKind(name: 'Housework', met: 3.3),
    ActivityKind(name: 'Other', met: 4.0),
  ];

  static ActivityKind? byName(String name) {
    for (final kind in kinds) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  /// Energy for [minutes] of [met] at [weightKg].
  ///
  /// `kcal/min = MET x 3.5 x kg / 200` — the standard conversion, and the
  /// reason bodyweight is a parameter rather than an average: the same half
  /// hour costs a 100 kg person twice what it costs a 50 kg one, and a table
  /// of flat numbers would be wrong for nearly everybody.
  ///
  /// It is an **estimate and is labelled as one on the card.** Published
  /// comparisons put consumer estimates of exercise energy 20–90% out, which
  /// is the whole reason [ActivityLog.kcal] is not added back to the day's
  /// calorie budget — see the activity card.
  static double kcalFor({
    required double met,
    required int minutes,
    double? weightKg,
  }) {
    if (minutes <= 0) return 0;
    // 70 kg only when the profile has no weight — the quiz collects one, so
    // this is the skipped-quiz path rather than the normal one.
    final kg = (weightKg == null || weightKg <= 0) ? 70.0 : weightKg;
    return met * 3.5 * kg / 200 * minutes;
  }
}
