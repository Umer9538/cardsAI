import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';

/// Drives the premium flow's buttons.
///
/// Mirrors `AuthController`: methods return a bool rather than throwing, so a
/// screen can navigate on success without wrapping every call, and the failure
/// message is read from [errorMessage].
class SubscriptionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    return error is RepositoryException
        ? error.message
        : 'That did not go through. Please try again.';
  }

  /// The plan the flow is currently working with.
  ///
  /// Carried on the controller rather than passed down through four screens'
  /// constructors, because the review screen needs what the chooser picked and
  /// the two are not adjacent.
  SubscriptionPlan? selected;

  void select(SubscriptionPlan plan) => selected = plan;

  Future<bool> purchase([String? planId]) {
    final id = planId ?? selected?.id;
    if (id == null) {
      state = AsyncError(
        const RepositoryException('Choose a plan first.', code: 'no-plan'),
        StackTrace.current,
      );
      return Future.value(false);
    }
    return _run(
      () => ref.read(subscriptionRepositoryProvider).purchase(id),
    );
  }

  Future<bool> restore() =>
      _run(() => ref.read(subscriptionRepositoryProvider).restore());

  Future<bool> cancel() =>
      _run(() => ref.read(subscriptionRepositoryProvider).cancel());

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    state = result;
    return !result.hasError;
  }
}

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, void>(
  SubscriptionController.new,
);
