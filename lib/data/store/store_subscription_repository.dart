import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../worker/worker_endpoints.dart';

/// Real subscriptions, through the App Store and Google Play.
///
/// The store is the only thing that can take money, and the server is the only
/// thing that decides what an account is entitled to. This class is the wire
/// between them: it drives the store's purchase UI, then hands the resulting
/// receipt to `activateSubscription`, which validates it and writes the
/// entitlement. It never writes entitlement itself.
///
/// ---------------------------------------------------------------------------
/// SETUP REQUIRED — none of this works until the products exist
/// ---------------------------------------------------------------------------
/// The ids in [SubscriptionPlan.catalogue] must be created as **subscription**
/// products, with matching ids, in both consoles:
///
///   Play Console  → Monetise → Subscriptions → create `monthly`, `annual`
///   App Store Connect → Subscriptions → create `monthly`, `annual`
///
/// Until then [plans] returns the catalogue's hardcoded prices and [purchase]
/// fails with `products-unavailable`. That is the expected state, not a bug.
///
/// Once they exist, prices must come from the STORE rather than from our
/// constants — both stores return localised, currency-correct prices, and
/// showing a hardcoded "$4.99" to someone paying in another currency is both
/// wrong and grounds for rejection. [_merge] already does this.
class StoreSubscriptionRepository implements SubscriptionRepository {
  StoreSubscriptionRepository(this._functions, this._readEntitlement) {
    _listen();
  }

  final FirebaseFunctions _functions;

  /// Reads the server's current entitlement. Injected rather than duplicated,
  /// because the Firestore repository already knows how.
  final Future<Subscription> Function() _readEntitlement;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Resolves when the store confirms and the server has granted.
  Completer<Subscription>? _pending;

  List<ProductDetails> _products = const [];

  void _listen() {
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('purchase stream error: $error'),
    );
  }

  /// The store's own prices where available, ours as a fallback.
  List<SubscriptionPlan> _merge() {
    if (_products.isEmpty) return SubscriptionPlan.catalogue;
    return [
      for (final plan in SubscriptionPlan.catalogue)
        _productFor(plan.id) == null
            ? plan
            : SubscriptionPlan(
                id: plan.id,
                name: plan.name,
                // rawPrice and currencySymbol come from the store, already
                // localised for the account's region.
                price: _productFor(plan.id)!.rawPrice,
                currencySymbol: _productFor(plan.id)!.currencySymbol,
                period: plan.period,
                features: plan.features,
              ),
    ];
  }

  ProductDetails? _productFor(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  List<SubscriptionPlan> get plans => _merge();

  /// Loads product details from the store. Safe to call more than once.
  Future<void> loadProducts() async {
    if (!await _iap.isAvailable()) return;
    final response = await _iap.queryProductDetails(
      SubscriptionPlan.catalogue.map((p) => p.id).toSet(),
    );
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('store products missing: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  @override
  Stream<Subscription> watch() =>
      throw UnimplementedError('Entitlement is watched via Firestore.');

  @override
  Future<Subscription> current() => _readEntitlement();

  @override
  Future<Subscription> purchase(String planId) async {
    if (!await _iap.isAvailable()) {
      throw const RepositoryException(
        'Purchases are not available on this device.',
        code: 'store-unavailable',
      );
    }

    await loadProducts();
    final product = _productFor(planId);
    if (product == null) {
      throw const RepositoryException(
        'That plan is not available right now.',
        code: 'products-unavailable',
      );
    }

    final pending = Completer<Subscription>();
    _pending = pending;

    // buyNonConsumable is correct for subscriptions on both platforms —
    // buyConsumable is for things that are used up and re-bought.
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _pending = null;
      throw const RepositoryException(
        'That purchase could not be started.',
        code: 'purchase-failed',
      );
    }

    // The store's sheet has no time limit, but a purchase that never resolves
    // must not leave the UI spinning forever.
    return pending.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending = null;
        throw const RepositoryException(
          'That purchase did not complete.',
          code: 'purchase-timeout',
        );
      },
    );
  }

  @override
  Future<Subscription> restore() async {
    // Replays past purchases through the stream, where they are validated the
    // same way a fresh purchase is. Both stores require this to exist.
    await _iap.restorePurchases();
    return _readEntitlement();
  }

  @override
  Future<Subscription> cancel() async {
    // Neither store lets an app cancel a subscription — only the person can,
    // in their own account settings. The UI deep-links them there; this only
    // reports what the server currently holds.
    throw const RepositoryException(
      'Manage or cancel your subscription in your App Store or Google Play '
      'account settings.',
      code: 'cancel-in-store',
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;

        case PurchaseStatus.error:
          _fail(
            RepositoryException(
              purchase.error?.message ?? 'That purchase did not go through.',
              code: 'purchase-error',
            ),
          );

        case PurchaseStatus.canceled:
          _fail(
            const RepositoryException(
              'Purchase cancelled.',
              code: 'purchase-cancelled',
            ),
          );

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _validate(purchase);
      }

      // Required on both platforms. Skipping it makes the store refund the
      // purchase after a few days, which looks to the user like theft.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _validate(PurchaseDetails purchase) async {
    try {
      final result = await _functions
          .workerCallable('activateSubscription')
          .call<Map<String, dynamic>>({
        'planId': purchase.productID,
        'receipt': purchase.verificationData.serverVerificationData,
        'platform': Platform.isIOS ? 'apple' : 'google',
      });

      final subscription = Subscription.fromJson(
        (result.data['subscription'] as Map).cast<String, dynamic>(),
      );
      _pending?.complete(subscription);
      _pending = null;
    } on FirebaseFunctionsException catch (e) {
      _fail(
        RepositoryException(
          e.message?.isNotEmpty ?? false
              ? e.message!
              : 'We could not confirm that purchase.',
          code: e.code,
        ),
      );
    }
  }

  void _fail(RepositoryException error) {
    if (_pending?.isCompleted ?? true) return;
    _pending!.completeError(error);
    _pending = null;
  }

  void dispose() {
    _subscription?.cancel();
  }
}

/// Entitlement from the server, purchases from the store.
///
/// Splitting it this way keeps each half honest: the store is the only thing
/// that can take money, and the server is the only thing that can say what an
/// account is entitled to. Neither is allowed to do the other's job.
class StoreBackedSubscriptionRepository implements SubscriptionRepository {
  StoreBackedSubscriptionRepository({
    required SubscriptionRepository entitlement,
    required StoreSubscriptionRepository store,
  })  : _entitlement = entitlement,
        _store = store;

  final SubscriptionRepository _entitlement;
  final StoreSubscriptionRepository _store;

  @override
  List<SubscriptionPlan> get plans => _store.plans;

  @override
  Stream<Subscription> watch() => _entitlement.watch();

  @override
  Future<Subscription> current() => _entitlement.current();

  @override
  Future<Subscription> purchase(String planId) => _store.purchase(planId);

  @override
  Future<Subscription> restore() => _store.restore();

  @override
  Future<Subscription> cancel() => _store.cancel();

  /// Warms the store's product list so the chooser shows localised prices
  /// rather than our fallbacks.
  Future<void> loadProducts() => _store.loadProducts();

  void dispose() => _store.dispose();
}
