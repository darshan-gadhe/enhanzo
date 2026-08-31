import 'dart:async';

import 'package:easy_audience_network/easy_audience_network.dart';

import 'package:flutter/foundation.dart';
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
  if (!AdConfig.isSupportedPlatform) {
    assert(() {
      debugPrint('Meta: not an Android build — no ads will be requested.');
      return true;
    }());
    return;
  }
  if (!AdConfig.isInterstitialConfigured) {
    assert(() {
      debugPrint('Meta: no placement compiled in. Rebuild with '
          '--dart-define-from-file=.env');
      return true;
    }());
    return;
  }
  try {
    final ok = await EasyAudienceNetwork.init(
      testMode: AdConfig.testMode,
      // Only in a test build, and only if a hash was actually supplied —
      // passing it in release would register a real user's device as a
      // tester and stop their ads earning anything.
      testingId: AdConfig.testMode && AdConfig.testingDeviceHash.isNotEmpty
          ? AdConfig.testingDeviceHash
          : null,
    );
    // The SDK reports whether it came up, and this used to discard it. When
    // ads then failed to appear there was nothing to distinguish "the SDK
    // never initialised" from "Meta had no ad to give", which are different
    // problems with different fixes.
    assert(() {
      debugPrint(
        'Meta init: ${ok == true ? 'ok' : 'FAILED ($ok)'} · '
        'testMode=${AdConfig.testMode} · '
        'testDeviceHash=${AdConfig.testingDeviceHash.isEmpty ? 'none' : 'set'}',
      );
      if (AdConfig.testMode && AdConfig.testingDeviceHash.isEmpty) {
        debugPrint(
          'Meta: test mode with no device hash. The SDK usually refuses test '
          'ads until the device is registered — copy the hash it logs into '
          'META_TESTING_DEVICE_HASH in .env and relaunch.',
        );
      }
      return true;
    }());

    // Start caching the first interstitial now, so the first boundary has one
    // ready rather than starting a multi-second load the user has already
    // walked away from. This is also what installs the plugin's method-call
    // handler early enough to catch an error Meta raises synchronously.
    if (ok == true) unawaited(InterstitialAdService.preload());
  } catch (_) {
    // No ads this session; the interstitial service checks its own
    // preconditions and reports "unavailable" rather than depending on this
    // having succeeded.
    assert(() {
      debugPrint('Meta init threw — no ads this session.');
      return true;
    }());
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
  return InterstitialAdService.showIfReady(cooldown: Duration.zero);
}

/// Starts caching the interstitial that the *next* boundary will show.
///
/// Called when an enhancement begins, which buys the load the seconds it needs
/// while the model is running — the difference between an ad that is ready at
/// the boundary and one that arrives after the user has moved on.
///
/// A premium user preloads nothing: no request, no cached ad, no cost.
void prepareBoundaryInterstitial({required bool isPremium}) {
  if (isPremium) return;
  unawaited(InterstitialAdService.preload());
}
