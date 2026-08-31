import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';

/// Owns one capture, from analysing through editing to logged.
///
/// The result stays editable after it arrives — portions get adjusted, items
/// removed, items added — and only [logMeal] writes anything to the diary. The
/// original [ScanResult] is never rewritten by those edits, so the estimate the
/// model actually produced survives for the eval set.
class ScanController extends AsyncNotifier<ScanResult?> {
  final _uuid = const Uuid();

  @override
  FutureOr<ScanResult?> build() => null;

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    return error is RepositoryException
        ? error.message
        : 'We could not read that one. Try again, or describe your meal.';
  }

  /// The repository's code for the current failure, so the UI can offer the
  /// right way out — running out of scans wants an upgrade or a rewarded ad,
  /// not a "try again".
  String? get errorCode => (state.error as RepositoryException?)?.code;

  bool get outOfScans => errorCode == 'resource-exhausted';

  /// Re-runs the last capture after more scans have been banked.
  Future<void> retryLast() async {
    final path = _lastImagePath;
    final description = _lastDescription;
    if (path != null) {
      await analyzePhoto(path, hint: _lastHint);
    } else if (description != null) {
      await describe(description);
    }
  }

  String? _lastImagePath;
  String? _lastHint;
  String? _lastDescription;

  Future<void> analyzePhoto(String imagePath, {String? hint}) {
    _lastImagePath = imagePath;
    _lastHint = hint;
    _lastDescription = null;
    return _run(() => ref.read(scanRepositoryProvider).analyzePhoto(
          imagePath: imagePath,
          hint: hint,
        ));
  }

  Future<void> analyzeGallery(String imagePath, {String? hint}) =>
      _run(() => ref.read(scanRepositoryProvider).analyzePhoto(
            imagePath: imagePath,
            hint: hint,
            input: ScanInput.gallery,
          ));

  Future<void> describe(String description) {
    _lastDescription = description;
    _lastImagePath = null;
    return _run(() => ref.read(scanRepositoryProvider).analyzeText(description));
  }

  /// Barcode goes to the food database, not the model.
  ///
  /// A barcode identifies a product exactly, so asking a vision model to guess
  /// would be both worse and billable. A product the database has never seen is
  /// a normal outcome, and says so.
  Future<void> scanBarcode(String barcode) async {
    state = const AsyncLoading();
    _portions.clear();

    state = await AsyncValue.guard(() async {
      final item = await ref.read(foodDatabaseProvider).lookupBarcode(barcode);
      if (item == null) {
        throw const RepositoryException(
          'That product is not in the food database yet. Try a photo or '
          'describe it instead.',
          code: 'not-found',
        );
      }
      return ScanResult(
        id: _uuid.v4(),
        capturedAt: DateTime.now(),
        items: [item],
        input: ScanInput.barcode,
        confidence: FoodConfidence.medium,
      );
    });
    _asAnalysed = state.value?.items ?? const [];
  }

  /// Builds a result from foods picked out of the database by hand.
  void fromSearch(List<FoodItem> items) {
    _portions.clear();
    _asAnalysed = items;
    state = AsyncData(
      ScanResult(
        id: _uuid.v4(),
        capturedAt: DateTime.now(),
        items: items,
        input: ScanInput.search,
        confidence: FoodConfidence.high,
      ),
    );
  }

  /// The model's original items, before any portion edit.
  ///
  /// Portion factors are applied to these rather than to the current values,
  /// so tapping ½× then 2× returns to the original rather than compounding to
  /// 1× of something already halved.
  List<FoodItem> _asAnalysed = const [];

  /// Factor currently applied to each item, keyed by item id.
  final Map<String, double> _portions = {};

  double portionOf(String itemId) => _portions[itemId] ?? 1;

  /// Re-scales one item's portion — the ½× / ¾× / 1× / 1½× / 2× control.
  void adjustPortion(String itemId, double factor) {
    final current = state.value;
    if (current == null) return;

    _portions[itemId] = factor;

    state = AsyncData(
      current.copyWith(
        items: [
          for (final item in current.items)
            if (item.id != itemId)
              item
            else
              _originalOf(itemId, item).scaledBy(factor),
        ],
      ),
    );
  }

  FoodItem _originalOf(String id, FoodItem fallback) {
    for (final item in _asAnalysed) {
      if (item.id == id) return item;
    }
    return fallback;
  }

  void removeItem(String itemId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((item) => item.id != itemId).toList(),
      ),
    );
  }

  void addItem(FoodItem item) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: [...current.items, item]));
  }

  void renameItem(String itemId, String name) => _edit(
        (item) =>
            item.id == itemId ? item.copyWith(name: name, userEdited: true) : item,
      );

  /// Commits the current items to the diary and clears the controller.
  ///
  /// The meal is written first and the photo uploaded after, so a failed or
  /// slow upload can never cost someone the numbers — those are the point, and
  /// the photo is a nicety. If the upload succeeds the meal is updated with the
  /// durable URL; if it does not, the meal keeps its local path and the diary
  /// still renders.
  Future<Meal> logMeal({DateTime? eatenAt, bool favourite = false}) async {
    final current = state.value;
    if (current == null) {
      throw const RepositoryException(
        'There is nothing to log yet.',
        code: 'no-result',
      );
    }

    final diary = ref.read(diaryRepositoryProvider);
    final meal =
        current.toMeal(id: _uuid.v4(), eatenAt: eatenAt, favourite: favourite);
    await diary.addMeal(meal);
    state = const AsyncData(null);

    final localPath = meal.photoPath;
    if (localPath != null) {
      try {
        final url = await ref
            .read(photoRepositoryProvider)
            .upload(localPath, mealId: meal.id);
        if (url != null && url != localPath) {
          await diary.updateMeal(meal.copyWith(photoPath: url));
        }
      } on RepositoryException catch (error) {
        // Deliberately swallowed: the meal is logged, which is what the tap
        // asked for. Surfacing this as a failure would imply otherwise.
        debugPrint('meal photo upload failed: ${error.message}');
      }
    }

    return meal;
  }

  /// Drops the result without logging it — backing out of the result screen.
  void discard() => state = const AsyncData(null);

  void _edit(FoodItem Function(FoodItem) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(items: current.items.map(change).toList()),
    );
  }

  Future<void> _run(Future<ScanResult> Function() action) async {
    state = const AsyncLoading();
    _portions.clear();
    final result = await AsyncValue.guard(action);
    _asAnalysed = result.value?.items ?? const [];
    state = result;
  }
}

final scanControllerProvider =
    AsyncNotifierProvider<ScanController, ScanResult?>(ScanController.new);
