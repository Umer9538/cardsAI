import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../worker/worker_endpoints.dart';

/// The real scan pipeline: the `analyzeMeal` Cloud Function, which holds the
/// OpenAI key and calls the model on our behalf.
///
/// The app never talks to OpenAI directly and never holds an API key. That is
/// the whole reason the function exists — a key in the binary is a key that has
/// been published, and it would be spent by someone else within days.
class FunctionsScanRepository implements ScanRepository {
  FunctionsScanRepository(this._functions, this._firestore, this._auth);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final _uuid = const Uuid();

  /// Longer than the function's own 120s ceiling, so a server-side timeout
  /// surfaces as its own error rather than as a client timeout that hides it.
  static const Duration _timeout = Duration(seconds: 130);

  @override
  Future<ScanResult> analyzePhoto({
    required String imagePath,
    String? hint,
    ScanInput input = ScanInput.photo,
  }) async {
    final bytes = await _readCapture(imagePath);
    return _call(
      {
        'imageBase64': base64Encode(bytes),
        'mimeType': 'image/jpeg',
        if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
      },
      input: input,
      photoPath: imagePath,
    );
  }

  @override
  Future<ScanResult> analyzeText(String description) {
    if (description.trim().isEmpty) {
      throw const RepositoryException(
        'Describe what you ate.',
        code: 'empty-description',
      );
    }
    return _call({'description': description.trim()}, input: ScanInput.text);
  }

  @override
  Future<ScanResult> lookupBarcode(String barcode) async {
    // Needs a product database (Open Food Facts) rather than the model — a
    // barcode is a lookup, not an estimate. Deliberately not routed through
    // the function.
    throw const RepositoryException(
      'Barcode scanning is not available yet.',
      code: 'not-implemented',
    );
  }

  @override
  Future<List<ScanResult>> history({int limit = 50}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    // The server writes the scan log; the client only reads it. It records
    // what a scan cost and how it went, not the items — those live on the meal
    // once it is logged.
    final snap = await _firestore
        .collection('users/$uid/scans')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return ScanResult(
        id: doc.id,
        capturedAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        items: const [],
        input: ScanInput.values
                .where((i) => i.name == data['input'])
                .firstOrNull ??
            ScanInput.photo,
        confidence: FoodConfidence.values
                .where((c) => c.name == data['overallConfidence'])
                .firstOrNull ??
            FoodConfidence.unknown,
        modelId: data['model'] as String?,
        latencyMs: (data['latencyMs'] as num?)?.toInt(),
      );
    }).toList();
  }

  Future<List<int>> _readCapture(String imagePath) async {
    // The stand-in the app falls back to when there is no camera is a bundled
    // asset, not a file on disk.
    if (imagePath.startsWith('assets/')) {
      final data = await rootBundle.load(imagePath);
      return data.buffer.asUint8List();
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      throw const RepositoryException(
        'That photo is no longer available. Take another.',
        code: 'missing-capture',
      );
    }
    return file.readAsBytes();
  }

  Future<ScanResult> _call(
    Map<String, dynamic> payload, {
    required ScanInput input,
    String? photoPath,
  }) async {
    final started = DateTime.now();
    try {
      final response = await _functions
          .workerCallable(
            'analyzeMeal',
            options: HttpsCallableOptions(timeout: _timeout),
          )
          .call<Map<String, dynamic>>(payload);

      return _parse(
        response.data,
        input: input,
        photoPath: photoPath,
        capturedAt: started,
      );
    } on FirebaseFunctionsException catch (e) {
      throw RepositoryException(_translate(e), code: e.code);
    }
  }

  ScanResult _parse(
    Map<String, dynamic> data, {
    required ScanInput input,
    required DateTime capturedAt,
    String? photoPath,
  }) {
    final rawItems = (data['items'] as List?) ?? const [];

    final items = rawItems.map((raw) {
      final item = (raw as Map).cast<String, dynamic>();
      return FoodItem(
        // The server does not id individual items; the UI needs stable keys to
        // edit and remove them, so they are minted here.
        id: _uuid.v4(),
        name: item['name'] as String? ?? 'Unknown',
        portionDescription: item['portion_desc'] as String? ?? '',
        portionGrams: _toDouble(item['portion_grams']),
        nutrition: Nutrition(
          calories: _toDouble(item['calories']) ?? 0,
          protein: _toDouble(item['protein_g']) ?? 0,
          carbs: _toDouble(item['carbs_g']) ?? 0,
          fat: _toDouble(item['fat_g']) ?? 0,
          fiber: _toDouble(item['fiber_g']) ?? 0,
          sugar: _toDouble(item['sugar_g']) ?? 0,
        ),
        confidence: _confidence(item['confidence']),
      );
    }).toList();

    return ScanResult(
      id: data['id'] as String? ?? _uuid.v4(),
      capturedAt: capturedAt,
      items: items,
      input: input,
      photoPath: photoPath,
      confidence: _confidence(data['overallConfidence']),
      clarifyingQuestion: data['clarifyingQuestion'] as String?,
      modelId: data['model'] as String?,
      latencyMs: (data['latencyMs'] as num?)?.toInt(),
    );
  }

  static double? _toDouble(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };

  static FoodConfidence _confidence(Object? value) =>
      FoodConfidence.values.where((c) => c.name == value).firstOrNull ??
      FoodConfidence.unknown;

  /// The function's own `HttpsError` codes, as sentences.
  ///
  /// `e.message` is already user-facing for the errors the function raises
  /// itself — it writes them for this purpose — so it is preferred where
  /// present. The fallbacks cover transport failures, which have no message
  /// worth showing.
  static String _translate(FirebaseFunctionsException e) {
    final message = e.message;
    if (message != null && message.isNotEmpty) return message;

    return switch (e.code) {
      'unauthenticated' => 'Sign in to scan a meal.',
      'resource-exhausted' =>
        'You have used all your scans for this month.',
      'deadline-exceeded' =>
        'That took too long. Try again, or describe your meal.',
      'unavailable' =>
        'No connection to the analyser. Check your network and try again.',
      _ => 'We could not read that one. Try again, or describe your meal.',
    };
  }
}
