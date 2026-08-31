import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';

/// Food search against the local mirror of USDA FoodData Central.
///
/// The catalogue lives in a shared `foods` collection, synced nightly by the
/// Worker. Searching it instead of calling FDC live is the difference between
/// 100-200ms and 1-5 seconds, and between working and failing one call in
/// twelve — FDC's edge drops requests, and a search box cannot be built on that.
///
/// The query runs from the client rather than through the Worker on purpose:
/// one round trip instead of two, and Firestore's offline cache means a repeat
/// search still answers with no connection at all.
///
/// ---------------------------------------------------------------------------
/// Ranking
/// ---------------------------------------------------------------------------
/// Firestore has no full-text index and cannot order by relevance, so it is
/// only used to *narrow*: `array-contains-any` over the description's words
/// returns a candidate page, and the ordering is decided here.
///
/// The consequence worth knowing: for a very common word the candidate page is
/// an arbitrary slice, not the best matches. [_candidates] is therefore several
/// times the number of results actually shown, so the ranking has something to
/// choose between.
class FirestoreFoodRepository implements FoodDatabaseRepository {
  FirestoreFoodRepository(this._firestore, this._fallback);

  final FirebaseFirestore _firestore;

  /// Live USDA through the Worker, and Open Food Facts behind that. Used for
  /// barcode always, and for search when the mirror has nothing.
  final FoodDatabaseRepository _fallback;

  final _uuid = const Uuid();

  /// Firestore caps `arrayContainsAny` at 30; ten words is already a long
  /// query for a food.
  static const int _maxTokens = 10;

  /// Candidates fetched before ranking. Wide enough that a common word still
  /// leaves the ranker a real choice, narrow enough to stay one cheap read.
  static const int _candidates = 60;

  /// Words worth searching on.
  ///
  /// MUST match `tokenize` in `workers/src/catalogue.ts`. A token produced
  /// there and not here — or the reverse — is a food that can never be found.
  static List<String> tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.length > 2)
      .toSet()
      .toList();

  @override
  Future<FoodItem?> lookupBarcode(String barcode) =>
      _fallback.lookupBarcode(barcode);

  @override
  Future<List<FoodItem>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final tokens = tokenize(trimmed);
    // Nothing long enough to index — "egg" survives, "a pie" does not. Let the
    // live path try rather than returning an empty list.
    if (tokens.isEmpty) return _fallback.search(trimmed, limit: limit);

    try {
      final snapshot = await _firestore
          .collection('foods')
          .where('tokens', arrayContainsAny: tokens.take(_maxTokens).toList())
          .limit(_candidates)
          .get();

      if (snapshot.docs.isEmpty) {
        // An empty mirror is the state before the first sync completes, and is
        // indistinguishable here from a genuinely unknown food. Either way the
        // live database is the better answer.
        return _fallback.search(trimmed, limit: limit);
      }

      final lower = trimmed.toLowerCase();
      final scored = snapshot.docs
          .map((doc) => (_score(doc.data(), tokens, lower), doc.data()))
          .toList()
        ..sort((a, b) => b.$1.compareTo(a.$1));

      return scored.take(limit).map((e) => _toFoodItem(e.$2)).toList();
    } on FirebaseException catch (e) {
      debugPrint('food catalogue unavailable (${e.code}); using live search.');
      return _fallback.search(trimmed, limit: limit);
    }
  }

  /// How well one catalogue entry answers the query.
  ///
  /// Hand-tuned rather than derived: there is no relevance signal to work from,
  /// so this encodes what a person means when they type a food name. Matching
  /// the whole phrase beats matching the words separately; leading with the
  /// phrase beats containing it; and among equals the shorter description wins,
  /// because FDC's generic entries are short ("Spinach, raw") and its
  /// oddities are long ("Spinach, creamed, from fresh, made with margarine").
  static int _score(
    Map<String, dynamic> data,
    List<String> tokens,
    String phrase,
  ) {
    final name = (data['name'] as String? ?? '').toLowerCase();
    if (name.isEmpty) return -1000;

    var score = 0;
    for (final token in tokens) {
      if (name.contains(token)) score += 10;
    }
    if (name.startsWith(phrase)) {
      score += 40;
    } else if (name.contains(phrase)) {
      score += 20;
    }
    // First word of the description carries most of its meaning.
    if (tokens.isNotEmpty && name.startsWith(tokens.first)) score += 15;

    score -= name.length ~/ 15;
    return score;
  }

  FoodItem _toFoodItem(Map<String, dynamic> data) {
    double at(String key) => (data[key] as num?)?.toDouble() ?? 0;

    return FoodItem(
      // Minted per result, not from fdcId: the same food can be added to one
      // meal twice, and the scan controller keys portion edits and removals on
      // this id.
      id: _uuid.v4(),
      name: data['name'] as String? ?? 'Unknown',
      portionDescription: '100 g',
      portionGrams: (data['portionGrams'] as num?)?.toDouble() ?? 100,
      nutrition: Nutrition(
        calories: at('calories'),
        protein: at('protein'),
        carbs: at('carbs'),
        fat: at('fat'),
        fiber: at('fiber'),
        sugar: at('sugar'),
      ),
      source: FoodSource.database,
      // The composition is measured, but the portion is still the user's to
      // set — so this is not "high".
      confidence: FoodConfidence.medium,
    );
  }
}
