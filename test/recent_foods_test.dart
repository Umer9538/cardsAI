import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/recent_foods.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 6, 15, 20);

FoodItem _food(String name, {double grams = 100, double calories = 200}) =>
    FoodItem(
      id: '$name-$grams',
      name: name,
      nutrition: Nutrition(calories: calories, protein: 10, carbs: 20, fat: 5),
      portionGrams: grams,
    );

Meal _meal(int daysAgo, List<FoodItem> items, {int hour = 8}) => Meal(
      id: 'm$daysAgo-$hour',
      slot: MealSlot.breakfast,
      eatenAt: _now.subtract(Duration(days: daysAgo)).copyWith(hour: hour),
      items: items,
    );

void main() {
  test('the most-logged food comes first', () {
    final meals = [
      for (var d = 1; d <= 5; d++) _meal(d, [_food('Oats')]),
      _meal(1, [_food('Banana')], hour: 12),
      _meal(2, [_food('Banana')], hour: 12),
    ];

    final recent = RecentFoods.from(meals, now: _now);

    expect(recent.map((f) => f.item.name), ['Oats', 'Banana']);
    expect(recent.first.count, 5);
  });

  test('the portion is the one most recently logged', () {
    final meals = [
      _meal(5, [_food('Rice', grams: 100, calories: 130)]),
      _meal(1, [_food('Rice', grams: 250, calories: 325)]),
    ];

    final rice = RecentFoods.from(meals, now: _now).single;

    // Not the first portion, and not an average: someone who has moved to a
    // bigger bowl should get the bigger bowl offered back.
    expect(rice.item.portionGrams, 250);
    expect(rice.item.nutrition.calories, 325);
  });

  test('one meal counts a food once, however many rows it has', () {
    // A plate analysed as three helpings of rice is one instance of rice.
    // Counting rows would let a single messy scan dominate the list.
    final meals = [
      _meal(1, [_food('Rice'), _food('Rice'), _food('Rice')]),
      _meal(1, [_food('Eggs')], hour: 12),
      _meal(2, [_food('Eggs')], hour: 12),
    ];

    final recent = RecentFoods.from(meals, now: _now);

    expect(recent.first.item.name, 'Eggs');
    expect(recent.last.count, 1);
  });

  test('names differing only in case or spacing are one food', () {
    final meals = [
      _meal(1, [_food('Greek Yogurt')]),
      _meal(2, [_food('greek  yogurt')]),
      _meal(3, [_food(' GREEK YOGURT ')]),
    ];

    expect(RecentFoods.from(meals, now: _now), hasLength(1));
    expect(RecentFoods.from(meals, now: _now).single.count, 3);
  });

  test('anything older than the window is ignored', () {
    final meals = [
      for (var d = 30; d <= 40; d++) _meal(d, [_food('Old habit')]),
      _meal(1, [_food('Current')]),
    ];

    expect(
      RecentFoods.from(meals, now: _now).map((f) => f.item.name),
      ['Current'],
    );
  });

  test('a re-logged food does not ask to be checked again', () {
    final meals = [
      _meal(1, [
        FoodItem(
          id: 'x',
          name: 'Mystery stew',
          nutrition: const Nutrition(
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 15,
          ),
          confidence: FoodConfidence.low,
        ),
      ]),
    ];

    // The low confidence belonged to the scan that produced it. Someone who
    // already accepted this food should not be flagged over it every time.
    expect(RecentFoods.from(meals, now: _now).single.item.needsReview, isFalse);
  });

  test('an empty diary produces nothing', () {
    expect(RecentFoods.from(const [], now: _now), isEmpty);
  });

  test('the list is capped', () {
    final meals = [
      for (var i = 0; i < 30; i++) _meal(1, [_food('Food $i')], hour: i % 24),
    ];

    expect(RecentFoods.from(meals, now: _now), hasLength(12));
    expect(RecentFoods.from(meals, now: _now, limit: 5), hasLength(5));
  });
}
