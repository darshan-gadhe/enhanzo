import 'package:flutter/foundation.dart';

/// Meta Audience Network placement IDs, and how this build requests ads.
///
/// **Test ads work differently here than they do on AdMob.** Google publishes
/// universal test ad-unit IDs that anyone can hard-code. Meta does not: there
/// is no public placement ID to point at. Instead the *same* real placement ID
/// is used in every build, and Meta decides whether to serve a test ad from
/// [testMode] — which [kReleaseMode] drives, so debug and profile builds can
/// never request billable inventory and a release build can never accidentally
/// ship test ads.
///
/// That also means an unconfigured build has no placements at all rather than
/// falling back to something safe, so [isInterstitialConfigured] /
/// [isRewardedConfigured] exist for callers to check before asking for an ad.
///
/// Placement IDs are not secrets — they identify inventory, they don't
/// authorise spending — but they still come from `.env` so a fork of this repo
/// doesn't serve ads against someone else's Meta account.
class AdConfig {
  AdConfig._();

  /// From Meta Events Manager → Monetization Manager → Placements.
  /// Format is `<app_id>_<placement_id>`.
  static const String interstitialPlacementId = String.fromEnvironment(
    'META_INTERSTITIAL_PLACEMENT_ID',
  );
  static const String rewardedPlacementId = String.fromEnvironment(
    'META_REWARDED_PLACEMENT_ID',
  );

  /// True in debug and profile builds. Meta then serves test ads against the
  /// real placement, which is its documented way of testing — see
  /// `EasyAudienceNetwork.init(testMode: ...)` in [AdsBootstrap].
  ///
  /// Deliberately keyed off the build mode, never off which values happen to
  /// be filled in: a release build serves live ads or none at all.
  static bool get testMode => !kReleaseMode;

  /// This device's Meta test hash, if one has been supplied.
  ///
  /// [testMode] alone is often enough, but Meta's SDK frequently refuses to
  /// serve test ads until the specific device is registered, logging:
  ///
  /// ```
  /// When testing your app with Facebook's ad units you must specify the
  /// device hashed ID ... AdSettings.addTestDevice("HASH_ID")
  /// ```
  ///
  /// Run the app once, copy that hash out of logcat into
  /// `META_TESTING_DEVICE_HASH` in `.env`, and relaunch. Blank is fine and is
  /// the normal state — it only matters when test ads aren't filling.
  ///
  /// Ignored in release: [AdsBootstrap] only passes it when [testMode] is on,
  /// so a stale hash left in `.env` can never affect live ad delivery.
  static const String testingDeviceHash = String.fromEnvironment(
    'META_TESTING_DEVICE_HASH',
  );

  static bool get isInterstitialConfigured =>
      interstitialPlacementId.isNotEmpty;

  static bool get isRewardedConfigured => rewardedPlacementId.isNotEmpty;
}
