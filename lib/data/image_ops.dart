import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Pixel work the edit flow does on the device before anything is uploaded.
class ImageOps {
  ImageOps._();

  /// Longest edge of the image handed to the model.
  ///
  /// Real-ESRGAN multiplies whatever it is given, so a 4032px phone photo at 4×
  /// is a 16k render — slow, expensive, and beyond what the app then displays.
  /// The picker already asks the platform for something around this size; this
  /// is the backstop for sources that ignore it.
  static const int maxSourceEdge = 2048;

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

  /// Writes a centre crop of [source] at [aspectRatio] (width ÷ height) to
  /// [targetPath] and returns it.
  ///
  /// This is what makes the crop step real: the frame chosen there is the frame
  /// that reaches the model, not a label over an untouched upload. A null
  /// [aspectRatio] means "keep the photo's own proportions", in which case the
  /// file is only re-encoded if it exceeds [maxSourceEdge].
  ///
  /// The centre crop matches the crop canvas exactly — it lays the photo out
  /// with `BoxFit.cover` inside the chosen ratio, which shows precisely this
  /// region. On any decode failure the original file is returned unchanged, so
  /// a photo the engine can't read still gets its chance at the model.
  static Future<File> cropToRatio(
    File source, {
    required double? aspectRatio,
    required String targetPath,
  }) async {
    ui.Image? decoded;
    try {
      final bytes = await source.readAsBytes();
      decoded = await decodeImageFromList(bytes);

      final srcW = decoded.width.toDouble();
      final srcH = decoded.height.toDouble();
      if (srcW <= 0 || srcH <= 0) return source;

      // Region of the original that survives the crop.
      final ratio = aspectRatio ?? srcW / srcH;
      var cropW = srcW;
      var cropH = srcW / ratio;
      if (cropH > srcH) {
        cropH = srcH;
        cropW = srcH * ratio;
      }
      final srcRect = Rect.fromLTWH(
        (srcW - cropW) / 2,
        (srcH - cropH) / 2,
        cropW,
        cropH,
      );

      // Output size: the crop, scaled down if it is still oversized.
      final longest = cropW > cropH ? cropW : cropH;
      final scale = longest > maxSourceEdge ? maxSourceEdge / longest : 1.0;
      final outW = (cropW * scale).round().clamp(1, maxSourceEdge);
      final outH = (cropH * scale).round().clamp(1, maxSourceEdge);

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        decoded,
        srcRect,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      ui.Image cropped;
      try {
        cropped = await picture.toImage(outW, outH);
      } finally {
        picture.dispose();
      }

      try {
        final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return source;
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        return file;
      } finally {
        cropped.dispose();
      }
    } catch (_) {
      // A crop is an optimisation, never a reason to fail the edit.
      return source;
    } finally {
      decoded?.dispose();
    }
  }
}
