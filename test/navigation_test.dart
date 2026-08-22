// Unit tests for the retreat logic behind the system back gesture.
//
// AppShell hosts the edit flow, the generator and the paywall in a Stack rather
// than on the Navigator, so nothing about back navigation is handled by the
// framework — `FlowController.back` and `GenerateController.back` *are* the
// back button. These tests pin their state machines directly, including the
// branch that depends on how the flow was entered.

import 'package:ai_enhancer/models/models.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:ai_enhancer/widgets/demo_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container that is disposed at the end of the test.
ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('FlowController.back — entered from a tool tile (tool preset)', () {
    test('crop is the first step, so back leaves the flow', () {
      final c = makeContainer();
      final flow = c.read(flowProvider.notifier);

      flow.pickTool('Unblur');
      expect(c.read(flowProvider).step, EditFlow.crop);
      expect(c.read(flowProvider).toolPreset, isTrue);

      flow.back();
      expect(c.read(flowProvider).step, isNull);
    });

    test('processing rewinds to crop, never to a picker never shown', () {
      final c = makeContainer();
      final flow = c.read(flowProvider.notifier);

      flow.pickTool('Unblur');
      flow.cropNext(); // preset tool skips the picker entirely
      expect(c.read(flowProvider).step, EditFlow.processing);

      flow.back();
      // The picker was never part of this path, so returning to it would be
      // inventing a step the user never saw.
      expect(c.read(flowProvider).step, EditFlow.crop);
      expect(c.read(flowProvider).progress, 0);
    });
  });

  group('FlowController.back — entered from the create action (no tool yet)', () {
    test('crop advances to the picker, and back returns to crop', () {
      final c = makeContainer();
      final flow = c.read(flowProvider.notifier);

      flow.startUpload();
      expect(c.read(flowProvider).toolPreset, isFalse);

      flow.cropNext();
      expect(c.read(flowProvider).step, EditFlow.tool);

      flow.back();
      expect(c.read(flowProvider).step, EditFlow.crop);
    });

    test('processing rewinds to the picker the user came through', () {
      final c = makeContainer();
      final flow = c.read(flowProvider.notifier);

      flow.startUpload();
      flow.cropNext();
      flow.chooseTool('Remove BG');
      expect(c.read(flowProvider).step, EditFlow.processing);

      flow.back();
      expect(c.read(flowProvider).step, EditFlow.tool);
    });

    test('back unwinds the whole flow one step at a time', () {
      final c = makeContainer();
      final flow = c.read(flowProvider.notifier);

      flow.startUpload();
      flow.cropNext();
      expect(c.read(flowProvider).step, EditFlow.tool);

      flow.back();
      expect(c.read(flowProvider).step, EditFlow.crop);

      flow.back();
      expect(c.read(flowProvider).step, isNull);
    });
  });

  test('back on a null step is a no-op rather than a crash', () {
    final c = makeContainer();
    expect(c.read(flowProvider).step, isNull);

    c.read(flowProvider.notifier).back();
    expect(c.read(flowProvider).step, isNull);
  });

  test('the crop ratio chosen is carried through the flow', () {
    final c = makeContainer();
    final flow = c.read(flowProvider.notifier);

    flow.pickTool('AI Enhance');
    // Defaults to the portrait frame the canvas has always used.
    expect(c.read(flowProvider).cropRatio, CropRatio.portrait);

    flow.setCropRatio(CropRatio.wide);
    flow.cropNext();

    // Still set once processing starts — the result frames itself with it.
    expect(c.read(flowProvider).cropRatio, CropRatio.wide);
    expect(CropRatio.wide.resolve(), closeTo(16 / 9, 0.0001));
  });

  test('CropRatio.free falls back to the canvas default rather than null', () {
    expect(CropRatio.free.value, isNull);
    expect(CropRatio.free.resolve(), CropRatio.portrait.value);
  });

  group('FlowState.displayRatio — what every canvas in the flow lays out with', () {
    test('a chosen frame wins over the photo\'s own shape', () {
      const state = FlowState(cropRatio: CropRatio.square, photoAspect: 3 / 2);
      expect(state.displayRatio, 1);
    });

    test('Free means the photo\'s own proportions when there is a photo', () {
      const state = FlowState(cropRatio: CropRatio.free, photoAspect: 3 / 2);
      expect(state.displayRatio, closeTo(3 / 2, 0.0001));
    });

    test('Free without a photo keeps the prototype\'s default frame', () {
      const state = FlowState(cropRatio: CropRatio.free);
      expect(state.displayRatio, CropRatio.portrait.value);
    });
  });


  group('HistoryController.restore — the undo behind a delete', () {
    // History seeds empty now, so each test first stages the entries it needs.
    // `add` prepends (newest first) with a unique id, which is exactly the
    // ordering and identity the restore logic depends on.
    List<HistoryEntry> seed(ProviderContainer c, int count) {
      final history = c.read(historyProvider.notifier);
      for (int i = 0; i < count; i++) {
        history.add(tool: 'Tool $i', badge: '4K', scene: DemoScene.flower);
      }
      return c.read(historyProvider);
    }

    test('puts the entry back at its original position', () {
      final c = makeContainer();
      final history = c.read(historyProvider.notifier);

      final before = seed(c, 4);
      expect(before.length, greaterThan(2));

      const index = 1;
      final removed = before[index];
      history.remove(removed.id);
      expect(c.read(historyProvider).any((e) => e.id == removed.id), isFalse);

      history.restore(removed, index);
      // Back in its own day group, not dropped at the top as if it were new.
      expect(c.read(historyProvider)[index].id, removed.id);
      expect(c.read(historyProvider).length, before.length);
    });

    test('restoring an entry that is already present changes nothing', () {
      final c = makeContainer();
      final history = c.read(historyProvider.notifier);
      seed(c, 3);
      final existing = c.read(historyProvider).first;

      history.restore(existing, 0);
      expect(
        c.read(historyProvider).where((e) => e.id == existing.id).length,
        1,
      );
    });

    test('an out-of-range index clamps instead of throwing', () {
      final c = makeContainer();
      final history = c.read(historyProvider.notifier);
      seed(c, 3);

      final entry = c.read(historyProvider).first;
      history.remove(entry.id);
      final length = c.read(historyProvider).length;

      // The list may have changed between the delete and the undo tap.
      history.restore(entry, 9999);
      expect(c.read(historyProvider).length, length + 1);
      expect(c.read(historyProvider).last.id, entry.id);
    });

    test('a newly added edit lands at the top of the list', () {
      final c = makeContainer();
      final history = c.read(historyProvider.notifier);
      final before = c.read(historyProvider).length;

      history.add(tool: 'Unblur', badge: '4K', scene: DemoScene.flower);

      expect(c.read(historyProvider).length, before + 1);
      expect(c.read(historyProvider).first.tool, 'Unblur');
    });
  });
}
