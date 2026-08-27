import 'dart:async';

import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:flutter/foundation.dart';

import 'ad_config.dart';

/// How one interstitial attempt ended.
enum InterstitialOutcome {
  /// The ad was shown and the user dismissed it. The only "it worked" case.
  shown,

  /// Nothing could be shown — no fill, no network, no placement configured,
  /// or an attempt was already in flight. Callers must treat this as a no-op
  /// and carry on: an interstitial that fails to load is never a reason to
  /// block the user from what they were doing.
  unavailable,

  /// Held back by the cooldown: an interstitial ran too recently. Distinct
  /// from [unavailable] so "we chose not to" is never mistaken for "Meta had
  /// nothing", which is the difference between a healthy fill rate and a
  /// broken placement when reading logs.
  suppressed,
}

/// Loads and shows one Meta Audience Network interstitial at a time.
///
/// Nothing is ever unlocked in exchange for one — it is a full-screen break
/// between actions, so the caller does not wait on the result to decide
/// anything. [showInterstitial] still resolves once the ad is dismissed, so a
/// caller *may* sequence work after it if it wants to.
class InterstitialAdService {
  InterstitialAdService._();

  static bool _busy = false;

  /// When an interstitial was last actually shown. Null until the first one.
  static DateTime? _lastShownAt;

  /// Ceiling on the *load* phase only — never on display, since a user
  /// looking at an ad legitimately takes time. Without it, a load that
  /// reports nothing at all (an SDK that failed to initialize, say) would
  /// leave `_busy` set for the rest of the process and silently refuse every
  /// later interstitial.
  static const Duration _loadTimeout = Duration(seconds: 30);

  /// Shortest gap allowed between two interstitials.
  ///
  /// Without one, an interstitial fired on *every* saved edit — so a user
  /// working through a batch of photos met a full-screen ad each time. Both
  /// Meta's and Play's policies treat that frequency as a bad-experience
  /// signal, and it is the sort of thing that gets a placement throttled
  /// rather than earning more.
  static const Duration minInterval = Duration(minutes: 3);

  /// True while an interstitial is loading or on screen — so a caller can
  /// skip asking for one rather than queueing a second.
  static bool get isBusy => _busy;

  /// Whether [now] is still inside the cooldown that began at [lastShownAt].
  ///
  /// Pulled out as pure logic so the rule is testable on its own, without a
  /// platform channel or a real ad in the way.
  @visibleForTesting
  static bool isWithinCooldown(DateTime? lastShownAt, DateTime now) {
    if (lastShownAt == null) return false;
    return now.difference(lastShownAt) < minInterval;
  }

  /// Clears the cooldown. Tests only — the app never needs it.
  @visibleForTesting
  static void resetCooldownForTest() => _lastShownAt = null;

  /// Shows an interstitial, resolving when it is dismissed or when it turns
  /// out it can't be shown at all. Never throws.
  static Future<InterstitialOutcome> showInterstitial() async {
    if (!AdConfig.isSupportedPlatform ||
        !AdConfig.isInterstitialConfigured) {
      return InterstitialOutcome.unavailable;
    }
    if (_busy) return InterstitialOutcome.unavailable;
    if (isWithinCooldown(_lastShownAt, DateTime.now())) {
      return InterstitialOutcome.suppressed;
    }
    _busy = true;

    // Single-use: `load()` and `show()` each assert they run at most once, so
    // this is built fresh per attempt and destroyed at the end. Reusing one is
    // how this crashes.
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
        onDismissed: () {
          // Stamped on a real display, not on a load attempt: a no-fill must
          // not start a cooldown and silence the next genuine opportunity.
          _lastShownAt = DateTime.now();
          finish(InterstitialOutcome.shown);
        },
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
