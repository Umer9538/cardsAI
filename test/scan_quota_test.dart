import 'dart:io' as io;

import 'package:carbsai/core/ads/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scan allowance, and the three ways it can silently stop working.
///
/// The free tier renews daily rather than being three scans for the lifetime
/// of the account. That is one line in `quota.ts`, but it has consequences in
/// two other files and in the terms, and each of those can drift back without
/// anything failing to compile:
///
/// 1. `rewards.ts` writes the bonus a rewarded advert earns. It used to name
///    `users/{uid}/quota/free` directly. Against a daily bucket that is a
///    document nothing reads — the advert plays, the grant is reported, and
///    the scan count does not move.
/// 2. Premium has to stay worth paying for. At 100 a month it was *less* than
///    a renewing free tier of five a day, so the subscription was a downgrade.
/// 3. The terms describe the allowance, and a policy that describes the
///    previous product is the failure `legal_content_test` exists to catch.
String _read(String path) => io.File(path).readAsStringSync();

void main() {
  final quota = _read('workers/src/quota.ts');
  final scan = _read('workers/src/scan.ts');
  final rewards = _read('workers/src/rewards.ts');

  int number(String source, String field) {
    final match = RegExp('$field:\\s*(\\d+)').firstMatch(source);
    expect(match, isNotNull, reason: 'no $field in the config');
    return int.parse(match!.group(1)!);
  }

  test('the free bucket is a day and the premium bucket is a month', () {
    // YYYY-MM-DD is ten characters, YYYY-MM is seven. The slice length is the
    // whole of what makes one renew daily and the other monthly.
    expect(
      RegExp(r'freeBucketId[\s\S]*?slice\(0,\s*10\)').hasMatch(quota),
      isTrue,
      reason: 'the free bucket is no longer day-scoped',
    );
    expect(
      RegExp(r'premiumBucketId[\s\S]*?slice\(0,\s*7\)').hasMatch(quota),
      isTrue,
      reason: 'the premium bucket is no longer month-scoped',
    );
    // Prefixed, or a free bucket and a premium one are two formats of the
    // same thing in one collection, told apart only by string length.
    expect(quota, contains('free-\${'));
  });

  test('a rewarded advert pays into the bucket the scan actually reads', () {
    expect(
      rewards,
      contains('quotaPath(uid, freeBucketId())'),
      reason: 'the bonus must go through the same function the scan reserves '
          'against, or it lands in a document nothing reads',
    );
    expect(
      rewards.contains('quota/free`') || rewards.contains('quota/free'),
      isFalse,
      reason: 'rewards.ts names the old lifetime bucket directly',
    );
    expect(scan, contains('quotaPath(uid, bucket.id)'));
    expect(scan, contains('freeBucketId()'));
  });

  test('premium is worth more than the free tier, not less', () {
    final free = number(scan, 'freeScanLimit');
    final monthly = number(scan, 'monthlyQuota');

    // 28 is the shortest month: premium has to beat free even in February,
    // or a subscriber in the wrong month gets less than they would for
    // nothing. This is the check that would have caught 100 against 5/day.
    expect(
      monthly,
      greaterThan(free * 28),
      reason: 'monthlyQuota $monthly is below $free free scans a day over a '
          '28-day month — premium would be a downgrade someone paid for',
    );
  });

  test('the free allowance is generous enough to log a real day', () {
    // The app's own measure of tracking is a "day with a full picture": at
    // least two eating occasions. An allowance below that cannot produce one.
    expect(number(scan, 'freeScanLimit'), greaterThanOrEqualTo(2));
  });

  test('the refusal tells a free user the allowance comes back', () {
    final refusal = RegExp(r"That is today's[^`]*").firstMatch(scan)?.group(0);
    expect(refusal, isNotNull, reason: 'the free refusal copy has changed');
    expect(refusal, contains('tomorrow'));
  });

  test('adverts are off unless a build asks for them', () {
    // No --dart-define here, so this is what a plain `flutter build` ships.
    // Off by default is deliberate: a build that should have shown adverts
    // and did not costs a little revenue, and one that should not have and
    // did cannot be recalled from the people who already saw it.
    expect(AdConfig.enabled, isFalse);
  });
}
