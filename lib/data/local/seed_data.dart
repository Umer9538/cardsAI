import '../../core/models/models.dart';

/// The content the screens used to hardcode, promoted to domain objects.
///
/// This is what a fresh install starts with. It exists so the app looks like the
/// design on first run instead of showing five empty states, and it is the first
/// thing the Firebase catalogue replaces.
abstract final class SeedData {
  /// The three foods on the scan-result artboard.
  ///
  /// Also used as today's seeded meal, so Home has something to total.
  static List<FoodItem> get scannedFoods => const [
        FoodItem(
          id: 'seed-food-chicken',
          name: 'Grilled Chicken Strips',
          portionDescription: '1 serving',
          portionGrams: 120,
          nutrition: Nutrition(calories: 220, protein: 30, carbs: 0, fat: 10),
          confidence: FoodConfidence.high,
        ),
        FoodItem(
          id: 'seed-food-naan',
          name: 'Naan Bread',
          portionDescription: '1 piece',
          portionGrams: 90,
          nutrition: Nutrition(
            calories: 260,
            protein: 7,
            carbs: 45,
            fat: 6,
            fiber: 2,
            sugar: 3,
          ),
          confidence: FoodConfidence.high,
        ),
        FoodItem(
          id: 'seed-food-peppers',
          name: 'Sautéed Bell Peppers (Red & Yellow)',
          portionDescription: '1 cup',
          portionGrams: 90,
          nutrition: Nutrition(
            calories: 50,
            protein: 1,
            carbs: 12,
            fat: 0.3,
            fiber: 3,
            sugar: 6,
          ),
          confidence: FoodConfidence.medium,
        ),
      ];

  /// The plan catalogue.
  ///
  /// Mediterranean Lifestyle appears twice, under two ids. That is not a
  /// mistake: the Diets artboard and the Favorites artboard ship different
  /// photographs of the same plan, and the second is clipped short by the frame
  /// edge. Two records keep both screens pixel-faithful. Collapse them once the
  /// catalogue comes from the backend with one canonical image.
  /// The published catalogue.
  ///
  /// **Nothing here is favourited or owned.** Three plans used to ship with
  /// `isMine` and `isFavorite` already set, so a brand-new account opened onto
  /// a My Diets tab and a Favourites tab that were already full of choices
  /// nobody had made. An app that pretends you did something is the clearest
  /// possible signal that its numbers are decoration.
  ///
  /// The figures are the pattern's own — see [DietPlan.scaledTo], which is what
  /// puts them in the user's terms before they are shown.
  static List<DietPlan> get dietPlans => const [
        DietPlan(
          id: 'plan-mediterranean',
          goal: 'Heart health, long-term maintenance',
          name: 'Mediterranean Lifestyle',
          image: 'assets/images/app/diet_mediterranean.png',
          nutrition:
              Nutrition(calories: 2000, protein: 120, carbs: 200, fat: 70),
          description: 'Olive oil, fish, vegetables and whole grains — the '
              'pattern with the deepest evidence base behind it.',
        ),
        DietPlan(
          id: 'plan-keto',
          goal: 'Fat loss, appetite control',
          name: 'Keto Kickstart',
          image: 'assets/images/app/diet_keto.png',
          nutrition:
              Nutrition(calories: 1800, protein: 70, carbs: 30, fat: 105),
          description: 'Very low carb, high fat. Built to get you into ketosis '
              'and keep you there.',
          imageHeight: 204,
        ),
        DietPlan(
          id: 'plan-lowcarb',
          goal: 'Fat loss, steadier energy',
          name: 'Low-Carb Fat Burner',
          image: 'assets/images/app/diet_lowcarb.png',
          nutrition:
              Nutrition(calories: 1600, protein: 110, carbs: 60, fat: 90),
          description: 'Moderate protein, low carb, calorie-controlled.',
        ),
        DietPlan(
          id: 'plan-vegan',
          goal: 'Plant-based eating, cholesterol',
          name: 'Vegan Vitality',
          image: 'assets/images/app/diet_vegan.png',
          nutrition:
              Nutrition(calories: 2000, protein: 125, carbs: 300, fat: 55),
          description: 'Entirely plant-based, with the protein actually '
              'accounted for.',
        ),
        DietPlan(
          id: 'plan-detox',
          goal: 'A reset week, more vegetables',
          name: 'Detox Cleanse Plan',
          image: 'assets/images/app/diet_detox.png',
          nutrition:
              Nutrition(calories: 1400, protein: 60, carbs: 180, fat: 40),
          description: 'A short, light reset built around whole foods.',
          imageHeight: 110,
        ),
        DietPlan(
          id: 'plan-paleo',
          goal: 'Whole foods, fewer processed carbs',
          name: 'Paleo Power Plan',
          image: 'assets/images/app/fav_paleo.png',
          nutrition:
              Nutrition(calories: 2000, protein: 180, carbs: 150, fat: 80),
          description: 'Meat, fish, eggs, vegetables, nuts. No grains, no '
              'dairy, no refined sugar.',
        ),
        DietPlan(
          id: 'plan-indian-veg',
          goal: 'Weight loss on a desi diet',
          name: 'Indian Vegetarian Weight Loss',
          image: 'assets/images/app/fav_indian.png',
          nutrition:
              Nutrition(calories: 1800, protein: 100, carbs: 225, fat: 45),
          description: 'Dal, paneer and vegetables, portioned for a deficit.',
        ),
        DietPlan(
          id: 'plan-mediterranean-fav',
          goal: 'Heart health, long-term maintenance',
          name: 'Mediterranean Lifestyle',
          image: 'assets/images/app/fav_medi.png',
          nutrition:
              Nutrition(calories: 2000, protein: 120, carbs: 200, fat: 70),
          description: 'Olive oil, fish, vegetables and whole grains.',
          imageHeight: 175,
        ),
      ];

  /// The seven messages the populated notifications artboard ships with.
  static List<AppNotification> notifications(DateTime now) {
    const bodies = [
      'It’s time for your Lunch – Don’t forget to log your meal.',
      'You’re doing great! Try adding more fiber-rich foods to hit today’s '
          'target.',
      'You’ve hit 80% of your daily calorie goal—keep it going!',
      'Stay hydrated! Aim for at least 8 cups of water today.',
      'Consider a light snack to help maintain your energy levels.',
      'Review your progress this week and celebrate your small wins!',
      'Plan your dinner ahead—choosing healthier options can be fun!',
    ];
    return [
      for (final (i, body) in bodies.indexed)
        AppNotification(
          id: 'seed-notif-$i',
          body: body,
          // Newest first, an hour apart, so ordering is stable and obvious.
          createdAt: now.subtract(Duration(hours: i)),
        ),
    ];
  }

  /// A week of diary history so Analysis and the streak have something real to
  /// work from on a fresh install.
  ///
  /// Day 0 is today and carries [scannedFoods]; the six days before it get a
  /// breakfast and a dinner, which is what keeps the streak alive.
  static List<Meal> diary(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final meals = <Meal>[
      Meal(
        id: 'seed-meal-today',
        eatenAt: today.add(const Duration(hours: 13)),
        items: scannedFoods,
        photoPath: 'assets/images/app/scan_food.png',
      ),
    ];

    for (var back = 1; back < 7; back++) {
      final day = today.subtract(Duration(days: back));
      meals
        ..add(
          Meal(
            id: 'seed-meal-$back-breakfast',
            eatenAt: day.add(const Duration(hours: 8)),
            items: [
              FoodItem(
                id: 'seed-item-$back-oats',
                name: 'Porridge with Berries',
                portionDescription: '1 bowl',
                portionGrams: 250,
                nutrition: const Nutrition(
                  calories: 340,
                  protein: 12,
                  carbs: 58,
                  fat: 7,
                  fiber: 8,
                  sugar: 14,
                ),
                source: FoodSource.manual,
                confidence: FoodConfidence.high,
              ),
            ],
          ),
        )
        ..add(
          Meal(
            id: 'seed-meal-$back-dinner',
            eatenAt: day.add(const Duration(hours: 19)),
            items: [
              FoodItem(
                id: 'seed-item-$back-salmon',
                name: 'Baked Salmon & Greens',
                portionDescription: '1 plate',
                portionGrams: 380,
                // Nudged per day so the Analysis chart is not a flat line.
                nutrition: Nutrition(
                  calories: 620 + back * 25,
                  protein: 44 + back * 2,
                  carbs: 38 + back * 4,
                  fat: 28 + back.toDouble(),
                  fiber: 6,
                  sugar: 5,
                ),
                source: FoodSource.manual,
                confidence: FoodConfidence.high,
              ),
            ],
          ),
        );
    }
    return meals;
  }

  /// Notification categories on the preferences screen, and their defaults.
  static Map<String, bool> get notificationSettings => const {
        'mealReminders': true,
        'goalProgress': true,
        'weeklySummary': true,
        'tipsAndEducation': false,
        'productUpdates': false,
      };
}
