import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../data/revenuecat/revenuecat_service.dart';

export 'package:purchases_ui_flutter/purchases_ui_flutter.dart'
    show PaywallResult;

/// RevenueCat's own hosted paywall — the single place this app asks to be
/// paid.
///
/// There is deliberately no in-app paywall UI any more. The layout, copy,
/// pricing, trial wording and A/B tests all live in the RevenueCat dashboard
/// and reach the app over the air, so changing the offer no longer means
/// shipping a build.
///
/// **This requires a paywall to be designed and published for the current
/// offering in the RevenueCat dashboard.** Without one the native SDK has
/// nothing to draw and returns [PaywallResult.error]; that is reported to the
/// caller rather than swallowed, so a missing configuration surfaces instead
/// of looking like a dead button.
///
/// A completed purchase needs no handling here: [EntitlementController]
/// listens to RevenueCat's `CustomerInfo` stream, so Pro status updates
/// itself however the purchase happened.
Future<PaywallResult> showPaywall() async {
  await RevenueCatService.ensureConfigured();
  // No key for this build mode — presenting would reach an unconfigured
  // native SDK, the same crash [RevenueCatService] guards every other call
  // against.
  if (!RevenueCatService.isReady) return PaywallResult.error;

  try {
    return await RevenueCatUI.presentPaywall(displayCloseButton: true);
  } catch (_) {
    // A platform channel failure (no SDK on this platform, no paywall
    // published) is a reportable outcome, not a crash.
    return PaywallResult.error;
  }
}

/// RevenueCat's Customer Center — where an existing subscriber manages or
/// cancels their plan.
///
/// Shown instead of the paywall once the user is Pro: presenting a purchase
/// screen to someone who has already bought is the wrong door, and this is
/// the RevenueCat-native replacement for the old "Manage Subscription" link.
Future<void> showCustomerCenter() async {
  await RevenueCatService.ensureConfigured();
  if (!RevenueCatService.isReady) return;
  try {
    await RevenueCatUI.presentCustomerCenter();
  } catch (_) {
    // Nothing to fall back to, and nothing was charged — staying put is the
    // honest outcome.
  }
}
