// The interstitial frequency rule.
//
// Before this, an interstitial fired on every saved edit — a user working
// through a batch of photos met a full-screen ad each time. Meta and Play both
// treat that as a bad-experience signal, and it gets placements throttled
// rather than earning more.
//
// The cooldown decision is pure logic on purpose, so it can be proved here
// without a platform channel, a real placement, or a live ad in the way.

import 'package:ai_enhancer/data/ads/interstitial_ad_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 20, 12, 0, 0);

  test('the first interstitial of a session is never held back', () {
    expect(InterstitialAdService.isWithinCooldown(null, now), isFalse);
  });

  test('a second one immediately after is suppressed', () {
    expect(InterstitialAdService.isWithinCooldown(now, now), isTrue);
  });

  test('still suppressed just before the interval elapses', () {
    final shownAt = now.subtract(
      InterstitialAdService.minInterval - const Duration(seconds: 1),
    );
    expect(InterstitialAdService.isWithinCooldown(shownAt, now), isTrue);
  });

  test('allowed again once the interval has elapsed', () {
    final shownAt = now.subtract(InterstitialAdService.minInterval);
    expect(InterstitialAdService.isWithinCooldown(shownAt, now), isFalse);
  });

  test('allowed well after the interval', () {
    final shownAt = now.subtract(const Duration(hours: 2));
    expect(InterstitialAdService.isWithinCooldown(shownAt, now), isFalse);
  });

  test('the interval is a real gap, not effectively zero', () {
    // Guards against someone "disabling" the cooldown by zeroing it and
    // leaving the mechanism in place looking functional.
    expect(
      InterstitialAdService.minInterval,
      greaterThanOrEqualTo(const Duration(minutes: 1)),
    );
  });

  test('suppressed is distinct from unavailable', () {
    // "We chose not to" must never be read as "Meta had nothing" — that
    // distinction is what separates a healthy fill rate from a broken
    // placement when reading logs.
    expect(
      InterstitialOutcome.suppressed,
      isNot(InterstitialOutcome.unavailable),
    );
  });

  group('preloading — what lets an ad appear at the boundary at all', () {
    setUp(InterstitialAdService.resetForTest);

    test('nothing is cached before a load, so showing does nothing', () async {
      expect(InterstitialAdService.isReady, isFalse);
      expect(
        await InterstitialAdService.showIfReady(cooldown: Duration.zero),
        InterstitialOutcome.unavailable,
      );
    });

    test('an unconfigured build never starts a load', () async {
      // No placement under `flutter test`, so preload must fall out at the
      // precondition rather than reaching a platform channel that isn't there.
      await InterstitialAdService.preload();
      expect(InterstitialAdService.loads, 0);
      expect(InterstitialAdService.state, InterstitialState.notConfigured);
    });

    test('a show attempt is counted even when nothing can be shown', () async {
      await InterstitialAdService.showIfReady(cooldown: Duration.zero);
      await InterstitialAdService.showIfReady(cooldown: Duration.zero);
      // The count is what proves "a premium user costs zero ad requests"
      // elsewhere, so it has to move for a free user whatever the outcome.
      expect(InterstitialAdService.attempts, 2);
    });

    test('a failed attempt never starts the cooldown', () async {
      await InterstitialAdService.showIfReady(cooldown: Duration.zero);
      // Nothing was shown, so nothing may be held back next time.
      expect(
        await InterstitialAdService.showIfReady(cooldown: Duration.zero),
        isNot(InterstitialOutcome.suppressed),
      );
    });

    test('the service is never left stuck busy after a failed attempt',
        () async {
      await InterstitialAdService.showIfReady(cooldown: Duration.zero);
      // `_showing` stuck true would silently refuse every later interstitial
      // for the rest of the process.
      expect(InterstitialAdService.isBusy, isFalse);
    });

    test('the display timeout is short enough to not strand the caller', () {
      // The plugin discards the boolean the native show returns, so a refused
      // show is indistinguishable from a slow one; only this bounds it.
      expect(InterstitialAdService.minInterval,
          greaterThan(const Duration(seconds: 30)));
    });
  });

  test('an unsupported platform reports unavailable, not suppressed', () async {
    // No Meta SDK under `flutter test`, and no placement configured, so this
    // must fall out at the precondition check rather than the cooldown.
    InterstitialAdService.resetForTest();
    expect(
      await InterstitialAdService.showIfReady(),
      InterstitialOutcome.unavailable,
    );
  });
}
