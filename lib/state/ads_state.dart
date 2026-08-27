import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ads/ad_config.dart';

/// Initializes Meta Audience Network once per process. Watched eagerly from
/// [AppShell] (the same way [entitlementProvider] is), so the SDK is ready
/// before a user reaches an ad rather than adding that delay to their first
/// one. A no-op anywhere that isn't Android — this app's only shipping target.
///
/// [AdConfig.testMode] is what keeps development off billable inventory:
/// Meta serves test ads against the real placement when it's set, which is
/// its documented alternative to AdMob-style public test IDs.
///
/// There is no consent flow here. AdMob required Google's UMP SDK; Meta's SDK
/// carries its own consent handling and, for an app with no ads outside Meta,
/// there is nothing left for a separate CMP to gate. Never throws — a failed
/// init leaves the app fully usable, just without ads.
///
/// This is the whole of the app's ad state. There is no gate controller and no
/// per-attempt state to track: interstitials are fire-and-forget, and
/// [InterstitialAdService] owns its own in-flight flag and cooldown.
final adsBootstrapProvider = FutureProvider<void>((ref) async {
  if (!AdConfig.isSupportedPlatform) return;
  try {
    await EasyAudienceNetwork.init(
      testMode: AdConfig.testMode,
      // Only in a test build, and only if a hash was actually supplied —
      // passing it in release would register a real user's device as a
      // tester and stop their ads earning anything.
      testingId: AdConfig.testMode && AdConfig.testingDeviceHash.isNotEmpty
          ? AdConfig.testingDeviceHash
          : null,
    );
  } catch (_) {
    // No ads this session; the interstitial service checks its own
    // preconditions and reports "unavailable" rather than depending on this
    // having succeeded.
  }
});
