// Tests for premium state: how it is picked up after a purchase, how it
// survives a relaunch, and which way it fails when the store cannot answer.
//
// [EntitlementController] talks to an [EntitlementSource] rather than to
// RevenueCat's statics, so all of that is exercisable here against the
// [FakeStore] in test/support — no store, no Play Billing, no native SDK.

import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_store.dart';

/// Reads the provider and lets its non-awaited startup read settle — the same
/// "first frame is free, then it corrects itself" sequence the app runs.
Future<Entitlement> settle(ProviderContainer c) async {
  c.read(entitlementProvider);
  await pumpEventQueue();
  return c.read(entitlementProvider);
}

void main() {
  group('launch', () {
    test('a non-subscriber stays on the free tier', () async {
      final store = FakeStore(premium: false);
      expect((await settle(makeContainer(store))).isPro, isFalse);
    });

    test('premium is restored from the store on relaunch, not from disk', () async {
      // Nothing this app writes says "premium". A fresh container is a fresh
      // launch, and it comes back premium purely because the store says so.
      final store = FakeStore(premium: true);
      final relaunched = await settle(makeContainer(store));

      expect(relaunched.isPro, isTrue);
      expect(store.readCalls, 1);
    });

    test('the first frame is not-premium, before the store has answered', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);

      // Read without pumping: build() does not await the store.
      expect(c.read(entitlementProvider).isPro, isFalse);
      await pumpEventQueue();
      expect(c.read(entitlementProvider).isPro, isTrue);
    });
  });

  group('after a purchase', () {
    test('a store update flips premium on immediately', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await settle(c);
      expect(store.isListening, isTrue);

      store.pushUpdate(true);
      expect(c.read(entitlementProvider).isPro, isTrue);
    });

    test('refresh picks the purchase up even when nothing was listening', () async {
      // The case that matters: configuring the store failed at startup, so no
      // listener was ever registered. RevenueCat's paywall configures the SDK
      // itself, so a purchase there would complete into silence. Settings
      // calls refresh() on the way out, which must both re-subscribe and
      // re-read.
      final store = FakeStore(premium: false, connectFails: true);
      final c = makeContainer(store);
      await settle(c);

      expect(store.isListening, isFalse);
      expect(c.read(entitlementProvider).isPro, isFalse);

      // The paywall's own configure call succeeds, and the user buys.
      store.connectFails = false;
      store.premium = true;

      await c.read(entitlementProvider.notifier).refresh();

      expect(c.read(entitlementProvider).isPro, isTrue);
      expect(store.isListening, isTrue,
          reason: 'refresh must also repair the missing subscription');
    });

    test('refresh does not re-subscribe once it already is', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await settle(c);
      expect(store.connectCalls, 1);

      await c.read(entitlementProvider.notifier).refresh();
      expect(store.connectCalls, 1);
      expect(store.readCalls, 2);
    });

    test('an expiry reported by the store takes premium away again', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await settle(c);
      expect(c.read(entitlementProvider).isPro, isTrue);

      store.pushUpdate(false);
      expect(c.read(entitlementProvider).isPro, isFalse);
    });
  });

  group('when the store cannot answer', () {
    test('a failed connect leaves the user not-premium, never premium', () async {
      final store = FakeStore(premium: true, connectFails: true);
      expect((await settle(makeContainer(store))).isPro, isFalse);
    });

    test('a failed read leaves the last known state alone', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await settle(c);
      expect(c.read(entitlementProvider).isPro, isTrue);

      store.readFails = true;
      await c.read(entitlementProvider.notifier).refresh();

      expect(c.read(entitlementProvider).isPro, isTrue,
          reason: 'a store that cannot answer must not revoke a real purchase');
    });

    test('refresh never throws', () async {
      final store = FakeStore(connectFails: true, readFails: true);
      final c = makeContainer(store);
      await expectLater(
        c.read(entitlementProvider.notifier).refresh(),
        completes,
      );
    });
  });

  group('restore', () {
    test('a found subscription reports success and turns premium on', () async {
      final store = FakeStore(premium: true);
      final c = makeContainer(store);
      await settle(c);
      // Simulate the reinstall case: the app itself knows nothing yet.
      store.pushUpdate(false);
      store.premium = true;

      final outcome = await c.read(entitlementProvider.notifier).restore();

      expect(outcome, PurchaseOutcome.success);
      expect(c.read(entitlementProvider).isPro, isTrue);
      expect(c.read(entitlementProvider).restoring, isFalse);
    });

    test('nothing to restore reports noneFound and stays free', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await settle(c);

      expect(await c.read(entitlementProvider.notifier).restore(),
          PurchaseOutcome.noneFound);
      expect(c.read(entitlementProvider).isPro, isFalse);
    });

    test('a store failure reports failed and clears the in-flight flag', () async {
      final store = FakeStore(premium: false, readFails: true);
      final c = makeContainer(store);
      await settle(c);

      expect(await c.read(entitlementProvider.notifier).restore(),
          PurchaseOutcome.failed);
      expect(c.read(entitlementProvider).restoring, isFalse);
    });

    test('a second restore while one is in flight is rejected as busy', () async {
      final store = FakeStore(premium: false);
      final c = makeContainer(store);
      await settle(c);

      final first = c.read(entitlementProvider.notifier).restore();
      expect(c.read(entitlementProvider).restoring, isTrue);
      expect(await c.read(entitlementProvider.notifier).restore(),
          PurchaseOutcome.busy);

      await first;
      expect(store.restoreCalls, 1);
    });

    test('restore works even if the store was never connected at startup', () async {
      final store = FakeStore(premium: true, connectFails: true);
      final c = makeContainer(store);
      await settle(c);
      expect(c.read(entitlementProvider).isPro, isFalse);

      store.connectFails = false;
      expect(await c.read(entitlementProvider.notifier).restore(),
          PurchaseOutcome.success);
      expect(c.read(entitlementProvider).isPro, isTrue);
    });
  });

  test('disposing the container unsubscribes from the store', () async {
    final store = FakeStore();
    final c = ProviderContainer(
      overrides: [entitlementSourceProvider.overrideWithValue(store)],
    );
    c.read(entitlementProvider);
    await pumpEventQueue();
    expect(store.isListening, isTrue);

    c.dispose();
    expect(store.isListening, isFalse);
  });
}
