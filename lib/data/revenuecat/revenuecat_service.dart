import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_config.dart';

/// Thin wrapper over the RevenueCat SDK — the one place this app talks to
/// [Purchases] directly, so [EntitlementController] deals in plain
/// [CustomerInfo] without repeating SDK plumbing.
class RevenueCatService {
  RevenueCatService._();

  static bool _configured = false;

  /// Configures the SDK once per process. Safe to call repeatedly from
  /// multiple places (the entitlement controller and the paywall
  /// both call this) — later calls are no-ops.
  ///
  /// Does nothing if this build has no Play key (see
  /// [RevenueCatConfig.isConfigured]): the app then simply has no
  /// subscription capability instead of crashing on a blank API key, the
  /// same fallback shape [ReplicateConfig.isConfigured] already uses for the
  /// enhance pipeline.
  static Future<void> ensureConfigured() async {
    if (_configured || !RevenueCatConfig.isConfigured) return;
    await Purchases.setLogLevel(
      kReleaseMode ? LogLevel.error : LogLevel.debug,
    );
    await Purchases.configure(PurchasesConfiguration(RevenueCatConfig.apiKey));
    _configured = true;
  }

  static bool get isReady => _configured;

  /// Guards every call below: an unconfigured SDK must fail as a plain,
  /// catchable Dart error here rather than reach the native SDK, which
  /// otherwise hits a hard `fatalError()` inside RevenueCat's own hybrid
  /// layer — a process abort that no Dart `try`/`catch` can stop.
  static void _requireConfigured() {
    if (!_configured) {
      throw StateError('RevenueCat is not configured for this build.');
    }
  }

  static Future<CustomerInfo> getCustomerInfo() {
    _requireConfigured();
    return Purchases.getCustomerInfo();
  }

  static Future<CustomerInfo> restorePurchases() {
    _requireConfigured();
    return Purchases.restorePurchases();
  }

  static void addCustomerInfoListener(CustomerInfoUpdateListener listener) {
    if (!_configured) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  static void removeCustomerInfoListener(CustomerInfoUpdateListener listener) {
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  /// Whether [info] carries the Pro entitlement right now. The single place
  /// "is this user Pro" is decided, so a purchase, a restore and a
  /// background renewal/expiry update all agree on the same rule.
  static bool isPro(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
}
