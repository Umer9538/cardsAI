import 'dart:convert';

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
      'nutriments,quantity';

  /// Open Food Facts asks every client to identify itself, and rate-limits
  /// anonymous traffic harder.
  Map<String, String> get _headers => {
        'User-Agent': 'Carbsai/1.0 (nutrition tracker)',
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
      final response = await _client.get(uri, headers: _headers).timeout(_timeout);

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
        : (servingGrams == null || servingGrams <= 0 ? 1.0 : servingGrams / 100);
    final suffix = hasServingValues ? '_serving' : '_100g';

    double read(String key) =>
        (_number(nutriments['$key$suffix']) ?? 0) * scale;

    final brand = (product['brands'] as String?)
        ?.split(',')
        .first
        .trim();

    final portionGrams = servingGrams ?? (hasServingValues ? null : 100);

    return FoodItem(
      id: _uuid.v4(),
      name: brand == null || brand.isEmpty ? name : '$name ($brand)',
      portionDescription: (product['serving_size'] as String?)?.trim().isNotEmpty
              ?? false
          ? (product['serving_size'] as String).trim()
          : '100 g',
      portionGrams: portionGrams,
      nutrition: Nutrition(
        calories: read('energy-kcal'),
        protein: read('proteins'),
        carbs: read('carbohydrates'),
        fat: read('fat'),
        fiber: read('fiber'),
        sugar: read('sugars'),
      ),
      source: FoodSource.database,
      // A label is a measured value, not an estimate — but the *portion* still
      // is, so this is not "high".
      confidence: FoodConfidence.medium,
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
