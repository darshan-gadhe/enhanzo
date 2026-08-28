// Settings must state a premium subscription plainly, and must do so without
// being told twice: the badge is a view of the entitlement, so it follows a
// purchase, a relaunch, and an expiry on its own.
//
// These drive the real widget tree — bottom nav, Settings tab, the header
// badge — with only the store faked.

import 'package:ai_enhancer/main.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

/// The status Settings shows an active subscriber.
final premiumBadge = find.text('✨ PREMIUM USER');

/// Boot the app on a phone-sized viewport with [store] standing in for
/// RevenueCat.
Future<void> pumpApp(WidgetTester tester, FakeStore store) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [entitlementSourceProvider.overrideWithValue(store)],
      child: const EnhanzoApp(),
    ),
  );
  await tester.pump();
}

/// Open the Settings tab and let the shell's switcher and the screen's
/// entrance animation settle.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  // Settings reads the stored theme on build; mock it so that resolves to
  // "nothing stored" instead of hitting the missing plugin.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a free user sees no premium status', (tester) async {
    await pumpApp(tester, FakeStore(premium: false));
    await openSettings(tester);

    expect(premiumBadge, findsNothing);
    // …and is still being sold to.
    expect(find.text('Unlock every AI tool'), findsOneWidget);
  });

  testWidgets('an active subscriber is shown as a Premium User', (
    tester,
  ) async {
    // A relaunch: the app knows nothing until the store answers, and this is
    // the whole of how premium survives a restart.
    await pumpApp(tester, FakeStore(premium: true));
    await openSettings(tester);

    expect(premiumBadge, findsOneWidget);
    expect(find.text('Your subscription is active'), findsOneWidget);
    expect(find.text('Unlock every AI tool'), findsNothing);
  });

  testWidgets('the status appears as soon as a purchase completes, with '
      'Settings already open', (tester) async {
    final store = FakeStore(premium: false);
    await pumpApp(tester, store);
    await openSettings(tester);
    expect(premiumBadge, findsNothing);

    // What RevenueCat reports when its paywall takes a payment.
    store.pushUpdate(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(premiumBadge, findsOneWidget);
  });

  testWidgets('refresh() reaches the badge, for the purchase no listener saw', (
    tester,
  ) async {
    // Configuring the store failed at startup, so nothing is subscribed —
    // pushUpdate would go nowhere. This is the path Settings takes after
    // RevenueCat's paywall reports a purchase.
    final store = FakeStore(premium: false, connectFails: true);
    await pumpApp(tester, store);
    await openSettings(tester);
    expect(store.isListening, isFalse);
    expect(premiumBadge, findsNothing);

    store.connectFails = false;
    store.premium = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(entitlementProvider.notifier).refresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(premiumBadge, findsOneWidget);
  });

  testWidgets('an expired subscription stops being shown as premium', (
    tester,
  ) async {
    final store = FakeStore(premium: true);
    await pumpApp(tester, store);
    await openSettings(tester);
    expect(premiumBadge, findsOneWidget);

    store.pushUpdate(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(premiumBadge, findsNothing);
    expect(find.text('Unlock every AI tool'), findsOneWidget);
  });
}
