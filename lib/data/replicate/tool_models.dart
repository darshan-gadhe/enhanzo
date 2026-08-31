import '../../models/tool_options.dart';
import 'real_esrgan.dart';

/// What a tool needs from the user before it can run.
///
/// The flow reads this to decide whether to show a settings step, and what to
/// put on it. A tool that needs nothing goes straight from crop to processing,
/// exactly as the four enhance tools always have.
enum ToolNeeds {
  /// Nothing beyond the photo itself.
  nothing,

  /// A painted region. The mask is uploaded alongside the photo.
  mask,

  /// A painted region and a description of what to put there.
  maskAndPrompt,

  /// A description of what to generate in the new space.
  promptAndDirection,

  /// A choice of what the background becomes.
  background,
}

/// One catalog tool's model: which weights to run, and what to ask them for.
///
/// The app runs several models now and they take genuinely different inputs —
/// an upscaler wants a scale factor, an inpainter wants a mask and a prompt.
/// This is the seam that lets [EnhanceJob] stay one pipeline: prepare, upload,
/// predict, download, with the model deciding only what goes in `input`.
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

  /// What the user must supply first.
  ToolNeeds get needs => ToolNeeds.nothing;

  /// Longest edge this model can be handed, or null for the shared default.
  ///
  /// Not every model has the same ceiling, and finding that out the hard way
  /// is expensive: Stable Diffusion inpainting tried to allocate 51 GiB when
  /// given a 1373px photo that the upscaler processes without complaint.
  int? get maxEdge => null;

  /// Pixel ceiling, or null for the shared default.
  int? get maxPixels => null;

  /// The `input` object for a run.
  ///
  /// [maskUrl] is non-null exactly when [needs] asks for a mask; the job
  /// uploads it and passes it through.
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  });

  /// What the run did, short enough for a History chip.
  String get label;

  /// The same fact as a line the result screen can show on its own.
  String get resultSummary;
}

/// Real-ESRGAN, with optional GFPGAN face restoration — the enhance tools.
class RealEsrganModel extends ToolModel {
  final RealEsrganPreset preset;

  const RealEsrganModel(this.preset);

  @override
  String get version => RealEsrgan.version;

  @override
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  }) => RealEsrgan.inputFor(imageUrl: imageUrl, preset: preset);

  @override
  String get label => preset.label;

  @override
  String get resultSummary => 'Enhanced ${preset.label}';
}

/// `851-labs/background-remover` — segments the subject and replaces the rest.
///
/// Backs two tools. Remove BG leaves transparency; Replace BG swaps in white,
/// a green screen or a blur, which is the same model call with a different
/// `background_type`. Both are real: the model does the work either way.
class BackgroundModel extends ToolModel {
  /// Fixed for Remove BG; chosen by the user for Replace BG.
  final bool userChoosesBackground;

  const BackgroundModel({this.userChoosesBackground = false});

  @override
  String get version =>
      '851-labs/background-remover:'
      'a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc';

  @override
  ToolNeeds get needs =>
      userChoosesBackground ? ToolNeeds.background : ToolNeeds.nothing;

  @override
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  }) {
    final style = userChoosesBackground
        ? options.background
        : BackgroundStyle.transparent;
    return {
      'image': imageUrl.toString(),
      // PNG throughout: transparency needs an alpha channel, and JPEG would
      // silently composite the cut-out onto black.
      'format': 'png',
      'background_type': style.value,
      // Soft alpha. A hard threshold cuts cleanly through hair and fur, which
      // is exactly where a cut-out looks fake.
      'threshold': 0,
      'reverse': false,
    };
  }

  @override
  String get label => userChoosesBackground ? 'New background' : 'Cutout';

  @override
  String get resultSummary => userChoosesBackground
      ? 'Background replaced'
      : 'Background removed · transparent PNG';
}

/// `allenhooo/lama` — fills a painted region from its surroundings.
///
/// Backs four catalog tools, and they are the same operation: erase what is
/// under the brush and reconstruct what was behind it. Object Removal, Remove
/// People, Watermark Remove and Magic Eraser differ in what the user points it
/// at and in nothing else, which is why they share a model rather than each
/// pretending to a different one.
class InpaintFillModel extends ToolModel {
  /// Names the run in History, so four tools do not all read "Erased".
  final String action;

  const InpaintFillModel(this.action);

  @override
  String get version =>
      'allenhooo/lama:'
      'cdac78a1bec5b23c07fd29692fb70baa513ea403a39e643c48ec5edadb15fe72';

  @override
  ToolNeeds get needs => ToolNeeds.mask;

  @override
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  }) => {
    'image': imageUrl.toString(),
    'mask': maskUrl.toString(),
  };

  @override
  String get label => action;

  @override
  String get resultSummary => '$action from your photo';
}

/// `andreasjansson/stable-diffusion-inpainting` — paints something new into a
/// masked region, guided by a prompt.
class PromptInpaintModel extends ToolModel {
  const PromptInpaintModel();

  /// Stable Diffusion 1.5 inpainting is a 512px model. Handed more, it does
  /// not downscale — it tries to allocate for what it was given and dies:
  ///
  /// ```text
  /// CUDA out of memory. Tried to allocate 50.96 GiB (GPU 0; 79.25 GiB total)
  /// ```
  ///
  /// Found by running it, not by reading about it.
  ///
  /// The cost is visible to the user: a 1000x667 photo comes back 512x336,
  /// which is a downgrade rather than an edit. [label] and [resultSummary]
  /// say so rather than letting it be discovered.
  @override
  int get maxEdge => 512;

  @override
  int get maxPixels => 512 * 512;

  @override
  String get version =>
      'andreasjansson/stable-diffusion-inpainting:'
      'e490d072a34a94a11e9711ed5a6ba621c3fab884eda1665d9d3a282d65a21180';

  @override
  ToolNeeds get needs => ToolNeeds.maskAndPrompt;

  @override
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  }) => {
    'image': imageUrl.toString(),
    'mask': maskUrl.toString(),
    'prompt': options.prompt.trim(),
    'num_outputs': 1,
    'num_inference_steps': 25,
    'guidance_scale': 7.5,
    'invert_mask': false,
  };

  @override
  String get label => 'Filled · 512px';

  @override
  String get resultSummary =>
      'Painted into your photo · 512px, this model\'s native size';
}

/// `fermatresearch/sdxl-outpainting-lora` — extends the canvas outwards and
/// generates what belongs in the new space.
class OutpaintModel extends ToolModel {
  const OutpaintModel();

  @override
  String get version =>
      'fermatresearch/sdxl-outpainting-lora:'
      'a542ccf352995f3c41f0bcfaef641daa3058bf2b00e08e04feb0295334ab9804';

  @override
  ToolNeeds get needs => ToolNeeds.promptAndDirection;

  @override
  Map<String, Object?> inputFor({
    required Uri imageUrl,
    Uri? maskUrl,
    ToolOptions options = const ToolOptions(),
  }) {
    final expand = options.expansion;
    return {
      'image': imageUrl.toString(),
      'prompt': options.prompt.trim(),
      'outpaint_up': expand.up,
      'outpaint_down': expand.down,
      'outpaint_left': expand.left,
      'outpaint_right': expand.right,
      'num_outputs': 1,
      'guidance_scale': 7.5,
      // The model watermarks its output by default. The user's photo is theirs.
      'apply_watermark': false,
    };
  }

  @override
  String get label => 'Expanded';

  @override
  String get resultSummary => 'Canvas expanded';
}

/// Which model is behind each tool.
///
/// [Catalog] filters itself through [supports], so a tool with no model here is
/// not shown at all — the rule that keeps the catalog honest.
class ToolModels {
  ToolModels._();

  static const Map<String, ToolModel> _models = {
    // ── Enhance: Real-ESRGAN ──
    'AI Enhance': RealEsrganModel(
      RealEsrganPreset(scale: 2, faceEnhance: true),
    ),
    'HD Upscale': RealEsrganModel(
      RealEsrganPreset(scale: 4, faceEnhance: false),
    ),
    'Unblur': RealEsrganModel(RealEsrganPreset(scale: 4, faceEnhance: true)),
    'Restore Photo': RealEsrganModel(
      RealEsrganPreset(scale: 4, faceEnhance: true),
    ),

    // ── Background: one model, two framings ──
    'Remove BG': BackgroundModel(),
    'Replace BG': BackgroundModel(userChoosesBackground: true),

    // ── Object: one model, four framings. See InpaintFillModel. ──
    'Object Removal': InpaintFillModel('Object removed'),
    'Remove People': InpaintFillModel('People removed'),
    'Watermark Remove': InpaintFillModel('Watermark removed'),
    'Magic Eraser': InpaintFillModel('Erased'),

    // ── Generate ──
    'Inpainting': PromptInpaintModel(),
    'AI Expand': OutpaintModel(),
  };

  static bool supports(String tool) => _models.containsKey(tool);

  static ToolModel? forTool(String tool) => _models[tool];

  static ToolNeeds needsFor(String tool) =>
      _models[tool]?.needs ?? ToolNeeds.nothing;

  /// Names of every tool backed by real inference, for messaging and tests.
  static List<String> get supportedTools => _models.keys.toList();
}
