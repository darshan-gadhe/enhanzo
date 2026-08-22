import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ads/ad_config.dart';
import '../data/ads/rewarded_ad_service.dart';

/// Initializes Meta Audience Network once per process. Watched eagerly from
/// [AppShell] (the same way [entitlementProvider] is), so the SDK is ready
/// before a user reaches an ad rather than adding that delay to their first
/// attempt. A no-op anywhere that isn't Android — this app's only shipping
/// target.
///
/// [AdConfig.testMode] is what keeps development off billable inventory:
/// Meta serves test ads against the real placement when it's set, which is
/// its documented alternative to AdMob-style public test IDs.
///
/// There is no consent flow here. AdMob required Google's UMP SDK; Meta's
/// SDK carries its own consent handling and, for an app with no ads outside
/// Meta, there is nothing left for a separate CMP to gate. Never throws — a
/// failed init leaves the app fully usable, just without ads.
final adsBootstrapProvider = FutureProvider<void>((ref) async {
  if (!RewardedAdService.isSupportedPlatform) return;
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
    // No ads this session; every service checks its own preconditions and
    // reports "unavailable" rather than depending on this having succeeded.
  }
});

enum AdGateStatus { idle, loading, failed }

/// Transient state for one rewarded-ad attempt — the ad-gate sheet's loading
/// spinner and retry affordance read this, and nothing else does. There is
/// deliberately no "reward granted" flag stored here: a reward is a one-shot
/// event a caller reacts to from [AdGateController.watch]'s return value, not
/// a piece of state anything should be able to read stale later.
@immutable
class AdGateState {
  final AdGateStatus status;

  const AdGateState({this.status = AdGateStatus.idle});

  AdGateState copyWith({AdGateStatus? status}) =>
      AdGateState(status: status ?? this.status);
}

/// Drives one rewarded-ad attempt at a time: load, show, report whether the
/// reward was actually earned.
///
/// Owns no notion of what the reward is *for* — that decision belongs to
/// whatever screen calls [watch], and only in response to it returning
/// `true`. This separation is what keeps the ad-gate reusable for whichever
/// action ends up behind it, without the ad plumbing needing to know.
class AdGateController extends Notifier<AdGateState> {
  @override
  AdGateState build() => const AdGateState();

  /// Runs one attempt end to end. Returns `true` only if the user watched
  /// the ad through to completion and earned the reward — `false` for a
  /// dismissed-early or unavailable ad alike, since neither should unlock
  /// anything.
  Future<bool> watch() async {
    state = state.copyWith(status: AdGateStatus.loading);
    final outcome = await RewardedAdService.showRewardedAd();
    state = AdGateState(
      status: outcome == RewardOutcome.unavailable
          ? AdGateStatus.failed
          : AdGateStatus.idle,
    );
    return outcome == RewardOutcome.earned;
  }

  /// Clears a [AdGateStatus.failed] state back to idle — for "try again"
  /// without having already started a new load.
  void reset() => state = const AdGateState();
}

final adGateProvider = NotifierProvider<AdGateController, AdGateState>(
  AdGateController.new,
);
