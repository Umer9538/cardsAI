import 'package:flutter/foundation.dart';

import '../nutrition/dish_taxonomy.dart';

/// Hard constraints. Photos cannot express an allergy, so these are asked as
/// chips rather than inferred.
///
/// [words] are what a returned plan is scanned for, and [except] are the safe
/// compounds that contain one of those words and are not the thing — "oat
/// milk" is not dairy, "corn tortilla" is not gluten, "eggplant" is not an
/// egg. The scan is a **word-start** match (`cream` catches "creamy" and
/// "creamed"; `butter` catches "buttered" and "buttermilk") after every
/// exception phrase has been removed, so both a false refusal and a false
/// pass are a list entry away rather than a regex change. An exception that
/// ends in `free` or starts with `non-` is a *qualifier*: it removes the word
/// it qualifies as well, so "gluten-free bread" and "non-dairy milk" are not
/// hits. The lists are deliberately generous — paneer is dairy whether or
/// not the model thinks of it that way.
///
/// This table exists **twice**, here and in `workers/src/taxonomy.ts`, and
/// `dish_taxonomy_test.dart` diffs both lists. `AvoidanceCheck` is the Dart
/// matcher; `violations()` in `workers/src/planner.ts` is the server's, with
/// the same semantics, and `avoidance_check_test.dart` holds the cases both
/// must agree on.
enum Avoidance {
  beef(
    'Beef',
    words: [
      'beef',
      'steak',
      'mince',
      'burger',
      'hamburger',
      'cheeseburger',
      'brisket',
      'nihari',
      'sirloin',
      'ribeye',
      'veal',
      'oxtail',
      'pastrami',
    ],
    except: [
      'tuna steak',
      'swordfish steak',
      'salmon steak',
      'cauliflower steak',
      'lamb steak',
      'pork steak',
      'chicken burger',
      'turkey burger',
      'veggie burger',
      'vegan burger',
      'bean burger',
      'chickpea burger',
      'salmon burger',
      'fish burger',
      'lamb burger',
      'pork burger',
      'lamb mince',
      'turkey mince',
      'chicken mince',
      'pork mince',
      'soy mince',
      'plant mince',
      'minced garlic',
      'minced ginger',
      'minced onion',
      'minced herbs',
      'minced chilli',
      'minced coriander',
      'minced parsley',
    ],
  ),
  pork(
    'Pork',
    words: [
      'pork',
      'bacon',
      'ham',
      'sausage',
      'salami',
      'prosciutto',
      'chorizo',
      'pancetta',
      'pepperoni',
      'gammon',
      'lardon',
      'lard',
    ],
    except: [
      'chicken sausage',
      'turkey sausage',
      'beef sausage',
      'lamb sausage',
      'veggie sausage',
      'vegan sausage',
      'plant sausage',
      'hamburger',
      'hammered',
    ],
  ),
  dairy(
    'Dairy',
    words: [
      'milk',
      'cheese',
      'cheesy',
      'yoghurt',
      'yogurt',
      'butter',
      'cream',
      'paneer',
      'ghee',
      'lassi',
      'raita',
      'curd',
      'whey',
      'mozzarella',
      'feta',
      'parmesan',
      'cheddar',
      'ricotta',
      'mascarpone',
      'labneh',
      'kefir',
      'custard',
    ],
    except: [
      'oat milk',
      'almond milk',
      'soy milk',
      'soya milk',
      'coconut milk',
      'rice milk',
      'cashew milk',
      'hazelnut milk',
      'peanut butter',
      'almond butter',
      'cashew butter',
      'nut butter',
      'cocoa butter',
      'butternut',
      'coconut cream',
      'coconut yoghurt',
      'coconut yogurt',
      'soy yoghurt',
      'soy yogurt',
      'bean curd',
      'dairy-free',
      'dairy free',
      'non-dairy',
      'cream of tartar',
    ],
  ),
  gluten(
    'Gluten',
    words: [
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
      'flatbread',
      'seitan',
      'barley',
      'rye',
      'semolina',
      'spaghetti',
      'penne',
      'macaroni',
      'lasagne',
      'lasagna',
      'croissant',
      'bagel',
      'biscuit',
      'cracker',
      'crouton',
      'pizza',
      'dumpling',
      'puri',
      'bhatura',
      'pretzel',
    ],
    except: [
      'gluten-free',
      'gluten free',
      'corn tortilla',
      'rice noodle',
      'lettuce wrap',
      'glass noodle',
      'buckwheat',
      'toasted',
      'wrapped',
    ],
  ),
  nuts(
    'Nuts',
    words: [
      'nut',
      'almond',
      'peanut',
      'cashew',
      'walnut',
      'pistachio',
      'hazelnut',
      'pecan',
      'macadamia',
      'praline',
      'marzipan',
    ],
    except: [
      'nutmeg',
      'nutrition',
      'nutritional',
      'nutrient',
      'nutrients',
      'nutty seed',
    ],
  ),
  eggs(
    'Eggs',
    words: [
      'egg',
      'omelette',
      'omelet',
      'frittata',
      'shakshuka',
      'meringue',
      'mayonnaise',
      'mayo',
      'quiche',
      'custard',
    ],
    except: [
      'eggplant',
      'egg-free',
      'egg free',
      'eggless',
      'vegan mayo',
      'vegan mayonnaise',
    ],
  ),
  seafood(
    'Seafood',
    words: [
      'seafood',
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
      'anchovy',
      'anchovies',
      'shellfish',
      'swordfish',
      'oyster',
      'mussel',
      'clam',
      'lobster',
      'scallop',
      'calamari',
      'octopus',
      'haddock',
      'tilapia',
      'trout',
      'halibut',
      'seabass',
      'sea bass',
      'kipper',
      'eel',
      'caviar',
      'roe',
    ],
    except: ['crabapple'],
  );

  const Avoidance(this.label, {required this.words, required this.except});

  final String label;
  final List<String> words;
  final List<String> except;
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
      out.add(entry.value.chip);
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
