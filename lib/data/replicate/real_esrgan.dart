/// Real-ESRGAN itself: the pinned version, and the shape of its input.
///
/// Which *tools* run on it lives in [ToolModels], alongside every other model
/// the app can run — this file is only about this one model.
///
/// `daanelson/real-esrgan-a100` is Real-ESRGAN with optional GFPGAN face
/// restoration. It takes an image URL, an upscale factor and a face-enhance
/// flag, and returns one upscaled image URL:
///
/// ```sh
/// curl -s -X POST \
///   -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
///   -H "Content-Type: application/json" \
///   -H "Prefer: wait" \
///   -d '{
///     "version": "daanelson/real-esrgan-a100:f94d7ed4…",
///     "input": {"image": "https://…/photo.png", "scale": 4, "face_enhance": true}
///   }' \
///   https://api.replicate.com/v1/predictions
/// ```
class RealEsrgan {
  RealEsrgan._();

  /// Pinned version. A bare model name would silently follow upstream changes;
  /// the digest keeps every build asking for the same weights and the same
  /// input schema.
  static const String version =
      'daanelson/real-esrgan-a100:'
      'f94d7ed4a1f7e1ffed0d51e4089e4911609d5eeee5e874ef323d2c7562624bed';

  /// The `input` object for a run against [imageUrl].
  static Map<String, Object?> inputFor({
    required Uri imageUrl,
    required RealEsrganPreset preset,
  }) {
    return {
      'image': imageUrl.toString(),
      'scale': preset.scale,
      'face_enhance': preset.faceEnhance,
    };
  }
}

/// One tool's settings for [RealEsrgan].
class RealEsrganPreset {
  /// Upscale factor passed to the model.
  final int scale;

  /// Whether GFPGAN face restoration runs after the upscale.
  final bool faceEnhance;

  const RealEsrganPreset({required this.scale, required this.faceEnhance});

  /// What the run actually did, for the result screen and the history badge —
  /// the real parameters, not an export size the app never applied.
  String get label => faceEnhance ? '${scale}x · Faces' : '${scale}x';
}
