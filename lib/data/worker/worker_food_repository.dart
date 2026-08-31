import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'worker_endpoints.dart';

/// Food search through the Worker, barcode straight from the client.
///
/// The two halves go to different databases on purpose, because they are
/// different questions. A search is someone naming a food, and USDA FoodData
/// Central is where the reference foods live — it is also what the scan prompt
/// tells the model to match its composition against, so a searched food and an
/// estimated one now agree on what chicken breast is. A barcode identifies a
/// packaged product exactly, and Open Food Facts is the stronger database for
/// those.
///
/// Search goes through the Worker because FDC needs an API key. Barcode does
/// not, so it stays a direct client call with nothing in the way.
class WorkerFoodRepository implements FoodDatabaseRepository {
  WorkerFoodRepository(this._functions, this._openFoodFacts);

  final FirebaseFunctions _functions;

  /// Open Food Facts: owns barcode outright, and stands in for search when the
  /// Worker cannot answer.
  final FoodDatabaseRepository _openFoodFacts;

  @override
  Future<FoodItem?> lookupBarcode(String barcode) =>
      _openFoodFacts.lookupBarcode(barcode);

  @override
  Future<List<FoodItem>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    try {
      final result = await _functions
          .workerCallable('searchFoods')
          .call<Map<String, dynamic>>({'query': trimmed, 'limit': limit});

      final items = (result.data['items'] as List?) ?? const [];
      return items
          .map((raw) => FoodItem.fromJson((raw as Map).cast<String, dynamic>()))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      // Fall back rather than fail.
      //
      // Search is the path that is meant to always work — no camera, no model,
      // no quota, no cost — and it is what someone reaches for once their scans
      // have run out. An unconfigured key, a rate limit, or FDC being down
      // should degrade to a worse database, not to a dead end.
      debugPrint('USDA search unavailable (${e.code}); falling back to Open Food Facts.');
      return _openFoodFacts.search(trimmed, limit: limit);
    }
  }
}
