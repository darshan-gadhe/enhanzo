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

  test('an unsupported platform reports unavailable, not suppressed', () async {
    // No Meta SDK under `flutter test`, and no placement configured, so this
    // must fall out at the precondition check rather than the cooldown.
    InterstitialAdService.resetCooldownForTest();
    expect(
      await InterstitialAdService.showInterstitial(),
      InterstitialOutcome.unavailable,
    );
  });
}
