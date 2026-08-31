import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';
import 'seed_data.dart';

/// Stands in for the real pipeline until the Cloud Function exists.
///
/// It waits a realistic amount of time and returns the artboard's three foods,
/// so the analysing state, the result screen and the "log this meal" path are
/// all exercisable now. `FunctionsScanRepository` replaces it behind the same
/// interface; nothing above this line changes.
///
/// It does not pretend to recognise anything — the result is the same whatever
/// you photograph. Do not ship a build with this wired up.
class LocalScanRepository implements ScanRepository {
  LocalScanRepository(this._store);

  final JsonStore _store;
  final _uuid = const Uuid();

  /// Roughly the p50 the PRD targets, so the loading state is honestly sized.
  static const Duration _analysisTime = Duration(milliseconds: 2200);

  @override
  Future<ScanResult> analyzePhoto({
    required String imagePath,
    String? hint,
    ScanInput input = ScanInput.photo,
  }) async {
    final started = DateTime.now();
    await Future<void>.delayed(_analysisTime);
    return _record(
      ScanResult(
        id: _uuid.v4(),
        capturedAt: started,
        items: SeedData.scannedFoods,
        input: input,
        photoPath: imagePath,
        confidence: FoodConfidence.high,
        modelId: 'local-stub',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      ),
    );
  }

  @override
  Future<ScanResult> analyzeText(String description) async {
    if (description.trim().isEmpty) {
      throw const RepositoryException(
        'Describe what you ate.',
        code: 'empty-description',
      );
    }
    final started = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return _record(
      ScanResult(
        id: _uuid.v4(),
        capturedAt: started,
        items: SeedData.scannedFoods,
        input: ScanInput.text,
        confidence: FoodConfidence.medium,
        modelId: 'local-stub',
      ),
    );
  }

  @override
  Future<ScanResult> lookupBarcode(String barcode) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return _record(
      ScanResult(
        id: _uuid.v4(),
        capturedAt: DateTime.now(),
        items: [SeedData.scannedFoods.first],
        input: ScanInput.barcode,
        confidence: FoodConfidence.high,
        modelId: 'local-stub',
      ),
    );
  }

  @override
  Future<List<ScanResult>> history({int limit = 50}) async {
    final stored = _store.readList(StoreKeys.scans) ?? const [];
    return stored.map(ScanResult.fromJson).take(limit).toList();
  }

  /// Keeps the last 50, newest first. Unbounded history would grow the
  /// preferences blob without limit, and nothing reads past the recent ones.
  Future<ScanResult> _record(ScanResult result) async {
    final existing = _store.readList(StoreKeys.scans) ?? const [];
    final updated = [result.toJson(), ...existing].take(50).toList();
    await _store.writeList(StoreKeys.scans, updated);
    return result;
  }
}
