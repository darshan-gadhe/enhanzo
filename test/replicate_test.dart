// Tests for the Replicate pipeline: the request the app builds, the sequence
// it runs, and what it does with the reply.
//
// Every call is served by a MockClient, so nothing here touches the network or
// spends credit. What they pin is the contract — the pinned model version, the
// input keys Real-ESRGAN expects, the create → poll → download order, and the
// failure and cancellation paths.

import 'dart:convert';
import 'dart:io';

import 'package:ai_enhancer/data/replicate/enhance_job.dart';
import 'package:ai_enhancer/data/replicate/real_esrgan.dart';
import 'package:ai_enhancer/data/replicate/replicate_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The image bytes stood in for a photo. Deliberately not a decodable image:
/// `ImageOps.cropToRatio` is documented to hand back the original when it
/// can't decode, which is exactly the path a test should be able to rely on.
final _sourceBytes = Uint8List.fromList(List<int>.filled(64, 7));

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

  Future<File> writePhoto() async {
    final file = File('${sandbox.path}/photo.jpg');
    await file.writeAsBytes(_sourceBytes);
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

    test('only the enhance tools claim a model', () {
      expect(RealEsrgan.supports('HD Upscale'), isTrue);
      expect(RealEsrgan.presetFor('HD Upscale')!.scale, 4);
      // An upscaler cannot erase an object, so it does not pretend to.
      expect(RealEsrgan.supports('Object Removal'), isFalse);
      expect(RealEsrgan.presetFor('Remove BG'), isNull);
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
      expect(outcome.preset.scale, 4);
      expect(await outcome.result.readAsBytes(), _resultBytes);
      expect(outcome.result.path, endsWith('pred1.png'));
      // The stages the processing screen reports, in the order they happen.
      expect(phases.first, EnhancePhase.preparing);
      expect(phases.last, EnhancePhase.done);
      expect(phases, contains(EnhancePhase.uploading));
      expect(phases, contains(EnhancePhase.downloading));
    });

    test('a failed prediction surfaces the model\'s own reason', () async {
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
          isA<ReplicateException>().having(
            (e) => e.message,
            'message',
            'CUDA out of memory',
          ),
        ),
      );
    });

    test('an API error is reported with the service\'s own detail', () async {
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
              .having((e) => e.message, 'message', contains('insufficient'))
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

    test('a tool with no model behind it never reaches the network', () async {
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
          tool: 'Remove BG',
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
