import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

/// On-device entitlement, for the local backend.
///
/// Grants whatever is asked for. That is fine here — the local backend is a
/// development mode with no server and no money — but it is exactly why the
/// Firebase implementation routes purchases through a Cloud Function instead.
class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<Subscription>.broadcast();

  Subscription _subscription = Subscription.free;
  bool _loaded = false;

  void _load() {
    final stored = _store.readMap(StoreKeys.subscription);
    _subscription =
        stored == null ? Subscription.free : Subscription.fromJson(stored);
    _loaded = true;
    _controller.add(_subscription);
  }

  @override
  List<SubscriptionPlan> get plans => SubscriptionPlan.catalogue;

  @override
  Stream<Subscription> watch() async* {
    while (!_loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    yield _subscription;
    yield* _controller.stream;
  }

  @override
  Future<Subscription> current() async => _subscription;

  @override
  Future<Subscription> purchase(String planId) async {
    final plan = SubscriptionPlan.byId(planId);
    if (plan == null) {
      throw RepositoryException('No plan $planId', code: 'unknown-plan');
    }
    // Enough delay that the button's busy state is actually exercised.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    return _save(
      Subscription(
        status: SubscriptionStatus.active,
        planId: plan.id,
        startedAt: now,
        renewsAt: now.add(plan.period.length),
      ),
    );
  }

  @override
  Future<Subscription> restore() async => _subscription;

  @override
  Future<Subscription> cancel() async {
    if (!_subscription.isActive) return _subscription;
    return _save(
      Subscription(
        status: SubscriptionStatus.cancelled,
        planId: _subscription.planId,
        startedAt: _subscription.startedAt,
        renewsAt: _subscription.renewsAt,
      ),
    );
  }

  Future<Subscription> _save(Subscription subscription) async {
    await _store.writeMap(StoreKeys.subscription, subscription.toJson());
    _subscription = subscription;
    _controller.add(subscription);
    return subscription;
  }

  void dispose() => _controller.close();
}
