import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob identifiers.
///
/// Google's official **test** units are the default. They serve real ad
/// creatives, cost nothing, and — unlike live units — cannot get an account
/// suspended for self-clicks during development. Tapping your own live ads is
/// invalid traffic, and AdMob bans for it.
///
/// Ship with real ids by building with:
///
/// ```
/// flutter build appbundle \
///   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_APP_OPEN_ANDROID=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_APP_OPEN_IOS=ca-app-pub-XXXX/YYYY
/// ```
///
/// The **application** id is separate and cannot be set this way — it goes in
/// `AndroidManifest.xml` and `Info.plist`, and the app crashes at start-up
/// without it. Both currently hold Google's test application id; swap them
/// when you go live.
///
/// Verify these strings against the AdMob docs before shipping — Google has
/// changed test unit ids before.
abstract final class AdConfig {
  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testAppOpenAndroid =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenIos =
      'ca-app-pub-3940256099942544/5575463023';

  static const String _rewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const String _rewardedIos =
      String.fromEnvironment('ADMOB_REWARDED_IOS');
  static const String _appOpenAndroid =
      String.fromEnvironment('ADMOB_APP_OPEN_ANDROID');
  static const String _appOpenIos = String.fromEnvironment('ADMOB_APP_OPEN_IOS');

  static String get rewardedUnitId => _pick(
        android: _rewardedAndroid,
        ios: _rewardedIos,
        testAndroid: _testRewardedAndroid,
        testIos: _testRewardedIos,
      );

  static String get appOpenUnitId => _pick(
        android: _appOpenAndroid,
        ios: _appOpenIos,
        testAndroid: _testAppOpenAndroid,
        testIos: _testAppOpenIos,
      );

  /// True when the app is serving test ads — surfaced so a build can say so
  /// rather than leaving someone guessing why the ads look fake.
  static bool get usingTestUnits =>
      rewardedUnitId.startsWith('ca-app-pub-3940256099942544');

  static String _pick({
    required String android,
    required String ios,
    required String testAndroid,
    required String testIos,
  }) {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final configured = isAndroid ? android : ios;
    if (configured.isNotEmpty) return configured;
    return isAndroid ? testAndroid : testIos;
  }

  /// Scans granted for watching one rewarded ad.
  ///
  /// One, not three, and the reason is geography. A scan costs ~$0.0012. A
  /// rewarded impression is worth roughly $0.016 at a US eCPM near $16, which
  /// funds about thirteen scans — but roughly $0.001 at the ~$1 CPM these
  /// markets see, which funds 0.83 of one. At three scans an ad, every rewarded
  /// view in Pakistan or India **cost more than it earned**. At one, the worst
  /// market is around breakeven and the best is still ten-to-one.
  ///
  /// The published eCPM figures behind that are Tier-1 only — Pakistan appears
  /// in no country eCPM table that could be found, and India is being used as
  /// an unsourced proxy. Treat the floor as an estimate and watch the real
  /// numbers in AdMob before raising this.
  ///
  /// The server decides the real number — this is only what the UI promises,
  /// and the two must agree. See `grantBonusScans`.
  static const int scansPerRewardedAd = 1;
}
