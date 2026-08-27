import 'package:flutter/foundation.dart';

/// The Meta Audience Network interstitial placement, and how this build
/// requests it.
///
/// Interstitials are the app's only ad format. There is no banner and no
/// rewarded ad — nothing else is loaded, and no other placement is compiled
/// in.
///
/// **Test ads work differently here than they do on AdMob.** Google publishes
/// universal test ad-unit IDs that anyone can hard-code. Meta does not: there
/// is no public placement ID to point at. Instead the *same* real placement ID
/// is used in every build, and Meta decides whether to serve a test ad from
/// [testMode] — which [kReleaseMode] drives, so debug and profile builds can
/// never request billable inventory and a release build can never accidentally
/// ship test ads.
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

  /// True in debug and profile builds. Meta then serves test ads against the
  /// real placement, which is its documented way of testing — see
  /// `EasyAudienceNetwork.init(testMode: ...)` in [adsBootstrapProvider].
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
  /// Ignored in release: the bootstrap only passes it when [testMode] is on,
  /// so a stale hash left in `.env` can never affect live ad delivery.
  static const String testingDeviceHash = String.fromEnvironment(
    'META_TESTING_DEVICE_HASH',
  );

  static bool get isInterstitialConfigured =>
      interstitialPlacementId.isNotEmpty;

  /// Meta Audience Network ships Android and iOS SDKs; this app is Android
  /// only. Anything else — a widget test on the Dart VM, a desktop host — is
  /// treated as "no ads available" rather than attempting a platform call that
  /// doesn't exist there.
  ///
  /// Lives here rather than on a service so the one platform rule is shared,
  /// not duplicated per ad format.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
