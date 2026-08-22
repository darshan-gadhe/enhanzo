import 'dart:io';

import 'package:flutter/material.dart';

import 'demo_image.dart';

/// A photo in the edit flow: the user's own file when there is one, and the
/// bundled demo imagery when there isn't.
///
/// Every canvas in the flow — crop, processing, result, history — needs the
/// same fallback, because the app runs two pipelines: real inference on a
/// picked photo, and the simulated preview on `assets/tools` art. Routing both
/// through one widget keeps the fallback (and the decode sizing that stops a
/// full-resolution photo from being held in memory per tile) in a single place.
class EditImage extends StatelessWidget {
  /// The real image. Null falls through to [art], then to [scene].
  final File? file;

  final DemoScene scene;
  final DemoVariant variant;
  final int seed;
  final String? art;

  const EditImage({
    super.key,
    required this.file,
    required this.scene,
    this.variant = DemoVariant.after,
    this.seed = 7,
    this.art,
  });

  /// Ceiling on decode width. A 4× upscale of a 2048px source is 8192px wide;
  /// nothing in the app draws it larger than the screen.
  static const int _maxDecodeWidth = 2048;

  @override
  Widget build(BuildContext context) {
    final source = file;
    if (source == null) {
      return DemoImage(scene: scene, variant: variant, seed: seed, art: art);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, c) {
            final boxW = c.maxWidth.isFinite
                ? c.maxWidth
                : MediaQuery.sizeOf(context).width;
            return Image.file(
              source,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: (boxW * dpr).round().clamp(1, _maxDecodeWidth),
              // A file that has been cleared out from under us (cache eviction,
              // a deleted temp) degrades to the demo art rather than a broken
              // image box.
              errorBuilder: (_, _, _) =>
                  DemoImage(scene: scene, variant: variant, seed: seed, art: art),
            );
          },
        ),
      ),
    );
  }
}
