import '../models/models.dart';
import '../widgets/demo_image.dart';
import 'replicate/tool_models.dart';

/// The tools the app offers.
///
/// [categories] is filtered: it contains only tools that have a model behind
/// them, and drops any category that empties out as a result. That filter is
/// the point. Seven of these tools — background replacement, object and people
/// removal, watermark removal, the eraser, inpainting and canvas expansion —
/// need something the app has no surface for: a mask the user paints, or a
/// prompt they type. Listing them anyway meant a user picked a photo, chose a
/// crop, waited, and only then read that the tool "needs a model this build
/// doesn't have yet". An advertised feature that dead-ends is worse than one
/// that isn't advertised.
///
/// They stay authored in [allCategories] rather than being deleted, so
/// restoring one is a matter of giving it a model in [ToolModels] — the
/// filter picks it up with no change here.
class Catalog {
  Catalog._();

  /// Everything ever authored, shown or not. Art assets are keyed off this, so
  /// a hidden tool keeps its imagery ready for the day it comes back.
  static const List<ToolCategory> allCategories = [
    ToolCategory('Enhance', [
      Tool(
        'AI Enhance',
        'One-tap quality boost',
        scene: DemoScene.landscape,
        art: 'ai_enhance',
      ),
      Tool(
        'HD Upscale',
        'Up to 4x resolution',
        scene: DemoScene.city,
        seed: 11,
        art: 'hd_upscale',
      ),
      Tool(
        'Unblur',
        'Fix motion & focus',
        scene: DemoScene.flower,
        seed: 3,
        art: 'unblur',
      ),
      Tool(
        'Restore Photo',
        'Repair old & damaged',
        scene: DemoScene.oldPhoto,
        art: 'restore_photo',
      ),
    ]),
    ToolCategory('Background', [
      Tool(
        'Remove BG',
        'Cut out instantly',
        scene: DemoScene.flower,
        art: 'remove_bg',
      ),
      Tool(
        'Replace BG',
        'Swap the scene',
        scene: DemoScene.sunset,
        art: 'replace_bg',
      ),
    ]),
    ToolCategory('Object', [
      Tool(
        'Object Removal',
        'Erase anything',
        scene: DemoScene.city,
        seed: 4,
        art: 'object_removal',
      ),
      Tool(
        'Remove People',
        'Clear the frame',
        scene: DemoScene.landscape,
        seed: 9,
        art: 'remove_people',
      ),
      Tool(
        'Watermark Remove',
        'Clean up logos',
        scene: DemoScene.sunset,
        seed: 5,
        art: 'watermark_remove',
      ),
      Tool(
        'Magic Eraser',
        'Brush to delete',
        scene: DemoScene.flower,
        seed: 14,
        art: 'magic_eraser',
      ),
    ]),
    ToolCategory('Generate', [
      Tool(
        'AI Expand',
        'Extend the canvas',
        scene: DemoScene.landscape,
        seed: 19,
        art: 'ai_expand',
      ),
      Tool(
        'Inpainting',
        'Fill any region',
        scene: DemoScene.city,
        seed: 23,
        art: 'inpainting',
      ),
    ]),
  ];

  /// The tools a user can actually reach: those with a model behind them.
  ///
  /// Derived rather than hand-maintained, so the shown set and the working set
  /// cannot drift apart — which is exactly how seven dead tools came to be on
  /// the home screen.
  static List<ToolCategory> get categories => [
    for (final category in allCategories)
      if (category.tools.any((t) => ToolModels.supports(t.name)))
        ToolCategory(
          category.name,
          [
            for (final tool in category.tools)
              if (ToolModels.supports(tool.name)) tool,
          ],
        ),
  ];

  /// Look up a tool by name for scene-aware previews in the edit flow.
  ///
  /// Searches [allCategories], not the filtered list: a name that reaches here
  /// should resolve to its own art even if the tool is currently hidden,
  /// rather than silently falling back to a different tool's.
  static Tool toolNamed(String name) {
    for (final cat in allCategories) {
      for (final tool in cat.tools) {
        if (tool.name == name) return tool;
      }
    }
    return allCategories.first.tools.first;
  }

  // Subscription plans are not listed here — they're not a fixed catalog fact
  // like a tool is. RevenueCat's hosted paywall renders them from its own
  // dashboard configuration (see lib/widgets/paywall.dart), so the plans,
  // prices and trial wording always match what the store will actually charge.
}
