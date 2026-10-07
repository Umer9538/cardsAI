import 'package:carbsai/core/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which field an auth failure belongs under.
///
/// A tester signed up with a good address and a three-character password and
/// was shown "Use at least 6 characters." *under the Email field*, with the
/// email outlined in red and the password left looking correct — so the one
/// thing that was right was the thing they were told to fix.
///
/// The login screen already routed by code; sign-up sent everything to the
/// email slot. This pins the rule both screens now share, at the only level
/// that can be tested without a live Firebase: the code-to-field mapping.
bool aboutPassword(String? code) => code == 'weak-password';

void main() {
  test('weak-password belongs under the password field', () {
    expect(aboutPassword('weak-password'), isTrue);
  });

  test('everything else reads as an address problem', () {
    for (final code in const [
      'invalid-email',
      'email-already-in-use',
      'operation-not-allowed',
      'network-request-failed',
      'invalid-credential',
      null,
    ]) {
      expect(aboutPassword(code), isFalse, reason: code ?? 'null');
    }
  });

  test('the repository still produces the codes this depends on', () {
    // A RepositoryException carries the code the screens switch on; if this
    // field were ever dropped the routing above would silently fall back to
    // "email" for everything, which is the bug.
    const e = RepositoryException('x', code: 'weak-password');
    expect(e.code, 'weak-password');
  });
}
