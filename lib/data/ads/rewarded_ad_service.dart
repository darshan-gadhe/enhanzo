import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ad_config.dart';

/// Outcome of one attempt to watch a rewarded ad through to completion.
enum RewardOutcome {
  /// The user watched the ad in full and earned the reward.
  earned,

  /// The user closed the ad before it finished — no reward. Never treated as
  /// an error: backing out of an ad is exactly as ordinary as backing out of
  /// a purchase sheet, and the caller should offer another try or Premium,
  /// not show a failure message.
  dismissedEarly,

  /// No ad could be shown at all — no fill, no network, or this build has no
  /// placement configured. The caller can't distinguish "try again" from "go
  /// premium instead" being the better next step here, which is exactly why
  /// the ad-gate UI always offers both rather than assuming.
  unavailable,
}

/// Shows one Meta Audience Network **rewarded interstitial** and reports only
/// whether the reward was actually earned — never whether the ad opened.
///
/// Rewarded interstitial and rewarded video are separate placement formats in
/// Meta's dashboard, and the `easy_audience_network` plugin binds only the
/// latter. This talks to [MetaRewardedInterstitial] on the Android side
/// instead, which wraps `com.facebook.ads.RewardedInterstitialAd` directly.
///
/// The channel is one shot by design: one call in, one outcome back. The
/// "was it actually watched?" decision lives on the native side, next to the
/// only callback that can answer it, so nothing here can mistake an ad that
/// merely appeared for one that earned a reward.
class RewardedAdService {
  RewardedAdService._();

  static const MethodChannel _channel = MethodChannel(
    'enhanzo/meta_rewarded_interstitial',
  );

  /// Meta Audience Network ships Android and iOS SDKs; this app is Android
  /// only, and the bridge above exists only in the Android host. Anything
  /// else — a widget test on the Dart VM, a desktop host — is treated as "no
  /// ads available" rather than attempting a call with no handler.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Loads and shows a rewarded interstitial, resolving once the user has
  /// finished with it. Never leaves the caller waiting forever: anything that
  /// stops the ad appearing resolves as [RewardOutcome.unavailable] rather
  /// than hanging on a spinner with no way out.
  static Future<RewardOutcome> showRewardedAd() async {
    if (!isSupportedPlatform || !AdConfig.isRewardedConfigured) {
      return RewardOutcome.unavailable;
    }

    try {
      final result = await _channel.invokeMethod<String>('show', {
        'placementId': AdConfig.rewardedPlacementId,
      });
      return switch (result) {
        'earned' => RewardOutcome.earned,
        'dismissed' => RewardOutcome.dismissedEarly,
        // Covers 'unavailable' and any unexpected/null reply: nothing was
        // watched, so nothing may be unlocked.
        _ => RewardOutcome.unavailable,
      };
    } catch (_) {
      // A platform-channel failure (no handler registered, a transient native
      // error) is a reportable outcome, not a crash: resolving as unavailable
      // is what lets the gate offer a retry or Premium.
      return RewardOutcome.unavailable;
    }
  }
}
