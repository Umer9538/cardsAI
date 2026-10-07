import '../../features/settings/presentation/legal_content.dart';
import 'dish_taxonomy.dart';

/// Where each dish photo came from.
///
/// Every tile in the plan builder is an openly licensed photograph (CC0,
/// public domain, or CC BY), found through Openverse and kept at 640×640.
/// CC BY requires the creator to be credited somewhere a person can read, so
/// these render at the foot of the Help page. `assets/images/dishes/ATTRIBUTION.md`
/// holds the full record — source page, license URL, original file.
///
/// Generated from the sourcing run on 4 September 2026; edit by re-running
/// the generator, not by hand, so the two records cannot drift.
abstract final class DishPhotoCredits {
  /// `(dish id, creator, license)`.
  static const List<(String, String, String)> entries = [
    ('aloo-paratha', 'Виктор Пинчук', 'CC BY 4.0'),
    ('avocado-toast', 'nan palmero', 'CC BY 2.0'),
    ('biryani', 'debbietingzon', 'CC BY 2.0'),
    ('burger-fries', 'cornstalker', 'CC BY 2.0'),
    ('chicken-burrito', 'SodanieChea', 'CC BY 2.0'),
    ('chicken-karahi', 'Miansari66', 'CC0 1.0'),
    ('chicken-shawarma', 'Shoshanah', 'CC BY 2.0'),
    ('chicken-stir-fry', 'jeffreyw', 'CC BY 2.0'),
    ('dal-tadka', 'Biswarup Ganguly', 'CC BY 3.0'),
    ('falafel-wrap', 'Gary Soup', 'CC BY 2.0'),
    ('greek-salad', 'ozmafan', 'CC BY 2.0'),
    ('grilled-chicken-veg', 'jeffreyw', 'CC BY 2.0'),
    ('grilled-salmon', 'Khrl Zhfr', 'CC BY 2.0'),
    ('hummus-plate', 'renee_mcgurk', 'CC BY 2.0'),
    ('oats-berries', 'Ruth and Dave', 'CC BY 2.0'),
    ('ramen', 'midnightbreakfastcafe', 'CC BY 2.0'),
    ('shakshuka', 'adactio', 'CC BY 2.0'),
    ('sushi', 'jh_tan84', 'CC BY 2.0'),
    ('taco-bowl', 'HealthHomeHappy.com', 'CC BY 2.0'),
    ('tofu-bowl', 'Stacy Spensley', 'CC BY 2.0'),
  ];

  /// The credits as legal-page blocks: a heading, then one line per photo.
  static List<LegalBlock> get blocks => [
        const LegalBlock('Photo Credits', isHeading: true),
        const LegalBlock(
          'The dish photos in the plan builder are openly licensed '
          'photographs, used with thanks.',
        ),
        for (final (id, creator, license) in entries)
          LegalBlock(
            '${DishTaxonomy.byId(id)?.name ?? id} — $creator, $license',
          ),
      ];
}
