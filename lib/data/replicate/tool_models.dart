import 'real_esrgan.dart';

/// One catalog tool's model: which weights to run, and what to ask them for.
///
/// The app runs more than one model now, and they take genuinely different
/// inputs — an upscaler wants a scale factor, a background remover wants an
/// output format. This is the seam that lets [EnhanceJob] stay one pipeline:
/// prepare, upload, predict, download, with the model deciding only what goes
/// in the `input` object.
///
/// Every implementation must be permitted by the Cloudflare proxy, which
/// validates the version *and* rebuilds the input from its own per-model schema
/// (`cloudflare/replicate-proxy/src/validate.ts`). A model added here and not
/// there is refused with "That model version is not available through this
/// endpoint" — deliberately, since the proxy is what stops a stolen app key
/// from running anything it likes on the account.
abstract class ToolModel {
  const ToolModel();

  /// Pinned `owner/name:digest`. Never a bare tag: that would silently follow
  /// upstream changes to both the weights and the input schema.
  String get version;

  /// The `input` object for a run against [imageUrl].
  Map<String, Object?> inputFor(Uri imageUrl);

  /// What the run did, short enough for a History chip.
  String get label;

  /// The same fact as a line the result screen can show on its own.
  ///
  /// Separate from [label] because the two read differently: "Enhanced 4x ·
  /// Faces" is a sentence, "Enhanced Transparent PNG" is not. Each model
  /// writes its own rather than the screen gluing a prefix onto a badge.
  String get resultSummary;
}

/// Real-ESRGAN, with optional GFPGAN face restoration — the four enhance tools.
class RealEsrganModel extends ToolModel {
  final RealEsrganPreset preset;

  const RealEsrganModel(this.preset);

  @override
  String get version => RealEsrgan.version;

  @override
  Map<String, Object?> inputFor(Uri imageUrl) =>
      RealEsrgan.inputFor(imageUrl: imageUrl, preset: preset);

  @override
  String get label => preset.label;

  @override
  String get resultSummary => 'Enhanced ${preset.label}';
}

/// `851-labs/background-remover` — segments the subject and drops the rest.
///
/// Takes only an image, which is why this is the one background/object tool the
/// app can offer today: everything else in those categories needs a mask the
/// user paints or a prompt they type, and neither of those surfaces exists.
///
/// Returns a single image URL, the same shape the upscaler returns, so nothing
/// downstream has to special-case it.
class BackgroundRemoverModel extends ToolModel {
  const BackgroundRemoverModel();

  @override
  String get version =>
      '851-labs/background-remover:'
      'a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc';

  @override
  Map<String, Object?> inputFor(Uri imageUrl) => {
    'image': imageUrl.toString(),
    // PNG, because the result has an alpha channel and JPEG cannot carry one —
    // asking for jpg here would silently composite the cut-out onto black.
    'format': 'png',
    // Transparent background rather than a flat colour: it composites onto
    // whatever the user puts it on later.
    'background_type': 'rgba',
    // Soft alpha. A hard threshold cuts cleanly through hair and fur, which is
    // exactly where a cut-out looks fake.
    'threshold': 0,
    'reverse': false,
  };

  @override
  String get label => 'Cutout';

  @override
  String get resultSummary => 'Background removed · transparent PNG';
}

/// Which model is behind each tool — the single answer to "can the app
/// actually do this one".
///
/// [Catalog] filters itself through [supports], so a tool with no model here
/// is not shown at all. That is the rule that keeps the catalog honest: every
/// tool a user can tap is a tool that runs.
class ToolModels {
  ToolModels._();

  static const Map<String, ToolModel> _models = {
    // A gentle all-round pass: modest upscale, faces cleaned up.
    'AI Enhance': RealEsrganModel(
      RealEsrganPreset(scale: 2, faceEnhance: true),
    ),
    // The resolution tool: the model's full 4x with no face pass, so detail
    // stays as the model reconstructs it.
    'HD Upscale': RealEsrganModel(
      RealEsrganPreset(scale: 4, faceEnhance: false),
    ),
    // Soft and out-of-focus shots gain most from a big upscale plus faces.
    'Unblur': RealEsrganModel(RealEsrganPreset(scale: 4, faceEnhance: true)),
    // Old prints are usually small and portrait-heavy.
    'Restore Photo': RealEsrganModel(
      RealEsrganPreset(scale: 4, faceEnhance: true),
    ),
    'Remove BG': BackgroundRemoverModel(),
  };

  static bool supports(String tool) => _models.containsKey(tool);

  static ToolModel? forTool(String tool) => _models[tool];

  /// Names of every tool backed by real inference, for messaging and tests.
  static List<String> get supportedTools => _models.keys.toList();
}
