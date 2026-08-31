// The shared preparation layer, exercised on real pixels.
//
// These decode, raster and encode actual images through the engine — the same
// path a photo takes on a phone — so what they pin is the payload itself: its
// dimensions, its pixel count, and the fact that the file handed to the upload
// is the processed one and not the picked one.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ai_enhancer/data/image_budget.dart';
import 'package:ai_enhancer/data/image_ops.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes a real PNG of [width]x[height] into [dir] and returns it.
///
/// Painted with two blocks rather than a flat fill so a crop can be told apart
/// from a resize by looking at the result.
Future<File> makeImage(
  Directory dir,
  int width,
  int height, {
  String name = 'source.png',
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF204080),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
    Paint()..color = const Color(0xFFC03030),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final file = File('${dir.path}/$name');
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return file;
}

/// Reads back the dimensions of a file on disk — the payload as the server
/// would see it, not as the code claims it is.
Future<ui.Image> decodeFile(File file) async =>
    decodeImageFromList(await file.readAsBytes());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('image_prep');
  });

  tearDown(() async {
    if (sandbox.existsSync()) await sandbox.delete(recursive: true);
  });

  Future<PreparedImage> prepare(File source, {double? aspectRatio}) =>
      ImageOps.prepareForUpload(
        source,
        aspectRatio: aspectRatio,
        targetPathWithoutExtension: '${sandbox.path}/out/prepared',
      );

  group('the reported failure, end to end', () {
    test('a real 1536x1536 photo is downscaled into the budget', () async {
      final source = await makeImage(sandbox, 1536, 1536);
      expect(1536 * 1536, greaterThan(ImageBudget.modelMaxPixels));

      final prepared = await prepare(source);

      expect(prepared.wasResized, isTrue);
      expect(prepared.isWithinBudget(), isTrue);
      expect(prepared.pixelCount,
          lessThanOrEqualTo(ImageBudget.maxSafePixels));
      expect(prepared.width, prepared.height, reason: 'still square');

      // The file on disk really is that size — not just the record of it.
      final onDisk = await decodeFile(prepared.file);
      addTearDown(onDisk.dispose);
      expect(onDisk.width, prepared.width);
      expect(onDisk.height, prepared.height);
      expect(onDisk.width * onDisk.height,
          lessThanOrEqualTo(ImageBudget.maxSafePixels));
    });
  });

  group('the uploaded file', () {
    test('is the processed file, not the picked one', () async {
      final source = await makeImage(sandbox, 3000, 2000);
      final prepared = await prepare(source);

      expect(prepared.file.path, isNot(source.path));
      expect(prepared.file.existsSync(), isTrue);

      // The original is left alone — retry has to still work.
      final original = await decodeFile(source);
      addTearDown(original.dispose);
      expect(original.width, 3000);
      expect(prepared.width, lessThan(3000));
    });

    test('reports the byte length of what is actually on disk', () async {
      final source = await makeImage(sandbox, 2400, 1800);
      final prepared = await prepare(source);
      expect(prepared.byteLength, await prepared.file.length());
      expect(prepared.byteLength, greaterThan(0));
    });
  });

  group('quality — only downscale when required', () {
    test('an image already within budget is not re-encoded', () async {
      final source = await makeImage(sandbox, 900, 700, name: 'small.png');
      final before = await source.length();

      final prepared = await prepare(source);

      expect(prepared.wasResized, isFalse);
      expect(prepared.width, 900);
      expect(prepared.height, 700);
      // Copied byte-for-byte: no second compression pass on a photo that
      // needed nothing done to it.
      expect(prepared.byteLength, before);
    });

    test('a JPEG that fits keeps its own format rather than becoming PNG',
        () async {
      // The bytes are a PNG; the point under test is that the extension of the
      // pass-through payload follows the source, so the declared content type
      // stays honest.
      final png = await makeImage(sandbox, 640, 480, name: 'photo.png');
      final jpg = File('${sandbox.path}/photo.jpg');
      await jpg.writeAsBytes(await png.readAsBytes(), flush: true);

      final prepared = await prepare(jpg);

      expect(prepared.wasResized, isFalse);
      expect(prepared.format, 'jpg');
      expect(prepared.file.path, endsWith('.jpg'));
    });

    test('a resized image is written as PNG, the format the pipeline sends',
        () async {
      final source = await makeImage(sandbox, 2600, 2600);
      final prepared = await prepare(source);
      expect(prepared.format, 'png');
      expect(prepared.file.path, endsWith('.png'));
    });
  });

  group('shape', () {
    test('a 4:3 photo keeps 4:3', () async {
      final source = await makeImage(sandbox, 4000, 3000);
      final prepared = await prepare(source);
      expect(prepared.width / prepared.height, closeTo(4 / 3, 0.01));
      expect(prepared.isWithinBudget(), isTrue);
    });

    test('a 16:9 photo keeps 16:9', () async {
      final source = await makeImage(sandbox, 3840, 2160);
      final prepared = await prepare(source);
      expect(prepared.width / prepared.height, closeTo(16 / 9, 0.01));
      expect(prepared.isWithinBudget(), isTrue);
    });

    test('no aspect ratio means nothing is cropped away', () async {
      final source = await makeImage(sandbox, 1200, 900);
      final prepared = await prepare(source);
      expect(prepared.width / prepared.height, closeTo(1200 / 900, 0.001));
      expect(prepared.wasResized, isFalse);
    });

    test('a chosen frame is honoured, and still fits the budget', () async {
      final source = await makeImage(sandbox, 4000, 3000);
      final prepared = await prepare(source, aspectRatio: 1);
      expect(prepared.width, prepared.height);
      expect(prepared.isWithinBudget(), isTrue);
    });
  });

  group('images that cannot be prepared', () {
    test('a corrupt file fails with a message written for a user', () async {
      final corrupt = File('${sandbox.path}/corrupt.png');
      await corrupt.writeAsBytes(
        Uint8List.fromList(List<int>.filled(512, 7)),
        flush: true,
      );

      await expectLater(
        prepare(corrupt),
        throwsA(isA<ImagePreparationException>().having(
          (e) => e.message,
          'message',
          ImageOps.preparationFailedMessage,
        )),
      );
    });

    test('an empty file fails rather than being uploaded unmeasured', () async {
      final empty = File('${sandbox.path}/empty.jpg');
      await empty.writeAsBytes(const <int>[], flush: true);
      await expectLater(prepare(empty), throwsA(isA<ImagePreparationException>()));
    });

    test('a missing file fails cleanly', () async {
      final missing = File('${sandbox.path}/nope.png');
      await expectLater(
        prepare(missing),
        throwsA(isA<ImagePreparationException>()),
      );
    });

    test('an unsupported format is refused, not passed through', () async {
      // A PDF header: a real file, a real extension, not an image.
      final pdf = File('${sandbox.path}/document.pdf');
      await pdf.writeAsBytes(
        Uint8List.fromList('%PDF-1.7\n%âãÏÓ\n'.codeUnits),
        flush: true,
      );
      await expectLater(prepare(pdf), throwsA(isA<ImagePreparationException>()));
    });

    test('the failure message names no pixels, models or GPUs', () {
      final message = ImageOps.preparationFailedMessage.toLowerCase();
      for (final leak in const [
        'pixel',
        'gpu',
        'memory',
        'replicate',
        'esrgan',
        'dimension',
        'tensor',
      ]) {
        expect(message, isNot(contains(leak)));
      }
    });
  });
}
