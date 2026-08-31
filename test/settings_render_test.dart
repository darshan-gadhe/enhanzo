// Does the settings step actually draw?
//
// The state machine is covered elsewhere. This boots the real app and walks a
// mask tool to the settings step, because a step that is wired but never
// rendered is a step that does not exist.

import 'package:ai_enhancer/main.dart';
import 'package:ai_enhancer/models/tool_options.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:ai_enhancer/widgets/mask_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

Future<ProviderContainer> pumpApp(WidgetTester tester,
    {bool premium = false}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entitlementSourceProvider
            .overrideWithValue(FakeStore(premium: premium)),
      ],
      child: const EnhanzoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// Drives the flow to the settings step for [tool] without a real photo —
/// the step must render for the simulated pipeline too.
Future<void> openSettings(
  WidgetTester tester,
  ProviderContainer c,
  String tool,
) async {
  c.read(flowProvider.notifier).pickTool(tool);
  c.read(flowProvider.notifier).cropNext();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a mask tool renders the brush canvas and its hint',
      (tester) async {
    final c = await pumpApp(tester, premium: true);
    await openSettings(tester, c, 'Magic Eraser');

    expect(c.read(flowProvider).step, EditFlow.settings);
    expect(find.byType(MaskCanvas), findsOneWidget);
    expect(find.textContaining('Paint over'), findsOneWidget);
    expect(find.text('Magic Eraser'), findsWidgets);
    // The brush controls have to be reachable, not just present.
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('painting enables Next, and clearing disables it again',
      (tester) async {
    final c = await pumpApp(tester, premium: true);
    await openSettings(tester, c, 'Object Removal');
    final flow = c.read(flowProvider.notifier);

    expect(flow.settingsComplete, isFalse);

    // A drag across the canvas is what a user does.
    await tester.drag(find.byType(MaskCanvas), const Offset(60, 60));
    await tester.pump();

    expect(c.read(flowProvider).options.hasMask, isTrue,
        reason: 'the drag must reach the canvas, not something above it');
    expect(flow.settingsComplete, isTrue);
  });

  testWidgets('a prompt tool renders a text field and gates on it',
      (tester) async {
    final c = await pumpApp(tester, premium: true);
    await openSettings(tester, c, 'AI Expand');

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Right'), findsOneWidget);

    final flow = c.read(flowProvider.notifier);
    expect(flow.settingsComplete, isFalse);

    await tester.enterText(find.byType(TextField), 'more blue sky');
    await tester.pump();
    expect(flow.settingsComplete, isFalse, reason: 'no direction chosen yet');

    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(c.read(flowProvider).options.expansion.left, greaterThan(0));
    expect(flow.settingsComplete, isTrue);
  });

  testWidgets('Replace BG offers the background choices', (tester) async {
    final c = await pumpApp(tester, premium: true);
    await openSettings(tester, c, 'Replace BG');

    for (final style in BackgroundStyle.values) {
      expect(find.text(style.label), findsOneWidget, reason: style.label);
    }
    expect(find.byType(MaskCanvas), findsNothing,
        reason: 'nothing to paint here');

    await tester.tap(find.text('White'));
    await tester.pump();
    expect(c.read(flowProvider).options.background, BackgroundStyle.white);
  });

  testWidgets('an enhance tool never shows the step at all', (tester) async {
    final c = await pumpApp(tester, premium: true);
    await openSettings(tester, c, 'AI Enhance');

    expect(c.read(flowProvider).step, isNot(EditFlow.settings));
    expect(find.byType(MaskCanvas), findsNothing);
  });
}
