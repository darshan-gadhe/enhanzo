import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play rating, at a moment that has just gone well.
///
/// Rating average and review volume are among the heaviest ranking signals on
/// Play, and Settings' "Rate Enhanzo" row — which opens the store listing in a
/// browser — converts close to nothing, because most people never come back
/// from it. Google's In-App Review API shows the sheet in place instead.
///
/// **The whole design is about when *not* to ask.** A prompt shown at the
/// wrong moment earns a one-star review, which is worse than no review at all,
/// and Play throttles the API for apps that ask too often. So this asks only
/// when all of the following hold:
///
///  * the user has saved at least [_minSaves] enhancements, so they have
///    actually seen the product work more than once;
///  * this is not their first session;
///  * nothing has failed on the way here — the caller only invokes this from a
///    successful save, never from an error, a no-fill or a dismissed paywall;
///  * it has never been asked before.
///
/// Play itself decides whether to actually show the sheet — the API is a
/// request, not a command, and it silently does nothing when the user has
/// already rated or the quota is spent. That is why [_askedKey] is written
/// when the request is *made*: asking again would be spending a quota Play has
/// already declined to honour.
class ReviewPrompt {
  ReviewPrompt._();

  static const String _savesKey = 'review_saves_v1';
  static const String _askedKey = 'review_asked_v1';

  /// Saved enhancements before the prompt is allowed. Two, so the asker has
  /// seen a result they chose to keep, more than once.
  static const int _minSaves = 2;

  /// Overridable for tests, which must not reach a platform channel.
  @visibleForTesting
  static InAppReview instance = InAppReview.instance;

  /// True once this process has asked, so two saves in one session cannot ask
  /// twice while the write is still in flight.
  static bool _askedThisSession = false;

  @visibleForTesting
  static void resetForTest() => _askedThisSession = false;

  /// Records a saved enhancement and asks for a review if this is the moment.
  ///
  /// Never throws and never blocks the caller: a storage failure or an
  /// unavailable store simply means no prompt.
  static Future<void> recordSaveAndMaybeAsk() async {
    if (_askedThisSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return;

      final saves = (prefs.getInt(_savesKey) ?? 0) + 1;
      await prefs.setInt(_savesKey, saves);
      if (saves < _minSaves) return;

      if (!await instance.isAvailable()) return;

      // Marked before requesting, not after: Play may decline to show the
      // sheet for reasons this app cannot see, and retrying on the next save
      // would burn the quota rather than earn a review.
      _askedThisSession = true;
      await prefs.setBool(_askedKey, true);
      await instance.requestReview();
    } catch (_) {
      // A review prompt is never worth a failure the user can see.
    }
  }

  /// Whether the prompt would fire on the next save. Test seam.
  @visibleForTesting
  static Future<bool> isDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) ?? false) return false;
      return (prefs.getInt(_savesKey) ?? 0) + 1 >= _minSaves;
    } catch (_) {
      return false;
    }
  }
}
