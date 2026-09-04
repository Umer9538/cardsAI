import 'package:flutter/foundation.dart';

import '../nutrition/dish_taxonomy.dart';

/// Hard constraints. Photos cannot express an allergy, so these are asked as
/// chips rather than inferred.
///
/// The `words` on each one are what the server scans a returned plan for: a
/// plan that names any of them after the person said to leave it out is
/// rejected before it reaches them. The lists are deliberately generous —
/// "paneer" is dairy whether or not the model thinks of it that way.
enum Avoidance {
  beef('Beef', ['beef', 'steak', 'mince', 'burger', 'brisket', 'nihari']),
  pork('Pork', ['pork', 'bacon', 'ham', 'sausage', 'salami', 'prosciutto']),
  dairy('Dairy', [
    'milk',
    'cheese',
    'yoghurt',
    'yogurt',
    'butter',
    'cream',
    'paneer',
    'ghee',
    'lassi',
    'raita',
  ]),
  gluten('Gluten', [
    'bread',
    'toast',
    'roti',
    'naan',
    'chapati',
    'paratha',
    'pasta',
    'noodle',
    'wheat',
    'wrap',
    'tortilla',
    'pita',
    'couscous',
    'bulgur',
  ]),
  nuts('Nuts', ['almond', 'peanut', 'cashew', 'walnut', 'pistachio', 'hazelnut', 'pecan']),
  eggs('Eggs', ['egg', 'omelette', 'omelet', 'frittata', 'shakshuka']),
  seafood('Seafood', [
    'fish',
    'salmon',
    'tuna',
    'prawn',
    'shrimp',
    'cod',
    'sardine',
    'mackerel',
    'crab',
    'squid',
    'anchov',
  ]);

  const Avoidance(this.label, this.words);

  final String label;
  final List<String> words;
}

/// How much time there is to cook. Asked directly: time scarcity is a measured
/// barrier to eating a plan, and a day of 45-minute dinners for someone with 15
/// is a plan that gets abandoned.
enum CookTime {
  under15('Under 15 min', 'Quick things, mostly assembled', 15),
  upTo30('15–30 min', 'A proper cook, but not a project', 30),
  likesCooking('I like cooking', 'Time is not the constraint', 60),
  eatingOut('Mostly eating out', 'Point me at good choices', 0);

  const CookTime(this.label, this.detail, this.maxMinutes);

  final String label;
  final String detail;

  /// Ceiling per meal the prompt is given. Zero means "assume no cooking".
  final int maxMinutes;
}

/// The person's taste, as the plan builder learned it.
///
/// This is the *taste* half of the plan. The nutrition half — calories, macros,
/// meals a day, diet type — is never in here: the server reads those from the
/// profile, where `TargetCalculator`'s floors live, so a client cannot ask the
/// model to plan around numbers the app would refuse to compute.
@immutable
class TasteProfile {
  const TasteProfile({
    this.liked = const [],
    this.leaning = const {},
    this.avoid = const {},
    this.cookTime,
    this.notes = '',
  });

  /// Dish ids from [DishTaxonomy] the person tapped as looking good.
  final List<String> liked;

  /// The pole chosen on each axis they answered. Unanswered axes are absent.
  final Map<TasteAxis, TastePole> leaning;

  final Set<Avoidance> avoid;
  final CookTime? cookTime;

  /// The escape hatch. Photos miss things — "spicy" was the worst-missed
  /// dimension in the study this is built on — and this is where they land.
  final String notes;

  static const TasteProfile empty = TasteProfile();

  bool get isEmpty =>
      liked.isEmpty &&
      leaning.isEmpty &&
      avoid.isEmpty &&
      cookTime == null &&
      notes.trim().isEmpty;

  /// Cuisines represented among the liked dishes, most-liked first.
  List<Cuisine> get cuisines {
    final counts = <Cuisine, int>{};
    for (final id in liked) {
      final dish = DishTaxonomy.byId(id);
      if (dish != null) counts.update(dish.cuisine, (n) => n + 1, ifAbsent: () => 1);
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted;
  }

  /// Short chips describing what the plan was built for — shown on the build
  /// step as it assembles, and on the finished plan so it stops looking like
  /// another catalogue card.
  ///
  /// Order is the order a person would say it: what they eat, then what they
  /// leave out, then how much time they have.
  List<String> get summary {
    final out = <String>[];

    final top = cuisines.take(2).map((c) => c.label).toList();
    if (top.isNotEmpty) out.add(top.join(' & '));

    for (final entry in leaning.entries) {
      final chip = entry.value.chip;
      if (chip != null) out.add(chip);
    }

    if (avoid.isNotEmpty) {
      out.add('No ${avoid.map((a) => a.label.toLowerCase()).join(', ')}');
    }

    if (cookTime != null && cookTime != CookTime.likesCooking) {
      out.add(cookTime!.label);
    }

    return out;
  }

  TasteProfile copyWith({
    List<String>? liked,
    Map<TasteAxis, TastePole>? leaning,
    Set<Avoidance>? avoid,
    CookTime? cookTime,
    bool clearCookTime = false,
    String? notes,
  }) =>
      TasteProfile(
        liked: liked ?? this.liked,
        leaning: leaning ?? this.leaning,
        avoid: avoid ?? this.avoid,
        cookTime: clearCookTime ? null : (cookTime ?? this.cookTime),
        notes: notes ?? this.notes,
      );

  /// The wire shape. Every value is a stable id or enum name that the Worker
  /// validates against the same vocabulary — never a label, never free text
  /// except [notes], which the server clamps.
  Map<String, dynamic> toJson() => {
        'liked': liked,
        'leaning': {
          for (final entry in leaning.entries) entry.key.name: entry.value.name,
        },
        'avoid': [for (final a in avoid) a.name],
        'cookTime': cookTime?.name,
        'notes': notes.trim(),
      };

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    final leaning = <TasteAxis, TastePole>{};
    final rawLeaning = (json['leaning'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in rawLeaning.entries) {
      final axis = TasteAxis.values.where((a) => a.name == entry.key).firstOrNull;
      if (axis == null) continue;
      final pole = axis.poles.where((p) => p.name == entry.value).firstOrNull;
      if (pole != null) leaning[axis] = pole;
    }
    return TasteProfile(
      liked: [for (final v in (json['liked'] as List? ?? const [])) v as String],
      leaning: leaning,
      avoid: {
        for (final v in (json['avoid'] as List? ?? const []))
          ...Avoidance.values.where((a) => a.name == v),
      },
      cookTime:
          CookTime.values.where((c) => c.name == json['cookTime']).firstOrNull,
      notes: json['notes'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TasteProfile &&
      listEquals(other.liked, liked) &&
      mapEquals(other.leaning, leaning) &&
      setEquals(other.avoid, avoid) &&
      other.cookTime == cookTime &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(liked),
        Object.hashAll(leaning.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAll(avoid),
        cookTime,
        notes,
      );
}
