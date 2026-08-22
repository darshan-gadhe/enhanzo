import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'app_info.dart';
import 'image_ops.dart';

/// Where a photo comes into the app from.
enum PhotoSource { gallery, camera }

/// The user's photo, on its way into an edit.
///
/// Wraps `image_picker` so the rest of the app deals in [File]s and one failure
/// type rather than platform channels: a cancelled pick is `null`, and a denied
/// permission or a broken picker is a [PhotoPickException] with something worth
/// showing the user.
class PhotoLibrary {
  PhotoLibrary._();

  static final ImagePicker _picker = ImagePicker();

  /// Asks for one photo. Returns null when the user backs out.
  ///
  /// The platform downsizes on the way out: a modern phone camera produces far
  /// more pixels than the model needs, and shrinking here saves the upload
  /// rather than the render.
  static Future<File?> pick({PhotoSource source = PhotoSource.gallery}) async {
    try {
      final picked = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: ImageOps.maxSourceEdge.toDouble(),
        maxHeight: ImageOps.maxSourceEdge.toDouble(),
        imageQuality: 92,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (error) {
      throw PhotoPickException(_messageFor(error, source));
    }
  }

  static String _messageFor(Object error, PhotoSource source) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('denied')) {
      return source == PhotoSource.camera
          ? '${AppInfo.shortName} needs camera access to take a photo.'
          : '${AppInfo.shortName} needs photo access to open your library.';
    }
    if (text.contains('camera_access_denied')) {
      return '${AppInfo.shortName} needs camera access to take a photo.';
    }
    return "That photo couldn't be opened. Try another one.";
  }
}

/// A pick that failed for a reason the user can act on.
class PhotoPickException implements Exception {
  final String message;
  const PhotoPickException(this.message);

  @override
  String toString() => message;
}
