/// The Replicate model behind the app's enhance tools.
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

  /// The tools this model actually implements, and what each one asks it for.
  ///
  /// The rest of the catalog (background removal, object erase, generation) is
  /// a different class of model and is deliberately absent rather than mapped
  /// onto an upscaler that cannot do the job — see [supports].
  static const Map<String, RealEsrganPreset> _presets = {
    // A gentle all-round pass: modest upscale, faces cleaned up.
    'AI Enhance': RealEsrganPreset(scale: 2, faceEnhance: true),
    // The resolution tool: the model's full 4× with no face pass, so detail
    // stays as the model reconstructs it.
    'HD Upscale': RealEsrganPreset(scale: 4, faceEnhance: false),
    // Soft and out-of-focus shots gain most from a big upscale plus faces.
    'Unblur': RealEsrganPreset(scale: 4, faceEnhance: true),
    // Old prints are usually small and portrait-heavy.
    'Restore Photo': RealEsrganPreset(scale: 4, faceEnhance: true),
  };

  /// Whether [tool] runs on this model.
  static bool supports(String tool) => _presets.containsKey(tool);

  /// Settings for [tool], or null when the model doesn't implement it.
  static RealEsrganPreset? presetFor(String tool) => _presets[tool];

  /// Names of every tool backed by real inference, for messaging.
  static List<String> get supportedTools => _presets.keys.toList();

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
