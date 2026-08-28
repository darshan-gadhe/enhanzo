import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';

/// Called whenever the store reports a change in what the user owns.
typedef PremiumListener = void Function(bool isPremium);

/// The subscription system of record, reduced to the four questions this app
/// actually asks it.
///
/// [EntitlementController] used to call [RevenueCatService]'s statics directly,
/// which made premium state impossible to test: every path ran through the
/// native SDK, and the only currency was [CustomerInfo] — a plugin type with no
/// public constructor. This interface deals in a plain `bool` instead, so the
/// controller's behaviour (purchase updates it, a relaunch re-reads it, a
/// failure leaves it not-premium) can be pinned without a store.
///
/// Deliberately not a cache. Nothing here writes premium status anywhere: every
/// answer comes from RevenueCat, which is itself backed by Play Billing, so the
/// app cannot grant itself a subscription it does not own.
abstract class EntitlementSource {
  /// Prepares the store SDK. Idempotent — safe to call before every read.
  Future<void> connect();

  /// True once [connect] has reached a usable SDK. False when this build has
  /// no store key, or when configuring it failed.
  bool get isReady;

  /// Whether the store account owns premium right now.
  Future<bool> readIsPremium();

  /// Re-links purchases made by this store account on another install.
  /// Returns what the account owns afterwards.
  Future<bool> restore();

  /// Subscribes to store-side changes: a renewal, an expiry, a cancellation, a
  /// refund, or a purchase completed inside RevenueCat's own paywall. Replaces
  /// any previous subscription.
  void listen(PremiumListener onChange);

  /// Unsubscribes. Safe to call when nothing is subscribed.
  void stopListening();
}

/// The real implementation — RevenueCat, with Play Billing underneath it.
///
/// A thin adapter: the entitlement rule itself stays in
/// [RevenueCatService.isPro], so the listener, the first read and a restore all
/// still decide "is this user premium" the same single way.
class RevenueCatEntitlementSource implements EntitlementSource {
  void Function(CustomerInfo)? _bridge;

  @override
  Future<void> connect() => RevenueCatService.ensureConfigured();

  @override
  bool get isReady => RevenueCatService.isReady;

  @override
  Future<bool> readIsPremium() async =>
      RevenueCatService.isPro(await RevenueCatService.getCustomerInfo());

  @override
  Future<bool> restore() async =>
      RevenueCatService.isPro(await RevenueCatService.restorePurchases());

  @override
  void listen(PremiumListener onChange) {
    stopListening();
    // Registering against an unconfigured SDK is silently dropped by
    // [RevenueCatService], which would leave this holding a bridge that was
    // never actually subscribed — and the controller believing it was.
    if (!isReady) return;
    void bridge(CustomerInfo info) => onChange(RevenueCatService.isPro(info));
    _bridge = bridge;
    RevenueCatService.addCustomerInfoListener(bridge);
  }

  @override
  void stopListening() {
    final bridge = _bridge;
    if (bridge == null) return;
    _bridge = null;
    RevenueCatService.removeCustomerInfoListener(bridge);
  }
}
