// Regression test for the History tab's first-run state.
//
// The empty state centres a column that contains a LayoutBuilder (the fanned
// preview). Any ancestor that sizes itself from the child's *intrinsic* height
// — SliverFillRemaining(hasScrollBody: false), IntrinsicHeight — makes that
// LayoutBuilder throw during layout, which leaves the sliver's geometry null
// and cascades into "Null check operator used on a null value" on every
// subsequent paint. Nothing in the widget tree looks wrong, so this pins it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_enhancer/main.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:ai_enhancer/widgets/demo_image.dart';

Future<void> pumpHistoryTab(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: EnhanzoApp()));
  await tester.pump();
  // By semantics label, not visible text: the floating-pill bottom nav only
  // renders a tab's Text label while active, but every tab keeps its
  // Semantics(label: ...) wrapper regardless of selection state.
  await tester.tap(find.bySemanticsLabel('History'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('empty History renders without a layout exception', (
    tester,
  ) async {
    await pumpHistoryTab(tester, const Size(1170, 2532));

    expect(find.text('No edits yet'), findsOneWidget);
    expect(find.text('Start an edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty History survives a short viewport and large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // A small phone in landscape — the shortest realistic viewport, where the
    // centred column has to start scrolling instead of overflowing.
    await pumpHistoryTab(tester, const Size(1334, 750));

    expect(find.text('No edits yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first saved edit replaces the empty state with the grid', (
    tester,
  ) async {
    await pumpHistoryTab(tester, const Size(1170, 2532));
    expect(find.text('No edits yet'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container
        .read(historyProvider.notifier)
        .add(tool: 'Unblur', badge: '4K', scene: DemoScene.flower);
    await tester.pump();

    expect(find.text('No edits yet'), findsNothing);
    expect(find.text('1 edit'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
