import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

/// On-device stand-in for Firebase Auth.
///
/// It validates input and persists a session, but it does not check a password
/// against anything — there is no server to check against. Any well-formed
/// credentials sign you in, which is what makes the app walkable end to end.
///
/// The point of it is the *shape*: every screen already talks to
/// [AuthRepository], so `FirebaseAuthRepository` drops in behind the same
/// interface with no screen touched.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store, this._profiles) {
    _restore();
  }

  final JsonStore _store;
  final ProfileRepository _profiles;
  final _uuid = const Uuid();

  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _current;
  bool _restored = false;

  /// Reads the persisted session so a relaunch does not drop back to login.
  Future<void> _restore() async {
    final stored = _store.readMap(StoreKeys.session);
    _current = stored == null ? null : UserProfile.fromJson(stored);
    _restored = true;
    _controller.add(_current);
  }

  @override
  Stream<UserProfile?> authStateChanges() async* {
    // Callers decide the app's first screen from this, so it must not emit
    // "signed out" before the stored session has been read back.
    while (!_restored) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    yield _current;
    yield* _controller.stream;
  }

  @override
  UserProfile? get currentUser => _current;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    _validate(email: email, password: password);
    await _latency();

    // Prefer the saved profile so a returning user keeps their name and goals.
    final existing = await _profiles.load();
    final profile = existing?.email == email.trim()
        ? existing!
        : UserProfile(
            id: _uuid.v4(),
            name: _nameFromEmail(email),
            email: email.trim(),
          );
    return _establish(profile);
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _validate(email: email, password: password);
    if (name.trim().isEmpty) {
      throw const RepositoryException(
        'Enter your name.',
        code: 'invalid-name',
      );
    }
    await _latency();
    return _establish(
      UserProfile(id: _uuid.v4(), name: name.trim(), email: email.trim()),
    );
  }

  @override
  Future<UserProfile> signInWithGoogle() => _signInWithProvider();

  @override
  Future<UserProfile> signInWithApple() => _signInWithProvider();

  /// Both federated buttons land here until the real SDKs are wired.
  Future<UserProfile> _signInWithProvider() async {
    await _latency();
    final existing = await _profiles.load();
    return _establish(
      existing ??
          UserProfile(
            id: _uuid.v4(),
            name: 'Jane Cooper',
            email: 'janecooper@email.com',
          ),
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _validate(email: email);
    await _latency();
    // Intentionally silent about whether the address exists.
  }

  /// No mail server on the local backend; the code is whatever you type.
  @override
  Future<void> sendEmailOtp() => _latency();

  @override
  Future<void> verifyCode(String code) async {
    if (code.trim().length < 6) {
      throw const RepositoryException(
        'Enter the 6-digit code.',
        code: 'invalid-code',
      );
    }
    await _latency();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw const RepositoryException(
        'Use at least 6 characters.',
        code: 'weak-password',
      );
    }
    if (currentPassword == newPassword) {
      throw const RepositoryException(
        'Choose a password you have not used here before.',
        code: 'password-reused',
      );
    }
    await _latency();
  }

  @override
  Future<void> signOut() async {
    await _store.remove(StoreKeys.session);
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    for (final key in StoreKeys.all) {
      await _store.remove(key);
    }
    _current = null;
    _controller.add(null);
  }

  Future<UserProfile> _establish(UserProfile profile) async {
    final saved = await _profiles.save(profile);
    await _store.writeMap(StoreKeys.session, saved.toJson());
    _current = saved;
    _controller.add(saved);
    return saved;
  }

  void _validate({required String email, String? password}) {
    if (!email.contains('@') || email.trim().length < 3) {
      throw const RepositoryException(
        'Enter a valid email address.',
        code: 'invalid-email',
      );
    }
    if (password != null && password.length < 6) {
      throw const RepositoryException(
        'Password must be at least 6 characters.',
        code: 'weak-password',
      );
    }
  }

  /// "jane.cooper@x.com" -> "Jane Cooper". Only a placeholder until the real
  /// provider hands back a display name.
  String _nameFromEmail(String email) {
    final local = email.trim().split('@').first;
    final words = local.split(RegExp(r'[._\-+]')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return 'There';
    return words
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Enough delay that loading states are actually exercised in development.
  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  void dispose() => _controller.close();
}
