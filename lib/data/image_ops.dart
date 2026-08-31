import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/tool_options.dart';
import 'image_budget.dart';

/// An image that has been measured and proven to fit the model's input budget.
///
/// The point of the type is that it cannot be forged.
/// [ReplicateClient.uploadImage] takes one of these rather than a [File], and
/// the only way to obtain one is [ImageOps.prepareForUpload] — so "every tool
/// goes through the shared preparation layer" is not a convention anyone has to
/// remember, it is the only thing that compiles.
@immutable
class PreparedImage {
  /// The file that will actually be uploaded. Not the picked photo, and not a
  /// preview: this is the payload.
  final File file;

  final int width;
  final int height;

  /// Size of [file] on disk, in bytes.
  final int byteLength;

  /// Extension of [file], which decides the declared content type.
  final String format;

  /// Whether the pixels were re-encoded, or the picked file was passed through
  /// untouched because it already fitted.
  final bool wasResized;

  const PreparedImage._({
    required this.file,
    required this.width,
    required this.height,
    required this.byteLength,
    required this.format,
    required this.wasResized,
  });

  int get pixelCount => width * height;

  /// Restates the guarantee at the point of use. Cheap, and it means a future
  /// change to the preparation path cannot quietly stop honouring it.
  bool isWithinBudget({int? maxEdge, int? maxPixels}) =>
      ImageBudget.isWithinBudget(
        width,
        height,
        maxEdge: maxEdge,
        maxPixels: maxPixels,
      );

  @override
  String toString() =>
      'PreparedImage(${width}x$height, $pixelCount px, $byteLength bytes, '
      '$format, resized: $wasResized)';
}

/// A photo that could not be made safe to send.
///
/// Carries user-facing text only. The technical reason goes to the debug log,
/// never to the screen.
class ImagePreparationException implements Exception {
  final String message;
  const ImagePreparationException(this.message);

  @override
  String toString() => message;
}

/// Pixel work the edit flow does on the device before anything is uploaded.
class ImageOps {
  ImageOps._();

  /// Kept as the name the picker and the crop canvas refer to.
  static int get maxSourceEdge => ImageBudget.maxSourceEdge;

  /// What the user is told when a photo cannot be prepared. Deliberately says
  /// nothing about pixels, GPUs or models.
  static const String preparationFailedMessage =
      "Your photo couldn't be prepared for enhancement. Please try another "
      'image.';

  /// The width ÷ height of [file], or null if it can't be read.
  ///
  /// The crop step needs this to honour "Free": without the photo's own
  /// proportions there is nothing to fall back to but an arbitrary frame.
  static Future<double?> aspectRatioOf(File file) async {
    ui.Image? image;
    try {
      image = await decodeImageFromList(await file.readAsBytes());
      if (image.width <= 0 || image.height <= 0) return null;
      return image.width / image.height;
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// Turns a picked photo into the exact payload that will be uploaded.
  ///
  /// **This is the single image-preparation pipeline.** Every tool that sends
  /// an image to Replicate reaches it through here, because [PreparedImage] is
  /// the only thing the upload will take and this is the only place one is
  /// made.
  ///
  /// It does three things in one decode → one raster → one encode, rather than
  /// cropping and then resizing as two passes over the same photo:
  ///
  ///  1. **Crop** to [aspectRatio] (width ÷ height) if the user chose a frame.
  ///     A null ratio means "keep the photo's own proportions", and nothing is
  ///     cropped away — see the note on subjects below.
  ///  2. **Fit** the result inside [ImageBudget], proportionally. This is what
  ///     stops the model's "greater than the max size that fits in GPU memory"
  ///     failure, which an edge-only cap could not.
  ///  3. **Encode** to PNG, but only if step 1 or 2 actually changed the
  ///     pixels. A photo that already fits and needs no crop is *copied*
  ///     byte-for-byte, so it is never recompressed for nothing.
  ///
  /// ## On subjects
  ///
  /// The downscale in step 2 is a proportional resize of the whole frame. It
  /// never crops, never re-frames, and never guesses where the subject is —
  /// the complete composition reaches the model, which does its own face
  /// detection (GFPGAN, via the `face_enhance` preset). The only crop that
  /// happens is the one the user explicitly asked for on the crop step.
  ///
  /// Throws [ImagePreparationException] when the photo cannot be decoded or
  /// encoded. It deliberately does **not** fall back to uploading the original:
  /// an image whose size could not be measured is exactly the image that must
  /// not be sent, and that fallback is how an oversized photo reached the model
  /// in the first place.
  static Future<PreparedImage> prepareForUpload(
    File source, {
    required double? aspectRatio,
    required String targetPathWithoutExtension,
    int? maxEdge,
    int? maxPixels,
  }) async {
    ui.Image? decoded;
    try {
      final bytes = await source.readAsBytes();
      decoded = await decodeImageFromList(bytes);

      final srcW = decoded.width;
      final srcH = decoded.height;
      if (srcW <= 0 || srcH <= 0) {
        throw const ImagePreparationException(preparationFailedMessage);
      }

      // Region of the original that survives the crop. With no chosen ratio
      // this is the whole photo.
      final ratio = aspectRatio ?? srcW / srcH;
      var cropW = srcW.toDouble();
      var cropH = srcW / ratio;
      if (cropH > srcH) {
        cropH = srcH.toDouble();
        cropW = srcH * ratio;
      }
      final cropped =
          cropW.round() != srcW || cropH.round() != srcH;

      // The size that will actually be sent.
      final fitted = ImageBudget.fit(
        cropW.round(),
        cropH.round(),
        maxEdge: maxEdge,
        maxPixels: maxPixels,
      );
      final resized =
          fitted.width != cropW.round() || fitted.height != cropH.round();

      // Nothing to do: pass the picked file through untouched rather than
      // re-encode it into a larger PNG for no gain.
      if (!cropped && !resized) {
        decoded.dispose();
        decoded = null;
        final ext = _extensionOf(source.path);
        final target = File('$targetPathWithoutExtension.$ext');
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        return _report(
          PreparedImage._(
            file: target,
            width: fitted.width,
            height: fitted.height,
            byteLength: await target.length(),
            format: ext,
            wasResized: false,
          ),
          source: '${srcW}x$srcH',
        );
      }

      final srcRect = Rect.fromLTWH(
        (srcW - cropW) / 2,
        (srcH - cropH) / 2,
        cropW,
        cropH,
      );

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        decoded,
        srcRect,
        Rect.fromLTWH(0, 0, fitted.width.toDouble(), fitted.height.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();

      // The source decode is dead the moment it has been drawn. Releasing it
      // before rasterising means the full-resolution photo and the output
      // never both exist at their peak.
      decoded.dispose();
      decoded = null;

      ui.Image raster;
      try {
        raster = await picture.toImage(fitted.width, fitted.height);
      } finally {
        picture.dispose();
      }

      Uint8List? encoded;
      try {
        final data = await raster.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const ImagePreparationException(preparationFailedMessage);
        }
        encoded = data.buffer.asUint8List();
      } finally {
        raster.dispose();
      }

      final target = File('$targetPathWithoutExtension.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(encoded, flush: true);

      return _report(
        PreparedImage._(
          file: target,
          width: fitted.width,
          height: fitted.height,
          byteLength: encoded.length,
          format: 'png',
          wasResized: resized,
        ),
        source: '${srcW}x$srcH',
      );
    } on ImagePreparationException {
      rethrow;
    } catch (error) {
      // Any decode, raster or write failure. The original is deliberately not
      // used as a fallback: it has never been measured.
      assert(() {
        debugPrint('Image preparation failed: $error');
        return true;
      }());
      throw const ImagePreparationException(preparationFailedMessage);
    } finally {
      decoded?.dispose();
    }
  }

  /// Debug-only record of what is about to be uploaded.
  ///
  /// Dimensions, pixel count, byte length, format and the local file name —
  /// never image content, never a credential. Stripped entirely from release
  /// builds by `assert`.
  static PreparedImage _report(PreparedImage image, {required String source}) {
    assert(() {
      debugPrint(
        'Upload payload: $source -> ${image.width}x${image.height} '
        '(${image.pixelCount} px, budget ${ImageBudget.maxSafePixels}), '
        '${image.byteLength} bytes, ${image.format}, '
        'file ${image.file.uri.pathSegments.last}',
      );
      return true;
    }());
    return image;
  }

  /// Rasterises the painted mask to match [image] exactly and writes it out.
  ///
  /// The mask must be the same size as the photo the model receives — not the
  /// photo the user painted on, which was whatever the canvas happened to be.
  /// [ToolOptions] stores strokes in normalised coordinates precisely so this
  /// can size them to the prepared upload at the last moment.
  ///
  /// Returns a [PreparedImage] like any other, so the mask travels the same
  /// verified path to the upload as the photo does. Throws
  /// [ImagePreparationException] when nothing was painted: an all-black mask
  /// asks the model to change nothing, which is a wasted paid run.
  static Future<PreparedImage> prepareMask(
    ToolOptions options,
    PreparedImage image, {
    required String targetPathWithoutExtension,
  }) async {
    ui.Image? raster;
    try {
      raster = await options.rasteriseMask(image.width, image.height);
      if (raster == null) {
        throw const ImagePreparationException(
          'Paint over the part you want changed, then try again.',
        );
      }
      final data = await raster.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const ImagePreparationException(preparationFailedMessage);
      }
      final bytes = data.buffer.asUint8List();
      final target = File('$targetPathWithoutExtension.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);

      return _report(
        PreparedImage._(
          file: target,
          width: image.width,
          height: image.height,
          byteLength: bytes.length,
          format: 'png',
          wasResized: false,
        ),
        source: 'mask for ${image.width}x${image.height}',
      );
    } on ImagePreparationException {
      rethrow;
    } catch (error) {
      assert(() {
        debugPrint('Mask preparation failed: $error');
        return true;
      }());
      throw const ImagePreparationException(preparationFailedMessage);
    } finally {
      raster?.dispose();
    }
  }

  static String _extensionOf(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'png';
    final ext = name.substring(dot + 1).toLowerCase();
    return ext.length <= 4 && ext.isNotEmpty ? ext : 'png';
  }
}
