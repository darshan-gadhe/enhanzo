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

  /// Default shortest gap between two interstitials.
  ///
  /// Without one, an interstitial fired on *every* saved edit — so a user
  /// working through a batch of photos met a full-screen ad each time. Both
  /// Meta's and Play's policies treat that frequency as a bad-experience
  /// signal, and it is the sort of thing that gets a placement throttled
  /// rather than earning more.
  ///
  /// The free-enhancement boundary now passes [Duration.zero] instead, and the
  /// reason is worth stating: a free user gets three enhancements in the
  /// lifetime of the install, so there can be at most three interstitials —
  /// ever. The batch this interval was written to prevent cannot happen any
  /// more, because the allowance is itself the frequency cap, and leaving a
  /// three-minute gap in place would silently drop the second and third ad of
  /// the only three the app will ever get. [_busy] remains the guard against
  /// two ads from one boundary; this is only about spacing.
  ///
  /// It stays as the default so any *other* call site is spaced by default and
  /// has to opt out deliberately.
  static const Duration minInterval = Duration(minutes: 3);

  /// True while an interstitial is loading or on screen — so a caller can
  /// skip asking for one rather than queueing a second.
  static bool get isBusy => _busy;

  /// Whether [now] is still inside the cooldown that began at [lastShownAt].
  ///
  /// Pulled out as pure logic so the rule is testable on its own, without a
  /// platform channel or a real ad in the way.
  @visibleForTesting
  static bool isWithinCooldown(
    DateTime? lastShownAt,
    DateTime now, {
    Duration interval = minInterval,
  }) {
    if (lastShownAt == null) return false;
    if (interval == Duration.zero) return false;
    return now.difference(lastShownAt) < interval;
  }

  /// How many times [showInterstitial] has been entered this process.
  ///
  /// Test-only, and it earns its place: "a premium user costs zero ad
  /// requests" is a claim about what the app *doesn't* do, and the only way to
  /// check it is to count. Incremented on entry, before any early return, so
  /// even a request that is refused is counted as having been made.
  @visibleForTesting
  static int attempts = 0;

  /// Clears the cooldown. Tests only — the app never needs it.
  @visibleForTesting
  static void resetCooldownForTest() => _lastShownAt = null;

  /// Returns the service to its start-of-process state. Tests only.
  @visibleForTesting
  static void resetForTest() {
    attempts = 0;
    _lastShownAt = null;
    _busy = false;
  }

  /// Shows an interstitial, resolving when it is dismissed or when it turns
  /// out it can't be shown at all. Never throws.
  ///
  /// [cooldown] overrides [minInterval] for this attempt — see that constant
  /// for why the free-enhancement boundary passes [Duration.zero].
  static Future<InterstitialOutcome> showInterstitial({
    Duration cooldown = minInterval,
  }) async {
    attempts++;
    if (!AdConfig.isSupportedPlatform ||
        !AdConfig.isInterstitialConfigured) {
      return InterstitialOutcome.unavailable;
    }
    // The true duplicate guard, independent of any interval: one attempt at a
    // time, so a double tap or a repeated callback cannot put two ads up.
    if (_busy) return InterstitialOutcome.unavailable;
    if (isWithinCooldown(_lastShownAt, DateTime.now(), interval: cooldown)) {
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
