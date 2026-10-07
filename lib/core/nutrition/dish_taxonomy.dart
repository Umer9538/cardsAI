/// The dishes the plan builder shows, and what each one says about a person.
///
/// This exists **twice**: here and in `workers/src/taxonomy.ts`. The client
/// sends dish ids and pole names, never labels, and the Worker resolves them
/// against its own copy — so a dish the app knows and the server does not is a
/// tap that quietly changes nothing. `dish_taxonomy_test.dart` diffs the two
/// files' ids to keep them honest.
///
/// Why photos of dishes rather than a list of cuisines: in the one controlled
/// study of this (Yum-me, Yang et al.), plans built from a two-round
/// tap-what-looks-good photo quiz were accepted 72.5% of the time against
/// 50.8% for the same nutrition with no taste input, in 53 seconds — and the
/// categorical questions people expect (cuisine, cook time) predicted taste
/// noticeably worse than the pictures did. So the grid is the instrument and
/// the chips are for the things a photo cannot show.
library;

enum Cuisine {
  southAsian('South Asian'),
  mediterranean('Mediterranean'),
  eastAsian('East Asian'),
  western('Western'),
  latin('Mexican & Latin'),
  middleEastern('Middle Eastern');

  const Cuisine(this.label);

  final String label;
}

/// What a dish is made of and how, at the resolution the prompt uses.
enum DishTag {
  spicy,
  mild,
  rice,
  bread,
  meat,
  fish,
  egg,
  plants,
  breakfast,
  cooked,
  assembled,
  quick,
}

/// One tile in the grid.
///
/// [asset] is the photo, and it is nullable on purpose: the tile draws the
/// name over a sticker card until a licensed photo lands, and a wrong photo
/// is worse than none — someone tapping "biryani" over a picture of pilaf has
/// told us about pilaf. [minutes] is the honest cook time, which is what the
/// prompt is given when someone with fifteen minutes liked a forty-minute dish.
class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.tags,
    required this.minutes,
    this.asset,
  });

  final String id;
  final String name;
  final Cuisine cuisine;
  final Set<DishTag> tags;
  final int minutes;
  final String? asset;
}

/// One end of a this-or-that question.
///
/// [chip] is how it reads back on the finished plan: "Loves heat", not "hot".
enum TastePole {
  hot('Loves heat'),
  mild('Keeps it mild'),
  rice('Rice over bread'),
  bread('Bread over rice'),
  meat('Meat-forward'),
  plants('Plant-forward'),
  bigBreakfast('Big breakfasts'),
  lightBreakfast('Light breakfasts'),
  skipBreakfast('Skips breakfast'),
  cooked('Cooked meals'),
  assembled('Assembled, not cooked');

  const TastePole(this.chip);

  final String chip;
}

/// A pairwise question: two dishes that differ in one thing, and the pole each
/// one stands for. Each pair isolates its own variable within one cuisine
/// where it can — shawarma against falafel is a protein question and nothing
/// else — because a pair that differs in three ways answers none of them.
///
/// [neither] is what "Neither" *means* on this axis. On most it means no
/// leaning and the axis stays unanswered; on breakfast it means "I skip it",
/// which is information the plan needs, so that one carries a pole.
enum TasteAxis {
  spice(
    'Heat',
    left: 'chicken-karahi',
    right: 'grilled-chicken-veg',
    leftPole: TastePole.hot,
    rightPole: TastePole.mild,
    neitherLabel: 'Either way',
  ),
  starch(
    'Starch',
    left: 'taco-bowl',
    right: 'chicken-burrito',
    leftPole: TastePole.rice,
    rightPole: TastePole.bread,
    neitherLabel: 'Either way',
  ),
  protein(
    'Protein',
    left: 'chicken-shawarma',
    right: 'falafel-wrap',
    leftPole: TastePole.meat,
    rightPole: TastePole.plants,
    neitherLabel: 'Either way',
  ),
  breakfast(
    'Breakfast',
    left: 'shakshuka',
    right: 'oats-berries',
    leftPole: TastePole.bigBreakfast,
    rightPole: TastePole.lightBreakfast,
    neitherLabel: 'I skip breakfast',
    neither: TastePole.skipBreakfast,
  ),
  prep(
    'Cooking',
    left: 'chicken-stir-fry',
    right: 'greek-salad',
    leftPole: TastePole.cooked,
    rightPole: TastePole.assembled,
    neitherLabel: 'Either way',
  );

  const TasteAxis(
    this.label, {
    required this.left,
    required this.right,
    required this.leftPole,
    required this.rightPole,
    required this.neitherLabel,
    this.neither,
  });

  final String label;

  /// Dish ids, resolved through [DishTaxonomy.byId].
  final String left;
  final String right;
  final TastePole leftPole;
  final TastePole rightPole;
  final String neitherLabel;
  final TastePole? neither;

  /// Every pole this axis can answer with. `fromJson` validates against it.
  List<TastePole> get poles => [leftPole, rightPole, ?neither];
}

abstract final class DishTaxonomy {
  static const List<Dish> all = [
    // South Asian
    Dish(
      id: 'chicken-karahi',
      name: 'Chicken karahi',
      cuisine: Cuisine.southAsian,
      tags: {DishTag.spicy, DishTag.meat, DishTag.cooked},
      minutes: 40,
      asset: 'assets/images/dishes/chicken-karahi.webp',
    ),
    Dish(
      id: 'dal-tadka',
      name: 'Dal tadka',
      cuisine: Cuisine.southAsian,
      tags: {DishTag.plants, DishTag.cooked, DishTag.mild},
      minutes: 30,
      asset: 'assets/images/dishes/dal-tadka.webp',
    ),
    Dish(
      id: 'biryani',
      name: 'Chicken biryani',
      cuisine: Cuisine.southAsian,
      tags: {DishTag.spicy, DishTag.rice, DishTag.meat, DishTag.cooked},
      minutes: 60,
      asset: 'assets/images/dishes/biryani.webp',
    ),
    Dish(
      id: 'aloo-paratha',
      name: 'Aloo paratha',
      cuisine: Cuisine.southAsian,
      tags: {DishTag.bread, DishTag.plants, DishTag.breakfast, DishTag.cooked},
      minutes: 25,
      asset: 'assets/images/dishes/aloo-paratha.webp',
    ),
    // Mediterranean
    Dish(
      id: 'greek-salad',
      name: 'Greek salad',
      cuisine: Cuisine.mediterranean,
      tags: {DishTag.plants, DishTag.assembled, DishTag.mild, DishTag.quick},
      minutes: 10,
      asset: 'assets/images/dishes/greek-salad.webp',
    ),
    Dish(
      id: 'grilled-salmon',
      name: 'Grilled salmon',
      cuisine: Cuisine.mediterranean,
      tags: {DishTag.fish, DishTag.cooked, DishTag.mild},
      minutes: 20,
      asset: 'assets/images/dishes/grilled-salmon.webp',
    ),
    Dish(
      id: 'hummus-plate',
      name: 'Hummus & pita',
      cuisine: Cuisine.mediterranean,
      tags: {DishTag.plants, DishTag.assembled, DishTag.bread, DishTag.quick},
      minutes: 10,
      asset: 'assets/images/dishes/hummus-plate.webp',
    ),
    Dish(
      id: 'shakshuka',
      name: 'Shakshuka',
      cuisine: Cuisine.mediterranean,
      tags: {DishTag.egg, DishTag.breakfast, DishTag.cooked, DishTag.spicy},
      minutes: 25,
      asset: 'assets/images/dishes/shakshuka.webp',
    ),
    // East Asian
    Dish(
      id: 'chicken-stir-fry',
      name: 'Chicken stir-fry',
      cuisine: Cuisine.eastAsian,
      tags: {DishTag.meat, DishTag.rice, DishTag.cooked},
      minutes: 20,
      asset: 'assets/images/dishes/chicken-stir-fry.webp',
    ),
    Dish(
      id: 'sushi',
      name: 'Salmon sushi',
      cuisine: Cuisine.eastAsian,
      tags: {DishTag.fish, DishTag.rice, DishTag.assembled},
      minutes: 15,
      asset: 'assets/images/dishes/sushi.webp',
    ),
    Dish(
      id: 'ramen',
      name: 'Ramen',
      cuisine: Cuisine.eastAsian,
      tags: {DishTag.meat, DishTag.cooked},
      minutes: 30,
      asset: 'assets/images/dishes/ramen.webp',
    ),
    Dish(
      id: 'tofu-bowl',
      name: 'Tofu rice bowl',
      cuisine: Cuisine.eastAsian,
      tags: {DishTag.plants, DishTag.rice, DishTag.mild, DishTag.quick},
      minutes: 15,
      asset: 'assets/images/dishes/tofu-bowl.webp',
    ),
    // Western
    Dish(
      id: 'grilled-chicken-veg',
      name: 'Grilled chicken & veg',
      cuisine: Cuisine.western,
      tags: {DishTag.meat, DishTag.cooked, DishTag.mild},
      minutes: 25,
      asset: 'assets/images/dishes/grilled-chicken-veg.webp',
    ),
    Dish(
      id: 'avocado-toast',
      name: 'Avocado toast',
      cuisine: Cuisine.western,
      tags: {
        DishTag.plants,
        DishTag.bread,
        DishTag.breakfast,
        DishTag.assembled,
        DishTag.quick,
      },
      minutes: 10,
      asset: 'assets/images/dishes/avocado-toast.webp',
    ),
    Dish(
      id: 'oats-berries',
      name: 'Oats & berries',
      cuisine: Cuisine.western,
      tags: {
        DishTag.plants,
        DishTag.breakfast,
        DishTag.assembled,
        DishTag.quick,
        DishTag.mild,
      },
      minutes: 5,
      asset: 'assets/images/dishes/oats-berries.webp',
    ),
    Dish(
      id: 'burger-fries',
      name: 'Burger & fries',
      cuisine: Cuisine.western,
      tags: {DishTag.meat, DishTag.bread, DishTag.cooked},
      minutes: 30,
      asset: 'assets/images/dishes/burger-fries.webp',
    ),
    // Mexican & Latin
    Dish(
      id: 'chicken-burrito',
      name: 'Chicken burrito',
      cuisine: Cuisine.latin,
      tags: {DishTag.meat, DishTag.bread, DishTag.spicy, DishTag.assembled},
      minutes: 15,
      asset: 'assets/images/dishes/chicken-burrito.webp',
    ),
    Dish(
      id: 'taco-bowl',
      name: 'Chicken taco bowl',
      cuisine: Cuisine.latin,
      tags: {DishTag.meat, DishTag.rice, DishTag.spicy, DishTag.assembled},
      minutes: 20,
      asset: 'assets/images/dishes/taco-bowl.webp',
    ),
    // Middle Eastern
    Dish(
      id: 'chicken-shawarma',
      name: 'Chicken shawarma',
      cuisine: Cuisine.middleEastern,
      tags: {DishTag.meat, DishTag.bread, DishTag.spicy, DishTag.cooked},
      minutes: 30,
      asset: 'assets/images/dishes/chicken-shawarma.webp',
    ),
    Dish(
      id: 'falafel-wrap',
      name: 'Falafel wrap',
      cuisine: Cuisine.middleEastern,
      tags: {DishTag.plants, DishTag.bread, DishTag.assembled},
      minutes: 15,
      asset: 'assets/images/dishes/falafel-wrap.webp',
    ),
  ];

  static final Map<String, Dish> _byId = {for (final d in all) d.id: d};

  static Dish? byId(String id) => _byId[id];

  /// The first grid: one dish from every cuisine, then the widest spread of
  /// tags the rest allow. Nine so it is a 3×3.
  static const List<String> gridA = [
    'chicken-karahi',
    'greek-salad',
    'chicken-stir-fry',
    'avocado-toast',
    'taco-bowl',
    'chicken-shawarma',
    'dal-tadka',
    'grilled-salmon',
    'sushi',
  ];

  /// The second grid, chosen to be *unlike* the first — the study's second
  /// round is for exploration, not confirmation. Someone who tapped nothing
  /// meaty in round one gets ramen and a burger here anyway, because "no" is
  /// data too.
  static const List<String> gridB = [
    'biryani',
    'hummus-plate',
    'ramen',
    'oats-berries',
    'chicken-burrito',
    'falafel-wrap',
    'aloo-paratha',
    'tofu-bowl',
    'burger-fries',
  ];

  static List<Dish> grid(List<String> ids) =>
      [for (final id in ids) byId(id)!];
}
