import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One continuous drag of the mask brush, in normalised image space.
///
/// Points are fractions of the image's width and height rather than pixels, so
/// a mask painted on a preview of any size rasterises correctly onto the
/// prepared upload — which may be a different size, since
/// [ImageOps.prepareForUpload] downscales to the model's budget. Storing pixels
/// here would tie the mask to whatever the canvas happened to be that day.
@immutable
class MaskStroke {
  final List<Offset> points;

  /// Brush radius as a fraction of the image's shorter edge, so a stroke keeps
  /// its apparent thickness whatever the image's aspect ratio.
  final double radius;

  const MaskStroke({required this.points, required this.radius});

  MaskStroke extendedTo(Offset point) =>
      MaskStroke(points: [...points, point], radius: radius);
}

/// Where an outpaint should add canvas, in pixels of the prepared image.
@immutable
class Expansion {
  final int up;
  final int down;
  final int left;
  final int right;

  const Expansion({this.up = 0, this.down = 0, this.left = 0, this.right = 0});

  static const Expansion none = Expansion();

  bool get isEmpty => up == 0 && down == 0 && left == 0 && right == 0;

  Expansion copyWith({int? up, int? down, int? left, int? right}) => Expansion(
    up: up ?? this.up,
    down: down ?? this.down,
    left: left ?? this.left,
    right: right ?? this.right,
  );
}

/// What the background remover should leave behind.
enum BackgroundStyle {
  transparent('Transparent', 'rgba'),
  white('White', 'white'),
  green('Green screen', 'green'),
  blur('Blurred', 'blur');

  final String label;

  /// The value the model's `background_type` takes. The proxy allow-lists
  /// exactly these, so a value invented here would be refused.
  final String value;

  const BackgroundStyle(this.label, this.value);
}

/// Everything the user supplied on a tool's settings step.
///
/// One object rather than a parameter per tool: the flow carries it, the job
/// hands it to the model, and a tool that needs nothing simply reads nothing
/// from it.
@immutable
class ToolOptions {
  /// What the user typed, for the tools that generate rather than repair.
  final String prompt;

  /// The painted region, in normalised coordinates.
  final List<MaskStroke> strokes;

  final BackgroundStyle background;
  final Expansion expansion;

  const ToolOptions({
    this.prompt = '',
    this.strokes = const [],
    this.background = BackgroundStyle.transparent,
    this.expansion = Expansion.none,
  });

  bool get hasMask => strokes.any((s) => s.points.isNotEmpty);
  bool get hasPrompt => prompt.trim().isNotEmpty;

  ToolOptions copyWith({
    String? prompt,
    List<MaskStroke>? strokes,
    BackgroundStyle? background,
    Expansion? expansion,
  }) {
    return ToolOptions(
      prompt: prompt ?? this.prompt,
      strokes: strokes ?? this.strokes,
      background: background ?? this.background,
      expansion: expansion ?? this.expansion,
    );
  }

  /// Rasterises [strokes] into the mask image the model expects.
  ///
  /// White is the region to change, black is the region to keep — the
  /// convention LaMa and Stable Diffusion inpainting both use. Sized to the
  /// *prepared upload*, not to the canvas the user painted on, which is why
  /// the strokes are stored normalised.
  ///
  /// Returns null when nothing was painted: a caller must not upload an
  /// all-black mask and ask the model to change nothing.
  Future<ui.Image?> rasteriseMask(int width, int height) async {
    if (!hasMask || width <= 0 || height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF000000),
    );

    final shortest = math.min(width, height);
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, stroke.radius * shortest * 2)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.dx * width, first.dy * height);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * width, point.dy * height);
      }
      // A single tap is a dot, not a zero-length line the stroke painter
      // would drop entirely.
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(first.dx * width, first.dy * height),
          math.max(1, stroke.radius * shortest),
          Paint()..color = const Color(0xFFFFFFFF),
        );
      } else {
        canvas.drawPath(path, paint);
      }
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
