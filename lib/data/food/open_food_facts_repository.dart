import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';

/// Barcode lookup and food search, against Open Food Facts.
///
/// Chosen over USDA FoodData Central because it needs no API key and no
/// registration, which means barcode and search work on the free Firebase plan
/// — unlike the photo pipeline, nothing here has a secret to protect, so the
/// client can call it directly and there is no Cloud Function in the way.
///
/// Open Food Facts is crowd-sourced, so coverage is excellent for packaged
/// goods in Europe and patchy for loose produce and anything regional. Missing
/// products are normal, not an error, and the UI says so rather than implying
/// the scan failed.
class OpenFoodFactsRepository implements FoodDatabaseRepository {
  OpenFoodFactsRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final _uuid = const Uuid();

  static const String _host = 'world.openfoodfacts.org';

  /// Requested explicitly so the response carries only what is needed — the
  /// full product document runs to hundreds of fields and megabytes per page.
  static const String _fields =
      'code,product_name,brands,serving_quantity,serving_size,'
      'nutriments,quantity,'
      // The packshot. Easy to forget: `fields` is an allow-list, so a key that
      // is not named here is simply absent from the response — the parser was
      // reading `image_front_url` out of a document that never contained it.
      'image_front_url,image_url,image_front_small_url';

  /// The field allow-list, exposed so a test can assert the photograph is in
  /// it. Adding a reader without adding its key here is a silent no-op.
  @visibleForTesting
  static const String debugFields = _fields;

  /// Open Food Facts asks every client to identify itself, and rate-limits
  /// anonymous traffic harder.
  Map<String, String> get _headers => {
    'User-Agent': 'Carbs AI/1.0 (nutrition tracker)',
    'Accept': 'application/json',
  };

  static const Duration _timeout = Duration(seconds: 12);

  @override
  Future<FoodItem?> lookupBarcode(String barcode) async {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      throw const RepositoryException(
        'That does not look like a product barcode.',
        code: 'invalid-barcode',
      );
    }

    final uri = Uri.https(_host, '/api/v2/product/$digits.json', {
      'fields': _fields,
    });

    final body = await _get(uri);
    // status 0 is Open Food Facts for "no such product", which is a normal
    // outcome for anything not in the database yet.
    if (body['status'] == 0 || body['product'] == null) return null;

    return _toFoodItem((body['product'] as Map).cast<String, dynamic>());
  }

  @override
  Future<List<FoodItem>> search(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final uri = Uri.https(_host, '/cgi/search.pl', {
      'search_terms': trimmed,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '$limit',
      'fields': _fields,
    });

    final body = await _get(uri);
    final products = (body['products'] as List?) ?? const [];

    return products
        .map((raw) => _toFoodItem((raw as Map).cast<String, dynamic>()))
        .whereType<FoodItem>()
        .toList();
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode == 429) {
        throw const RepositoryException(
          'The food database is busy. Try again in a moment.',
          code: 'rate-limited',
        );
      }
      if (response.statusCode != 200) {
        throw RepositoryException(
          'The food database is unavailable right now.',
          code: 'http-${response.statusCode}',
        );
      }
      return (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } on RepositoryException {
      rethrow;
    } catch (error) {
      throw const RepositoryException(
        'Could not reach the food database. Check your connection.',
        code: 'network',
      );
    }
  }

  /// Builds an item for one serving, falling back to 100g.
  ///
  /// Open Food Facts stores nutrition per 100g and, when the packaging says so,
  /// per serving. Serving is what a person actually eats, so it wins; the
  /// per-100g values are scaled to the serving weight when only those exist.
  /// Exposed so the plausibility rules below can be tested against real
  /// records. The HTTP half is not the interesting part; what Open Food Facts
  /// is allowed to put on screen is.
  @visibleForTesting
  FoodItem? parseProduct(Map<String, dynamic> product) => _toFoodItem(product);

  FoodItem? _toFoodItem(Map<String, dynamic> product) {
    final name = (product['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final nutriments =
        (product['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};

    final servingGrams = _number(product['serving_quantity']);
    final hasServingValues = nutriments.containsKey('energy-kcal_serving');

    // Either read the per-serving figures directly, or scale the per-100g ones
    // by the serving weight.
    final scale = hasServingValues
        ? 1.0
        : (servingGrams == null || servingGrams <= 0
              ? 1.0
              : servingGrams / 100);
    final suffix = hasServingValues ? '_serving' : '_100g';

    double read(String key) =>
        (_number(nutriments['$key$suffix']) ?? 0) * scale;

    final brand = (product['brands'] as String?)?.split(',').first.trim();

    final portionGrams = servingGrams ?? (hasServingValues ? null : 100);

    final nutrition = Nutrition(
      calories: read('energy-kcal'),
      protein: read('proteins'),
      carbs: read('carbohydrates'),
      fat: read('fat'),
      fiber: read('fiber'),
      sugar: read('sugars'),
    );

    // A record with no nutrition in it is not a result.
    //
    // Open Food Facts is crowd-sourced, so plenty of products exist as a name
    // and a photograph with the figures never filled in. Returning those as a
    // 0 kcal food is worse than returning nothing: it logs a real meal as
    // free, silently. `searchFoods` drops the FDC equivalents for the same
    // reason.
    if (nutrition.calories <= 0 &&
        nutrition.protein <= 0 &&
        nutrition.carbs <= 0 &&
        nutrition.fat <= 0) {
      return null;
    }

    // Energy out of nothing is not a record either.
    //
    // The guard above only fires when *everything* is zero, so a product with
    // calories and no macros at all walked straight through it — which is what
    // `8888888888888` is: a crowd-sourced joke entry called "Motorcycle", 100
    // kcal, every macro field empty. It rendered as a confident label with
    // "Protein 0g · Carbs 0g · Fat 0g" beside 100 kcal, which no food can be.
    // Calories are *defined* by the macros; a record missing all three has not
    // been filled in, whatever its energy field says.
    final fromMacros =
        nutrition.protein * 4 + nutrition.carbs * 4 + nutrition.fat * 9;
    final stated = nutrition.calories;
    if (stated > 0 && fromMacros <= 0) return null;

    // And a record whose macros do not add up to its own calories is one
    // somebody typed in wrong.
    //
    // A tester scanned a Bordeaux reported as 292 kcal with 41.9g protein and
    // 28g fat — by the Atwater factors those macros are 560 kcal, and wine has
    // essentially no protein or fat at all. The scan pipeline already does
    // this check in `sanitize()` and drops the item to low confidence rather
    // than silently "fixing" it; this path had no equivalent and presented the
    // numbers as a measured label.
    final drift = stated > 0 && fromMacros > 0
        ? (fromMacros - stated).abs() / stated
        : 0.0;

    // Past a point it stops being uncertainty and becomes a bad record.
    //
    // `2222222222222` is filed as 147 kcal with 15.7g protein, 33.4g carbs and
    // 30.5g fat — 471 kcal by Atwater, out by a factor of 3.2. Flagging that
    // with a "Check this" chip still puts four fabricated numbers in front of
    // someone as a *label reading*, and the chip asks them to check against a
    // packet they are holding and will believe over us. A label this far from
    // its own macros is not worth showing at any confidence.
    if (drift > 1.0) return null;

    final mismatched = drift > 0.30;

    return FoodItem(
      id: _uuid.v4(),
      name: brand == null || brand.isEmpty ? name : '$name ($brand)',
      portionDescription:
          (product['serving_size'] as String?)?.trim().isNotEmpty ?? false
          ? (product['serving_size'] as String).trim()
          : '100 g',
      portionGrams: portionGrams,
      nutrition: nutrition,
      source: FoodSource.database,
      // A label is a measured value, not an estimate — but the *portion* still
      // is, so this is not "high"; and a record that contradicts itself earns
      // the "Check this" chip the result screen already renders for low.
      confidence: mismatched ? FoodConfidence.low : FoodConfidence.medium,
      imageUrl: _imageUrl(product),
    );
  }

  /// The product photograph, preferring the front of the pack.
  ///
  /// Open Food Facts exposes several sizes and angles under different keys and
  /// not every product has every one, so this walks them in order of how
  /// recognisable the result is. `_front_small` is last on purpose: it is only
  /// 200px and this fills a 428pt hero, but a soft picture of the right jar
  /// beats a stock photo of someone else's dinner.
  static String? _imageUrl(Map<String, dynamic> product) {
    for (final key in const [
      'image_front_url',
      'image_url',
      'image_front_small_url',
    ]) {
      final value = (product[key] as String?)?.trim();
      if (value != null && value.startsWith('http')) return value;
    }
    return null;
  }

  static double? _number(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}
