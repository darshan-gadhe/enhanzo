import 'package:flutter/foundation.dart';

/// Turns whatever Replicate or the model says into something a user can read.
///
/// Model errors are written for the person who deployed the model. This one
/// reached a user's screen verbatim:
///
/// ```text
/// Input image of dimensions (1536, 1536, 4) has a total number of pixels
/// 2359296 greater than the max size that fits in GPU memory on this
/// hardware, 2096704. Resize input image and try again.
/// ```
///
/// Nothing in that sentence is actionable by someone holding a phone, and it
/// reads as the app being broken. Every message this app shows for a failed
/// run now comes from here: a small set of causes worth distinguishing, and one
/// honest fallback for everything else. The raw text is kept, but only in the
/// debug log.
///
/// Recognition is by substring rather than by an error code because Replicate
/// does not send one for a model-level failure — the string is all there is.
class ModelErrors {
  ModelErrors._();

  static const String _generic =
      "The enhancer couldn't finish this photo. Please try again.";

  /// Shown when the image was rejected for its size. The safety layer in
  /// [ImageBudget] should make this unreachable, so it is also worth a loud
  /// debug line: reaching it means the budget is wrong for some hardware, not
  /// that the user did anything unusual.
  static const String tooLarge =
      'This photo is too large to enhance. Please try a smaller photo.';

  /// [raw] is the model's `error` field, or an API `detail` string.
  static String friendly(String? raw) {
    final text = (raw ?? '').toLowerCase();

    assert(() {
      if (raw != null && raw.isNotEmpty) {
        debugPrint('Replicate reported: $raw');
      }
      return true;
    }());

    if (text.isEmpty) return _generic;

    // The GPU-budget rejection, in the several shapes it is phrased in.
    // 'gpu memory' rather than the full 'fits in GPU memory': the model
    // phrases this several ways ("does not fit in GPU memory", "fits in GPU
    // memory on this hardware"), and matching the exact sentence missed the
    // variants.
    if (text.contains('gpu memory') ||
        text.contains('resize input image') ||
        text.contains('total number of pixels') ||
        text.contains('out of memory') ||
        (text.contains('cuda') && text.contains('memory'))) {
      return tooLarge;
    }

    // The account behind the proxy, not the photo. Worth saying plainly so the
    // user stops retrying a thing that cannot succeed yet.
    if (text.contains('insufficient credit') ||
        text.contains('payment') ||
        text.contains('billing')) {
      return 'Enhancing is temporarily unavailable. Please try again later.';
    }

    if (text.contains('daily limit') ||
        text.contains('rate limit') ||
        text.contains('too many requests') ||
        text.contains('quota')) {
      return "You've reached today's enhancement limit. Please try again "
          'tomorrow.';
    }

    if (text.contains('timed out') || text.contains('timeout')) {
      return 'That took longer than expected. Please try again.';
    }

    if (text.contains('unsupported') ||
        text.contains('cannot identify image') ||
        text.contains('decode') ||
        text.contains('corrupt')) {
      return "That photo couldn't be read. Please try another image.";
    }

    return _generic;
  }
}
