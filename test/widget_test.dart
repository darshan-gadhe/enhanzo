// Widget tests for the Enhanzo app shell after the Home-centric redesign.
//
// The app is now three tabs — Home / History / Settings — with every tool
// launched from Home's grid (there is no center FAB and no Tools tab), an
// empty-by-default History, and a Settings screen whose Appearance control is a
// single Dark Mode switch. These tests pin that surface.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_enhancer/main.dart';
import 'package:ai_enhancer/screens/legal_screen.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:ai_enhancer/widgets/demo_image.dart';

/// Boot the app on a phone-sized viewport (sheets and long lists need the full
/// height to be hit-testable).
Future<void> pumpPhoneApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: EnhanzoApp()));
  await tester.pump();
}

/// The app's single Riverpod container, read from the running tree.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Switch tabs and let the shell's keyed AnimatedSwitcher settle so the
/// outgoing screen has fully left the tree.
///
/// Taps by semantics label, not visible text: the floating-pill bottom nav
/// only renders a tab's [Text] label while it's active (an inactive tab is
/// icon-only), but every tab keeps a `Semantics(label: ...)` wrapper
/// regardless of selection state, so that's the stable target for both
/// finding and tapping an arbitrary tab.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // The theme and entitlement stores read SharedPreferences on launch; mock it
  // so those reads resolve to "nothing stored" cleanly instead of hitting the
  // missing plugin.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App boots to Home leading with the Most used grid', (
    tester,
  ) async {
    await pumpPhoneApp(tester);

    expect(find.text('Enhanzo'), findsOneWidget);
    expect(find.text('Most used'), findsOneWidget);
    // The four promoted tools head the grid.
    expect(find.text('AI Enhance'), findsWidgets);
    expect(find.text('HD Upscale'), findsWidgets);

    // Surfaces removed in the redesign are gone.
    expect(find.byIcon(Icons.add), findsNothing); // no center FAB
    expect(find.text('Tools'), findsNothing); // no Tools tab
    expect(find.text('Get Pro'), findsNothing); // no app-bar upgrade pill
  });

  testWidgets('Bottom nav is exactly Home / History / Settings', (
    tester,
  ) async {
    await pumpPhoneApp(tester);

    // The floating-pill nav only renders a tab's text label while it's
    // active (Home, on boot) — the other two are icon-only until selected.
    // Semantics labels are attached unconditionally, so they're what proves
    // all three tabs exist regardless of which one is currently active.
    expect(find.text('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('History'), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
  });

  testWidgets('Tapping a Home tool tile opens the crop step', (tester) async {
    await pumpPhoneApp(tester);

    await tester.tap(find.text('AI Enhance').first);
    await tester.pump();

    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('The crop step carries the upload control, not Home', (
    tester,
  ) async {
    await pumpPhoneApp(tester);

    // Home offers no upload of its own — the button lives one step in.
    expect(find.text('Upload a photo'), findsNothing);

    await tester.tap(find.text('AI Enhance').first);
    await tester.pump();

    // Nothing uploaded yet: the canvas is labelled as the tool's sample and
    // the upload button is the step's primary action.
    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('SAMPLE'), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
  });

  testWidgets('Uploading swaps the control to Change photo', (tester) async {
    await pumpPhoneApp(tester);
    await tester.tap(find.text('AI Enhance').first);
    await tester.pump();

    // Stands in for the picker, which is a platform channel. The file need not
    // exist: EditImage falls back to the tool art, which is the same path a
    // photo evicted from cache would take.
    containerOf(tester)
        .read(flowProvider.notifier)
        .setPhoto(File('photo.jpg'), aspect: 3 / 2);
    await tester.pump();

    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Upload a photo'), findsNothing);
    // The sample label goes with the sample.
    expect(find.text('SAMPLE'), findsNothing);
    // 'Free' now means the photo's own shape rather than the default frame.
    final state = containerOf(tester).read(flowProvider);
    expect(state.photoAspect, closeTo(3 / 2, 0.0001));
  });

  testWidgets('Full flow: tool tile → crop → processing → result → save', (
    tester,
  ) async {
    await pumpPhoneApp(tester);

    // A preset tool skips the picker entirely.
    await tester.tap(find.text('AI Enhance').first);
    await tester.pump();
    expect(find.text('Crop'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // settle transition

    // Straight into the determinate processing screen — never the picker.
    expect(find.text('Processing your photo'), findsOneWidget);
    expect(find.text('Choose a tool'), findsNothing);

    // Let simulated progress run to completion and hand off to the result.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Save to History'), findsOneWidget);

    // Saving records the edit and returns to Home.
    await tester.tap(find.text('Save to History'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Most used'), findsOneWidget); // back on Home

    // The saved edit now populates History.
    await openTab(tester, 'History');
    expect(find.text('1 edit'), findsOneWidget);
    expect(find.text('AI Enhance'), findsWidgets);
  });

  testWidgets('History: saved edits group into a grid; delete offers undo', (
    tester,
  ) async {
    await pumpPhoneApp(tester);

    // History seeds empty, so stage two edits directly through the controller.
    final history = containerOf(tester).read(historyProvider.notifier);
    history.add(tool: 'Restore Photo', badge: '4K', scene: DemoScene.portrait);
    history.add(tool: 'HD Upscale', badge: '8K', scene: DemoScene.landscape);

    await openTab(tester, 'History');
    expect(find.text('2 edits'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    // Open the newest entry's detail sheet and delete it.
    await tester.tap(find.text('HD Upscale'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump(); // pop sheet + raise undo snackbar
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1 edit'), findsOneWidget);
    expect(find.text('HD Upscale'), findsNothing);
  });

  testWidgets('Settings shows the redesigned rows and no removed controls', (
    tester,
  ) async {
    await pumpPhoneApp(tester);
    await openTab(tester, 'Settings');

    // Above the fold under the upgrade card.
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);

    // Controls removed in the redesign never appear.
    expect(find.text('Export Quality'), findsNothing);
    expect(find.text('Cloud Backup'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    // No account / login UI.
    expect(find.textContaining('@'), findsNothing);

    // The support and share rows sit below the fold — scroll them in.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      300,
      scrollable: list,
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Share App'),
      300,
      scrollable: list,
    );
    expect(find.text('Share App'), findsOneWidget);
  });

  testWidgets('Settings Dark Mode switch flips the app theme', (tester) async {
    await pumpPhoneApp(tester);
    final container = containerOf(tester);
    await openTab(tester, 'Settings');

    expect(container.read(themeModeProvider), ThemeMode.light);

    // Exactly one switch on the screen — Appearance's Dark Mode.
    final sw = find.byType(Switch);
    expect(sw, findsOneWidget);
    expect(tester.widget<Switch>(sw).value, isFalse);

    await tester.tap(sw);
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets(
    'Settings Privacy row opens the policy in the app',
    (tester) async {
      await pumpPhoneApp(tester);
      await openTab(tester, 'Settings');

      // Scroll a lower row fully into view; this lifts Privacy Policy up into
      // clear space above the bottom nav so the tap lands instead of hitting
      // the bar.
      await tester.scrollUntilVisible(
        find.text('Share App'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // The document is shown in-app rather than opened as a URL. It used to
      // launch `enhanzo.app/privacy`, which has nothing behind it — a row
      // whose only possible outcome was "Couldn't open that link right now."
      expect(find.byType(LegalScreen), findsOneWidget);
      // A distinctive line from the real policy text, proving the document is
      // actually rendered and not just an empty shell.
      expect(
        find.textContaining('Advertising Identifiers', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('Settings Terms row opens the terms in the app', (tester) async {
    await pumpPhoneApp(tester);
    await openTab(tester, 'Settings');

    await tester.scrollUntilVisible(
      find.text('Share App'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalScreen), findsOneWidget);
    expect(
      find.textContaining('SUBSCRIPTIONS AND PAYMENT', findRichText: true),
      findsOneWidget,
    );
  });
}
