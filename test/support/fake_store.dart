// A stand-in for RevenueCat + Play Billing, shared by the entitlement unit
// tests and the Settings widget tests.
//
// The store owns the answer; the app only ever reads it. Nothing here writes
// premium status anywhere the app could later trust on its own.

import 'package:ai_enhancer/data/revenuecat/entitlement_source.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store whose answer the test controls.
class FakeStore implements EntitlementSource {
  /// What the store account owns. A "purchase" is a write to this.
  bool premium;

  /// Makes [connect] throw, standing in for a native init failure — the case
  /// that leaves the SDK unwatched and used to strand a paying user on free.
  bool connectFails;

  /// Makes [readIsPremium] and [restore] throw.
  bool readFails;

  /// How long the store takes to answer.
  ///
  /// Real RevenueCat is a network round-trip while local storage is a disk
  /// read, and the gap between them is where a reinstalling subscriber used to
  /// look like a brand-new user. Tests that care about that ordering set this.
  Duration answerDelay;

  /// Whether [connect] has succeeded. The controller keys its subscription
  /// off this, exactly as the RevenueCat implementation does.
  bool _ready = false;

  int connectCalls = 0;
  int readCalls = 0;
  int restoreCalls = 0;
  PremiumListener? _listener;

  FakeStore({
    this.premium = false,
    this.connectFails = false,
    this.readFails = false,
    this.answerDelay = Duration.zero,
  });

  bool get isListening => _listener != null;

  /// What a store-side change looks like: a renewal, an expiry, or a purchase
  /// completed inside RevenueCat's own paywall.
  void pushUpdate(bool isPremium) {
    premium = isPremium;
    _listener?.call(isPremium);
  }

  @override
  Future<void> connect() async {
    connectCalls++;
    if (answerDelay > Duration.zero) await Future<void>.delayed(answerDelay);
    if (connectFails) throw StateError('native init failed');
    _ready = true;
  }

  @override
  bool get isReady => _ready;

  @override
  Future<bool> readIsPremium() async {
    readCalls++;
    if (answerDelay > Duration.zero) await Future<void>.delayed(answerDelay);
    // Mirrors RevenueCatService: calling an unconfigured store is an error,
    // not a "false".
    if (!_ready) throw StateError('not configured');
    if (readFails) throw StateError('no answer');
    return premium;
  }

  @override
  Future<bool> restore() async {
    restoreCalls++;
    if (!_ready) throw StateError('not configured');
    if (readFails) throw StateError('no answer');
    return premium;
  }

  @override
  void listen(PremiumListener onChange) {
    if (!_ready) return;
    _listener = onChange;
  }

  @override
  void stopListening() => _listener = null;
}

/// A container wired to [store], disposed at the end of the test.
ProviderContainer makeContainer(FakeStore store) {
  final container = ProviderContainer(
    overrides: [entitlementSourceProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}
