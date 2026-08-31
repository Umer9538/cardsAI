import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';

/// Drives the auth screens' submit buttons.
///
/// Every method returns a bool rather than throwing, so a screen can navigate
/// on success without a try/catch around the call; the failure message is read
/// from [errorMessage]. The `AsyncValue` state carries the in-flight flag the
/// buttons disable on.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// The message to show under the form, or null when there is nothing wrong.
  ///
  /// Anything that is not a [RepositoryException] is a bug, so it gets a
  /// generic message rather than leaking an internal error to the user.
  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    return error is RepositoryException
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password));

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() => ref
          .read(authRepositoryProvider)
          .signUp(name: name, email: email, password: password));

  Future<bool> signInWithGoogle() =>
      _run(() => ref.read(authRepositoryProvider).signInWithGoogle());

  Future<bool> signInWithApple() =>
      _run(() => ref.read(authRepositoryProvider).signInWithApple());

  Future<bool> sendPasswordReset(String email) =>
      _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  Future<bool> sendEmailOtp() =>
      _run(() => ref.read(authRepositoryProvider).sendEmailOtp());

  Future<bool> verifyCode(String code) =>
      _run(() => ref.read(authRepositoryProvider).verifyCode(code));

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _run(() => ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          ));

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    state = const AsyncData(null);
  }

  /// Clears a stale message when the user edits the form.
  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
