import 'dart:io';

import 'package:flutter/material.dart';

import '../models/tool_options.dart';
import '../theme/theme.dart';
import 'components/components.dart';
import 'demo_image.dart';
import 'edit_image.dart';

/// Paint over the part of a photo a tool should change.
///
/// Strokes are recorded in **normalised** coordinates — fractions of the
/// widget's width and height — not pixels. The mask has to line up with the
/// image the model receives, which is the prepared upload and may be a
/// different size to whatever this canvas happened to be; normalised strokes
/// rasterise correctly onto either. See [ToolOptions.rasteriseMask].
///
/// The overlay is drawn semi-transparent so the photo stays visible underneath
/// while painting. What the model gets is the hard black-and-white mask, not
/// this preview.
class MaskCanvas extends StatefulWidget {
  final File? photo;
  final ToolOptions options;
  final ValueChanged<ToolOptions> onChanged;

  const MaskCanvas({
    super.key,
    required this.photo,
    required this.options,
    required this.onChanged,
  });

  @override
  State<MaskCanvas> createState() => _MaskCanvasState();
}

class _MaskCanvasState extends State<MaskCanvas> {
  /// Brush radius as a fraction of the shorter edge. Roughly a fingertip on a
  /// phone-sized canvas.
  double _radius = 0.06;

  Size _canvas = Size.zero;

  Offset _normalise(Offset local) {
    if (_canvas.width <= 0 || _canvas.height <= 0) return Offset.zero;
    return Offset(
      (local.dx / _canvas.width).clamp(0.0, 1.0),
      (local.dy / _canvas.height).clamp(0.0, 1.0),
    );
  }

  void _startStroke(Offset local) {
    final stroke = MaskStroke(points: [_normalise(local)], radius: _radius);
    widget.onChanged(
      widget.options.copyWith(strokes: [...widget.options.strokes, stroke]),
    );
  }

  void _extendStroke(Offset local) {
    final strokes = widget.options.strokes;
    if (strokes.isEmpty) return;
    final extended = [...strokes];
    extended[extended.length - 1] =
        extended.last.extendedTo(_normalise(local));
    widget.onChanged(widget.options.copyWith(strokes: extended));
  }

  void _undo() {
    final strokes = widget.options.strokes;
    if (strokes.isEmpty) return;
    widget.onChanged(
      widget.options.copyWith(strokes: strokes.sublist(0, strokes.length - 1)),
    );
  }

  void _clear() =>
      widget.onChanged(widget.options.copyWith(strokes: const []));

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _canvas = Size(constraints.maxWidth, constraints.maxHeight);
              return ClipRRect(
                borderRadius: AppRadius.brXl,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EditImage(
                      file: widget.photo,
                      scene: DemoScene.landscape,
                    ),
                    // The gesture layer sits above the photo so a drag paints
                    // rather than scrolling whatever is behind it.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _startStroke(d.localPosition),
                      onPanUpdate: (d) => _extendStroke(d.localPosition),
                      onTapDown: (d) => _startStroke(d.localPosition),
                      child: CustomPaint(
                        painter: _MaskPainter(
                          strokes: widget.options.strokes,
                          color: p.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Row(
          children: [
            Text('Brush', style: AppText.captionMd(p.textSecondary)),
            Expanded(
              child: Slider(
                value: _radius,
                min: 0.02,
                max: 0.16,
                onChanged: (v) => setState(() => _radius = v),
              ),
            ),
            _MaskAction(
              icon: AppIcons.refresh,
              label: 'Undo',
              onTap: widget.options.strokes.isEmpty ? null : _undo,
            ),
            const SizedBox(width: AppSpacing.innerGap),
            _MaskAction(
              icon: AppIcons.close,
              label: 'Clear',
              onTap: widget.options.strokes.isEmpty ? null : _clear,
            ),
          ],
        ),
      ],
    );
  }
}

class _MaskAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MaskAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: AppPressable(
        onTap: onTap ?? () {},
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: Icon(icon, size: AppSizing.iconLg, color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Draws the painted region over the photo.
///
/// Semi-transparent on purpose: the point of painting is seeing what is
/// underneath, and an opaque overlay would hide the thing being targeted.
class _MaskPainter extends CustomPainter {
  final List<MaskStroke> strokes;
  final Color color;

  const _MaskPainter({required this.strokes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.radius * shortest * 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final scaled = [
        for (final point in stroke.points)
          Offset(point.dx * size.width, point.dy * size.height),
      ];

      if (scaled.length == 1) {
        canvas.drawCircle(
          scaled.first,
          stroke.radius * shortest,
          Paint()..color = color.withValues(alpha: 0.45),
        );
      } else {
        final path = Path()..moveTo(scaled.first.dx, scaled.first.dy);
        for (final point in scaled.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MaskPainter old) =>
      old.strokes != strokes || old.color != color;
}
