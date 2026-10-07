import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_config.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'worker_endpoints.dart';

/// Turns the user's own targets into a one-day plan, through the same Worker
/// and the same model the scan pipeline uses.
///
/// Only the free text is sent. Everything the plan is built against — calories,
/// macros, meals per day, diet preference — the server reads from the profile,
/// because those numbers are `TargetCalculator`'s output and that is where the
/// deficit cap and the calorie floors live. The plan's *purpose* — weight
/// loss, muscle — comes back the same way: it is the server's reading of the
/// profile's goal and motivation, returned as `purpose`, never sent.
class WorkerPlannerRepository implements PlannerRepository {
  WorkerPlannerRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _uuid = Uuid();

  @override
  Future<DietPlan> generate({TasteProfile? taste, String? notes}) async {
    final profile = (taste ?? TasteProfile.empty).copyWith(
      // One notes field on the wire. The quiz's own "anything else" box and
      // the legacy text builder both land here.
      notes: [
        if ((taste?.notes ?? '').trim().isNotEmpty) taste!.notes.trim(),
        if ((notes ?? '').trim().isNotEmpty) notes!.trim(),
      ].join('\n'),
    );
    try {
      final result = await _functions
          .workerCallable('generatePlan')
          .call<Map<String, dynamic>>(profile.toJson());

      // The purpose leads "Built for you", ahead of the taste chips: what
      // the day is for, then what is in it.
      final purpose = (result.data['purpose'] as String?)?.trim() ?? '';
      return _toPlan(result.data).copyWith(
        builtFor: [if (purpose.isNotEmpty) purpose, ...profile.summary],
      );
    } on FirebaseFunctionsException catch (e) {
      throw RepositoryException(_message(e), code: e.code);
    } on StateError catch (error, stack) {
      // Only [AppConfig.workerUri]'s own refusal means an unconfigured build.
      //
      // This used to catch every StateError and report all of them as a
      // missing WORKER_URL, which sent the reader to the build flags for a
      // failure that had nothing to do with them — a worse lie than the
      // generic message it replaced, because it was specific and wrong. A
      // catch clause may only claim a cause it has actually checked.
      if (AppConfig.workerBaseUrl.isEmpty) {
        throw const RepositoryException(
          'This build has no server address, so it cannot build a plan. Run it '
          'with --dart-define=WORKER_URL=…',
          code: 'not-configured',
        );
      }
      debugPrint('plan generation failed: $error\n$stack');
      rethrow;
    }
  }

  /// The Worker writes its own sentences for the two codes it raises, so those
  /// are preferred — but only when the message is genuinely a sentence.
  /// `cloud_functions` puts the status name in `message` when the call never
  /// reached the Worker, and "RESOURCE_EXHAUSTED" is not something to show a
  /// person. See [looksLikeAStatusCode].
  static String _message(FirebaseFunctionsException e) {
    final message = looksLikeAStatusCode(e.message) ? null : e.message;
    return switch (e.code) {
      'resource-exhausted' =>
        message ?? 'That is all the plans for today. Come back tomorrow.',
      'failed-precondition' => message ??
          'Answer a few questions about yourself first, so the plan has a '
              'target to hit.',
      'unauthenticated' => 'Sign in to build a plan.',
      'unavailable' || 'internal' =>
        'We could not reach the planner. Check your connection and try again.',
      'deadline-exceeded' => 'That took too long. Please try again.',
      _ => 'The plan could not be built. Try again in a moment.',
    };
  }

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
      image: 'assets/images/app/diet_mediterranean.webp',
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
