import '../models/models.dart';
import '../widgets/demo_image.dart';

/// Static catalog data mirroring the Enhanzo prototype.
class Catalog {
  Catalog._();

  static const List<ToolCategory> categories = [
    ToolCategory('Enhance', [
      Tool(
        'AI Enhance',
        'One-tap quality boost',
        scene: DemoScene.landscape,
        art: 'ai_enhance',
      ),
      Tool(
        'HD Upscale',
        'Up to 8K resolution',
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

  /// Look up a tool by name for scene-aware previews in the edit flow.
  static Tool toolNamed(String name) {
    for (final cat in categories) {
      for (final tool in cat.tools) {
        if (tool.name == name) return tool;
      }
    }
    return categories.first.tools.first;
  }

  // Subscription plans are not listed here — they're not a fixed catalog fact
  // like a tool is. RevenueCat's hosted paywall renders them from its own
  // dashboard configuration (see lib/widgets/paywall.dart), so the plans,
  // prices and trial wording always match what the store will actually charge.
}
