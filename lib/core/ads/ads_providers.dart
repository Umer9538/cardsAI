import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/worker/worker_endpoints.dart';
import '../app_config.dart';
import '../providers/providers.dart';
import '../repositories/repositories.dart';
import 'ad_config.dart';
import 'ads_service.dart';

/// Whether this build shows ads at all.
///
/// Overridden to false in tests: `google_mobile_ads` has no platform side
/// there, so every call would throw.
final adsEnabledProvider = Provider<bool>(
  (ref) => AppConfig.backend == AppBackend.firebase,
);

/// The ad network, or a no-op.
///
/// Premium accounts get [NoAdsService], so the SDK is never even initialised
/// for them — not merely hidden. Paying to remove ads and still having the ad
/// SDK running is the kind of thing people notice.
final adsServiceProvider = Provider<AdsService>((ref) {
  if (!ref.watch(adsEnabledProvider) || ref.watch(isPremiumProvider)) {
    return const NoAdsService();
  }
  final service = AdMobService();
  ref.onDispose(service.dispose);
  // Fire and forget: nothing should wait on the ad SDK to render a screen.
  service.initialize();
  return service;
});

/// Watches a rewarded ad and banks the scans it earns.
class RewardController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String? get errorMessage {
    final error = state.error;
    if (error == null) return null;
    return error is RepositoryException
        ? error.message
        : 'That did not work. Try again in a moment.';
  }

  bool get canWatch => ref.read(adsServiceProvider).rewardedReady;

  /// Returns the number of scans banked, or null if nothing was earned.
  ///
  /// Closing the ad early earns nothing, and the reward is granted by the
  /// server rather than counted here — the client is not trusted with its own
  /// quota.
  Future<int?> watchForScans() async {
    state = const AsyncLoading();

    final earned = await ref.read(adsServiceProvider).showRewarded();
    if (!earned) {
      state = const AsyncData(null);
      return null;
    }

    try {
      final result = await ref
          .read(functionsProvider)
          .workerCallable('grantBonusScans')
          .call<Map<String, dynamic>>();
      state = const AsyncData(null);
      return (result.data['granted'] as num?)?.toInt() ??
          AdConfig.scansPerRewardedAd;
    } on FirebaseFunctionsException catch (e) {
      // The ad was watched and the reward was not banked. Say so plainly —
      // silently swallowing it looks like theft.
      state = AsyncError(
        RepositoryException(
          e.message?.isNotEmpty ?? false
              ? e.message!
              : 'We could not add those scans. Try again in a moment.',
          code: e.code,
        ),
        StackTrace.current,
      );
      debugPrint('grantBonusScans failed: ${e.code}');
      return null;
    }
  }
}

final rewardControllerProvider =
    AsyncNotifierProvider<RewardController, void>(RewardController.new);
