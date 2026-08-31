// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
//
// Inpainting against real photographs, through the shipping pipeline.
//
//   flutter test tool/live_check/inpaint_check.dart --dart-define-from-file=.env
//
// Lives outside `test/` so the suite never runs it: every case is a paid
// prediction. It exists because the model's safety checker rejected a
// synthetic test image, and only real photos can say whether that was the
// image or the model.

import 'dart:io';

import 'package:ai_enhancer/data/replicate/enhance_job.dart';
import 'package:ai_enhancer/models/tool_options.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _photos = '/private/tmp/claude-501/'
    '-Users-darshangadhe-Downloads-ai-enhancer/'
    'd813fed8-dde2-4b56-90d3-279c8ccd2f53/scratchpad/photos';

/// A mask over the middle of the frame, where a real user would paint.
final _mask = [
  MaskStroke(
    points: const [
      Offset(0.40, 0.45), Offset(0.50, 0.50), Offset(0.60, 0.55),
    ],
    radius: 0.12,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;

  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    sandbox = await Directory.systemTemp.createTemp('inpaint');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => sandbox.path,
        );
  });

  const cases = {
    'photo1.jpg': 'a grassy meadow, photograph',
    'photo2.jpg': 'an empty paved road, photograph',
    'photo3.jpg': 'a plain brick wall, photograph',
  };

  cases.forEach((name, prompt) {
    test('Inpainting — $name', () async {
      final photo = File('$_photos/$name');
      expect(photo.existsSync(), isTrue, reason: 'missing $name');

      try {
        final outcome = await EnhanceJob(
          photo: photo,
          tool: 'Inpainting',
          aspectRatio: null,
          options: ToolOptions(prompt: prompt, strokes: _mask),
        ).run();

        final bytes = await outcome.result.readAsBytes();
        final image = await decodeImageFromList(bytes);
        print('  PASS $name -> ${image.width}x${image.height}, '
            '${bytes.length} bytes');
        image.dispose();
        expect(bytes.length, greaterThan(1000));
      } catch (error) {
        print('  FAIL $name -> $error');
        rethrow;
      }
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}
