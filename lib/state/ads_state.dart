import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ads/ad_config.dart';
import '../data/ads/interstitial_ad_service.dart';

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


/// The app's only ad boundary: one interstitial after a free user's
/// enhancement has completed and been saved.
///
/// **A premium user costs zero ad requests.** The check is here, before the
/// service is entered, so nothing is loaded, requested, or counted against the
/// placement on their behalf — which is what "no ad requests" has to mean to
/// be worth saying.
///
/// [Duration.zero] rather than the service's default three-minute spacing: a
/// free user gets [AccessState.freeLimit] enhancements for the life of the
/// install, so this can fire at most that many times, ever. The allowance is
/// the frequency cap; the interval would only silently drop the second and
/// third of the three. See [InterstitialAdService.minInterval].
///
/// Never throws, and the caller never waits on it: no fill, no network, a
/// failed SDK init and an unconfigured placement all resolve to
/// [InterstitialOutcome.unavailable], which is a no-op by design.
Future<InterstitialOutcome> showBoundaryInterstitial({
  required bool isPremium,
}) async {
  if (isPremium) return InterstitialOutcome.unavailable;
  return InterstitialAdService.showInterstitial(cooldown: Duration.zero);
}
