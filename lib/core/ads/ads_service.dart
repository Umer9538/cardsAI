import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// What the app needs from an ad network.
///
/// An interface rather than calling the SDK directly, for the same reason the
/// repositories are: premium accounts get [NoAdsService] and never load the SDK
/// at all, and the widget tests get it too — `google_mobile_ads` has no
/// platform side in a test and would throw on every call.
abstract interface class AdsService {
  Future<void> initialize();

  /// Whether a rewarded ad is loaded and can be shown right now.
  bool get rewardedReady;

  /// Shows a rewarded ad. Resolves true only if the reward was actually earned
  /// — closing early must not pay out.
  Future<bool> showRewarded();

  /// Shows the app-open ad, if one is loaded and enough time has passed.
  Future<void> showAppOpenIfReady();

  void dispose();
}

/// Ads are off: premium accounts, and any environment with no ad SDK.
class NoAdsService implements AdsService {
  const NoAdsService();

  @override
  Future<void> initialize() async {}

  @override
  bool get rewardedReady => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<void> showAppOpenIfReady() async {}

  @override
  void dispose() {}
}

/// Google AdMob: a rewarded unit and an app-open unit.
///
/// No banners and no interstitials, deliberately. The artboards reserve no
/// space for a banner, and an interstitial in the middle of logging a meal
/// works against the ten-second target the whole app is built around. Rewarded
/// is asked for rather than inflicted, and pays the most.
class AdMobService implements AdsService {
  AdMobService();

  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;
  bool _initialized = false;
  bool _showing = false;
  DateTime? _appOpenLoadedAt;
  DateTime? _appOpenShownAt;

  /// App-open ads expire four hours after load, per Google's guidance.
  static const Duration _appOpenTtl = Duration(hours: 4);

  /// Never show an app-open ad twice within this window. Someone switching to
  /// the camera and back should not be charged an ad for it.
  static const Duration _appOpenCooldown = Duration(minutes: 15);

  /// How many app-open ads one person may see in a day.
  ///
  /// A cooldown alone is not enough here, and the reason is specific to this
  /// category: a calorie tracker is opened five to ten times a day *by design*
  /// — that is the product working — so a per-launch ad is a five-to-ten-times
  /// -a-day toll on the exact behaviour the app is trying to build. Reviewers
  /// of Cronometer and MyFitnessPal count it themselves, and it is the most
  /// common reason given for abandoning an otherwise-liked tracker.
  ///
  /// Two is the whole day's budget.
  static const int _appOpenPerDay = 2;

  int _appOpenShownToday = 0;
  DateTime? _appOpenDay;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await MobileAds.instance.initialize();

    // Consent must be resolved before ads are requested, or EEA users get
    // non-personalised ads at best and a policy violation at worst.
    await _requestConsent();

    // Then ATT, in that order — Google's own guidance. The UMP form explains
    // why the app is asking; Apple's system prompt is a bare yes/no, and it
    // lands better after the explanation than before it.
    await _requestTracking();

    unawaited(_loadRewarded());
    unawaited(_loadAppOpen());
  }

  /// Google's User Messaging Platform — the consent form AdMob requires in the
  /// EEA and UK.
  ///
  /// Failures here are non-fatal on purpose: no consent means non-personalised
  /// ads, which is a smaller problem than an app that will not start.
  Future<void> _requestConsent() async {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _showConsentForm();
          }
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error) {
        debugPrint('consent update failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('consent timed out; continuing without');
      },
    );
  }

  /// Apple's App Tracking Transparency prompt, iOS only.
  ///
  /// `Info.plist` has carried `NSUserTrackingUsageDescription` since ads were
  /// added and nothing ever requested authorisation. That is two problems at
  /// once: a declared tracking purpose with no prompt is something App Review
  /// looks for, and without the prompt every iOS impression is served
  /// non-personalised, which is the low end of the eCPM range this app's whole
  /// ad case rests on.
  ///
  /// Only ever asked once — iOS returns the previous answer thereafter, and
  /// re-prompting is not possible — so a refusal is final and simply means
  /// non-personalised ads. Non-fatal for the same reason consent is: an ad
  /// SDK must never be able to stop the app starting.
  Future<void> _requestTracking() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (error) {
      debugPrint('ATT request failed: $error');
    }
  }

  Future<void> _showConsentForm() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) debugPrint('consent form failed: ${error.message}');
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// The ad request carries nothing about the user, and must not.
  ///
  /// `AdRequest` takes `keywords`, `contentUrl` and `neighboringContentUrls`,
  /// and it would be easy to reach for them — a nutrition app knows a great
  /// deal about who is looking at the screen. Apple Guideline 5.1.3(i) bars
  /// health data from advertising targeting outright, and a diet, a weight or a
  /// goal is health data. **Keep this const and empty.**
  static const AdRequest _request = AdRequest();

  Future<void> _loadRewarded() async {
    if (_rewarded != null) return;
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: _request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (error) {
          _rewarded = null;
          debugPrint('rewarded failed to load: ${error.message}');
        },
      ),
    );
  }

  Future<void> _loadAppOpen() async {
    if (_appOpen != null) return;
    await AppOpenAd.load(
      adUnitId: AdConfig.appOpenUnitId,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _appOpen = null;
          debugPrint('app open failed to load: ${error.message}');
        },
      ),
    );
  }

  @override
  bool get rewardedReady => _rewarded != null;

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null || _showing) {
      unawaited(_loadRewarded());
      return false;
    }

    _rewarded = null;
    _showing = true;

    // Resolved from the callbacks rather than by awaiting show(), which returns
    // as soon as the ad is presented and tells us nothing about the reward.
    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        unawaited(_loadRewarded());
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        unawaited(_loadRewarded());
        debugPrint('rewarded failed to show: ${error.message}');
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return completer.future;
  }

  @override
  Future<void> showAppOpenIfReady() async {
    final ad = _appOpen;
    if (ad == null || _showing) return;

    final loadedAt = _appOpenLoadedAt;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) > _appOpenTtl) {
      // Stale ads must not be shown; Google counts it as a policy issue and
      // the impression would not pay anyway.
      ad.dispose();
      _appOpen = null;
      unawaited(_loadAppOpen());
      return;
    }

    final now = DateTime.now();

    final shownAt = _appOpenShownAt;
    if (shownAt != null && now.difference(shownAt) < _appOpenCooldown) {
      return;
    }

    // Local midnight, not a rolling 24 hours: "twice today" is what a person
    // experiences, and a rolling window would let a late-night session and an
    // early-morning one both count against the same budget.
    final today = DateTime(now.year, now.month, now.day);
    if (_appOpenDay != today) {
      _appOpenDay = today;
      _appOpenShownToday = 0;
    }
    if (_appOpenShownToday >= _appOpenPerDay) return;
    _appOpenShownToday++;

    _appOpen = null;
    _showing = true;
    _appOpenShownAt = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        unawaited(_loadAppOpen());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        unawaited(_loadAppOpen());
        debugPrint('app open failed to show: ${error.message}');
      },
    );

    await ad.show();
  }

  @override
  void dispose() {
    _rewarded?.dispose();
    _appOpen?.dispose();
    _rewarded = null;
    _appOpen = null;
  }
}
