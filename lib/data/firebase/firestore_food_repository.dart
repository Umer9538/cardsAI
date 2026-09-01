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

  /// Candidates fetched before ranking.
  ///
  /// Wide enough that a common word still leaves the ranker a real choice, and
  /// bounded because it is the read cost of every single search: Firestore's
  /// free tier allows 50,000 document reads a day across the *whole app*, so at
  /// this width roughly 800 searches a day is the ceiling before the diary
  /// starts competing with the search box for quota.
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

  /// Sorted word pairs of [tokens].
  ///
  /// MUST match `pairsOf` in `workers/src/catalogue.ts`.
  static List<String> pairsOf(List<String> tokens) {
    final words = tokens.take(8).toList();
    final pairs = <String>{};
    for (var i = 0; i < words.length; i++) {
      for (var j = i + 1; j < words.length; j++) {
        pairs.add(([words[i], words[j]]..sort()).join('|'));
      }
    }
    return pairs.toList();
  }

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
      // Two strategies, because a one-word query and a two-word query fail in
      // different ways against an index with no full-text search.
      var docs = tokens.length >= 2
          ? await _byPairs(tokens)
          : await _byNamePrefix(trimmed.toLowerCase());

      // Neither is exhaustive — a pair only matches when both words appear, and
      // a prefix only when the name begins with the query. Falling back to the
      // loose token query keeps an unusual phrasing findable.
      if (docs.isEmpty) docs = await _byTokens(tokens);

      if (docs.isEmpty) {
        // An empty mirror is also the state before the first sync completes,
        // and is indistinguishable here from a genuinely unknown food.
        return _fallback.search(trimmed, limit: limit);
      }

      final phrase = trimmed.toLowerCase();
      final scored = docs.map((d) => (_score(d, tokens, phrase), d)).toList()
        ..sort((a, b) => b.$1.compareTo(a.$1));

      return scored.take(limit).map((e) => _toFoodItem(e.$2)).toList();
    } on FirebaseException catch (e) {
      debugPrint('food catalogue unavailable (${e.code}); using live search.');
      return _fallback.search(trimmed, limit: limit);
    }
  }

  /// Multi-word queries, by sorted word pair.
  ///
  /// This is the query that makes multi-word search work. A pair is one indexed
  /// term that requires *both* words, so "olive oil" cannot match "OLIVE
  /// GARDEN, spaghetti with meat sauce" — that name has no "oil" in it. Matching
  /// the two words separately, which is what the token query does, returns
  /// everything containing either and leaves the ranker an arbitrary page.
  Future<List<Map<String, dynamic>>> _byPairs(List<String> tokens) async {
    final pairs = pairsOf(tokens);
    if (pairs.isEmpty) return const [];

    final snapshot = await _firestore
        .collection('foods')
        .where('pairs', arrayContainsAny: pairs.take(_maxTokens).toList())
        .orderBy('rank')
        .limit(_candidates)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// Single-word queries, by name prefix.
  ///
  /// FDC names lead with the food and follow with qualifiers — "Spinach, raw",
  /// "Bananas, dehydrated". So for one word the useful set is the names that
  /// *begin* with it, which is a range scan rather than an arbitrary page: it is
  /// the difference between "Spinach, raw" and "New Zealand spinach, raw".
  ///
  /// `\uf8ff` is past every ordinary character, so it bounds the range at the
  /// end of the prefix.
  Future<List<Map<String, dynamic>>> _byNamePrefix(String prefix) async {
    final snapshot = await _firestore
        .collection('foods')
        .where('nameLower', isGreaterThanOrEqualTo: prefix)
        .where('nameLower', isLessThan: '$prefix\uf8ff')
        .orderBy('nameLower')
        .limit(_candidates)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// The loose fallback: any single word, generic foods first.
  Future<List<Map<String, dynamic>>> _byTokens(List<String> tokens) async {
    final snapshot = await _firestore
        .collection('foods')
        .where('tokens', arrayContainsAny: tokens.take(_maxTokens).toList())
        .orderBy('rank')
        .limit(_candidates)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  /// How well one catalogue entry answers the query.
  ///
  /// Hand-tuned rather than derived: there is no relevance signal to work from,
  /// so this encodes what a person means when they type a food name.
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

    // The strongest signal available, and the one that sorts "Rice, brown,
    // long-grain, cooked" above "Babyfood, cereal, brown rice, dry": an FDC
    // description names the food first and qualifies it afterwards, so a name
    // whose first word is what you asked for is the food itself rather than
    // something containing it. Compared by prefix in both directions, because
    // "bananas" should answer "banana".
    final first = name.split(RegExp(r'[^a-z0-9]+')).firstWhere(
          (w) => w.isNotEmpty,
          orElse: () => '',
        );
    if (first.isNotEmpty &&
        tokens.any((t) => first.startsWith(t) || t.startsWith(first))) {
      score += 25;
    }

    // Among equals the shorter description wins: FDC's generic entries are
    // short ("Spinach, raw") and its oddities are long ("Spinach, creamed,
    // from fresh, made with margarine").
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
