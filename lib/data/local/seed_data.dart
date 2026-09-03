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
      eat: [
        'Olive oil',
        'Oily fish',
        'Vegetables',
        'Whole grains',
        'Legumes',
        'Nuts',
      ],
      limit: ['Red meat', 'Butter', 'Refined sugar'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Greek yoghurt, walnuts and honey',
          items: [
            FoodItem(
              id: 'plan-mediterranean-breakfast-0',
              name: 'Greek yoghurt, plain, 200 g',
              nutrition: Nutrition(
                calories: 130,
                protein: 20,
                carbs: 8,
                fat: 1,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-breakfast-1',
              name: 'Walnuts, 20 g',
              nutrition: Nutrition(
                calories: 131,
                protein: 3,
                carbs: 3,
                fat: 13,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Chickpea and tomato salad with olive oil',
          items: [
            FoodItem(
              id: 'plan-mediterranean-lunch-0',
              name: 'Chickpeas, cooked, 150 g',
              nutrition: Nutrition(
                calories: 246,
                protein: 13,
                carbs: 41,
                fat: 4,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-lunch-1',
              name: 'Olive oil, 1 tbsp',
              nutrition: Nutrition(
                calories: 119,
                protein: 0,
                carbs: 0,
                fat: 14,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-lunch-2',
              name: 'Tomato and cucumber, 150 g',
              nutrition: Nutrition(calories: 27, protein: 1, carbs: 6, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Grilled sardines, bulgur and greens',
          items: [
            FoodItem(
              id: 'plan-mediterranean-dinner-0',
              name: 'Sardines, grilled, 120 g',
              nutrition: Nutrition(
                calories: 250,
                protein: 30,
                carbs: 0,
                fat: 14,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-dinner-1',
              name: 'Bulgur, cooked, 180 g',
              nutrition: Nutrition(
                calories: 151,
                protein: 6,
                carbs: 34,
                fat: 0,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-dinner-2',
              name: 'Spinach, sautéed, 100 g',
              nutrition: Nutrition(calories: 45, protein: 3, carbs: 4, fat: 2),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Orange and almonds',
          items: [
            FoodItem(
              id: 'plan-mediterranean-snack-0',
              name: 'Orange, 1 medium',
              nutrition: Nutrition(calories: 62, protein: 1, carbs: 15, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-snack-1',
              name: 'Almonds, 15 g',
              nutrition: Nutrition(calories: 87, protein: 3, carbs: 3, fat: 8),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Heart health, long-term maintenance',
      name: 'Mediterranean Lifestyle',
      image: 'assets/images/app/diet_mediterranean.png',
      nutrition: Nutrition(calories: 1248, protein: 80, carbs: 114, fat: 56),
      description:
          'Olive oil, fish, vegetables and whole grains — the '
          'pattern with the deepest evidence base behind it.',
    ),
    DietPlan(
      id: 'plan-keto',
      eat: [
        'Eggs',
        'Oily fish',
        'Avocado',
        'Cheese',
        'Leafy greens',
        'Olive oil',
      ],
      limit: ['Bread and rice', 'Fruit', 'Sugar', 'Starchy vegetables'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Eggs fried in butter with avocado',
          items: [
            FoodItem(
              id: 'plan-keto-breakfast-0',
              name: 'Eggs, 3 large',
              nutrition: Nutrition(
                calories: 234,
                protein: 19,
                carbs: 2,
                fat: 16,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-breakfast-1',
              name: 'Butter, 10 g',
              nutrition: Nutrition(calories: 72, protein: 0, carbs: 0, fat: 8),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-breakfast-2',
              name: 'Avocado, half',
              nutrition: Nutrition(
                calories: 120,
                protein: 1,
                carbs: 6,
                fat: 11,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Salmon with buttered broccoli',
          items: [
            FoodItem(
              id: 'plan-keto-lunch-0',
              name: 'Salmon, baked, 150 g',
              nutrition: Nutrition(
                calories: 309,
                protein: 34,
                carbs: 0,
                fat: 19,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-lunch-1',
              name: 'Broccoli, 150 g',
              nutrition: Nutrition(calories: 51, protein: 4, carbs: 10, fat: 1),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-lunch-2',
              name: 'Butter, 10 g',
              nutrition: Nutrition(calories: 72, protein: 0, carbs: 0, fat: 8),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Ribeye and salad with olive oil',
          items: [
            FoodItem(
              id: 'plan-keto-dinner-0',
              name: 'Ribeye steak, 180 g',
              nutrition: Nutrition(
                calories: 460,
                protein: 44,
                carbs: 0,
                fat: 31,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-dinner-1',
              name: 'Mixed leaves, 80 g',
              nutrition: Nutrition(calories: 14, protein: 1, carbs: 2, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-dinner-2',
              name: 'Olive oil, 1 tbsp',
              nutrition: Nutrition(
                calories: 119,
                protein: 0,
                carbs: 0,
                fat: 14,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Cheddar and olives',
          items: [
            FoodItem(
              id: 'plan-keto-snack-0',
              name: 'Cheddar, 40 g',
              nutrition: Nutrition(
                calories: 162,
                protein: 10,
                carbs: 1,
                fat: 13,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-keto-snack-1',
              name: 'Olives, 30 g',
              nutrition: Nutrition(calories: 43, protein: 0, carbs: 1, fat: 4),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Fat loss, appetite control',
      name: 'Keto Kickstart',
      image: 'assets/images/app/diet_keto.png',
      nutrition: Nutrition(calories: 1656, protein: 113, carbs: 22, fat: 125),
      description:
          'Very low carb, high fat. Built to get you into ketosis '
          'and keep you there.',
      imageHeight: 204,
    ),
    DietPlan(
      id: 'plan-lowcarb',
      eat: [
        'Lean meat',
        'Fish',
        'Eggs',
        'Non-starchy vegetables',
        'Greek yoghurt',
      ],
      limit: ['Bread', 'Pasta', 'Sugary drinks', 'Potatoes'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Omelette with spinach and feta',
          items: [
            FoodItem(
              id: 'plan-lowcarb-breakfast-0',
              name: 'Eggs, 3 large',
              nutrition: Nutrition(
                calories: 234,
                protein: 19,
                carbs: 2,
                fat: 16,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-lowcarb-breakfast-1',
              name: 'Spinach, 60 g',
              nutrition: Nutrition(calories: 14, protein: 2, carbs: 2, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-lowcarb-breakfast-2',
              name: 'Feta, 30 g',
              nutrition: Nutrition(calories: 79, protein: 4, carbs: 1, fat: 6),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Chicken breast with roasted vegetables',
          items: [
            FoodItem(
              id: 'plan-lowcarb-lunch-0',
              name: 'Chicken breast, grilled, 180 g',
              nutrition: Nutrition(
                calories: 297,
                protein: 56,
                carbs: 0,
                fat: 6,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-lowcarb-lunch-1',
              name: 'Courgette and pepper, roasted, 200 g',
              nutrition: Nutrition(calories: 90, protein: 3, carbs: 10, fat: 5),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Beef mince with cauliflower rice',
          items: [
            FoodItem(
              id: 'plan-lowcarb-dinner-0',
              name: 'Beef mince, 5% fat, 150 g',
              nutrition: Nutrition(
                calories: 204,
                protein: 32,
                carbs: 0,
                fat: 8,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-lowcarb-dinner-1',
              name: 'Cauliflower rice, 200 g',
              nutrition: Nutrition(calories: 50, protein: 4, carbs: 10, fat: 1),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-lowcarb-dinner-2',
              name: 'Olive oil, 1 tsp',
              nutrition: Nutrition(calories: 40, protein: 0, carbs: 0, fat: 5),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Greek yoghurt',
          items: [
            FoodItem(
              id: 'plan-lowcarb-snack-0',
              name: 'Greek yoghurt, plain, 170 g',
              nutrition: Nutrition(
                calories: 111,
                protein: 17,
                carbs: 6,
                fat: 1,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Fat loss, steadier energy',
      name: 'Low-Carb Fat Burner',
      image: 'assets/images/app/diet_lowcarb.png',
      nutrition: Nutrition(calories: 1119, protein: 137, carbs: 31, fat: 48),
      description: 'Moderate protein, low carb, calorie-controlled.',
    ),
    DietPlan(
      id: 'plan-vegan',
      eat: [
        'Legumes',
        'Tofu and tempeh',
        'Whole grains',
        'Nuts and seeds',
        'Vegetables',
      ],
      limit: ['All animal products', 'Refined sugar'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Oats with soy milk and peanut butter',
          items: [
            FoodItem(
              id: 'plan-vegan-breakfast-0',
              name: 'Oats, 80 g dry',
              nutrition: Nutrition(
                calories: 303,
                protein: 11,
                carbs: 54,
                fat: 5,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-breakfast-1',
              name: 'Soy milk, 200 ml',
              nutrition: Nutrition(calories: 66, protein: 6, carbs: 3, fat: 4),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-breakfast-2',
              name: 'Peanut butter, 20 g',
              nutrition: Nutrition(
                calories: 118,
                protein: 5,
                carbs: 4,
                fat: 10,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Lentil daal with brown rice',
          items: [
            FoodItem(
              id: 'plan-vegan-lunch-0',
              name: 'Red lentil daal, 250 g',
              nutrition: Nutrition(
                calories: 232,
                protein: 15,
                carbs: 36,
                fat: 3,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-lunch-1',
              name: 'Brown rice, cooked, 180 g',
              nutrition: Nutrition(
                calories: 199,
                protein: 5,
                carbs: 41,
                fat: 2,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Tofu stir-fry with vegetables',
          items: [
            FoodItem(
              id: 'plan-vegan-dinner-0',
              name: 'Firm tofu, 200 g',
              nutrition: Nutrition(
                calories: 288,
                protein: 31,
                carbs: 7,
                fat: 17,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-dinner-1',
              name: 'Mixed stir-fry vegetables, 250 g',
              nutrition: Nutrition(calories: 88, protein: 4, carbs: 16, fat: 1),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-dinner-2',
              name: 'Sesame oil, 1 tsp',
              nutrition: Nutrition(calories: 40, protein: 0, carbs: 0, fat: 5),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Hummus with carrot sticks',
          items: [
            FoodItem(
              id: 'plan-vegan-snack-0',
              name: 'Hummus, 60 g',
              nutrition: Nutrition(calories: 100, protein: 3, carbs: 8, fat: 6),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-vegan-snack-1',
              name: 'Carrot, 100 g',
              nutrition: Nutrition(calories: 41, protein: 1, carbs: 10, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Plant-based eating, cholesterol',
      name: 'Vegan Vitality',
      image: 'assets/images/app/diet_vegan.png',
      nutrition: Nutrition(calories: 1475, protein: 81, carbs: 179, fat: 53),
      description:
          'Entirely plant-based, with the protein actually '
          'accounted for.',
    ),
    DietPlan(
      id: 'plan-detox',
      eat: ['Vegetables', 'Fruit', 'Water', 'Whole grains', 'Herbal tea'],
      limit: ['Alcohol', 'Fried food', 'Added sugar', 'Processed meat'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Fruit and yoghurt bowl',
          items: [
            FoodItem(
              id: 'plan-detox-breakfast-0',
              name: 'Greek yoghurt, plain, 150 g',
              nutrition: Nutrition(calories: 98, protein: 15, carbs: 6, fat: 1),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-detox-breakfast-1',
              name: 'Berries, 150 g',
              nutrition: Nutrition(calories: 84, protein: 1, carbs: 20, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-detox-breakfast-2',
              name: 'Chia seeds, 15 g',
              nutrition: Nutrition(calories: 73, protein: 2, carbs: 6, fat: 5),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Vegetable soup with wholemeal bread',
          items: [
            FoodItem(
              id: 'plan-detox-lunch-0',
              name: 'Vegetable soup, 350 g',
              nutrition: Nutrition(
                calories: 140,
                protein: 5,
                carbs: 22,
                fat: 4,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-detox-lunch-1',
              name: 'Wholemeal bread, 2 slices',
              nutrition: Nutrition(
                calories: 164,
                protein: 8,
                carbs: 28,
                fat: 2,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Baked white fish with vegetables',
          items: [
            FoodItem(
              id: 'plan-detox-dinner-0',
              name: 'Cod, baked, 180 g',
              nutrition: Nutrition(
                calories: 190,
                protein: 41,
                carbs: 0,
                fat: 2,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-detox-dinner-1',
              name: 'Roasted root vegetables, 250 g',
              nutrition: Nutrition(
                calories: 178,
                protein: 4,
                carbs: 35,
                fat: 3,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Apple and green tea',
          items: [
            FoodItem(
              id: 'plan-detox-snack-0',
              name: 'Apple, 1 medium',
              nutrition: Nutrition(calories: 95, protein: 0, carbs: 25, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'A reset week, more vegetables',
      name: 'Detox Cleanse Plan',
      image: 'assets/images/app/diet_detox.png',
      nutrition: Nutrition(calories: 1022, protein: 76, carbs: 142, fat: 17),
      description: 'A short, light reset built around whole foods.',
      imageHeight: 110,
    ),
    DietPlan(
      id: 'plan-paleo',
      eat: ['Meat and fish', 'Eggs', 'Vegetables', 'Fruit', 'Nuts'],
      limit: ['Grains', 'Legumes', 'Dairy', 'Processed food'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Eggs with mushrooms and tomato',
          items: [
            FoodItem(
              id: 'plan-paleo-breakfast-0',
              name: 'Eggs, 3 large',
              nutrition: Nutrition(
                calories: 234,
                protein: 19,
                carbs: 2,
                fat: 16,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-paleo-breakfast-1',
              name: 'Mushrooms and tomato, 150 g',
              nutrition: Nutrition(calories: 42, protein: 3, carbs: 6, fat: 1),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Chicken salad with avocado',
          items: [
            FoodItem(
              id: 'plan-paleo-lunch-0',
              name: 'Chicken breast, grilled, 150 g',
              nutrition: Nutrition(
                calories: 248,
                protein: 47,
                carbs: 0,
                fat: 5,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-paleo-lunch-1',
              name: 'Avocado, half',
              nutrition: Nutrition(
                calories: 120,
                protein: 1,
                carbs: 6,
                fat: 11,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-paleo-lunch-2',
              name: 'Mixed leaves, 100 g',
              nutrition: Nutrition(calories: 17, protein: 2, carbs: 3, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Steak with sweet potato',
          items: [
            FoodItem(
              id: 'plan-paleo-dinner-0',
              name: 'Sirloin steak, 180 g',
              nutrition: Nutrition(
                calories: 371,
                protein: 47,
                carbs: 0,
                fat: 19,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-paleo-dinner-1',
              name: 'Sweet potato, baked, 200 g',
              nutrition: Nutrition(
                calories: 180,
                protein: 4,
                carbs: 41,
                fat: 0,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Banana and cashews',
          items: [
            FoodItem(
              id: 'plan-paleo-snack-0',
              name: 'Banana, 1 medium',
              nutrition: Nutrition(
                calories: 105,
                protein: 1,
                carbs: 27,
                fat: 0,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-paleo-snack-1',
              name: 'Cashews, 25 g',
              nutrition: Nutrition(
                calories: 138,
                protein: 5,
                carbs: 8,
                fat: 11,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Whole foods, fewer processed carbs',
      name: 'Paleo Power Plan',
      image: 'assets/images/app/fav_paleo.png',
      nutrition: Nutrition(calories: 1455, protein: 129, carbs: 93, fat: 63),
      description:
          'Meat, fish, eggs, vegetables, nuts. No grains, no '
          'dairy, no refined sugar.',
    ),
    DietPlan(
      id: 'plan-indian-veg',
      eat: ['Daal', 'Paneer', 'Roti', 'Vegetables', 'Curd'],
      limit: [
        'Fried snacks',
        'Sweets',
        'Extra ghee',
        'White rice at every meal',
      ],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Vegetable poha with curd',
          items: [
            FoodItem(
              id: 'plan-indian-veg-breakfast-0',
              name: 'Poha, 150 g',
              nutrition: Nutrition(
                calories: 250,
                protein: 5,
                carbs: 45,
                fat: 5,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-indian-veg-breakfast-1',
              name: 'Curd, 100 g',
              nutrition: Nutrition(calories: 61, protein: 3, carbs: 5, fat: 3),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Daal, two roti and salad',
          items: [
            FoodItem(
              id: 'plan-indian-veg-lunch-0',
              name: 'Toor daal, 200 g',
              nutrition: Nutrition(
                calories: 232,
                protein: 13,
                carbs: 34,
                fat: 5,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-indian-veg-lunch-1',
              name: 'Roti, 2 medium',
              nutrition: Nutrition(
                calories: 240,
                protein: 8,
                carbs: 46,
                fat: 3,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-indian-veg-lunch-2',
              name: 'Kachumber salad, 100 g',
              nutrition: Nutrition(calories: 30, protein: 1, carbs: 6, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Palak paneer with one roti',
          items: [
            FoodItem(
              id: 'plan-indian-veg-dinner-0',
              name: 'Palak paneer, 200 g',
              nutrition: Nutrition(
                calories: 300,
                protein: 16,
                carbs: 12,
                fat: 22,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-indian-veg-dinner-1',
              name: 'Roti, 1 medium',
              nutrition: Nutrition(
                calories: 120,
                protein: 4,
                carbs: 23,
                fat: 2,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Roasted chana',
          items: [
            FoodItem(
              id: 'plan-indian-veg-snack-0',
              name: 'Roasted chana, 40 g',
              nutrition: Nutrition(
                calories: 145,
                protein: 8,
                carbs: 24,
                fat: 2,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Weight loss on a desi diet',
      name: 'Indian Vegetarian Weight Loss',
      image: 'assets/images/app/fav_indian.png',
      nutrition: Nutrition(calories: 1378, protein: 58, carbs: 195, fat: 42),
      description: 'Dal, paneer and vegetables, portioned for a deficit.',
    ),
    DietPlan(
      id: 'plan-mediterranean-fav',
      eat: [
        'Olive oil',
        'Oily fish',
        'Vegetables',
        'Whole grains',
        'Legumes',
        'Nuts',
      ],
      limit: ['Red meat', 'Butter', 'Refined sugar'],
      day: [
        PlannedMeal(
          slot: MealSlot.breakfast,
          title: 'Greek yoghurt, walnuts and honey',
          items: [
            FoodItem(
              id: 'plan-mediterranean-fav-breakfast-0',
              name: 'Greek yoghurt, plain, 200 g',
              nutrition: Nutrition(
                calories: 130,
                protein: 20,
                carbs: 8,
                fat: 1,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-breakfast-1',
              name: 'Walnuts, 20 g',
              nutrition: Nutrition(
                calories: 131,
                protein: 3,
                carbs: 3,
                fat: 13,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.lunch,
          title: 'Chickpea and tomato salad with olive oil',
          items: [
            FoodItem(
              id: 'plan-mediterranean-fav-lunch-0',
              name: 'Chickpeas, cooked, 150 g',
              nutrition: Nutrition(
                calories: 246,
                protein: 13,
                carbs: 41,
                fat: 4,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-lunch-1',
              name: 'Olive oil, 1 tbsp',
              nutrition: Nutrition(
                calories: 119,
                protein: 0,
                carbs: 0,
                fat: 14,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-lunch-2',
              name: 'Tomato and cucumber, 150 g',
              nutrition: Nutrition(calories: 27, protein: 1, carbs: 6, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.dinner,
          title: 'Grilled sardines, bulgur and greens',
          items: [
            FoodItem(
              id: 'plan-mediterranean-fav-dinner-0',
              name: 'Sardines, grilled, 120 g',
              nutrition: Nutrition(
                calories: 250,
                protein: 30,
                carbs: 0,
                fat: 14,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-dinner-1',
              name: 'Bulgur, cooked, 180 g',
              nutrition: Nutrition(
                calories: 151,
                protein: 6,
                carbs: 34,
                fat: 0,
              ),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-dinner-2',
              name: 'Spinach, sautéed, 100 g',
              nutrition: Nutrition(calories: 45, protein: 3, carbs: 4, fat: 2),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
        PlannedMeal(
          slot: MealSlot.snack,
          title: 'Orange and almonds',
          items: [
            FoodItem(
              id: 'plan-mediterranean-fav-snack-0',
              name: 'Orange, 1 medium',
              nutrition: Nutrition(calories: 62, protein: 1, carbs: 15, fat: 0),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
            FoodItem(
              id: 'plan-mediterranean-fav-snack-1',
              name: 'Almonds, 15 g',
              nutrition: Nutrition(calories: 87, protein: 3, carbs: 3, fat: 8),
              source: FoodSource.database,
              confidence: FoodConfidence.high,
            ),
          ],
        ),
      ],
      goal: 'Heart health, long-term maintenance',
      name: 'Mediterranean Lifestyle',
      image: 'assets/images/app/fav_medi.png',
      nutrition: Nutrition(calories: 1248, protein: 80, carbs: 114, fat: 56),
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
