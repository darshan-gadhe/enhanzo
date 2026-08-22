import 'package:flutter/widgets.dart';

import '../widgets/demo_image.dart';

/// A single tool, identified by its name and the demo scene used for its
/// before/after preview. Tools carry no colour of their own: what a tool does
/// is shown by its preview, not by an arbitrary tint.
@immutable
class Tool {
  final String name;
  final String desc;
  final DemoScene scene;
  final int seed;

  /// Asset key for this tool's real before/after photography, e.g.
  /// `'ai_enhance'` → `assets/tools/ai_enhance_before.webp` +
  /// `assets/tools/ai_enhance_after.webp`. Null falls back to the procedural
  /// [scene] painter, so a tool without art still renders.
  final String? art;

  const Tool(
    this.name,
    this.desc, {
    this.scene = DemoScene.landscape,
    this.seed = 7,
    this.art,
  });
}

/// The crop frames offered before an edit runs.
///
/// The ratio chosen here follows the photo through the flow and frames the
/// result, so picking one is a real decision rather than a label on a fixed
/// canvas.
enum CropRatio {
  /// Keep the source photo's own proportions.
  free('Free', null),
  square('1:1', 1),
  portrait('3:4', 3 / 4),
  wide('16:9', 16 / 9);

  /// Chip label.
  final String label;

  /// Width ÷ height, or null to inherit the source's ratio.
  final double? value;

  const CropRatio(this.label, this.value);

  /// Proportions to actually lay out with.
  ///
  /// [free] has no ratio of its own, so it falls back to the shape the canvas
  /// used before any choice was made.
  double resolve() => value ?? portrait.value!;
}

/// A named group of tools.
@immutable
class ToolCategory {
  final String name;
  final List<Tool> tools;

  const ToolCategory(this.name, this.tools);

  /// Count label for the section header. Derived from the list so it can never
  /// advertise more tools than the category actually holds.
  String get count => '${tools.length} ${tools.length == 1 ? 'tool' : 'tools'}';
}

/// A completed edit shown in History.
@immutable
class HistoryEntry {
  final int id;
  final String tool;
  final DateTime time;
  final String badge;
  final DemoScene scene;
  final int seed;

  /// Asset key for this edit's real photography (see [Tool.art]). Null renders
  /// the procedural [scene] instead.
  final String? art;

  /// Path to the photo that was sent to the model, and to the image it
  /// returned — set only for edits that really ran. Both null on a simulated
  /// edit, which falls back to [art] and then to [scene].
  final String? sourcePath;
  final String? resultPath;

  const HistoryEntry({
    required this.id,
    required this.tool,
    required this.time,
    required this.badge,
    required this.scene,
    this.seed = 7,
    this.art,
    this.sourcePath,
    this.resultPath,
  });

  /// True when this entry has a real file behind it — the condition for
  /// showing it full-size, comparing it, or sharing it.
  bool get hasImages => resultPath != null;
}

// The `Plan` / `PlanId` view-models that used to live here are gone with the
// custom paywall. Plan names, prices, badges and trial wording are now
// RevenueCat's to render — this app never rebuilds them as its own types, so
// there is nothing left here to keep in sync with the dashboard.
