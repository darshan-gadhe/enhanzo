import 'dart:async';

import 'package:easy_audience_network/easy_audience_network.dart';

import 'ad_config.dart';
import 'rewarded_ad_service.dart' show RewardedAdService;

/// How one interstitial attempt ended.
enum InterstitialOutcome {
  /// The ad was shown and the user dismissed it. The only "it worked" case.
  shown,

  /// Nothing could be shown — no fill, no network, no placement configured,
  /// or an attempt was already in flight. Callers must treat this as a no-op
  /// and carry on: an interstitial that fails to load is never a reason to
  /// block the user from what they were doing.
  unavailable,
}

/// Loads and shows one Meta Audience Network interstitial at a time.
///
/// Unlike the rewarded ad, nothing is ever unlocked in exchange for this —
/// it's a full-screen break between actions, so the caller does not wait on
/// the result to decide anything. [showInterstitial] still resolves once the
/// ad is dismissed so a caller *may* sequence work after it if it wants to.
class InterstitialAdService {
  InterstitialAdService._();

  static bool _busy = false;

  /// Ceiling on the *load* phase only. Matches the native rewarded bridge's
  /// own backstop (MetaRewardedInterstitial.LOAD_TIMEOUT_MS).
  static const Duration _loadTimeout = Duration(seconds: 30);

  /// True while an interstitial is loading or on screen — so a caller can
  /// skip asking for one rather than queueing a second.
  static bool get isBusy => _busy;

  /// Shows an interstitial, resolving when it is dismissed or when it turns
  /// out it can't be shown at all. Never throws.
  static Future<InterstitialOutcome> showInterstitial() async {
    if (!RewardedAdService.isSupportedPlatform ||
        !AdConfig.isInterstitialConfigured) {
      return InterstitialOutcome.unavailable;
    }
    if (_busy) return InterstitialOutcome.unavailable;
    _busy = true;

    // Single-use, exactly like the rewarded ad: `load()` and `show()` each
    // assert they run at most once, so this is built fresh and destroyed at
    // the end of the attempt.
    final ad = InterstitialAd(AdConfig.interstitialPlacementId);
    final completer = Completer<InterstitialOutcome>();

    void finish(InterstitialOutcome outcome) {
      if (!completer.isCompleted) completer.complete(outcome);
    }

    // Cancelled the moment the ad is on screen — see below.
    Timer? loadTimeout;

    try {
      ad.listener = InterstitialAdListener(
        onLoaded: () {
          // It's displaying now, and how long the user looks at it is their
          // business, so the load backstop stops applying here.
          loadTimeout?.cancel();
          unawaited(
            Future<void>(ad.show).catchError((_) => finish(
                  InterstitialOutcome.unavailable,
                )),
          );
        },
        onDismissed: () => finish(InterstitialOutcome.shown),
        onError: (_, _) => finish(InterstitialOutcome.unavailable),
      );

      // Backstop for a load that reports nothing at all — which is exactly
      // what happens when EasyAudienceNetwork.init() failed earlier (no
      // network at launch, say) and the SDK is inert. Without it the completer
      // below never resolves, so `finally` never runs, `_busy` stays true for
      // the rest of the process, and every later interstitial is silently
      // refused at the top of this method.
      loadTimeout = Timer(
        _loadTimeout,
        () => finish(InterstitialOutcome.unavailable),
      );

      await ad.load();
      return await completer.future;
    } catch (_) {
      return InterstitialOutcome.unavailable;
    } finally {
      loadTimeout?.cancel();
      _busy = false;
      unawaited(Future<void>(ad.destroy).catchError((_) {}));
    }
  }
}
