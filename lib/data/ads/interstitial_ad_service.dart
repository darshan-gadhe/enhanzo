import 'dart:async';

import 'package:easy_audience_network/easy_audience_network.dart';
import 'package:flutter/foundation.dart';

import 'ad_config.dart';

/// How one interstitial attempt ended.
enum InterstitialOutcome {
  /// The ad was shown and the user dismissed it. The only "it worked" case.
  shown,

  /// Nothing could be shown — no ad was ready, no placement configured, or one
  /// was already on screen. Callers must treat this as a no-op and carry on: an
  /// interstitial that isn't there is never a reason to block the user.
  unavailable,

  /// Held back by the cooldown: an interstitial ran too recently. Distinct
  /// from [unavailable] so "we chose not to" is never mistaken for "Meta had
  /// nothing", which is the difference between a healthy fill rate and a
  /// broken placement when reading logs.
  suppressed,
}

/// Why the last attempt did not put an ad on screen. Debug reporting only.
enum InterstitialState {
  idle,
  loading,
  ready,
  showing,
  failed,
  notConfigured,
}

/// Loads Meta Audience Network interstitials ahead of time and shows one at a
/// task boundary.
///
/// ## Why it preloads
///
/// This used to load the ad *at* the boundary and show it from the load
/// callback, which was wrong in two ways that both look like "ads don't work":
///
///  * **Nothing could appear on time.** A load takes seconds. The call was
///    fire-and-forget, so the ad arrived long after the user had moved on and
///    covered whatever screen they were on by then — or, more often, the load
///    timed out and nothing appeared at all.
///  * **The first attempt of a process could lose its callbacks.** The plugin
///    registers its method-call handler *after* `loadAd` returns
///    (`interstitial_ad_platform_interface.dart`), so any callback Meta raises
///    synchronously inside `loadAd` — an invalid placement id, for one — is
///    delivered to a channel with no handler and dropped. The failure is
///    silent: no error, no ad, nothing to read.
///
/// Preloading fixes both. The load starts at app launch and again after each
/// finished edit, so by the time a boundary arrives the ad is already cached
/// and [showIfReady] either shows it immediately or does nothing at all. It
/// also means the handler is installed at launch, so a synchronous error is
/// raised where [preload]'s logging can report it instead of vanishing.
///
/// Nothing is ever unlocked in exchange for an ad, and no caller waits on one.
class InterstitialAdService {
  InterstitialAdService._();

  /// The cached ad: loading, or ready to show.
  static InterstitialAd? _ad;

  static bool _ready = false;
  static bool _loading = false;
  static bool _showing = false;

  /// When an interstitial was last actually shown. Null until the first one.
  static DateTime? _lastShownAt;

  static Timer? _loadTimer;
  static Timer? _showTimer;
  static Completer<InterstitialOutcome>? _showCompleter;

  /// Ceiling on a load. Meta answers in seconds; a load still outstanding
  /// after this is treated as no ad rather than left to hold the slot forever.
  static const Duration _loadTimeout = Duration(seconds: 30);

  /// Ceiling on the gap between asking to show and the ad appearing.
  ///
  /// The plugin's `show()` discards the boolean the native side returns, so a
  /// refused show (the cached ad went stale, say) is indistinguishable from a
  /// slow one. Without this the caller's future would never resolve and the
  /// service would stay stuck in [InterstitialState.showing].
  static const Duration _displayTimeout = Duration(seconds: 5);

  /// Default shortest gap between two interstitials.
  ///
  /// Without one, an interstitial fired on *every* saved edit — so a user
  /// working through a batch of photos met a full-screen ad each time. Both
  /// Meta's and Play's policies treat that frequency as a bad-experience
  /// signal, and it is the sort of thing that gets a placement throttled
  /// rather than earning more.
  ///
  /// The free-enhancement boundary passes [Duration.zero] instead: a free user
  /// gets three enhancements in the lifetime of the install, so there can be at
  /// most three interstitials ever, and the allowance is itself the frequency
  /// cap. Leaving a three-minute gap in place would silently drop the second
  /// and third of the only three the app will ever show.
  static const Duration minInterval = Duration(minutes: 3);

  /// What the service is doing right now. Debug reporting only.
  @visibleForTesting
  static InterstitialState get state {
    if (!AdConfig.isSupportedPlatform || !AdConfig.isInterstitialConfigured) {
      return InterstitialState.notConfigured;
    }
    if (_showing) return InterstitialState.showing;
    if (_ready) return InterstitialState.ready;
    if (_loading) return InterstitialState.loading;
    return _lastError == null ? InterstitialState.idle : InterstitialState.failed;
  }

  static String? _lastError;

  /// Meta's own words for the last failure, or null if there hasn't been one.
  @visibleForTesting
  static String? get lastError => _lastError;

  /// How many times [showIfReady] has been entered this process.
  ///
  /// Test-only, and it earns its place: "a premium user costs zero ad
  /// requests" is a claim about what the app *doesn't* do, and the only way to
  /// check it is to count. Incremented on entry, before any early return.
  @visibleForTesting
  static int attempts = 0;

  /// How many loads have been started this process. Test-only.
  @visibleForTesting
  static int loads = 0;

  /// True while an ad is loading or on screen.
  static bool get isBusy => _loading || _showing;

  /// True when an ad is cached and could be shown right now.
  static bool get isReady => _ready;

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

  /// Clears the cooldown. Tests only — the app never needs it.
  @visibleForTesting
  static void resetCooldownForTest() => _lastShownAt = null;

  /// Returns the service to its start-of-process state. Tests only.
  @visibleForTesting
  static void resetForTest() {
    attempts = 0;
    loads = 0;
    _lastShownAt = null;
    _lastError = null;
    _ready = false;
    _loading = false;
    _showing = false;
    _loadTimer?.cancel();
    _showTimer?.cancel();
    _showCompleter = null;
    _ad = null;
  }

  static void _log(String message) {
    assert(() {
      debugPrint('Meta interstitial: $message');
      return true;
    }());
  }

  /// Starts caching one interstitial, if there isn't one already.
  ///
  /// Call it early and call it often — at launch, and again after each finished
  /// edit. Cheap when there is nothing to do, never throws, and never retries
  /// on its own: a failed load waits for the next explicit call rather than
  /// hammering the placement.
  static Future<void> preload() async {
    if (!AdConfig.isSupportedPlatform) {
      _log('skipped: not Android');
      return;
    }
    if (!AdConfig.isInterstitialConfigured) {
      _log('skipped: no placement compiled in — rebuild with '
          '--dart-define-from-file=.env');
      return;
    }
    if (_ready || _loading || _showing) return;

    _loading = true;
    loads++;
    _lastError = null;

    // Single-use: `load()` and `show()` each assert they run at most once, so
    // this is built fresh per attempt and destroyed at the end. Reusing one is
    // how this crashes.
    final ad = InterstitialAd(AdConfig.interstitialPlacementId);
    _ad = ad;

    ad.listener = InterstitialAdListener(
      onLoaded: () {
        if (!identical(_ad, ad)) return;
        _loadTimer?.cancel();
        _loading = false;
        _ready = true;
        _log('loaded and cached, ready for the next boundary');
      },
      onError: (code, message) {
        if (!identical(_ad, ad)) return;
        _loadTimer?.cancel();
        _lastError = '$code: $message';
        _loading = false;
        _ready = false;
        _ad = null;
        _log('error $code — $message');
        if (code == 1001) {
          _log(
            'code 1001 is NO FILL: the request reached Meta and was answered '
            '"no ad available". The integration is working; Meta had nothing '
            'to serve. Expected until the app and placement are approved in '
            'Monetization Manager, and normal at low volume afterwards.',
          );
        }
        _finishShow(InterstitialOutcome.unavailable);
        unawaited(Future<void>(ad.destroy).catchError((_) {}));
      },
      onDisplayed: () {
        _showTimer?.cancel();
        _log('displayed');
      },
      onDismissed: () {
        // Stamped on a real display, not on a load attempt: a no-fill must
        // not start a cooldown and silence the next genuine opportunity.
        _lastShownAt = DateTime.now();
        _log('dismissed');
        _ready = false;
        _ad = null;
        _finishShow(InterstitialOutcome.shown);
        unawaited(Future<void>(ad.destroy).catchError((_) {}));
      },
    );

    _loadTimer = Timer(_loadTimeout, () {
      if (!identical(_ad, ad) || !_loading) return;
      _loading = false;
      _ready = false;
      _ad = null;
      _lastError = 'load timed out after ${_loadTimeout.inSeconds}s';
      _log('load timed out — no callback from Meta at all. If this repeats, '
          'the SDK is not initialised or the placement id is wrong.');
      unawaited(Future<void>(ad.destroy).catchError((_) {}));
    });

    try {
      _log('requesting…');
      await ad.load();
    } catch (error) {
      _loadTimer?.cancel();
      _loading = false;
      _ready = false;
      _ad = null;
      _lastError = '$error';
      _log('load threw: $error');
    }
  }

  /// Shows the cached interstitial if one is ready, and otherwise does nothing.
  ///
  /// Resolves when the ad is dismissed, or immediately when there is nothing to
  /// show. Never throws, and the caller is never left waiting on Meta.
  ///
  /// [cooldown] overrides [minInterval] for this attempt — see that constant
  /// for why the free-enhancement boundary passes [Duration.zero].
  static Future<InterstitialOutcome> showIfReady({
    Duration cooldown = minInterval,
  }) async {
    attempts++;

    if (!AdConfig.isSupportedPlatform || !AdConfig.isInterstitialConfigured) {
      _log('not shown: android=${AdConfig.isSupportedPlatform} '
          'placement=${AdConfig.isInterstitialConfigured}');
      return InterstitialOutcome.unavailable;
    }
    // One at a time, independent of any interval: a double tap or a repeated
    // callback cannot put two ads up.
    if (_showing) {
      _log('not shown: one is already on screen');
      return InterstitialOutcome.unavailable;
    }
    if (isWithinCooldown(_lastShownAt, DateTime.now(), interval: cooldown)) {
      _log('not shown: inside the ${cooldown.inMinutes}m cooldown');
      return InterstitialOutcome.suppressed;
    }
    if (!_ready || _ad == null) {
      _log(
        'not shown: nothing cached '
        '(${_loading ? 'still loading' : _lastError ?? 'never loaded'}). '
        'Starting a load for the next boundary.',
      );
      // Not awaited: the user moved on, and an ad that arrives now would land
      // on whatever they are doing next.
      unawaited(preload());
      return InterstitialOutcome.unavailable;
    }

    final ad = _ad!;
    _showing = true;
    _ready = false;
    final completer = Completer<InterstitialOutcome>();
    _showCompleter = completer;

    // The plugin drops the boolean the native side returns, so a refused show
    // looks exactly like a slow one. Cancelled by onDisplayed.
    _showTimer = Timer(_displayTimeout, () {
      _log('asked to show but nothing appeared within '
          '${_displayTimeout.inSeconds}s — treating as unavailable');
      _ad = null;
      _finishShow(InterstitialOutcome.unavailable);
      unawaited(preload());
    });

    try {
      _log('showing…');
      await ad.show();
    } catch (error) {
      _log('show threw: $error');
      _showTimer?.cancel();
      _ad = null;
      _finishShow(InterstitialOutcome.unavailable);
    }

    final outcome = await completer.future;
    // Have the next one ready before the next boundary arrives.
    unawaited(preload());
    return outcome;
  }

  static void _finishShow(InterstitialOutcome outcome) {
    _showTimer?.cancel();
    _showing = false;
    final completer = _showCompleter;
    _showCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }
}
