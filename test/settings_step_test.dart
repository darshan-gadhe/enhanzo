// The settings step — where a tool collects the mask, prompt, background or
// direction it needs before it can run.
//
// Driven at the controller level, because what matters is the state machine:
// which tools stop for input, what counts as ready, what survives a step back,
// and what must not survive into the next edit.

import 'dart:io';

import 'package:ai_enhancer/models/tool_options.dart';
import 'package:ai_enhancer/state/access_state.dart';
import 'package:ai_enhancer/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_store.dart';

ProviderContainer makeContainer(FakeStore store) {
  final c = ProviderContainer(
    overrides: [entitlementSourceProvider.overrideWithValue(store)],
  );
  addTearDown(c.dispose);
  return c;
}

Future<ProviderContainer> booted({bool premium = false}) async {
  final c = makeContainer(FakeStore(premium: premium));
  c.read(entitlementProvider);
  c.read(accessProvider);
  await pumpEventQueue();
  return c;
}

/// A stroke covering the middle of the frame.
final aMask = ToolOptions(
  strokes: [
    MaskStroke(points: const [Offset(0.4, 0.4), Offset(0.6, 0.6)], radius: 0.1),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late File photo;
  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('settings');
    photo = File('${dir.path}/p.png')..writeAsBytesSync(const [1, 2, 3]);
  });

  group('which tools stop for input', () {
    test('an enhance tool goes straight to processing', () async {
      final c = await booted();
      final flow = c.read(flowProvider.notifier);
      flow.pickTool('AI Enhance', photo: photo);
      flow.cropNext();
      expect(c.read(flowProvider).step, isNot(EditFlow.settings));
    });

    for (final tool in const [
      'Object Removal',
      'Remove People',
      'Watermark Remove',
      'Magic Eraser',
      'Inpainting',
      'AI Expand',
      'Replace BG',
    ]) {
      test('$tool stops at settings', () async {
        final c = await booted();
        final flow = c.read(flowProvider.notifier);
        flow.pickTool(tool, photo: photo);
        flow.cropNext();
        expect(c.read(flowProvider).step, EditFlow.settings);
      });
    }
  });

  group('what counts as ready', () {
    Future<FlowController> at(String tool) async {
      final c = await booted();
      final flow = c.read(flowProvider.notifier);
      flow.pickTool(tool, photo: photo);
      flow.cropNext();
      return flow;
    }

    test('a mask tool needs a mask', () async {
      final flow = await at('Magic Eraser');
      expect(flow.settingsComplete, isFalse);
      flow.setOptions(aMask);
      expect(flow.settingsComplete, isTrue);
    });

    test('inpainting needs both, and says no to either alone', () async {
      final flow = await at('Inpainting');
      expect(flow.settingsComplete, isFalse);
      flow.setOptions(aMask);
      expect(flow.settingsComplete, isFalse, reason: 'no prompt yet');
      flow.setOptions(aMask.copyWith(prompt: 'a brick wall'));
      expect(flow.settingsComplete, isTrue);
    });

    test('a prompt of only spaces is not a prompt', () async {
      final flow = await at('Inpainting');
      flow.setOptions(aMask.copyWith(prompt: '   '));
      expect(flow.settingsComplete, isFalse);
    });

    test('AI Expand needs a direction as well as a prompt', () async {
      final flow = await at('AI Expand');
      flow.setOptions(const ToolOptions(prompt: 'more sky'));
      expect(flow.settingsComplete, isFalse, reason: 'expanding by nothing');
      flow.setOptions(const ToolOptions(
        prompt: 'more sky',
        expansion: Expansion(left: 256),
      ));
      expect(flow.settingsComplete, isTrue);
    });

    test('Replace BG is ready immediately — it has a default', () async {
      final flow = await at('Replace BG');
      expect(flow.settingsComplete, isTrue);
    });
  });

  group('state that must not leak between edits', () {
    test('a new edit does not inherit the last one\'s mask', () async {
      final c = await booted();
      final flow = c.read(flowProvider.notifier);
      flow.pickTool('Magic Eraser', photo: photo);
      flow.cropNext();
      flow.setOptions(aMask.copyWith(prompt: 'something'));
      expect(c.read(flowProvider).options.hasMask, isTrue);

      // "Apply another" starts a fresh edit on the same photo.
      flow.applyAnother();

      expect(c.read(flowProvider).options.hasMask, isFalse,
          reason: 'a mask painted for one tool is meaningless to the next');
      expect(c.read(flowProvider).options.hasPrompt, isFalse);
    });

    test('a mask survives stepping back to fix the crop', () async {
      final c = await booted();
      final flow = c.read(flowProvider.notifier);
      flow.pickTool('Magic Eraser', photo: photo);
      flow.cropNext();
      flow.setOptions(aMask);

      flow.back();
      expect(c.read(flowProvider).step, EditFlow.crop);
      expect(c.read(flowProvider).options.hasMask, isTrue,
          reason: 'repainting to fix a crop would be hostile');
    });
  });

  group('the free limit is checked before the work, not after it', () {
    test('an exhausted user is stopped before painting anything', () async {
      final c = await booted();
      final access = c.read(accessProvider.notifier);
      for (var i = 0; i < AccessState.freeLimit; i++) {
        await access.consumeFreeGeneration();
      }
      expect(c.read(accessProvider).canGenerate, isFalse);

      final flow = c.read(flowProvider.notifier);
      flow.pickTool('Magic Eraser', photo: photo);
      flow.cropNext();

      // Asking for the paywall only after a mask has been painted throws away
      // work the user cannot use.
      expect(c.read(flowProvider).step, isNot(EditFlow.settings));
      expect(c.read(flowProvider).needsUpgrade, isTrue);
    });

    test('a premium user reaches settings normally', () async {
      final c = await booted(premium: true);
      final flow = c.read(flowProvider.notifier);
      flow.pickTool('Magic Eraser', photo: photo);
      flow.cropNext();
      expect(c.read(flowProvider).step, EditFlow.settings);
    });
  });
}
