// The new-user premium flow, one scenario per group.
//
// Everything here runs against the real controllers with a fake store standing
// in for RevenueCat, so what is pinned is behaviour: who is shown the trial
// paywall, what a purchase changes and when, what survives a restart, and what
// an expiry takes away. Nothing hardcodes premium — every answer comes from
// the store.

import 'package:ai_enhancer/data/access_store.dart';
import 'package:ai_enhancer/data/ads/interstitial_ad_service.dart';
import 'package:ai_enhancer/state/access_state.dart';
import 'package:ai_enhancer/state/ads_state.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

ProviderContainer makeContainer(FakeStore store) {
  final container = ProviderContainer(
    overrides: [entitlementSourceProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// A launch: read both providers and let the store and the disk both answer.
Future<AccessState> launch(ProviderContainer c) async {
  c.read(entitlementProvider);
  c.read(accessProvider);
  await pumpEventQueue();
  return c.read(accessProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InterstitialAdService.resetForTest();
  });

  group('1 — a brand-new user', () {
    test('is offered the paywall on first open', () async {
      final c = makeContainer(FakeStore(premium: false));
      final state = await launch(c);

      expect(state.onboardingSeen, isFalse);
      expect(state.isPremium, isFalse);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isTrue);
    });

    test('is not offered it before the store has answered', () async {
      // The defect this pins: reading local storage takes a moment and asking
      // RevenueCat takes a round-trip. Deciding on the local read alone shows
      // the paywall to anyone the store has not vouched for yet.
      final c = makeContainer(
        FakeStore(premium: false, answerDelay: const Duration(seconds: 1)),
      );
      c.read(entitlementProvider);
      c.read(accessProvider);
      await pumpEventQueue();

      expect(c.read(accessProvider).loaded, isTrue,
          reason: 'the disk has answered');
      expect(c.read(accessProvider).premiumKnown, isFalse,
          reason: 'the store has not');
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });
  });

  group('2 — a user who dismisses the paywall', () {
    test('continues as free, with the full allowance', () async {
      final c = makeContainer(FakeStore(premium: false));
      await launch(c);
      // Dismissing is a presentation that happened, so it counts as offered.
      await c.read(accessProvider.notifier).markOnboardingSeen();

      final state = c.read(accessProvider);
      expect(state.isPremium, isFalse);
      expect(state.canGenerate, isTrue);
      expect(state.freeRemaining, AccessState.freeLimit);
    });

    test('is not offered it again on the next launch', () async {
      final first = makeContainer(FakeStore(premium: false));
      await launch(first);
      await first.read(accessProvider.notifier).markOnboardingSeen();

      final second = makeContainer(FakeStore(premium: false));
      await launch(second);
      expect(
          second.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });

    test('a paywall that never appeared is retried, not counted as offered',
        () async {
      // PaywallResult.error — no network on first launch, nothing published.
      // Recording that as "offered" silently costs a new user the trial on the
      // one launch it was meant for.
      final first = makeContainer(FakeStore(premium: false));
      await launch(first);
      await first.read(accessProvider.notifier).recordOnboardingFailure();

      final second = makeContainer(FakeStore(premium: false));
      await launch(second);
      expect(second.read(accessProvider).onboardingSeen, isFalse);
      expect(
          second.read(accessProvider.notifier).shouldOfferOnboarding, isTrue);
    });

    test('but a configuration that never works stops nagging', () async {
      final c = makeContainer(FakeStore(premium: false));
      await launch(c);
      final access = c.read(accessProvider.notifier);
      for (var i = 0; i < AccessStore.maxOnboardingTries; i++) {
        await access.recordOnboardingFailure();
      }
      expect(access.shouldOfferOnboarding, isFalse);

      final next = makeContainer(FakeStore(premium: false));
      await launch(next);
      expect(next.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });
  });

  group('3 & 4 — starting the trial / a successful purchase', () {
    test('premium takes effect immediately, without a relaunch', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await launch(c);
      expect(c.read(accessProvider).isPremium, isFalse);

      // What RevenueCat reports the moment its paywall completes a purchase —
      // a trial start and a paid purchase are the same entitlement to the app.
      store.pushUpdate(true);
      await pumpEventQueue();

      expect(c.read(entitlementProvider).isPro, isTrue);
      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider).canGenerate, isTrue);
    });

    test('an explicit refresh reaches premium even with nothing listening',
        () async {
      // The paywall configures the SDK itself, so a purchase can complete on a
      // store this app never managed to subscribe to at launch.
      final store = FakeStore(premium: false, connectFails: true);
      final c = makeContainer(store);
      await launch(c);
      expect(store.isListening, isFalse);

      store.connectFails = false;
      store.premium = true;
      await c.read(entitlementProvider.notifier).refresh();
      await pumpEventQueue();

      expect(c.read(accessProvider).isPremium, isTrue);
    });

    test('premium disables ads entirely — no request, no preload', () async {
      InterstitialAdService.resetForTest();
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await launch(c);

      store.pushUpdate(true);
      await pumpEventQueue();

      final premium = c.read(accessProvider).isPremium;
      expect(premium, isTrue);
      prepareBoundaryInterstitial(isPremium: premium);
      await showBoundaryInterstitial(isPremium: premium);
      await pumpEventQueue();

      expect(InterstitialAdService.loads, 0);
      expect(InterstitialAdService.attempts, 0);
    });

    test('premium is never spent from the free allowance', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await launch(c);

      for (var i = 0; i < 6; i++) {
        await c.read(accessProvider.notifier).consumeFreeGeneration();
      }
      expect(c.read(accessProvider).freeUsed, 0);
      expect(c.read(accessProvider).canGenerate, isTrue);
    });
  });

  group('5 — restart after purchase', () {
    test('is still premium, from the store rather than from disk', () async {
      // Nothing this app writes says "premium". A fresh container is a fresh
      // launch, and it comes back premium purely because the store says so.
      final relaunched = makeContainer(FakeStore(premium: true));
      final state = await launch(relaunched);

      expect(state.isPremium, isTrue);
      expect(state.premiumKnown, isTrue);
      expect(state.canGenerate, isTrue);
    });

    test('a subscriber reinstalling is never sold what they already own',
        () async {
      // The defect this pins. A reinstall clears local storage, so
      // onboardingSeen is false and the user looks brand new — while the store
      // takes a round-trip to say they are a subscriber.
      final c = makeContainer(
        FakeStore(premium: true, answerDelay: const Duration(milliseconds: 50)),
      );
      c.read(entitlementProvider);
      c.read(accessProvider);
      await pumpEventQueue();

      expect(c.read(accessProvider).onboardingSeen, isFalse,
          reason: 'a reinstall has no local flag');
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse,
          reason: 'and must still not be offered the trial');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpEventQueue();
      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });

    test('a premium user is not offered the paywall at all', () async {
      final c = makeContainer(FakeStore(premium: true));
      await launch(c);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });
  });

  group('6 — expiry and cancellation', () {
    test('returns the user to the free rules', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await launch(c);
      expect(c.read(accessProvider).canGenerate, isTrue);

      store.pushUpdate(false);
      await pumpEventQueue();

      final state = c.read(accessProvider);
      expect(state.isPremium, isFalse);
      expect(state.premiumKnown, isTrue);
      expect(state.loaded, isTrue);
      // A fresh install that subscribed immediately still has its allowance.
      expect(state.canGenerate, isTrue);
      expect(state.freeRemaining, AccessState.freeLimit);
    });

    test('an expired subscriber who had used their free runs stays blocked',
        () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await launch(c);
      for (var i = 0; i < AccessState.freeLimit; i++) {
        await c.read(accessProvider.notifier).consumeFreeGeneration();
      }
      store.pushUpdate(true);
      await pumpEventQueue();
      expect(c.read(accessProvider).canGenerate, isTrue);

      store.pushUpdate(false);
      await pumpEventQueue();

      expect(c.read(accessProvider).loaded, isTrue);
      expect(c.read(accessProvider).freeUsed, AccessState.freeLimit);
      expect(c.read(accessProvider).canGenerate, isFalse);
    });

    test('ads come back for a lapsed subscriber', () async {
      InterstitialAdService.resetForTest();
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await launch(c);

      store.pushUpdate(false);
      await pumpEventQueue();

      await showBoundaryInterstitial(
        isPremium: c.read(accessProvider).isPremium,
      );
      expect(InterstitialAdService.attempts, 1);
    });

    test('a store that cannot answer fails to free, never to premium',
        () async {
      final c = makeContainer(FakeStore(premium: true, connectFails: true));
      final state = await launch(c);

      expect(state.isPremium, isFalse);
      // Settled, so the app does not hang waiting for an answer that is not
      // coming — the user is offered the paywall and can still use the app.
      expect(state.premiumKnown, isTrue);
      expect(state.canGenerate, isTrue);
    });
  });
}
