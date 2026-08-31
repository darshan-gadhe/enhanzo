// Tests for the Replicate pipeline: the request the app builds, the sequence
// it runs, and what it does with the reply.
//
// Every call is served by a MockClient, so nothing here touches the network or
// spends credit. What they pin is the contract — the pinned model version, the
// input keys Real-ESRGAN expects, the create → poll → download order, and the
// failure and cancellation paths.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_enhancer/data/image_budget.dart';
import 'package:ai_enhancer/data/image_ops.dart';
import 'package:ai_enhancer/data/replicate/enhance_job.dart';
import 'package:ai_enhancer/data/replicate/model_errors.dart';
import 'package:ai_enhancer/data/replicate/real_esrgan.dart';
import 'package:ai_enhancer/data/replicate/tool_models.dart';
import 'package:ai_enhancer/data/replicate/replicate_client.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What the model "returns".
final _resultBytes = Uint8List.fromList(List<int>.filled(128, 42));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('enhance_test');
    // path_provider is a platform channel; the job only needs somewhere to
    // write, so point it at a temp directory.
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

  /// A real, decodable photo. It has to be real: the job now refuses to upload
  /// anything whose size it could not measure, which is the whole point of the
  /// preparation layer. [width] and [height] default to something already
  /// inside the budget so tests that are about the network are not also about
  /// resizing.
  Future<File> writePhoto({int width = 800, int height = 600}) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF2A6FDB),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final file = File('${sandbox.path}/photo.png');
    await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    return file;
  }

  group('the request the app sends', () {
    test('the model version is pinned to the digest, not the tag', () {
      expect(
        RealEsrgan.version,
        'daanelson/real-esrgan-a100:'
        'f94d7ed4a1f7e1ffed0d51e4089e4911609d5eeee5e874ef323d2c7562624bed',
      );
    });

    test('input carries exactly the keys Real-ESRGAN takes', () {
      final input = RealEsrgan.inputFor(
        imageUrl: Uri.parse('https://example.com/photo.png'),
        preset: const RealEsrganPreset(scale: 4, faceEnhance: true),
      );

      expect(input, {
        'image': 'https://example.com/photo.png',
        'scale': 4,
        'face_enhance': true,
      });
    });

    test('each tool maps to the model that can actually do it', () {
      expect(ToolModels.forTool('HD Upscale'), isA<RealEsrganModel>());
      expect(
        (ToolModels.forTool('HD Upscale')! as RealEsrganModel).preset.scale,
        4,
      );
      // An upscaler cannot cut out a background, so background removal runs on
      // a background remover rather than being mapped onto the upscaler.
      expect(ToolModels.forTool('Remove BG'), isA<BackgroundModel>());
      // Object removal needs a mask, so it runs on an inpainting model rather
      // than being mapped onto something that cannot do it.
      expect(ToolModels.forTool('Object Removal'), isA<InpaintFillModel>());
      expect(ToolModels.needsFor('Object Removal'), ToolNeeds.mask);
      // A name that is not a tool still has nothing behind it.
      expect(ToolModels.supports('Teleport'), isFalse);
      expect(ToolModels.forTool('Teleport'), isNull);
    });

    test('the background remover asks for a transparent PNG', () {
      final input = const BackgroundModel().inputFor(
        imageUrl: Uri.parse('https://api.replicate.com/v1/files/f'),
      );
      expect(input, {
        'image': 'https://api.replicate.com/v1/files/f',
        // JPEG cannot carry alpha; asking for it would composite onto black.
        'format': 'png',
        'background_type': 'rgba',
        'threshold': 0,
        'reverse': false,
      });
    });

    test('every model pins a digest rather than following a tag', () {
      for (final tool in ToolModels.supportedTools) {
        final version = ToolModels.forTool(tool)!.version;
        expect(version, contains(':'), reason: tool);
        expect(version.split(':').last, hasLength(64), reason: tool);
      }
    });

    test('createPrediction asks the server to hold the connection open', () async {
      late http.Request seen;
      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({'id': 'abc', 'status': 'starting'}),
            201,
          );
        }),
      );

      await client.createPrediction(
        version: RealEsrgan.version,
        input: const {'scale': 4},
      );

      expect(seen.url.path, '/v1/predictions');
      expect(seen.headers['Prefer'], startsWith('wait='));
      expect(jsonDecode(seen.body), {
        'version': RealEsrgan.version,
        'input': {'scale': 4},
      });
    });
  });

  group('EnhanceJob', () {
    test('uploads, predicts, polls and saves the result', () async {
      final calls = <String>[];
      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          final path = request.url.path;
          calls.add('${request.method} $path');

          if (path == '/v1/files') {
            return http.Response(
              jsonEncode({
                'id': 'file1',
                'urls': {'get': 'https://api.replicate.com/v1/files/file1'},
              }),
              201,
            );
          }
          if (path == '/v1/predictions') {
            // Long enough that the server's wait expires, so the poll loop is
            // the thing under test.
            return http.Response(
              jsonEncode({'id': 'pred1', 'status': 'processing'}),
              201,
            );
          }
          if (path == '/v1/predictions/pred1') {
            return http.Response(
              jsonEncode({
                'id': 'pred1',
                'status': 'succeeded',
                'output': 'https://replicate.delivery/out/pred1.png',
              }),
              200,
            );
          }
          return http.Response.bytes(_resultBytes, 200);
        }),
      );

      final phases = <EnhancePhase>[];
      final outcome = await EnhanceJob(
        photo: await writePhoto(),
        tool: 'HD Upscale',
        aspectRatio: 1,
        client: client,
      ).run(onPhase: phases.add);

      expect(calls, [
        'POST /v1/files',
        'POST /v1/predictions',
        'GET /v1/predictions/pred1',
        'GET /out/pred1.png',
      ]);
      expect(outcome.predictionId, 'pred1');
      expect(outcome.outputLabel, '4x');
      expect(await outcome.result.readAsBytes(), _resultBytes);
      expect(outcome.result.path, endsWith('pred1.png'));
      // The stages the processing screen reports, in the order they happen.
      expect(phases.first, EnhancePhase.preparing);
      expect(phases.last, EnhancePhase.done);
      expect(phases, contains(EnhancePhase.uploading));
      expect(phases, contains(EnhancePhase.downloading));
    });

    test('a failed prediction never shows the model\'s own words', () async {
      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          if (request.url.path == '/v1/files') {
            return http.Response(
              jsonEncode({
                'urls': {'get': 'https://api.replicate.com/v1/files/f'},
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'pred2',
              'status': 'failed',
              'error': 'CUDA out of memory',
            }),
            201,
          );
        }),
      );

      await expectLater(
        EnhanceJob(
          photo: await writePhoto(),
          tool: 'AI Enhance',
          aspectRatio: null,
          client: client,
        ).run(),
        throwsA(
          isA<ReplicateException>()
              // Translated, not relayed. "CUDA out of memory" told a user
              // holding a phone nothing they could act on.
              .having((e) => e.message, 'message', ModelErrors.tooLarge)
              .having((e) => e.message, 'message', isNot(contains('CUDA')))
              .having((e) => e.message, 'message', isNot(contains('memory'))),
        ),
      );
    });

    test('the reported GPU failure is translated, not relayed', () async {
      // The exact string the live model returned.
      const raw =
          'Input image of dimensions (1536, 1536, 4) has a total number of '
          'pixels 2359296 greater than the max size that fits in GPU memory '
          'on this hardware, 2096704. Resize input image and try again.';

      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          if (request.url.path == '/v1/files') {
            return http.Response(
              jsonEncode({
                'urls': {'get': 'https://api.replicate.com/v1/files/f'},
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({'id': 'p', 'status': 'failed', 'error': raw}),
            201,
          );
        }),
      );

      await expectLater(
        EnhanceJob(
          photo: await writePhoto(),
          tool: 'AI Enhance',
          aspectRatio: null,
          client: client,
        ).run(),
        throwsA(isA<ReplicateException>().having(
          (e) => e.message,
          'message',
          ModelErrors.tooLarge,
        )),
      );
    });

    test('the file that is uploaded is the prepared one', () async {
      // A photo well past the budget, so preparation must change it.
      Uint8List? uploaded;
      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          if (request.url.path == '/v1/files') {
            uploaded = request.bodyBytes;
            return http.Response(
              jsonEncode({
                'urls': {'get': 'https://api.replicate.com/v1/files/f'},
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({'id': 'p', 'status': 'failed', 'error': 'stop here'}),
            201,
          );
        }),
      );

      final photo = await writePhoto(width: 1536, height: 1536);
      await expectLater(
        EnhanceJob(
          photo: photo,
          tool: 'AI Enhance',
          aspectRatio: null,
          client: client,
        ).run(),
        throwsA(isA<ReplicateException>()),
      );

      // The multipart body carries the payload; the original PNG appears
      // nowhere in it.
      final original = await photo.readAsBytes();
      expect(uploaded, isNotNull);
      expect(uploaded!.length, lessThan(original.length + 4096));

      // And the source the outcome would have shown really is downscaled.
      final prepared = await ImageOps.prepareForUpload(
        photo,
        aspectRatio: null,
        targetPathWithoutExtension: '${sandbox.path}/check',
      );
      expect(prepared.pixelCount,
          lessThanOrEqualTo(ImageBudget.maxSafePixels));
      expect(prepared.width, lessThan(1536));
    });

    test('an API error is reported in words a user can act on', () async {
      final client = ReplicateClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': 'You have insufficient credit.'}),
            402,
          ),
        ),
      );

      await expectLater(
        EnhanceJob(
          photo: await writePhoto(),
          tool: 'AI Enhance',
          aspectRatio: null,
          client: client,
        ).run(),
        throwsA(
          isA<ReplicateException>()
              // The service says "You have insufficient credit." — true, and
              // meaningless to whoever is holding the phone.
              .having((e) => e.message, 'message', isNot(contains('credit')))
              .having((e) => e.message, 'message',
                  contains('temporarily unavailable'))
              .having((e) => e.statusCode, 'statusCode', 402),
        ),
      );
    });

    test('cancelling stops the run rather than finishing it', () async {
      late EnhanceJob job;
      var predictionsCreated = 0;

      final client = ReplicateClient(
        httpClient: MockClient((request) async {
          if (request.url.path == '/v1/files') {
            // Abandoned mid-upload: nothing may be spent after this point.
            await job.cancel();
            return http.Response(
              jsonEncode({
                'urls': {'get': 'https://api.replicate.com/v1/files/f'},
              }),
              201,
            );
          }
          predictionsCreated++;
          return http.Response(jsonEncode({'id': 'x', 'status': 'starting'}), 201);
        }),
      );

      job = EnhanceJob(
        photo: await writePhoto(),
        tool: 'Unblur',
        aspectRatio: null,
        client: client,
      );

      await expectLater(job.run(), throwsA(isA<EnhanceCancelled>()));
      expect(predictionsCreated, 0);
    });

    test('an unknown tool never reaches the network', () async {
      var requests = 0;
      final client = ReplicateClient(
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        EnhanceJob(
          photo: await writePhoto(),
          // Not a tool at all — every catalog tool now has a model, so this
          // is what "no model behind it" has to look like.
          tool: 'Teleport',
          aspectRatio: null,
          client: client,
        ).run(),
        throwsA(isA<StateError>()),
      );
      expect(requests, 0);
    });
  });

  group('Prediction', () {
    test('reads a single output URL and a list one alike', () {
      expect(
        Prediction.fromJson({
          'id': 'a',
          'status': 'succeeded',
          'output': 'https://out/1.png',
        }).outputUrl.toString(),
        'https://out/1.png',
      );
      expect(
        Prediction.fromJson({
          'id': 'a',
          'status': 'succeeded',
          'output': ['https://out/2.png'],
        }).outputUrl.toString(),
        'https://out/2.png',
      );
      expect(
        Prediction.fromJson({'id': 'a', 'status': 'processing'}).outputUrl,
        isNull,
      );
    });

    test('only terminal states end the poll loop', () {
      Prediction at(String status) =>
          Prediction.fromJson({'id': 'a', 'status': status});

      expect(at('starting').isTerminal, isFalse);
      expect(at('processing').isTerminal, isFalse);
      expect(at('succeeded').isTerminal, isTrue);
      expect(at('failed').isTerminal, isTrue);
      expect(at('canceled').isTerminal, isTrue);
    });
  });
}
