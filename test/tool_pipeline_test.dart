// Every tool, one at a time.
//
// The claim being tested is architectural: there is one image-preparation
// layer, and no tool reaches Replicate around it. Rather than assert that by
// reading the code, each tool is actually run — a real oversized photo in, a
// mock Replicate underneath — and the bytes that arrive at the upload are
// measured.
//
// The catalog tools with no model behind them are run too, to check they stop
// before the network rather than sending anything.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_enhancer/data/app_info.dart';
import 'package:ai_enhancer/data/catalog.dart';
import 'package:ai_enhancer/data/image_budget.dart';
import 'package:ai_enhancer/data/replicate/enhance_job.dart';
import 'package:ai_enhancer/data/replicate/tool_models.dart';
import 'package:ai_enhancer/data/replicate/replicate_client.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The size that failed in production.
const _oversizedEdge = 1536;

/// What one run observed at the upload boundary.
class Upload {
  final int width;
  final int height;
  final int byteLength;
  const Upload(this.width, this.height, this.byteLength);

  int get pixelCount => width * height;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('tool_pipeline');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => sandbox.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  Future<File> oversizedPhoto() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1536, 1536),
      Paint()..color = const Color(0xFF1B4F72),
    );
    // A "subject" off-centre, so a test can tell a proportional resize from a
    // crop that threw away part of the frame.
    canvas.drawCircle(
      const Offset(1300, 240),
      160,
      Paint()..color = const Color(0xFFF4D03F),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(_oversizedEdge, _oversizedEdge);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final file = File('${sandbox.path}/photo.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  /// Runs [tool] end to end against a mock Replicate and reports what was
  /// uploaded. Returns null if nothing was.
  Future<Upload?> runTool(String tool, {double? aspectRatio}) async {
    Upload? seen;
    final client = ReplicateClient(
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/files') {
          // The payload as it goes over the wire. Decoding it is the only
          // honest way to know what the model would receive.
          final body = request.bodyBytes;
          final marker = utf8.encode('\r\n\r\n');
          var start = 0;
          for (var i = 0; i + marker.length <= body.length; i++) {
            var hit = true;
            for (var j = 0; j < marker.length; j++) {
              if (body[i + j] != marker[j]) {
                hit = false;
                break;
              }
            }
            if (hit) {
              start = i + marker.length;
              break;
            }
          }
          final image = await decodeImageFromList(
            Uint8List.fromList(body.sublist(start)),
          );
          seen = Upload(image.width, image.height, body.length);
          image.dispose();

          return http.Response(
            jsonEncode({
              'urls': {'get': 'https://api.replicate.com/v1/files/f'},
            }),
            201,
          );
        }
        if (path == '/v1/predictions') {
          return http.Response(
            jsonEncode({
              'id': 'p',
              'status': 'succeeded',
              'output': 'https://replicate.delivery/out/p.png',
            }),
            201,
          );
        }
        return http.Response.bytes(const [1, 2, 3], 200);
      }),
    );

    await EnhanceJob(
      photo: await oversizedPhoto(),
      tool: tool,
      aspectRatio: aspectRatio,
      client: client,
    ).run();
    return seen;
  }

  group('every tool backed by a model', () {
    // Read from the model's own table, so a tool added later is covered here
    // the day it is added rather than the day someone remembers.
    for (final tool in ToolModels.supportedTools) {
      test('$tool sends a photo inside the GPU budget', () async {
        final upload = await runTool(tool);

        expect(upload, isNotNull, reason: '$tool uploaded nothing');
        expect(
          upload!.pixelCount,
          lessThanOrEqualTo(ImageBudget.maxSafePixels),
          reason: '$tool sent ${upload.width}x${upload.height}',
        );
        expect(upload.width, lessThanOrEqualTo(ImageBudget.maxSourceEdge));
        expect(upload.height, lessThanOrEqualTo(ImageBudget.maxSourceEdge));

        // The original was 1536x1536 and had to move.
        expect(upload.width, lessThan(_oversizedEdge));
        // A square stays square: the frame was resized, not re-cropped.
        expect(upload.width, upload.height);
      });
    }

    test('the supported tools are exactly the ones this test covers', () {
      expect(
        ToolModels.supportedTools,
        containsAll(<String>[
          'AI Enhance',
          'HD Upscale',
          'Unblur',
          'Restore Photo',
          'Remove BG',
        ]),
      );
      expect(ToolModels.supportedTools, hasLength(5));
    });

    test('every shown tool has a model — the catalog cannot advertise a '
        'dead one', () {
      final shown = [
        for (final category in Catalog.categories)
          for (final tool in category.tools) tool.name,
      ];
      expect(shown, isNotEmpty);
      for (final tool in shown) {
        expect(ToolModels.supports(tool), isTrue, reason: '$tool is shown');
      }
      expect(shown.toSet(), ToolModels.supportedTools.toSet());
    });

    test('they all send the same prepared size — one layer, not five',
        () async {
      final sizes = <String, String>{};
      for (final tool in ToolModels.supportedTools) {
        final upload = await runTool(tool);
        sizes[tool] = '${upload!.width}x${upload.height}';
      }
      expect(sizes.values.toSet(), hasLength(1),
          reason: 'tools disagreed on how to prepare the same photo: $sizes');
    });
  });

  group('catalog tools with no model behind them', () {
    // Authored but not shown — see Catalog.allCategories.
    final unsupported = [
      for (final category in Catalog.allCategories)
        for (final tool in category.tools)
          if (!ToolModels.supports(tool.name)) tool.name,
    ];

    test('they exist, none claim a model, and none are shown', () {
      expect(unsupported, isNotEmpty);
      final shown = {
        for (final category in Catalog.categories)
          for (final tool in category.tools) tool.name,
      };
      for (final tool in unsupported) {
        expect(ToolModels.supports(tool), isFalse);
        expect(shown, isNot(contains(tool)),
            reason: '$tool has no model and must not be advertised');
      }
    });

    for (final tool in [
      'Replace BG',
      'Object Removal',
      'Remove People',
      'Watermark Remove',
      'Magic Eraser',
      'AI Expand',
      'Inpainting',
    ]) {
      test('$tool stops before the network rather than uploading', () async {
        await expectLater(runTool(tool), throwsA(isA<StateError>()));
      });
    }
  });

  group('what the app claims it can do', () {
    test('each model describes its own result, in its own words', () {
      expect(ToolModels.forTool('HD Upscale')!.resultSummary,
          'Enhanced 4x');
      // Not 'Enhanced Transparent PNG' — the result line is a sentence, not a
      // badge with a prefix glued on.
      expect(ToolModels.forTool('Remove BG')!.resultSummary,
          isNot(startsWith('Enhanced ')));
      for (final tool in ToolModels.supportedTools) {
        final model = ToolModels.forTool(tool)!;
        expect(model.label, isNotEmpty, reason: tool);
        expect(model.resultSummary, isNotEmpty, reason: tool);
      }
    });

    test('the premium benefits are things premium actually gives', () {
      final claims = AppInfo.proBenefits.join(' | ').toLowerCase();

      // Free users get every tool — the limit is on how many runs, not which
      // tools — so "every tool unlocked" was never true.
      expect(claims, isNot(contains('unlocked')));
      // The app applies no watermark to anyone, so there is none to remove.
      expect(claims, isNot(contains('watermark')));
      // Inputs are capped to the model's GPU budget, so 8K is not a promise
      // an ordinary photo can keep.
      expect(claims, isNot(contains('8k')));

      // What it does give.
      expect(claims, contains('unlimited'));
      expect(claims, contains('no ads'));
    });

    test('no tool subtitle promises a resolution the budget cannot reach', () {
      for (final category in Catalog.categories) {
        for (final tool in category.tools) {
          expect(tool.desc.toLowerCase(), isNot(contains('8k')),
              reason: tool.name);
        }
      }
    });
  });

  group('subject preservation', () {
    test('a resize keeps the whole frame — nothing is cropped away', () async {
      // No chosen ratio: the composition that reaches the model is the
      // composition the user took.
      final upload = await runTool('AI Enhance');
      expect(upload!.width / upload.height, closeTo(1.0, 0.01));
    });

    test('only an explicitly chosen frame crops', () async {
      final free = await runTool('AI Enhance');
      final wide = await runTool('AI Enhance', aspectRatio: 16 / 9);

      expect(free!.width / free.height, closeTo(1.0, 0.01));
      expect(wide!.width / wide.height, closeTo(16 / 9, 0.01));
      expect(wide.pixelCount, lessThanOrEqualTo(ImageBudget.maxSafePixels));
    });
  });
}
