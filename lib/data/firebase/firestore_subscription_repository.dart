import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../worker/worker_endpoints.dart';

/// Entitlement, owned by the server.
///
/// The client can only ever READ `users/{uid}/subscription/current` — the rules
/// deny writing it. Purchases go through the `activateSubscription` function,
/// which is where store-receipt validation belongs. An entitlement a client can
/// write is not an entitlement; it is a suggestion.
class FirestoreSubscriptionRepository implements SubscriptionRepository {
  FirestoreSubscriptionRepository(this._firestore, this._functions, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final fb.FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.doc('users/$uid/subscription/current');
  }

  @override
  List<SubscriptionPlan> get plans => SubscriptionPlan.catalogue;

  @override
  Stream<Subscription> watch() =>
      _auth.authStateChanges().asyncExpand((user) {
        if (user == null) return Stream.value(Subscription.free);
        return _firestore
            .doc('users/${user.uid}/subscription/current')
            .snapshots()
            .map((snap) => snap.data() == null
                ? Subscription.free
                : Subscription.fromJson(snap.data()!));
      });

  @override
  Future<Subscription> current() async {
    final doc = _doc;
    if (doc == null) return Subscription.free;
    final snap = await doc.get();
    return snap.data() == null
        ? Subscription.free
        : Subscription.fromJson(snap.data()!);
  }

  @override
  Future<Subscription> purchase(String planId) =>
      _call('activateSubscription', {'planId': planId});

  /// Re-reads what the server holds.
  ///
  /// With real in-app purchases this must also ask the store for the account's
  /// purchase history and re-validate it — the server record alone cannot
  /// recover an entitlement bought on a different install.
  @override
  Future<Subscription> restore() => current();

  @override
  Future<Subscription> cancel() => _call('cancelSubscription');

  Future<Subscription> _call(
    String name, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      final result =
          await _functions.workerCallable(name).call<Map<String, dynamic>>(payload);
      return Subscription.fromJson(
        (result.data['subscription'] as Map).cast<String, dynamic>(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw RepositoryException(
        e.message?.isNotEmpty ?? false
            ? e.message!
            : 'That did not go through. Please try again.',
        code: e.code,
      );
    }
  }
}
