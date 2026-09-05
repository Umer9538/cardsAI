import 'package:carbsai/data/firebase/functions_scan_repository.dart';
import 'package:carbsai/data/worker/worker_endpoints.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

/// No failure may reach a person as a shouted status code.
///
/// `cloud_functions` sets `FirebaseFunctionsException.message` to the gRPC
/// status name — "UNAVAILABLE", "DEADLINE_EXCEEDED" — when the call never got
/// as far as the Worker. Every repository here prefers that message over its
/// own table, because for an error the Worker *raises* the message is a
/// sentence written for this purpose. On a transport failure it is not, and
/// "non-empty" is not the test that tells the two apart.
///
/// Seen on a device with no DNS: the scan result screen's entire explanation
/// was the word UNAVAILABLE.
void main() {
  group('looksLikeAStatusCode', () {
    test('recognises what the transport puts there', () {
      expect(looksLikeAStatusCode('UNAVAILABLE'), isTrue);
      expect(looksLikeAStatusCode('DEADLINE_EXCEEDED'), isTrue);
      expect(looksLikeAStatusCode('RESOURCE_EXHAUSTED'), isTrue);
      expect(looksLikeAStatusCode('  UNAVAILABLE  '), isTrue);
      expect(looksLikeAStatusCode(null), isTrue);
      expect(looksLikeAStatusCode(''), isTrue);
      expect(looksLikeAStatusCode('   '), isTrue);
    });

    test('leaves a sentence alone, including a shouty one', () {
      expect(
        looksLikeAStatusCode('You have used all your scans for this month.'),
        isFalse,
      );
      expect(looksLikeAStatusCode('That photo could not be read'), isFalse);
      // A real message may still contain capitals and underscores; what marks
      // the placeholder is that it is *only* those.
      expect(looksLikeAStatusCode('NO FOOD found on that plate'), isFalse);
    });
  });

  group('the scan repository', () {
    test('turns a transport failure into a sentence, not its status', () {
      final failure = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'UNAVAILABLE',
      );

      final described = FunctionsScanRepository.describeFailure(failure);

      expect(described, isNot('UNAVAILABLE'));
      expect(
        described,
        'No connection to the analyser. Check your network and try again.',
      );
    });

    test("keeps the Worker's own sentence when it wrote one", () {
      final failure = FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'You have used all 3 of your free scans.',
      );

      expect(
        FunctionsScanRepository.describeFailure(failure),
        'You have used all 3 of your free scans.',
      );
    });
  });
}
