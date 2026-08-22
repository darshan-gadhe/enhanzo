import 'dart:math';

import 'package:flutter/material.dart';

/// The subjects available for demo imagery across the app.
enum DemoScene {
  portrait,
  landscape,
  sunset,
  city,
  flower,
  oldPhoto,
  anime,
  galaxy,
}

/// How a scene is rendered: the degraded original vs. the AI-enhanced output.
enum DemoVariant { before, after }

/// The native aspect ratio (width ÷ height) of the tool photography. The art is
/// shot at 3:2, so any card that wants to show a whole frame uncropped should
/// size its image box to this and let [DemoImage] fill it with `cover`.
const double kToolArtAspect = 3 / 2;

/// Shows a tool's imagery: real bundled photography when an [art] key is given,
/// otherwise a procedurally-painted stand-in so a tool without art still renders
/// believable content.
///
/// [art] is a tool key (e.g. `'ai_enhance'`); the widget resolves it to
/// `assets/tools/<art>_<before|after>.webp` for the current [variant]. If that
/// asset is missing at runtime it falls back to the [scene] painter rather than
/// showing a broken-image box.
class DemoImage extends StatelessWidget {
  final DemoScene scene;
  final DemoVariant variant;
  final int seed;

  /// Tool art key. When set, real photography is shown instead of [scene].
  final String? art;

  const DemoImage({
    super.key,
    required this.scene,
    this.variant = DemoVariant.after,
    this.seed = 7,
    this.art,
  });

  @override
  Widget build(BuildContext context) {
    if (art != null) {
      final suffix = variant == DemoVariant.before ? 'before' : 'after';
      final dpr = MediaQuery.devicePixelRatioOf(context);
      return RepaintBoundary(
        child: ClipRect(
          // Decode near the size the image is actually drawn at, not its full
          // 1536px master: a half-width grid tile shows this at ~170pt, so
          // decoding at the box width keeps a dozen on-screen comparisons off
          // the ~150MB of RAM that full-res copies would take. Capped at the
          // source width so it never decodes larger than it is.
          child: LayoutBuilder(
            builder: (context, c) {
              final boxW = c.maxWidth.isFinite
                  ? c.maxWidth
                  : MediaQuery.sizeOf(context).width;
              final cacheW = (boxW * dpr).round().clamp(1, 1536);
              // WebP, not PNG: these are photographic before/after masters at
              // 1536x1024, and as lossless PNGs they were ~3 MB each — 60 MB
              // of the bundle for 24 files. At WebP q90 the set is under 7 MB
              // with no visible difference, and the app ships less than half
              // the download it used to.
              return Image.asset(
                'assets/tools/${art}_$suffix.webp',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: cacheW,
                // A missing asset degrades to the procedural scene instead of a
                // broken-image glyph, so a mis-keyed tool never shows an error.
                errorBuilder: (_, _, _) => _procedural(),
              );
            },
          ),
        ),
      );
    }
    return _procedural();
  }

  Widget _procedural() {
    Widget image = CustomPaint(
      painter: _ScenePainter(scene: scene, seed: seed),
      size: Size.infinite,
    );

    if (variant == DemoVariant.before) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          scene == DemoScene.oldPhoto ? _sepia : _washedOut,
        ),
        child: image,
      );
      image = CustomPaint(
        foregroundPainter: _DamagePainter(
          seed: seed,
          scratches: scene == DemoScene.oldPhoto,
        ),
        child: image,
      );
    }

    return RepaintBoundary(child: ClipRect(child: image));
  }

  /// Desaturated + slightly dim: a dull phone-camera original.
  static const List<double> _washedOut = [
    0.60, 0.31, 0.03, 0, 14, //
    0.09, 0.82, 0.03, 0, 14, //
    0.09, 0.31, 0.54, 0, 14, //
    0, 0, 0, 1, 0,
  ];

  static const List<double> _sepia = [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// Film grain, vignette and (optionally) scratches layered over "before"
/// images so the enhanced side reads as a real repair.
class _DamagePainter extends CustomPainter {
  final int seed;
  final bool scratches;

  _DamagePainter({required this.seed, required this.scratches});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(seed);

    // Vignette.
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.32)],
        stops: const [0.62, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Grain.
    final grain = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.12);
    final count = (size.width * size.height / 240).clamp(60, 420).toInt();
    for (int i = 0; i < count; i++) {
      final p = Offset(
        rand.nextDouble() * size.width,
        rand.nextDouble() * size.height,
      );
      canvas.drawCircle(
        p,
        rand.nextDouble() * 0.9 + 0.3,
        rand.nextBool() ? grain : dark,
      );
    }

    if (!scratches) return;

    // Scratches + a torn corner for the restoration demo.
    final scratch = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.1;
    for (int i = 0; i < 4; i++) {
      final x = rand.nextDouble() * size.width;
      final sway = (rand.nextDouble() - 0.5) * size.width * 0.14;
      canvas.drawLine(
        Offset(x, -4),
        Offset(x + sway, size.height + 4),
        scratch,
      );
    }
    final tear = Path()
      ..moveTo(size.width, size.height * 0.72)
      ..lineTo(size.width * 0.86, size.height * 0.84)
      ..lineTo(size.width * 0.93, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      tear,
      Paint()..color = const Color(0xFFE8E0D0).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_DamagePainter old) =>
      old.seed != seed || old.scratches != scratches;
}

/// One portrait subject: backdrop, key-light glow, skin gradient, hair color.
class _PortraitLook {
  final List<Color> backdrop;
  final Color glow;
  final List<Color> skin;
  final Color hair;

  const _PortraitLook({
    required this.backdrop,
    required this.glow,
    required this.skin,
    required this.hair,
  });
}

class _ScenePainter extends CustomPainter {
  final DemoScene scene;
  final int seed;

  _ScenePainter({required this.scene, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene) {
      case DemoScene.portrait:
        _portrait(canvas, size);
      case DemoScene.landscape:
        _landscape(canvas, size);
      case DemoScene.sunset:
        _sunset(canvas, size);
      case DemoScene.city:
        _city(canvas, size);
      case DemoScene.flower:
        _flower(canvas, size);
      case DemoScene.oldPhoto:
        _oldPhoto(canvas, size);
      case DemoScene.anime:
        _anime(canvas, size);
      case DemoScene.galaxy:
        _galaxy(canvas, size);
    }
  }

  void _fill(
    Canvas canvas,
    Size size,
    List<Color> colors, {
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
    List<double>? stops,
  }) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
          stops: stops,
        ).createShader(Offset.zero & size),
    );
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double inner = 0.9,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: inner),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  // -- Studio portrait: backdrop, head-and-shoulders silhouette with a rim
  //    light, like a headshot session. Figure sizes derive from the short
  //    side so wide/tall crops keep human proportions. The seed picks one of
  //    a few subjects so portrait cards don't all look identical.
  static const List<_PortraitLook> _portraitLooks = [
    _PortraitLook(
      // Warm studio, brown hair.
      backdrop: [Color(0xFF977D66), Color(0xFF4A362A)],
      glow: Color(0xFFF2D6AC),
      skin: [Color(0xFFE9BB95), Color(0xFFA5744F)],
      hair: Color(0xFF2B211C),
    ),
    _PortraitLook(
      // Cool slate studio, black hair.
      backdrop: [Color(0xFF6F7E90), Color(0xFF2C3542)],
      glow: Color(0xFFD9E6F2),
      skin: [Color(0xFFD9A57E), Color(0xFF8F6242)],
      hair: Color(0xFF181820),
    ),
    _PortraitLook(
      // Mauve editorial, auburn hair.
      backdrop: [Color(0xFF8F6B7E), Color(0xFF3E2A38)],
      glow: Color(0xFFF2D8CE),
      skin: [Color(0xFFF0C6A2), Color(0xFFB07C55)],
      hair: Color(0xFF4A2A1E),
    ),
  ];

  void _portrait(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final s = min(w, h);
    final look = _portraitLooks[seed % _portraitLooks.length];
    _fill(
      canvas,
      size,
      look.backdrop,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    _glow(canvas, Offset(w * 0.40, h * 0.24), s * 0.95, look.glow, inner: 0.45);

    final cx = w * 0.5;
    // Shoulders / torso, anchored to the bottom edge.
    final shoulderTop = h - s * 0.40;
    final torso = Path()
      ..moveTo(cx - s * 0.56, h + 2)
      ..cubicTo(
        cx - s * 0.52,
        shoulderTop + s * 0.12,
        cx - s * 0.30,
        shoulderTop,
        cx - s * 0.12,
        shoulderTop + s * 0.02,
      )
      ..lineTo(cx + s * 0.12, shoulderTop + s * 0.02)
      ..cubicTo(
        cx + s * 0.32,
        shoulderTop,
        cx + s * 0.52,
        shoulderTop + s * 0.12,
        cx + s * 0.58,
        h + 2,
      )
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C4858), Color(0xFF201D28)],
        ).createShader(Offset.zero & size),
    );

    // Neck + head.
    final skin = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: look.skin,
          ).createShader(
            Rect.fromCenter(
              center: Offset(cx, h - s * 0.6),
              width: s,
              height: s,
            ),
          );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, h - s * 0.42),
        width: s * 0.15,
        height: s * 0.16,
      ),
      skin,
    );
    final head = Rect.fromCenter(
      center: Offset(cx, h - s * 0.62),
      width: s * 0.38,
      height: s * 0.46,
    );
    canvas.drawOval(head, skin);

    // Hair: a cap over the top of the head.
    final hair = Path()
      ..addArc(head.inflate(s * 0.025), pi, pi)
      ..cubicTo(
        head.right + s * 0.02,
        head.top + s * 0.12,
        head.right,
        head.top + s * 0.03,
        head.center.dx,
        head.top + s * 0.02,
      )
      ..close();
    canvas.drawPath(hair, Paint()..color = look.hair);

    // Rim light along the right edge of the face.
    canvas.drawArc(
      head.deflate(1.5),
      -pi * 0.42,
      pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFE0BC).withValues(alpha: 0.85),
    );
  }

  // -- Alpine valley: layered ridgelines, sun haze, meadow foreground.
  void _landscape(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFF7EC3EF), Color(0xFFD9EFFB)],
      stops: const [0, 0.62],
    );
    _glow(
      canvas,
      Offset(w * 0.74, h * 0.20),
      w * 0.42,
      const Color(0xFFFFF4D6),
    );
    canvas.drawCircle(
      Offset(w * 0.74, h * 0.20),
      w * 0.075,
      Paint()..color = const Color(0xFFFFF9E8),
    );

    // Clouds.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.8);
    for (final c in [
      Rect.fromCenter(
        center: Offset(w * 0.24, h * 0.17),
        width: w * 0.30,
        height: h * 0.07,
      ),
      Rect.fromCenter(
        center: Offset(w * 0.42, h * 0.26),
        width: w * 0.22,
        height: h * 0.05,
      ),
    ]) {
      canvas.drawOval(c, cloud);
    }

    Path ridge(double base, double a1, double a2, double a3) => Path()
      ..moveTo(0, h)
      ..lineTo(0, h * (base + a1))
      ..lineTo(w * 0.25, h * (base - a2))
      ..lineTo(w * 0.48, h * (base + a1 * 0.4))
      ..lineTo(w * 0.74, h * (base - a3))
      ..lineTo(w, h * (base + a1 * 0.6))
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      ridge(0.52, 0.06, 0.16, 0.10),
      Paint()..color = const Color(0xFF8FB4D9),
    );
    canvas.drawPath(
      ridge(0.62, 0.05, 0.20, 0.26),
      Paint()..color = const Color(0xFF4E7BA6),
    );
    // Snow caps on the near ridge.
    final snow = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.465)
        ..lineTo(w * 0.25, h * 0.42)
        ..lineTo(w * 0.30, h * 0.465)
        ..close(),
      snow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.685, h * 0.415)
        ..lineTo(w * 0.74, h * 0.36)
        ..lineTo(w * 0.795, h * 0.415)
        ..close(),
      snow,
    );

    final meadow = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.70, w, h * 0.86)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      meadow,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6FBF64), Color(0xFF3E8A46)],
        ).createShader(Offset.zero & size),
    );
  }

  // -- Golden-hour coast: burning sky, sun pillar on the water, dark headland.
  void _sunset(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [
        Color(0xFF3A2A6B),
        Color(0xFFC64F6E),
        Color(0xFFFF9E5C),
        Color(0xFFFFD98A),
      ],
      stops: const [0, 0.38, 0.60, 0.72],
    );
    final sun = Offset(w * 0.5, h * 0.60);
    _glow(canvas, sun, w * 0.5, const Color(0xFFFFE3A0), inner: 0.75);
    canvas.drawCircle(sun, w * 0.11, Paint()..color = const Color(0xFFFFF3D0));

    // Sea.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.66, w, h * 0.34),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB05468), Color(0xFF2C1E4E)],
        ).createShader(Rect.fromLTWH(0, h * 0.66, w, h * 0.34)),
    );
    // Sun reflection streaks.
    final streak = Paint()
      ..color = const Color(0xFFFFD9A0).withValues(alpha: 0.75);
    for (int i = 0; i < 5; i++) {
      final y = h * (0.70 + i * 0.055);
      final half = w * (0.10 - i * 0.012);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(sun.dx, y),
            width: half * 2,
            height: h * 0.012,
          ),
          const Radius.circular(4),
        ),
        streak,
      );
    }
    // Headland silhouette.
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.80)
        ..quadraticBezierTo(w * 0.18, h * 0.72, w * 0.34, h * 0.86)
        ..quadraticBezierTo(w * 0.42, h * 0.92, w * 0.5, h)
        ..close(),
      Paint()..color = const Color(0xFF1C1430),
    );
  }

  // -- Downtown at dusk: gradient sky, moon, lit windows.
  void _city(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFF141A3C), Color(0xFF4A3A78), Color(0xFFB65C8A)],
      stops: const [0, 0.55, 0.95],
    );
    _glow(
      canvas,
      Offset(w * 0.2, h * 0.16),
      w * 0.24,
      const Color(0xFFEFE8FF),
      inner: 0.7,
    );
    canvas.drawCircle(
      Offset(w * 0.2, h * 0.16),
      w * 0.05,
      Paint()..color = const Color(0xFFF4EFFF),
    );

    final rand = Random(seed);
    final blocks = <Rect>[];
    double x = -w * 0.02;
    int i = 0;
    while (x < w) {
      final bw = w * (0.11 + rand.nextDouble() * 0.10);
      final bh = h * (0.28 + rand.nextDouble() * 0.34);
      blocks.add(Rect.fromLTWH(x, h - bh, bw, bh));
      x += bw * (i.isEven ? 0.72 : 0.95); // overlap for depth
      i++;
    }
    for (final (bi, b) in blocks.indexed) {
      canvas.drawRect(
        b,
        Paint()
          ..color = bi.isEven
              ? const Color(0xFF1B1F42)
              : const Color(0xFF0E1130),
      );
      // Windows.
      final win = Paint()
        ..color = const Color(0xFFFFD98A).withValues(alpha: 0.9);
      final dim = Paint()
        ..color = const Color(0xFF6E7BD9).withValues(alpha: 0.5);
      final cols = max(2, b.width ~/ (w * 0.045));
      final rows = max(3, b.height ~/ (h * 0.07));
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (rand.nextDouble() < 0.42) continue;
          canvas.drawRect(
            Rect.fromLTWH(
              b.left + b.width * (c + 0.28) / cols,
              b.top + b.height * (r + 0.30) / rows,
              b.width / cols * 0.40,
              b.height / rows * 0.34,
            ),
            rand.nextDouble() < 0.7 ? win : dim,
          );
        }
      }
    }
  }

  // -- Macro flower on creamy bokeh.
  void _flower(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFF9BC98F), Color(0xFF4E7A4E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final rand = Random(seed);
    for (int i = 0; i < 9; i++) {
      _glow(
        canvas,
        Offset(rand.nextDouble() * w, rand.nextDouble() * h),
        w * (0.10 + rand.nextDouble() * 0.16),
        i.isEven ? const Color(0xFFEAF6C8) : const Color(0xFFFFF2DA),
        inner: 0.5,
      );
    }

    final center = Offset(w * 0.52, h * 0.56);
    // Stem.
    canvas.drawLine(
      center,
      Offset(w * 0.46, h * 1.02),
      Paint()
        ..color = const Color(0xFF2F5B33)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
    // Petals.
    final petal = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFB7C9), Color(0xFFE85D8A)],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.3));
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * pi / 3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -w * 0.16),
          width: w * 0.17,
          height: w * 0.30,
        ),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      w * 0.085,
      Paint()..color = const Color(0xFFFFC65C),
    );
    canvas.drawCircle(
      center,
      w * 0.085,
      Paint()..color = const Color(0xFFB07818).withValues(alpha: 0.35),
    );
  }

  // -- Vintage family shot: faded homestead scene (the sepia/scratch damage is
  //    applied by the "before" variant on top of this).
  void _oldPhoto(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFFBFD9E3), Color(0xFFEFE3C8)],
      stops: const [0, 0.7],
    );
    _glow(
      canvas,
      Offset(w * 0.3, h * 0.2),
      w * 0.3,
      const Color(0xFFFFF6DC),
      inner: 0.5,
    );

    // Ground.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.74, w, h * 0.26),
      Paint()..color = const Color(0xFFA68B5B),
    );
    // House.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.56, h * 0.42, w * 0.34, h * 0.34),
      Paint()..color = const Color(0xFF8A6A4F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.52, h * 0.44)
        ..lineTo(w * 0.73, h * 0.26)
        ..lineTo(w * 0.94, h * 0.44)
        ..close(),
      Paint()..color = const Color(0xFF5C4030),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.66, h * 0.56, w * 0.10, h * 0.20),
      Paint()..color = const Color(0xFF3E2C20),
    );
    // Two figures.
    for (final (dx, scale) in [(0.22, 1.0), (0.34, 0.82)]) {
      final fx = w * dx;
      final fh = h * 0.24 * scale;
      final top = h * 0.76 - fh;
      canvas.drawCircle(
        Offset(fx, top + fh * 0.14),
        fh * 0.14,
        Paint()..color = const Color(0xFF4A3527),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(fx - fh * 0.16, top + fh * 0.28, fh * 0.32, fh * 0.72),
          Radius.circular(fh * 0.12),
        ),
        Paint()..color = const Color(0xFF5D4634),
      );
    }
    // Tree.
    canvas.drawLine(
      Offset(w * 0.08, h * 0.76),
      Offset(w * 0.10, h * 0.42),
      Paint()
        ..color = const Color(0xFF5C4632)
        ..strokeWidth = w * 0.025,
    );
    canvas.drawCircle(
      Offset(w * 0.11, h * 0.36),
      w * 0.13,
      Paint()..color = const Color(0xFF7E9159),
    );
  }

  // -- Cel-shaded valley: saturated skies and puffy clouds.
  void _anime(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFF37B6FF), Color(0xFFA8E7FF)],
      stops: const [0, 0.65],
    );
    _glow(
      canvas,
      Offset(w * 0.82, h * 0.14),
      w * 0.3,
      Colors.white,
      inner: 0.9,
    );

    // Puffy cel clouds: clusters of hard-edged circles.
    final cloud = Paint()..color = Colors.white;
    final shade = Paint()..color = const Color(0xFFCBE9F7);
    for (final (cx, cy, s) in [(0.26, 0.24, 1.0), (0.62, 0.38, 0.7)]) {
      final c = Offset(w * cx, h * cy);
      final r = w * 0.09 * s;
      canvas.drawCircle(c.translate(-r * 1.2, r * 0.4), r * 0.9, shade);
      canvas.drawCircle(c.translate(r * 1.3, r * 0.5), r * 0.8, shade);
      canvas.drawCircle(c, r * 1.15, cloud);
      canvas.drawCircle(c.translate(-r * 1.1, r * 0.2), r * 0.85, cloud);
      canvas.drawCircle(c.translate(r * 1.2, r * 0.3), r * 0.75, cloud);
    }

    // Rolling hills, flat cel colors.
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.30, h * 0.52, w * 0.62, h * 0.70)
        ..quadraticBezierTo(w * 0.82, h * 0.80, w, h * 0.68)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = const Color(0xFF57C868),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.88)
        ..quadraticBezierTo(w * 0.45, h * 0.74, w, h * 0.92)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = const Color(0xFF2E9E4C),
    );
    // A tiny torii-red accent tree.
    canvas.drawLine(
      Offset(w * 0.78, h * 0.78),
      Offset(w * 0.78, h * 0.64),
      Paint()
        ..color = const Color(0xFF6B4A36)
        ..strokeWidth = w * 0.018,
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.58),
      w * 0.075,
      Paint()..color = const Color(0xFFFF7EA0),
    );
  }

  // -- Deep-space nebula with star field.
  void _galaxy(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    _fill(
      canvas,
      size,
      const [Color(0xFF0B0B26), Color(0xFF1E1040)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    _glow(
      canvas,
      Offset(w * 0.36, h * 0.40),
      w * 0.55,
      const Color(0xFF7B4DE0),
      inner: 0.55,
    );
    _glow(
      canvas,
      Offset(w * 0.68, h * 0.62),
      w * 0.45,
      const Color(0xFFE0559A),
      inner: 0.45,
    );
    _glow(
      canvas,
      Offset(w * 0.60, h * 0.24),
      w * 0.30,
      const Color(0xFF4DA0E0),
      inner: 0.5,
    );

    final rand = Random(seed);
    for (int i = 0; i < 70; i++) {
      final alpha = 0.35 + rand.nextDouble() * 0.65;
      canvas.drawCircle(
        Offset(rand.nextDouble() * w, rand.nextDouble() * h),
        rand.nextDouble() * 1.4 + 0.3,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    // One hero star with cross flare.
    final star = Offset(w * 0.30, h * 0.26);
    _glow(canvas, star, w * 0.07, Colors.white, inner: 0.9);
    final flare = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      star.translate(-w * 0.05, 0),
      star.translate(w * 0.05, 0),
      flare,
    );
    canvas.drawLine(
      star.translate(0, -w * 0.05),
      star.translate(0, w * 0.05),
      flare,
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene != scene || old.seed != seed;
}
