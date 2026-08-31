import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../worker/worker_endpoints.dart';

/// Firebase Auth behind the app's own [AuthRepository] contract.
///
/// The contract exists so screens never see a `FirebaseAuthException`. Every
/// failure is translated to a [RepositoryException] carrying a sentence a
/// person can act on — see [_translate], which is also where a project with
/// its sign-in providers still switched off gets a message that says so
/// rather than "operation-not-allowed".
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(
    this._auth,
    this._firestore,
    this._functions,
    this._profiles,
  );

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final ProfileRepository _profiles;

  /// Subcollections under `users/{uid}` that a delete has to clear.
  ///
  /// Deleting a document in Firestore does *not* delete its subcollections —
  /// they survive as orphans, invisible in the console but still billed and
  /// still returned by a collection-group query. They must be enumerated.
  static const List<String> _subcollections = [
    'meals',
    'plans',
    'notifications',
    'prefs',
  ];

  UserProfile? _current;

  @override
  Stream<UserProfile?> authStateChanges() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        _current = null;
        yield null;
        continue;
      }
      // The stored profile is authoritative for name and goals; the Firebase
      // user only knows what the provider told it.
      final stored = await _profiles.load();
      _current = stored ?? await _profiles.save(_profileFrom(user));
      yield _current;
    }
  }

  @override
  UserProfile? get currentUser => _current;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
    return _establish(credential.user!);
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) {
      throw const RepositoryException('Enter your name.', code: 'invalid-name');
    }

    final credential = await _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );

    // Set before the profile is written, so the display name is present the
    // first time anything reads the user back.
    await credential.user!.updateDisplayName(name.trim());
    return _establish(credential.user!, name: name.trim());
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    throw const RepositoryException(
      'Google sign-in is not wired up yet.',
      code: 'provider-unavailable',
    );
  }

  @override
  Future<UserProfile> signInWithApple() async {
    throw const RepositoryException(
      'Apple sign-in is not wired up yet.',
      code: 'provider-unavailable',
    );
  }

  @override
  Future<void> sendPasswordReset(String email) => _guard(
        () => _auth.sendPasswordResetEmail(email: email.trim()),
      );

  /// Firebase's own email verification is a *link*, not a code, which the
  /// artboard's six-box screen cannot express. So the codes are ours: minted,
  /// emailed and checked by the `sendEmailOtp` / `verifyEmailOtp` functions,
  /// which record the result on the Firebase user so `emailVerified` stays the
  /// single source of truth.
  @override
  Future<void> sendEmailOtp() => _callFunction('sendEmailOtp');

  @override
  Future<void> verifyCode(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const RepositoryException(
        'Enter the 6-digit code.',
        code: 'invalid-code',
      );
    }
    await _callFunction('verifyEmailOtp', {'code': code.trim()});

    // The ID token still says unverified until it is refreshed, and anything
    // keying on emailVerified would read a stale value for up to an hour.
    await _auth.currentUser?.reload();
  }

  /// Codes raised by the function itself, whose `message` we wrote and can
  /// show verbatim.
  ///
  /// Everything else is the transport failing — a function that is not
  /// deployed, no network, a cold-start timeout — and its `message` is a raw
  /// status like "NOT_FOUND", which must never reach a person.
  static const Set<String> _ourCodes = {
    'invalid-argument',
    'failed-precondition',
    'resource-exhausted',
    'deadline-exceeded',
    'not-found',
    'already-exists',
    'permission-denied',
  };

  Future<void> _callFunction(
    String name, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      await _functions.workerCallable(name).call<Object?>(payload);
    } on FirebaseFunctionsException catch (e) {
      throw RepositoryException(_describe(e), code: e.code);
    }
  }

  static String _describe(FirebaseFunctionsException e) {
    final message = e.message;
    final looksLikeAStatusCode =
        message == null || RegExp(r'^[A-Z_]+$').hasMatch(message.trim());

    if (!looksLikeAStatusCode && _ourCodes.contains(e.code)) return message;

    return switch (e.code) {
      'unauthenticated' => 'Sign in and try again.',
      'unavailable' || 'internal' =>
        'We could not reach the server. Check your connection and try again.',
      'not-found' =>
        'That feature is not available yet. Please try again later.',
      'deadline-exceeded' => 'That took too long. Please try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        'You need to be signed in to change your password.',
        code: 'not-signed-in',
      );
    }

    // Firebase requires a recent sign-in for this. Re-authenticating with the
    // supplied current password satisfies that without a second prompt —
    // except on the reset path, which has no current password and relies on
    // the emailed link having signed the user in moments earlier.
    if (currentPassword.isNotEmpty && user.email != null) {
      await _guard(
        () => user.reauthenticateWithCredential(
          fb.EmailAuthProvider.credential(
            email: user.email!,
            password: currentPassword,
          ),
        ),
      );
    }

    await _guard(() => user.updatePassword(newPassword));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Order matters: the security rules key on request.auth.uid, so deleting
    // the auth user first would revoke permission to delete their own data and
    // strand it.
    await _purge(user.uid);
    await _guard(user.delete);
  }

  /// Removes everything under `users/{uid}`.
  ///
  /// Batched at 400 — under Firestore's 500-operation limit with room for the
  /// user document itself — and looped, so an account with a long diary is not
  /// left half-deleted.
  Future<void> _purge(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);

    for (final name in _subcollections) {
      while (true) {
        final page = await userDoc.collection(name).limit(400).get();
        if (page.docs.isEmpty) break;

        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // A short page means that was the last one.
        if (page.docs.length < 400) break;
      }
    }

    await userDoc.delete();
  }

  Future<UserProfile> _establish(fb.User user, {String? name}) async {
    final existing = await _profiles.load();
    final profile = (existing ?? _profileFrom(user)).copyWith(
      id: user.uid,
      name: name ?? existing?.name ?? _profileFrom(user).name,
      email: user.email ?? '',
    );
    _current = await _profiles.save(profile);
    return _current!;
  }

  UserProfile _profileFrom(fb.User user) => UserProfile(
        id: user.uid,
        name: user.displayName?.trim().isNotEmpty ?? false
            ? user.displayName!.trim()
            : _nameFromEmail(user.email ?? ''),
        email: user.email ?? '',
      );

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final words = local.split(RegExp(r'[._\-+]')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return 'There';
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on fb.FirebaseAuthException catch (e) {
      throw RepositoryException(_translate(e), code: e.code);
    }
  }

  /// Firebase's codes, as sentences.
  ///
  /// `operation-not-allowed` gets a specific message because it means the
  /// provider is switched off in the console, which is a setup mistake rather
  /// than anything the user did — and is exactly the wall a fresh project hits.
  static String _translate(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'That email or password is not right.',
        'email-already-in-use' =>
          'There is already an account with that email.',
        'weak-password' => 'Use at least 6 characters.',
        'requires-recent-login' =>
          'Please sign in again before making this change.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment and try again.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        'operation-not-allowed' =>
          'Email sign-in is not enabled for this project yet. Turn it on in '
              'Firebase Console → Authentication → Sign-in method.',
        _ => e.message ?? 'Something went wrong. Please try again.',
      };
}
