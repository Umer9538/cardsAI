import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'meal_clock.dart';

/// Where a reminder's time came from.
///
/// Rendered in Settings, because a time the app made up and a time it learned
/// are different promises and the person is entitled to know which they have.
enum ReminderSource {
  /// A time the person set themselves. Beats everything below: it is a
  /// statement of intent, not an inference from what they happened to do.
  chosen,

  /// The median of their own logged meals — the best signal the app can derive
  /// on its own, and the one the evidence below is about.
  observed,

  /// A starting time, until one of the above exists.
  suggested,
}

/// One reminder: which meal, what time of day, and where the time came from.
@immutable
class MealReminder {
  const MealReminder({
    required this.slot,
    required this.hour,
    required this.minute,
    this.source = ReminderSource.observed,
    this.loggedToday = false,
  });

  final MealSlot slot;
  final int hour;
  final int minute;
  final ReminderSource source;

  /// Whether this meal is already in today's diary.
  ///
  /// The scheduler uses it to start the daily repeat tomorrow instead. A
  /// reminder to log the lunch you logged an hour ago is the one that teaches
  /// people the notifications are not worth reading.
  final bool loggedToday;

  int get id => 100 + slot.index;

  /// Minutes from midnight — the form the preferences and the tests use.
  int get minuteOfDay => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is MealReminder &&
      other.slot == slot &&
      other.hour == hour &&
      other.minute == minute &&
      other.source == source &&
      other.loggedToday == loggedToday;

  @override
  int get hashCode => Object.hash(slot, hour, minute, source, loggedToday);

  @override
  String toString() =>
      '${slot.name} at ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')} (${source.name})';
}

/// Which slots a person wants reminding about, and when.
///
/// Held apart from the diary because these are answers, not observations: a
/// time someone typed and a meal they switched off are the two things the
/// arithmetic below must never overrule.
@immutable
class ReminderPreferences {
  const ReminderPreferences({
    this.times = const {},
    this.off = const {},
  });

  /// Minute of the day the person chose for a slot. Absent means "work it out".
  final Map<MealSlot, int> times;

  /// Slots switched off individually. Someone who does not eat breakfast should
  /// not have to turn off all three to stop being asked about it.
  final Set<MealSlot> off;

  bool isEnabled(MealSlot slot) => !off.contains(slot);

  int? chosenFor(MealSlot slot) => times[slot];

  ReminderPreferences withTime(MealSlot slot, int? minuteOfDay) {
    final next = Map<MealSlot, int>.of(times);
    if (minuteOfDay == null) {
      next.remove(slot);
    } else {
      next[slot] = minuteOfDay;
    }
    return ReminderPreferences(times: next, off: off);
  }

  ReminderPreferences withEnabled(MealSlot slot, {required bool enabled}) {
    final next = Set<MealSlot>.of(off);
    if (enabled) {
      next.remove(slot);
    } else {
      next.add(slot);
    }
    return ReminderPreferences(times: times, off: next);
  }

  Map<String, dynamic> toJson() => {
        'times': {for (final e in times.entries) e.key.name: e.value},
        'off': [for (final slot in off) slot.name],
      };

  /// Anything unrecognised is dropped rather than throwing: this is read on the
  /// path that also schedules, and a preferences blob written by a later build
  /// must not cost someone their reminders.
  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    MealSlot? slotNamed(String name) {
      for (final slot in MealSlot.values) {
        if (slot.name == name) return slot;
      }
      return null;
    }

    final times = <MealSlot, int>{};
    final raw = json['times'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final slot = slotNamed('${entry.key}');
        final minute = entry.value;
        if (slot == null || minute is! num) continue;
        final value = minute.toInt();
        if (value < 0 || value >= 24 * 60) continue;
        times[slot] = value;
      }
    }

    final off = <MealSlot>{};
    final rawOff = json['off'];
    if (rawOff is List) {
      for (final name in rawOff) {
        final slot = slotNamed('$name');
        if (slot != null) off.add(slot);
      }
    }

    return ReminderPreferences(times: times, off: off);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      mapEquals(other.times, times) &&
      setEquals(other.off, off);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(times.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAllUnordered(off),
      );
}

/// Works out when to remind someone about a meal.
///
/// **This is the whole feature, and it is not a detail.** Prompts timed to a
/// person's own meals raised food-photo capture from 2.8 to 4.6 images a day
/// (p≤.001); generic fixed-time prompts produced +0.83 at p=.23 — no effect.
/// So the observed median is what this reaches for first, and it is worth the
/// notification permission.
///
/// **It used to reach for that and nothing else, and therefore reminded nobody.**
/// A slot needs [minimumSamples] logged meals before a median means anything,
/// so a new account got an empty schedule — and the diary that would have
/// filled it is the thing the reminders exist to produce. Reminders arrived
/// only for people who had already built the habit unprompted, which is the one
/// group that does not need them.
///
/// The way out is the one every app in this category takes: start from a
/// suggested time, let the person correct it, and replace it with their own
/// median once there is one. That is not the generic prompt the trial measured
/// — a fixed 8am ping nobody can move — because it is [ReminderSource.chosen]
/// as soon as anyone touches it, and [ReminderSource.observed] as soon as the
/// diary can say better.
abstract final class ReminderSchedule {
  /// Slots that get a reminder. Snacks do not: they have no time of day worth
  /// predicting, and a fourth notification is how people turn all of them off.
  static const List<MealSlot> slots = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
  ];

  /// Days of history to learn from.
  static const int window = 28;

  /// A slot needs this many logged meals before its median is worth using.
  ///
  /// Below it the median is one or two mornings, which is a habit the app has
  /// invented rather than observed — so a [suggested] time is used instead,
  /// which at least does not claim to be about this person.
  static const int minimumSamples = 3;

  /// Minutes after the usual time. Reminding at the median is reminding of
  /// something already done; the point is the day it is running late.
  ///
  /// It applies to both *derived* rungs — the observed median and the country
  /// pattern in [MealClock] — because both of those say when someone eats, and
  /// a time to eat has to be turned into a time to remind. A [chosen] time is
  /// already the time to remind: it is what the person typed into a screen that
  /// says "remind me at".
  static const int graceMinutes = 45;

  /// The reminders to schedule for [meals].
  ///
  /// [clock] supplies the bottom rung — where a slot starts before this person
  /// has a diary of their own. It defaults to [MealClock.fallback] so the pure
  /// function stays callable with no context; the app passes the device's own.
  static List<MealReminder> from(
    List<Meal> meals, {
    ReminderPreferences preferences = const ReminderPreferences(),
    MealClock clock = MealClock.fallback,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final since = today.subtract(const Duration(days: window));
    final midnight = DateTime(today.year, today.month, today.day);

    final byslot = <MealSlot, List<int>>{};
    final loggedToday = <MealSlot>{};
    for (final meal in meals) {
      if (!slots.contains(meal.slot)) continue;
      if (!meal.eatenAt.isBefore(midnight)) loggedToday.add(meal.slot);
      if (meal.eatenAt.isBefore(since)) continue;
      byslot
          .putIfAbsent(meal.slot, () => [])
          .add(meal.eatenAt.hour * 60 + meal.eatenAt.minute);
    }

    final reminders = <MealReminder>[];
    for (final slot in slots) {
      if (!preferences.isEnabled(slot)) continue;

      final at = _timeFor(slot, byslot[slot], preferences, clock);

      // Past midnight is nobody's meal reminder.
      if (at.minuteOfDay >= 24 * 60) continue;
      reminders.add(
        MealReminder(
          slot: slot,
          hour: at.minuteOfDay ~/ 60,
          minute: at.minuteOfDay % 60,
          source: at.source,
          loggedToday: loggedToday.contains(slot),
        ),
      );
    }
    return reminders;
  }

  /// The best time available for one slot, and what makes it the best.
  static ({int minuteOfDay, ReminderSource source}) _timeFor(
    MealSlot slot,
    List<int>? times,
    ReminderPreferences preferences,
    MealClock clock,
  ) {
    final chosen = preferences.chosenFor(slot);
    if (chosen != null) {
      return (minuteOfDay: chosen, source: ReminderSource.chosen);
    }

    if (times != null && times.length >= minimumSamples) {
      // Median, not mean: one 2am snack logged as breakfast would drag a mean
      // across the whole morning, and the median simply ignores it.
      times.sort();
      return (
        minuteOfDay: times[times.length ~/ 2] + graceMinutes,
        source: ReminderSource.observed,
      );
    }

    return (
      minuteOfDay: clock[slot] + graceMinutes,
      source: ReminderSource.suggested,
    );
  }

  /// The notification's title — the meal, and nothing else.
  ///
  /// Android already prints the app name above it and iOS beside it, so
  /// "Carbs AI · Lunch" would say Carbs AI twice. What someone glancing at a
  /// crowded lock screen needs from the bold line is which meal it is about.
  static String title(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => 'Breakfast',
        MealSlot.lunch => 'Lunch',
        MealSlot.dinner => 'Dinner',
        MealSlot.snack => 'Snack',
      };

  /// What the notification says under the title.
  ///
  /// Neutral, and deliberately so. Reviewers of this category describe
  /// guilt-worded reminders — a mascot pleading, a streak about to break — as
  /// the reason they turned notifications off for good, and a notification
  /// nobody receives is worth less than none at all. There is nothing here
  /// about falling behind, no number, and no exclamation mark.
  ///
  /// It rotates because the failure mode of a daily notification is not
  /// annoyance, it is invisibility: the identical sentence at the identical
  /// time becomes furniture inside a week and stops being read at all. Each
  /// line says the same thing in a different way, and every one of them is
  /// about the single action this app is for.
  ///
  /// Keyed on the day of the year rather than shuffled, so it is a pure
  /// function and a test can pin it. **It changes when the schedule is
  /// rewritten, not at midnight** — the OS holds the text of a repeating
  /// notification until something reschedules it, which the app does whenever
  /// it opens and whenever a meal is logged. Someone using the app sees the
  /// rotation; someone who has stopped sees one line, which is the right way
  /// round.
  static const Map<MealSlot, List<String>> _bodies = {
    MealSlot.breakfast: [
      'Snap it before the plate is empty.',
      'One photo now, and breakfast is logged.',
      'A photo takes less time than remembering at noon.',
      'Point the camera at it and Carbs AI does the rest.',
    ],
    MealSlot.lunch: [
      'Snap your lunch before it disappears.',
      'One photo now, and lunch is logged.',
      'Quicker to photograph than to reconstruct tonight.',
      'Point the camera at it and Carbs AI does the rest.',
    ],
    MealSlot.dinner: [
      'Snap it while it is still on the plate.',
      'One photo now, and dinner is logged.',
      'A photo tonight saves rebuilding the day tomorrow.',
      'Point the camera at it and Carbs AI does the rest.',
    ],
    MealSlot.snack: [
      'One photo now, and it is logged.',
    ],
  };

  static String body(MealSlot slot, {DateTime? on}) {
    final lines = _bodies[slot]!;
    final day = on ?? DateTime.now();
    // Day of the year. A DST boundary can move this by one, which changes
    // which line shows and nothing else.
    final index = day.difference(DateTime(day.year)).inDays;
    return lines[index % lines.length];
  }
}

/// A weekly weigh-in prompt.
///
/// Weight is the outcome the app keeps promising — the plan screen renders
/// "On track for X kg by DATE" — and `WeightHistory` needs readings to compute
/// a trend from. Nothing in the app ever asked for one, so the trend stayed
/// empty for anyone who did not think to open the card themselves.
///
/// Weekly rather than daily on purpose. The card already leads with a seven-day
/// mean because body weight swings a kilo a day on water alone, so a daily
/// prompt would be asking for readings the trend deliberately smooths away —
/// and four more notifications a week is how people turn all of them off.
@immutable
class WeightReminder {
  const WeightReminder({
    required this.weekday,
    required this.hour,
    required this.minute,
    this.loggedThisWeek = false,
  });

  /// `DateTime.monday`..`DateTime.sunday`.
  final int weekday;
  final int hour;
  final int minute;

  /// Whether a reading was already recorded in the current week.
  ///
  /// Same reasoning as [MealReminder.loggedToday]: a prompt to do the thing
  /// you did this morning is the one that teaches people to stop reading them.
  final bool loggedThisWeek;

  /// Distinct from the meal ids, which are `100 + slot.index`.
  static const int notificationId = 200;

  int get minuteOfDay => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is WeightReminder &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute &&
      other.loggedThisWeek == loggedThisWeek;

  @override
  int get hashCode => Object.hash(weekday, hour, minute, loggedThisWeek);

  @override
  String toString() => 'weigh-in on weekday $weekday at '
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// When to ask for a weigh-in, and whether to bother this week.
abstract final class WeighInSchedule {
  /// Sunday morning. A weight taken on the same weekday each time is the one
  /// worth comparing, and the weekend is when someone is home and unhurried.
  static const int defaultWeekday = DateTime.sunday;
  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  /// Ships **off**, like every other notification in this app: an account that
  /// never answered the question has not agreed to be messaged.
  static const bool defaultEnabled = false;

  /// The reminder to schedule, or null when it is switched off.
  ///
  /// [entries] is the weight history; only whether one falls in the current
  /// week matters here.
  static WeightReminder? from({
    required bool enabled,
    List<WeightEntry> entries = const [],
    int weekday = defaultWeekday,
    int hour = defaultHour,
    int minute = defaultMinute,
    DateTime? now,
  }) {
    if (!enabled) return null;

    final today = now ?? DateTime.now();
    return WeightReminder(
      weekday: weekday,
      hour: hour,
      minute: minute,
      loggedThisWeek: entries.any((e) => _sameWeek(e.at, today)),
    );
  }

  /// Monday-start weeks, matching `DateTime.weekday`'s own numbering.
  static bool _sameWeek(DateTime a, DateTime b) {
    DateTime startOf(DateTime d) {
      final midnight = DateTime(d.year, d.month, d.day);
      return midnight.subtract(Duration(days: midnight.weekday - 1));
    }

    return startOf(a) == startOf(b);
  }

  static const String title = 'Weekly weigh-in';

  /// No number and no judgement: the app does not know whether this person is
  /// cutting or gaining, and a reminder that congratulates or scolds is the
  /// one that gets switched off.
  static const String body = 'Step on the scale to keep your trend moving.';
}


/// The weekly weigh-in's on/off, weekday and time.
@immutable
class WeighInPreference {
  const WeighInPreference({
    this.enabled = WeighInSchedule.defaultEnabled,
    this.weekday = WeighInSchedule.defaultWeekday,
    this.hour = WeighInSchedule.defaultHour,
    this.minute = WeighInSchedule.defaultMinute,
  });

  final bool enabled;
  final int weekday;
  final int hour;
  final int minute;

  int get minuteOfDay => hour * 60 + minute;

  WeighInPreference copyWith({
    bool? enabled,
    int? weekday,
    int? minuteOfDay,
  }) =>
      WeighInPreference(
        enabled: enabled ?? this.enabled,
        weekday: weekday ?? this.weekday,
        hour: minuteOfDay == null ? hour : minuteOfDay ~/ 60,
        minute: minuteOfDay == null ? minute : minuteOfDay % 60,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
      };

  factory WeighInPreference.fromJson(Map<String, dynamic> json) {
    int clamp(Object? value, int fallback, int low, int high) {
      final n = value is num ? value.toInt() : fallback;
      return n < low || n > high ? fallback : n;
    }

    return WeighInPreference(
      enabled: json['enabled'] == true,
      weekday: clamp(json['weekday'], WeighInSchedule.defaultWeekday, 1, 7),
      hour: clamp(json['hour'], WeighInSchedule.defaultHour, 0, 23),
      minute: clamp(json['minute'], WeighInSchedule.defaultMinute, 0, 59),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeighInPreference &&
      other.enabled == enabled &&
      other.weekday == weekday &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, weekday, hour, minute);
}

/// A nudge to drink something.
@immutable
class WaterReminder {
  const WaterReminder({required this.index, required this.minuteOfDay});

  /// 0-based position in the day's run, which also gives the notification id.
  final int index;
  final int minuteOfDay;

  int get hour => minuteOfDay ~/ 60;
  int get minute => minuteOfDay % 60;

  /// Above the meal ids (100+) and the weigh-in (200).
  int get id => 300 + index;

  @override
  bool operator ==(Object other) =>
      other is WaterReminder &&
      other.index == index &&
      other.minuteOfDay == minuteOfDay;

  @override
  int get hashCode => Object.hash(index, minuteOfDay);

  @override
  String toString() => 'water at ${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

/// When to nudge about water.
///
/// Spread across the person's **own eating window** rather than a fixed
/// office day: the window is bounded by their first and last meal reminder,
/// which are already derived from when they actually eat. Someone who eats
/// breakfast at 06:00 and someone who eats dinner at 22:00 should not get the
/// same six pings.
abstract final class WaterSchedule {
  /// Ships off, like every other notification here.
  static const bool defaultEnabled = false;

  /// Most a day can carry. Six is NutriPal's figure and it is a reasonable
  /// ceiling — past that the notifications are the thing you notice, not the
  /// water.
  static const int maxPerDay = 6;

  /// Never closer together than this, so they cannot bunch up when the
  /// eating window is short.
  static const int minimumGapMinutes = 60;

  /// Fallback window when there is nothing to derive one from — roughly
  /// waking hours, and only used before any reminder times exist.
  static const int fallbackStartMinute = 8 * 60;
  static const int fallbackEndMinute = 21 * 60;

  static const String title = 'Water';
  static const String body = 'Time for a glass.';

  /// [count] reminders between the first and last of [mealTimes].
  ///
  /// Returns fewer than [count] when the window is too short to hold them at
  /// [minimumGapMinutes] apart — bunched reminders are worse than fewer.
  static List<WaterReminder> from({
    required bool enabled,
    List<int> mealTimes = const [],
    int count = 4,
  }) {
    if (!enabled || count <= 0) return const [];

    final times = [...mealTimes]..sort();
    final start = times.isEmpty ? fallbackStartMinute : times.first;
    final end = times.isEmpty ? fallbackEndMinute : times.last;
    if (end <= start) return const [];

    final wanted = count.clamp(1, maxPerDay);
    // Fenceposts: `wanted` reminders need `wanted + 1` intervals so neither
    // the first nor the last lands exactly on a meal reminder — two
    // notifications in the same minute read as one duplicate.
    final step = (end - start) / (wanted + 1);
    if (step < minimumGapMinutes) {
      final fits = ((end - start) / minimumGapMinutes).floor() - 1;
      if (fits < 1) return const [];
      return from(enabled: true, mealTimes: mealTimes, count: fits);
    }

    return [
      for (var i = 1; i <= wanted; i++)
        WaterReminder(
          index: i - 1,
          minuteOfDay: (start + step * i).round(),
        ),
    ];
  }
}

/// The water nudges' own settings.
///
/// Only two knobs, deliberately: on, and how many. The *times* are derived
/// from the eating window rather than chosen, because six times is six pickers
/// and nobody fills those in — and a time the app derived can move with the
/// person, which a chosen one cannot.
@immutable
class WaterPreference {
  const WaterPreference({
    this.enabled = WaterSchedule.defaultEnabled,
    this.count = 4,
  });

  final bool enabled;
  final int count;

  WaterPreference copyWith({bool? enabled, int? count}) => WaterPreference(
        enabled: enabled ?? this.enabled,
        count: count ?? this.count,
      );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'count': count};

  factory WaterPreference.fromJson(Map<String, dynamic> json) {
    final stored = json['count'];
    final count = stored is num ? stored.toInt() : 4;
    return WaterPreference(
      enabled: json['enabled'] == true,
      count: count < 1 || count > WaterSchedule.maxPerDay ? 4 : count,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaterPreference &&
      other.enabled == enabled &&
      other.count == count;

  @override
  int get hashCode => Object.hash(enabled, count);
}

/// The nightly "how did today go" nudge.
class DaySummaryReminder {
  const DaySummaryReminder({required this.hour, required this.minute});

  final int hour;
  final int minute;

  /// Clear of the meal ids (100-102), the weigh-in (200) and water (300+).
  static const int notificationId = 201;

  int get minuteOfDay => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is DaySummaryReminder &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'day summary at '
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// When to ask someone to look at their day, and what it is allowed to say.
///
/// **It carries no number, and that is the whole design.** A scheduled local
/// notification's text is fixed when it is scheduled, hours before it fires —
/// so "you are 300 under today" would be a figure from this morning read out
/// at night, wrong the moment anything else was logged. The same reason the
/// meal reminders carry none. The personal part is on the other side of the
/// tap: the in-app feed recomputes from the diary the instant the app opens,
/// and that is where the real figures are.
abstract final class DaySummarySchedule {
  /// Two hours after dinner, which is the app's own guess at "the eating is
  /// done" — derived from the person's dinner reminder, which is itself either
  /// their logged median or their country's pattern.
  static const int afterDinnerMinutes = 120;

  /// Never later than this. Past it the notification is one someone reads in
  /// the morning, about a day they can no longer act on, and it will have been
  /// sitting on the lock screen through the night.
  static const int latestMinuteOfDay = 22 * 60 + 30;

  /// And never earlier, however early the dinner pattern is: Stockholm eats at
  /// 17:30, and a "how did today go" at 19:30 arrives before the evening has
  /// happened.
  static const int earliestMinuteOfDay = 20 * 60;

  static const String title = 'Today so far';
  static const String body =
      'Open Carbs AI to see how the day went against your target.';

  /// The reminder to schedule, or null when the category is off.
  ///
  /// [mealReminders] is the schedule already computed for the day; the dinner
  /// entry is the only one that matters. With no dinner reminder — someone who
  /// switched that slot off — it falls back to the earliest sensible hour
  /// rather than guessing a pattern of its own.
  static DaySummaryReminder? from({
    required bool enabled,
    List<MealReminder> mealReminders = const [],
    DateTime? now,
  }) {
    if (!enabled) return null;

    final dinner = mealReminders
        .where((r) => r.slot == MealSlot.dinner)
        .firstOrNull;

    final at = dinner == null
        ? earliestMinuteOfDay
        : (dinner.minuteOfDay + afterDinnerMinutes)
            .clamp(earliestMinuteOfDay, latestMinuteOfDay);

    return DaySummaryReminder(hour: at ~/ 60, minute: at % 60);
  }
}
