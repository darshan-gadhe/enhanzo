import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';

/// Reports what Google Play is actually offering, in debug builds only.
///
/// The app draws no paywall of its own: the trial badge, the price and the
/// button all come from RevenueCat's hosted paywall, which reads them from
/// Play. So "the paywall shows a 3-day free trial at the right price" is not a
/// claim this codebase can make or check — it is a fact about the offering.
///
/// What it *can* do is say what the offering contains, which is the only way to
/// tell a paywall that is configured wrong from one that is faithfully showing
/// what Play gave it.
///
/// **The trap this exists for.** A free trial on Google Play arrives as a
/// [SubscriptionOption.freePhase]. It does **not** arrive as
/// `StoreProduct.introductoryPrice`, which is StoreKit-only and is always null
/// on Android. Reading the wrong one makes a correctly configured trial look
/// absent, which is exactly how this app once concluded there was no trial
/// when Play had one all along.
class OfferingDiagnostics {
  OfferingDiagnostics._();

  /// Dumps the current offering. No-op in release, and never throws.
  static Future<void> log() async {
    if (kReleaseMode) return;
    if (!RevenueCatService.isReady) {
      debugPrint('RevenueCat offering: SDK not configured — nothing to read.');
      return;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        debugPrint(
          'RevenueCat offering: none current. The hosted paywall has nothing '
          'to draw, so it will report an error rather than appear. Set a '
          'current offering in the RevenueCat dashboard.',
        );
        return;
      }

      debugPrint(
        'RevenueCat offering "${current.identifier}": '
        '${current.availablePackages.length} package(s)',
      );

      for (final package in current.availablePackages) {
        final product = package.storeProduct;
        final options =
            product.subscriptionOptions ?? const <SubscriptionOption>[];
        final withTrial = [
          for (final option in options)
            if (option.freePhase != null) option,
        ];

        debugPrint(
          '  • ${package.identifier} — ${product.identifier} '
          '@ ${product.priceString}',
        );

        if (withTrial.isEmpty) {
          debugPrint(
            '      no free trial on any subscription option. If Play Console '
            'has one configured, the offer is probably not attached to this '
            'base plan, or the package points at a different base plan.',
          );
        } else {
          for (final option in withTrial) {
            final free = option.freePhase!;
            final paid = option.fullPricePhase;
            debugPrint(
              '      FREE TRIAL ${free.billingPeriod?.iso8601 ?? '?'} '
              'then ${paid?.price.formatted ?? product.priceString} '
              'per ${paid?.billingPeriod?.iso8601 ?? '?'} '
              '[option ${option.id}]',
            );
          }
        }

        // The StoreKit-only field, printed so the difference is visible rather
        // than something to remember.
        debugPrint(
          '      introductoryPrice (iOS-only, always null here): '
          '${product.introductoryPrice}',
        );
      }
    } catch (error) {
      debugPrint('RevenueCat offering: could not be read — $error');
    }
  }
}
