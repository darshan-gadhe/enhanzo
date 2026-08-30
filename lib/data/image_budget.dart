import 'dart:math' as math;

/// A width and height in pixels.
class ImageSize {
  final int width;
  final int height;

  const ImageSize(this.width, this.height);

  int get pixelCount => width * height;
  int get longestEdge => width > height ? width : height;
  double get aspectRatio => width / height;

  @override
  bool operator ==(Object other) =>
      other is ImageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}

/// The size limits every image must satisfy before it is sent to Replicate.
///
/// This is arithmetic only — no decoding, no files, no I/O — so the rule that
/// keeps photos inside the model's GPU budget can be reasoned about and tested
/// on its own. [ImageOps.prepareForUpload] is what applies it to real pixels,
/// and it is the only way to produce the [PreparedImage] that
/// [ReplicateClient.uploadImage] will accept.
///
/// ## Why this exists
///
/// Real-ESRGAN's A100 deployment rejects an input it cannot fit in GPU memory,
/// and says so in the model's own words:
///
/// ```text
/// Input image of dimensions (1536, 1536, 4) has a total number of pixels
/// 2359296 greater than the max size that fits in GPU memory on this
/// hardware, 2096704. Resize input image and try again.
/// ```
///
/// The app used to cap only the *longest edge* (2048px), which does nothing for
/// a square: 1536×1536 is 2,359,296 pixels, well past the limit, with neither
/// edge anywhere near 2048. The cap has to be on the pixel count, because that
/// is what the memory is.
class ImageBudget {
  ImageBudget._();

  /// The ceiling the model itself reported: 2,096,704 px, which is exactly
  /// 1448². Recorded as the hardware's number, not as the app's target.
  static const int modelMaxPixels = 2096704;

  /// What this app will actually send: 90% of [modelMaxPixels].
  ///
  /// Deliberately short of the boundary rather than on it. The reported ceiling
  /// belongs to one hardware assignment and one model version — a different GPU
  /// or an upstream change in how the model pads its input can move it, and the
  /// cost of being 10% under is a barely visible difference in a photo that is
  /// about to be upscaled 2–4× anyway. The cost of being one pixel over is a
  /// failed edit.
  ///
  /// = floor(2096704 × 0.90). Pinned by a test rather than computed, because
  /// `const` cannot do the arithmetic.
  static const int maxSafePixels = 1887033;

  /// Ceiling on either edge, independent of the pixel count.
  ///
  /// [maxSafePixels] already bounds anything near-square, but an extreme
  /// panorama can be inside the pixel budget while still being enormously wide
  /// (8000×235 is only 1.88M px). Long thin buffers are their own memory and
  /// decode problem on a phone, and the picker is already asked for this size.
  static const int maxSourceEdge = 2048;

  /// Whether an image of [width]×[height] can be sent as it is.
  static bool isWithinBudget(int width, int height) =>
      width > 0 &&
      height > 0 &&
      width * height <= maxSafePixels &&
      width <= maxSourceEdge &&
      height <= maxSourceEdge;

  /// The largest size within the budget that keeps [width]:[height]'s shape.
  ///
  /// Returns the input unchanged when it already fits — "only downscale when
  /// required". Never enlarges, never stretches: both edges are scaled by the
  /// same factor, so the aspect ratio survives to within the one pixel that
  /// rounding to whole pixels costs.
  ///
  /// Throws [ArgumentError] on a non-positive dimension, which is not a size
  /// to be fitted but an image that failed to decode.
  static ImageSize fit(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image has no size: ${width}x$height');
    }
    if (isWithinBudget(width, height)) return ImageSize(width, height);

    var w = width;
    var h = height;

    // 1. The edge cap. Scaling the longest edge down to the ceiling brings the
    //    other with it, so the shape is preserved.
    final longest = w > h ? w : h;
    if (longest > maxSourceEdge) {
      final scale = maxSourceEdge / longest;
      w = math.max(1, (w * scale).floor());
      h = math.max(1, (h * scale).floor());
    }

    // 2. The pixel cap: scale = sqrt(budget / area), applied to both edges.
    if (w * h > maxSafePixels) {
      var scale = math.sqrt(maxSafePixels / (w * h));
      var nw = math.max(1, (w * scale).floor());
      var nh = math.max(1, (h * scale).floor());

      // Flooring both edges can only shrink the area below w·h·scale² =
      // maxSafePixels, so this holds on the first attempt. The loop is here
      // because "guaranteed" should not rest on that argument alone: floating
      // point decides `scale`, and a budget this close to a hard failure is
      // worth making structurally true rather than provably true.
      var guard = 0;
      while (nw * nh > maxSafePixels && guard++ < 64) {
        scale *= 0.999;
        nw = math.max(1, (w * scale).floor());
        nh = math.max(1, (h * scale).floor());
        // Both edges are already 1px; nothing further to give.
        if (nw == 1 && nh == 1) break;
      }
      w = nw;
      h = nh;
    }

    return ImageSize(w, h);
  }
}
