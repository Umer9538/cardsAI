import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'worker_endpoints.dart';

/// Turns the user's own targets into a one-day plan, through the same Worker
/// and the same model the scan pipeline uses.
///
/// Only the free text is sent. Everything the plan is built against — calories,
/// macros, meals per day, diet preference — the server reads from the profile,
/// because those numbers are `TargetCalculator`'s output and that is where the
/// deficit cap and the calorie floors live.
class WorkerPlannerRepository implements PlannerRepository {
  WorkerPlannerRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _uuid = Uuid();

  @override
  Future<DietPlan> generate({String? notes}) async {
    try {
      final result = await _functions
          .workerCallable('generatePlan')
          .call<Map<String, dynamic>>({'notes': notes ?? ''});

      return _toPlan(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw RepositoryException(_message(e), code: e.code);
    }
  }

  static String _message(FirebaseFunctionsException e) => switch (e.code) {
        'resource-exhausted' =>
          e.message ?? 'That is all the plans for today. Come back tomorrow.',
        'failed-precondition' => e.message ??
            'Answer a few questions about yourself first, so the plan has a '
                'target to hit.',
        'unauthenticated' => 'Sign in to build a plan.',
        _ => 'The plan could not be built. Try again in a moment.',
      };

  /// Maps the model's output onto the app's own types.
  ///
  /// The generated plan carries no image — every catalogue plan ships one and
  /// there is nothing to photograph here — so it takes the artboard's own
  /// stand-in rather than leaving a hole in the card.
  DietPlan _toPlan(Map<String, dynamic> data) {
    final meals = <PlannedMeal>[];
    for (final raw in (data['meals'] as List? ?? const [])) {
      final meal = (raw as Map).cast<String, dynamic>();
      final items = <FoodItem>[];
      for (final rawItem in (meal['items'] as List? ?? const [])) {
        final item = (rawItem as Map).cast<String, dynamic>();
        items.add(
          FoodItem(
            id: _uuid.v4(),
            name: item['name'] as String? ?? '',
            nutrition: Nutrition(
              calories: _number(item['calories']),
              protein: _number(item['protein']),
              carbs: _number(item['carbs']),
              fat: _number(item['fat']),
            ),
            source: FoodSource.ai,
            // The figures are the model's, not a lab's. `medium` rather than
            // `high` says so without flagging every row for review.
            confidence: FoodConfidence.medium,
          ),
        );
      }
      meals.add(
        PlannedMeal(
          slot: MealSlot.values.firstWhere(
            (s) => s.name == meal['slot'],
            orElse: () => MealSlot.snack,
          ),
          title: meal['title'] as String? ?? '',
          items: items,
        ),
      );
    }

    final total = Nutrition.sum(meals.map((m) => m.nutrition));

    return DietPlan(
      id: 'plan-mine-${_uuid.v4()}',
      name: data['name'] as String? ?? 'My Plan',
      image: 'assets/images/app/diet_mediterranean.png',
      description: data['description'] as String? ?? '',
      goal: data['goal'] as String? ?? '',
      eat: [for (final v in (data['eat'] as List? ?? const [])) v as String],
      limit: [for (final v in (data['limit'] as List? ?? const [])) v as String],
      day: meals,
      // Derived from the day, exactly as the catalogue's are. A plan whose
      // stated macros disagree with its own meals is the bug this replaced.
      nutrition: total,
      isMine: true,
    );
  }

  static double _number(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}
