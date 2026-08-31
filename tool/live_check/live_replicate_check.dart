// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
//
// This is a test file that deliberately lives outside `test/` so the suite
// never runs it. Printing and test-only helpers are exactly right here; the
// analyzer only objects because of where the file sits.
// Live end-to-end check against the real Replicate pipeline. NOT part of the
// suite: it lives outside `test/`, so `flutter test` never picks it up, and it
// spends real credit every time it runs. Invoke it deliberately:
//
//   flutter test tool/live_check/live_replicate_check.dart \
//       --dart-define-from-file=.env
//
// It exists because no amount of mocking can answer "does the model accept
// what we send it now" — only the model can.
//
// Two real predictions against live Replicate:
//   1. the ORIGINAL 1536x1536 payload sent raw, to reproduce the reported GPU
//      failure and prove it was real and is still real;
//   2. the SAME photo through the shipping preparation layer, to prove it now
//      succeeds end to end.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_enhancer/data/image_budget.dart';
import 'package:ai_enhancer/data/image_ops.dart';
import 'package:ai_enhancer/data/replicate/device_id.dart';
import 'package:ai_enhancer/data/replicate/tool_models.dart';
import 'package:ai_enhancer/data/replicate/enhance_job.dart';
import 'package:ai_enhancer/models/tool_options.dart';
import 'package:ai_enhancer/data/replicate/replicate_client.dart';
import 'package:ai_enhancer/data/replicate/replicate_config.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void say(Object? m) => print('    $m');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUpAll(() async {
    // TestWidgetsFlutterBinding installs an HttpOverrides that answers every
    // request with 400 and never touches the network. This check is only
    // meaningful against the real service, so it is removed.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    sandbox = await Directory.systemTemp.createTemp('live_check');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => sandbox.path,
        );
  });

  Future<File> photo1536() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1536, 1536),
        Paint()..color = const Color(0xFF1B4F72));
    canvas.drawCircle(const Offset(1180, 380), 220,
        Paint()..color = const Color(0xFFF4D03F));
    canvas.drawCircle(const Offset(520, 1020), 300,
        Paint()..color = const Color(0xFFE74C3C));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1536, 1536);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${sandbox.path}/live_1536.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  /// Uploads a file with no preparation at all.
  ///
  /// The app cannot do this any more — [ReplicateClient.uploadImage] takes a
  /// [PreparedImage], which only [ImageOps.prepareForUpload] can produce — so
  /// the bypass is rebuilt here by hand. That is the point: step 1 has to send
  /// what the broken build sent, or it proves nothing about the fix.
  Future<Uri> uploadRaw(File file) async {
    final request = http.MultipartRequest(
      'POST',
      ReplicateConfig.endpoint('/v1/files'),
    )
      ..headers['X-App-Key'] = ReplicateConfig.appKey
      ..headers['X-Device-Id'] = await DeviceId.get()
      ..files.add(await http.MultipartFile.fromPath('content', file.path,
          contentType: MediaType('image', 'png')));
    final response =
        await http.Response.fromStream(await request.send());
    final match = RegExp(r'"get"\s*:\s*"([^"]+)"').firstMatch(response.body);
    return Uri.parse(match!.group(1)!);
  }

  test('configuration is live', () {
    say('proxy mode: ${ReplicateConfig.usesProxy}');
    expect(ReplicateConfig.isConfigured, isTrue,
        reason: 'run with --dart-define-from-file=.env');
  });

  test('STEP 1 — raw 1536x1536 reproduces the reported GPU failure', () async {
    final client = ReplicateClient();
    try {
      final source = await photo1536();
      say('sending 1536x1536 = ${1536 * 1536} px, unprepared');
      expect(ImageBudget.isWithinBudget(1536, 1536), isFalse);

      final uploaded = await uploadRaw(source);
      var prediction = await client.createPrediction(
        version: ToolModels.forTool('AI Enhance')!.version,
        input:
            ToolModels.forTool('AI Enhance')!.inputFor(imageUrl: uploaded),
      );
      if (!prediction.isTerminal) {
        prediction = await client.awaitPrediction(prediction.id,
            timeout: const Duration(minutes: 4));
      }
      say('status: ${prediction.status}');
      say('model said: ${prediction.error}');
      expect(prediction.isFailed, isTrue,
          reason: 'expected the GPU rejection; got ${prediction.status}');
      expect(prediction.error, contains('greater than the max size'));
    } finally {
      client.close();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));

  // Every tool the app claims a model for, run for real, one at a time.
  // Tools that need nothing from the user run through the raw client here;
  // the ones that need a mask or a prompt are exercised through EnhanceJob
  // below, because the mask upload is part of what has to be proved.
  for (final tool in ToolModels.supportedTools.where(
    (t) => ToolModels.needsFor(t) == ToolNeeds.nothing,
  )) {
    test('TOOL — $tool completes end to end', () async {
      final client = ReplicateClient();
      try {
        final model = ToolModels.forTool(tool)!;
        final source = await photo1536();
        final prepared = await ImageOps.prepareForUpload(
          source,
          aspectRatio: null,
          targetPathWithoutExtension: '${sandbox.path}/${tool.hashCode}',
        );
        final uploaded = await client.uploadImage(prepared);
        final input = model.inputFor(imageUrl: uploaded);
        say('$tool -> ${model.runtimeType} (${model.label}), '
            'input ${prepared.width}x${prepared.height}');

        var prediction = await client.createPrediction(
          version: model.version,
          input: input,
        );
        if (!prediction.isTerminal) {
          prediction = await client.awaitPrediction(prediction.id,
              timeout: const Duration(minutes: 5));
        }
        say('$tool -> ${prediction.status}  ${prediction.error ?? ''}');
        expect(prediction.isSucceeded, isTrue,
            reason: '$tool failed: ${prediction.error}');

        final bytes = await client.downloadOutput(prediction.outputUrl!);
        say('$tool -> result ${bytes.length} bytes');
        expect(bytes.length, greaterThan(1000));

        // The result must be a real, decodable image the app can display.
        final decoded = await decodeImageFromList(bytes);
        say('$tool -> output ${decoded.width}x${decoded.height}');
        // An upscaler must grow the image; a background remover keeps its
        // size and changes what is in it.
        if (model is RealEsrganModel) {
          expect(decoded.width, greaterThan(prepared.width));
        } else {
          expect(decoded.width, greaterThan(0));
        }
        decoded.dispose();
      } finally {
        client.close();
      }
    }, timeout: const Timeout(Duration(minutes: 8)));
  }

  // The tools that need a mask or a prompt, run through EnhanceJob itself —
  // the same code path the app uses, mask upload included.
  final cases = <String, ToolOptions>{
    'Object Removal': ToolOptions(strokes: [
      MaskStroke(points: [
        const Offset(0.55, 0.20), const Offset(0.75, 0.28),
        const Offset(0.80, 0.35),
      ], radius: 0.10),
    ]),
    'Magic Eraser': ToolOptions(strokes: [
      MaskStroke(points: [const Offset(0.35, 0.65)], radius: 0.14),
    ]),
    'Remove People': ToolOptions(strokes: [
      MaskStroke(points: [const Offset(0.50, 0.50)], radius: 0.12),
    ]),
    'Watermark Remove': ToolOptions(strokes: [
      MaskStroke(points: [
        const Offset(0.10, 0.90), const Offset(0.35, 0.90),
      ], radius: 0.05),
    ]),
    'Inpainting': ToolOptions(
      prompt: 'a plain grey concrete wall, photograph',
      strokes: [
        MaskStroke(points: [
          const Offset(0.30, 0.60), const Offset(0.45, 0.70),
        ], radius: 0.12),
      ],
    ),
    'AI Expand': const ToolOptions(
      prompt: 'more of the same blue sky',
      expansion: Expansion(left: 256, right: 256),
    ),
    'Replace BG': const ToolOptions(background: BackgroundStyle.white),
  };

  cases.forEach((tool, options) {
    test('TOOL — $tool completes end to end', () async {
      final photo = await photo1536();
      final outcome = await EnhanceJob(
        photo: photo,
        tool: tool,
        aspectRatio: null,
        options: options,
      ).run(onPhase: (p) => say('  $tool: ${p.name}'));

      final bytes = await outcome.result.readAsBytes();
      say('$tool -> ${outcome.outputLabel} · ${bytes.length} bytes '
          '· ${outcome.result.path.split('/').last}');
      expect(bytes.length, greaterThan(1000));

      final decoded = await decodeImageFromList(bytes);
      say('$tool -> output ${decoded.width}x${decoded.height}');
      expect(decoded.width, greaterThan(0));
      decoded.dispose();
    }, timeout: const Timeout(Duration(minutes: 8)));
  });

  test('STEP 2 — the same photo, prepared, succeeds', () async {
    final client = ReplicateClient();
    try {
      final source = await photo1536();
      final prepared = await ImageOps.prepareForUpload(
        source,
        aspectRatio: null,
        targetPathWithoutExtension: '${sandbox.path}/prepared',
      );
      say('prepared: ${prepared.width}x${prepared.height} '
          '(${prepared.pixelCount} px), ${prepared.byteLength} bytes');
      expect(prepared.isWithinBudget(), isTrue);

      final uploaded = await client.uploadImage(prepared);
      var prediction = await client.createPrediction(
        version: ToolModels.forTool('AI Enhance')!.version,
        input:
            ToolModels.forTool('AI Enhance')!.inputFor(imageUrl: uploaded),
      );
      say('prediction ${prediction.id}: ${prediction.status}');
      if (!prediction.isTerminal) {
        prediction = await client.awaitPrediction(prediction.id,
            timeout: const Duration(minutes: 4),
            onPoll: (p) => say('  poll: ${p.status}'));
      }
      say('final: ${prediction.status}   error: ${prediction.error}');
      expect(prediction.isSucceeded, isTrue,
          reason: 'model reported: ${prediction.error}');

      final bytes = await client.downloadOutput(prediction.outputUrl!);
      say('downloaded ${bytes.length} bytes of result');
      expect(bytes.length, greaterThan(1000));
    } finally {
      client.close();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
