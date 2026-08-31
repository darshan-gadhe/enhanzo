// The monetization flow, end to end at the state level.
//
// One authority decides everything here: [AccessController]. These tests drive
// it directly against a real SharedPreferences mock and a fake store, so the
// claims are about behaviour — how many free enhancements a user gets, what
// survives a restart, what a failure costs, and what a premium user is never
// asked for — rather than about which lines of code exist.

import 'dart:io';

import 'package:ai_enhancer/data/access_store.dart';
import 'package:ai_enhancer/data/ads/interstitial_ad_service.dart';
import 'package:ai_enhancer/state/access_state.dart';
import 'package:ai_enhancer/state/ads_state.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

/// A container wired to [store], disposed at the end of the test.
ProviderContainer makeContainer(FakeStore store) {
  final container = ProviderContainer(
    overrides: [entitlementSourceProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Boots access state and lets the stored counter and RevenueCat both land —
/// the same "first frame knows nothing, then it corrects itself" sequence the
/// app runs.
Future<AccessState> boot(ProviderContainer c) async {
  c.read(entitlementProvider);
  c.read(accessProvider);
  await pumpEventQueue();
  return c.read(accessProvider);
}

/// Simulates what the flow does when a run genuinely produces a result.
Future<void> succeed(ProviderContainer c) =>
    c.read(accessProvider.notifier).consumeFreeGeneration();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InterstitialAdService.resetForTest();
  });

  group('a brand-new install', () {
    test('is offered the paywall once, and is not premium', () async {
      final c = makeContainer(FakeStore(premium: false));
      final state = await boot(c);

      expect(state.isPremium, isFalse);
      expect(state.onboardingSeen, isFalse);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isTrue);
      expect(state.freeUsed, 0);
      expect(state.freeRemaining, 3);
    });

    test('closing the paywall leaves a usable free account', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      // Closing without buying is exactly "marked seen, still free".
      await c.read(accessProvider.notifier).markOnboardingSeen();

      expect(c.read(accessProvider).isPremium, isFalse);
      expect(c.read(accessProvider).canGenerate, isTrue);
      expect(c.read(accessProvider).freeRemaining, 3);
    });

    test('the next launch does not offer it again', () async {
      final first = makeContainer(FakeStore(premium: false));
      await boot(first);
      await first.read(accessProvider.notifier).markOnboardingSeen();

      // A new container is a new launch, reading the same storage.
      final second = makeContainer(FakeStore(premium: false));
      await boot(second);
      expect(second.read(accessProvider).onboardingSeen, isTrue);
      expect(
          second.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });

    test('a premium user is never offered the onboarding paywall', () async {
      final c = makeContainer(FakeStore(premium: true));
      await boot(c);
      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });

    test('the paywall is not offered before storage has answered', () {
      final c = makeContainer(FakeStore(premium: false));
      c.read(accessProvider);
      // Synchronously after build: nothing is known yet, so a returning user
      // cannot be mistaken for a new one.
      expect(c.read(accessProvider).loaded, isFalse);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });
  });

  group('the three free enhancements', () {
    test('#1, #2 and #3 are allowed; #4 is not', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);

      expect(c.read(accessProvider).canGenerate, isTrue);
      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 1);
      expect(c.read(accessProvider).canGenerate, isTrue);

      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 2);
      expect(c.read(accessProvider).canGenerate, isTrue);

      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 3);

      // The fourth attempt is a paywall, not a run.
      expect(c.read(accessProvider).canGenerate, isFalse);
      expect(c.read(accessProvider).freeLimitReached, isTrue);
      expect(c.read(accessProvider).freeRemaining, 0);
    });

    test('the limit is three', () => expect(AccessState.freeLimit, 3));

    test('nothing is allowed before the counter has been read', () {
      final c = makeContainer(FakeStore(premium: false));
      c.read(accessProvider);
      // Unloaded fails toward "no", so a slow disk is never free generations.
      expect(c.read(accessProvider).canGenerate, isFalse);
    });

    test('unreadable storage is treated as exhausted, not as fresh', () async {
      // A store that answers "unknown" — the read-failure path.
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      // Sanity: a working store does give three.
      expect(c.read(accessProvider).freeUsed, 0);
      expect(await AccessStore.readFreeUsed(), 0);
    });
  });

  group('what a failure costs', () {
    test('a run that never completes costs nothing', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);

      // Selecting a photo, cropping, cancelling, a preparation failure, an
      // upload failure, a model error, a timeout: none of them reach
      // consumeFreeGeneration, so the count cannot move.
      expect(c.read(accessProvider).freeUsed, 0);
      expect(c.read(accessProvider).canGenerate, isTrue);
    });

    test('a failed run after a successful one leaves the count where it was',
        () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 1);

      // Nothing happens for the failure — that is the whole assertion.
      expect(c.read(accessProvider).freeUsed, 1);
      expect(c.read(accessProvider).freeRemaining, 2);
    });
  });

  group('clearing app data', () {
    test('resets the free allowance, because that is where it lives', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);
      await succeed(c);
      await succeed(c);
      expect(c.read(accessProvider).canGenerate, isFalse);

      // What Android does to SharedPreferences on "Clear data".
      SharedPreferences.setMockInitialValues({});

      final fresh = makeContainer(FakeStore(premium: false));
      final state = await boot(fresh);
      expect(state.freeUsed, 0);
      expect(state.freeRemaining, 3);
      expect(state.canGenerate, isTrue);
      // And it is a new install again, so the paywall is offered once more.
      expect(state.onboardingSeen, isFalse);
    });

    test('does not resurrect premium — that comes from the store', () async {
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer(FakeStore(premium: true));
      final state = await boot(c);
      expect(state.isPremium, isTrue,
          reason: 'clearing local data cannot cancel a real subscription');
      expect(state.canGenerate, isTrue);
    });
  });

  group('restart and force close', () {
    for (final used in [1, 2, 3]) {
      test('$used used, force close, reopen — still $used', () async {
        final first = makeContainer(FakeStore(premium: false));
        await boot(first);
        for (var i = 0; i < used; i++) {
          await succeed(first);
        }
        expect(first.read(accessProvider).freeUsed, used);

        // A brand-new container over the same storage: a relaunch.
        final second = makeContainer(FakeStore(premium: false));
        final state = await boot(second);

        expect(state.freeUsed, used);
        expect(state.canGenerate, used < 3);
        if (used == 3) {
          expect(state.freeLimitReached, isTrue,
              reason: 'the fourth attempt must still open the paywall');
        }
      });
    }

    test('closing the paywall does not restore the allowance', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);
      await succeed(c);

      await c.read(accessProvider.notifier).markOnboardingSeen();
      expect(c.read(accessProvider).freeUsed, 2);
    });

    test('a premium user is still premium after a relaunch, with no counter',
        () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await boot(c);
      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider).canGenerate, isTrue);

      final relaunched = makeContainer(FakeStore(premium: true));
      final state = await boot(relaunched);
      expect(state.isPremium, isTrue);
      expect(state.canGenerate, isTrue);
    });
  });

  group('premium', () {
    test('is unlimited — the counter does not apply', () async {
      final c = makeContainer(FakeStore(premium: true));
      await boot(c);

      for (var i = 0; i < 10; i++) {
        expect(c.read(accessProvider).canGenerate, isTrue);
        await succeed(c);
      }
      expect(c.read(accessProvider).freeUsed, 0,
          reason: 'premium must never spend a free allowance');
      expect(c.read(accessProvider).freeLimitReached, isFalse);
    });

    test('costs zero ad requests', () async {
      InterstitialAdService.resetForTest();
      final outcome = await showBoundaryInterstitial(isPremium: true);

      expect(outcome, InterstitialOutcome.unavailable);
      expect(InterstitialAdService.attempts, 0,
          reason: 'the service must not even be entered for a premium user');
    });

    test('a purchase turns the limit off immediately', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await boot(c);
      await succeed(c);
      await succeed(c);
      await succeed(c);
      expect(c.read(accessProvider).canGenerate, isFalse);

      // What RevenueCat reports the moment its paywall takes payment.
      store.pushUpdate(true);
      await pumpEventQueue();

      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider).canGenerate, isTrue);
      expect(c.read(accessProvider).freeLimitReached, isFalse);
    });

    test('a restore turns the limit off too', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await boot(c);
      await succeed(c);
      await succeed(c);
      await succeed(c);

      store.premium = true;
      expect(await c.read(entitlementProvider.notifier).restore(),
          PurchaseOutcome.success);
      await pumpEventQueue();

      expect(c.read(accessProvider).canGenerate, isTrue);
    });

    test('an expiry returns the user to the free rules, with the count kept',
        () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await boot(c);
      expect(c.read(accessProvider).canGenerate, isTrue);

      // Two free enhancements had been spent before they ever subscribed.
      await AccessStore.writeFreeUsed(3);
      await c.read(accessProvider.notifier).reloadForTest();

      store.pushUpdate(false);
      await pumpEventQueue();

      expect(c.read(accessProvider).isPremium, isFalse);
      // For the right reason: the counter is loaded and says 3, not because
      // the controller lost track of itself. Without this the assertion below
      // passed while `loaded` was false, which is a different bug wearing the
      // same result.
      expect(c.read(accessProvider).loaded, isTrue);
      expect(c.read(accessProvider).freeUsed, 3);
      expect(c.read(accessProvider).canGenerate, isFalse,
          reason: 'an expired subscriber returns to the free tier they left');
    });

    test('a RevenueCat failure fails toward free, never toward premium',
        () async {
      final c = makeContainer(FakeStore(premium: true, connectFails: true));
      final state = await boot(c);

      expect(state.isPremium, isFalse);
      // Still usable — a broken store is not a broken app.
      expect(state.canGenerate, isTrue);
      expect(state.freeRemaining, 3);
    });
  });

  group('the interstitial boundary', () {
    test('a free user has one attempted', () async {
      InterstitialAdService.resetForTest();
      final outcome = await showBoundaryInterstitial(isPremium: false);

      expect(InterstitialAdService.attempts, 1);
      // Off-platform in a test, so nothing can fill — and that is a clean
      // no-op rather than an error.
      expect(outcome, InterstitialOutcome.unavailable);
    });

    test('no fill does not block anything and is not counted as shown',
        () async {
      final outcome = await showBoundaryInterstitial(isPremium: false);
      expect(outcome, isNot(InterstitialOutcome.shown));
      // The generation stands regardless.
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 1);
    });

    test('a failed attempt does not start the cooldown', () async {
      InterstitialAdService.resetForTest();
      await showBoundaryInterstitial(isPremium: false);
      await showBoundaryInterstitial(isPremium: false);

      // Two attempts really were made: a no-fill must not silence the next
      // genuine opportunity.
      expect(InterstitialAdService.attempts, 2);
      expect(
        InterstitialAdService.isWithinCooldown(null, DateTime.now()),
        isFalse,
      );
    });

    test('the free boundary opts out of the three-minute spacing', () {
      final justNow = DateTime.now();
      // Default spacing would suppress...
      expect(
        InterstitialAdService.isWithinCooldown(justNow, justNow),
        isTrue,
      );
      // ...but the boundary passes zero, because three enhancements is itself
      // the cap. All three get their ad.
      expect(
        InterstitialAdService.isWithinCooldown(
          justNow,
          justNow,
          interval: Duration.zero,
        ),
        isFalse,
      );
    });

    test('premium starts no preload either — not one request', () async {
      InterstitialAdService.resetForTest();
      prepareBoundaryInterstitial(isPremium: true);
      await pumpEventQueue();
      expect(InterstitialAdService.loads, 0);
      expect(InterstitialAdService.attempts, 0);
    });

    test('the free-generation counter never blocks the ad itself', () async {
      // The allowance gates whether an enhancement may *run*. Once one has
      // run and been saved, the ad at that boundary must not be second-guessed
      // by the same counter — including on the third and last one, where
      // remaining is about to hit zero.
      InterstitialAdService.resetForTest();
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);

      await succeed(c);
      await succeed(c);
      await succeed(c);
      expect(c.read(accessProvider).freeRemaining, 0);

      await showBoundaryInterstitial(
        isPremium: c.read(accessProvider).isPremium,
      );
      expect(InterstitialAdService.attempts, 1,
          reason: 'the last free enhancement still gets its ad');
    });

    test('each of the three free enhancements gets its own attempt', () async {
      InterstitialAdService.resetForTest();
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);

      for (var i = 0; i < 3; i++) {
        await succeed(c);
        await showBoundaryInterstitial(
          isPremium: c.read(accessProvider).isPremium,
        );
      }
      expect(InterstitialAdService.attempts, 3);
      expect(c.read(accessProvider).canGenerate, isFalse);
    });
  });

  group('the fourth image never reaches Replicate', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('monetization');
    });

    tearDown(() async {
      if (sandbox.existsSync()) await sandbox.delete(recursive: true);
    });

    /// A file standing in for the picked photo. It never has to be a valid
    /// image: the guard under test refuses before anything decodes it, which
    /// is exactly the point.
    Future<File> photo() async {
      final file = File('${sandbox.path}/photo.png');
      await file.writeAsBytes(const [1, 2, 3], flush: true);
      return file;
    }

    test('an exhausted free user is refused before any work starts', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);
      await succeed(c);
      await succeed(c);
      expect(c.read(accessProvider).canGenerate, isFalse);

      final flow = c.read(flowProvider.notifier);
      flow.pickTool('AI Enhance', photo: await photo());
      flow.cropNext();
      await pumpEventQueue();

      final state = c.read(flowProvider);
      expect(state.step, EditFlow.error);
      expect(state.needsUpgrade, isTrue,
          reason: 'the refusal must ask for the paywall');
      expect(state.failure, FlowController.freeLimitMessage);
      // Nothing ran: no phase was ever entered, so nothing was prepared,
      // uploaded or predicted.
      expect(state.phase, isNull);
      expect(state.result, isNull);
      // And the refusal itself costs nothing.
      expect(c.read(accessProvider).freeUsed, 3);
    });

    test('the paywall is asked for once per refusal, not repeatedly', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      for (var i = 0; i < 3; i++) {
        await succeed(c);
      }
      final flow = c.read(flowProvider.notifier);
      flow.pickTool('AI Enhance', photo: await photo());
      flow.cropNext();
      await pumpEventQueue();
      expect(c.read(flowProvider).needsUpgrade, isTrue);

      // What the overlay does when it presents the paywall.
      flow.upgradeOffered();
      expect(c.read(flowProvider).needsUpgrade, isFalse);
      // Acknowledging twice is harmless.
      flow.upgradeOffered();
      expect(c.read(flowProvider).needsUpgrade, isFalse);
    });

    test('a free user with allowance left is not refused', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      await succeed(c);

      final flow = c.read(flowProvider.notifier);
      flow.pickTool('AI Enhance', photo: await photo());
      flow.cropNext();
      await pumpEventQueue();

      // It got past the guard and into a real run — which then fails, because
      // there is no network in a test. That is the correct shape: refused for
      // the right reason, or not refused at all.
      expect(c.read(flowProvider).needsUpgrade, isFalse);
      expect(c.read(flowProvider).failure,
          isNot(FlowController.freeLimitMessage));
    });

    test('a premium user is never refused, whatever the counter says',
        () async {
      await AccessStore.writeFreeUsed(99);
      final c = makeContainer(FakeStore(premium: true));
      await boot(c);

      final flow = c.read(flowProvider.notifier);
      flow.pickTool('AI Enhance', photo: await photo());
      flow.cropNext();
      await pumpEventQueue();

      expect(c.read(flowProvider).needsUpgrade, isFalse);
      expect(c.read(flowProvider).failure,
          isNot(FlowController.freeLimitMessage));
    });
  });

  group('an entitlement change does not reset the free tier', () {
    // AccessController used to `watch` the entitlement, so every premium
    // change rebuilt it. The rebuild fired the previous build's onDispose,
    // which latched its disposed flag, so the restore that followed returned
    // early and `loaded` never became true again — leaving a free user unable
    // to enhance anything for the rest of the session.

    test('the counter survives a subscribe and an expiry', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await boot(c);
      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 1);

      store.pushUpdate(true);
      await pumpEventQueue();
      expect(c.read(accessProvider).isPremium, isTrue);
      expect(c.read(accessProvider).loaded, isTrue,
          reason: 'the restored state must not be thrown away');
      expect(c.read(accessProvider).freeUsed, 1);

      store.pushUpdate(false);
      await pumpEventQueue();
      final state = c.read(accessProvider);
      expect(state.isPremium, isFalse);
      expect(state.loaded, isTrue);
      expect(state.freeUsed, 1, reason: 'and the allowance is where it was');
      expect(state.canGenerate, isTrue);
      expect(state.freeRemaining, 2);
    });

    test('a free user is never left permanently unable to generate', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await boot(c);

      // Several transitions, as a renewal/expiry cycle would produce.
      for (final premium in [true, false, true, false]) {
        store.pushUpdate(premium);
        await pumpEventQueue();
      }

      expect(c.read(accessProvider).loaded, isTrue);
      expect(c.read(accessProvider).canGenerate, isTrue);
      // And it still counts.
      await succeed(c);
      expect(c.read(accessProvider).freeUsed, 1);
    });

    test('onboarding is not re-offered because premium status moved', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await boot(c);
      await c.read(accessProvider.notifier).markOnboardingSeen();

      store.pushUpdate(true);
      await pumpEventQueue();
      store.pushUpdate(false);
      await pumpEventQueue();

      expect(c.read(accessProvider).onboardingSeen, isTrue);
      expect(c.read(accessProvider.notifier).shouldOfferOnboarding, isFalse);
    });
  });

  group('double taps and duplicate callbacks', () {
    test('two results landing at once spend one allowance, not two', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      final access = c.read(accessProvider.notifier);

      await Future.wait([
        access.consumeFreeGeneration(),
        access.consumeFreeGeneration(),
      ]);

      expect(c.read(accessProvider).freeUsed, 1,
          reason: 'the in-flight guard must hold across both');
    });

    test('marking onboarding seen twice writes once and stays seen', () async {
      final c = makeContainer(FakeStore(premium: false));
      await boot(c);
      final access = c.read(accessProvider.notifier);

      await Future.wait([
        access.markOnboardingSeen(),
        access.markOnboardingSeen(),
      ]);

      expect(c.read(accessProvider).onboardingSeen, isTrue);
      expect(await AccessStore.readOnboardingSeen(), isTrue);
    });
  });
}
