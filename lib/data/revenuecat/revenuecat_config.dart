import 'package:flutter/foundation.dart';

/// The RevenueCat public SDK key this build uses, and the entitlement it
/// checks for Pro access.
///
/// **This app ships to Google Play only**, so there is exactly one key:
/// `goog_…`, supplied as `REVENUECAT_API_KEY_ANDROID`. There is deliberately
/// no `appl_…` key and no iOS branch — an App Store key would be dead weight
/// in a build that has no iOS target.
///
/// The same key is used in debug and release. Testing a real purchase against
/// Play is done with a **Play Console license tester** account, not with a
/// different key — Play decides sandbox-vs-real from the account, and
/// RevenueCat reports those as sandbox transactions either way.
///
/// A `test_…` key is deliberately not used anywhere: it is not a "debug
/// environment" key but a switch for RevenueCat's **Test Store**, a fully
/// simulated store that never contacts Google Play and returns an empty
/// offering — which is exactly why the paywall previously had nothing to
/// render in debug builds.
///
/// This is the SDK's *public* key — safe to compile into a client the same way
/// a Stripe publishable key is. RevenueCat's secret/server API key (used for
/// the REST API, webhooks, server-side reporting) never belongs here and this
/// app never needs it.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY_ANDROID',
  );

  /// The entitlement identifier configured in the RevenueCat dashboard that
  /// gates every Pro feature in this app. One entitlement, because there is
  /// only one product tier (Pro) behind two billing periods.
  static const String entitlementId = 'pro';

  /// The Google Play key, and only on Android. Anything else — a test run on
  /// the Dart VM, a desktop host — has no Play Billing underneath it, so it
  /// reports no key rather than configuring the SDK against a store that
  /// isn't there.
  static String get apiKey =>
      defaultTargetPlatform == TargetPlatform.android ? androidApiKey : '';

  /// False when the Play key hasn't been supplied, or this isn't Android.
  /// [RevenueCatService.ensureConfigured] checks this before touching the
  /// SDK, so a build without a key simply has no subscription capability
  /// rather than crashing on a blank API key.
  static bool get isConfigured => apiKey.isNotEmpty;
}
