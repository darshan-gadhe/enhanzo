import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for what a free user has already used up.
///
/// Two facts, both of which must survive a force-close and a relaunch:
///
///  * how many free enhancements have been spent, and
///  * whether the first-launch paywall has already been offered.
///
/// Neither is a security boundary — a determined user can clear app data and
/// start over, and that is true of every client-side free tier. What it must
/// not do is reset on its own: an in-memory counter would hand out three more
/// free enhancements on every app restart, which is the same as having no
/// limit at all.
///
/// Premium status is deliberately *not* stored here. That comes from
/// RevenueCat on every launch — see [EntitlementController] — so the app can
/// never grant itself a subscription it does not own.
///
/// Reads and writes are best-effort in the same way [ThemeStore]'s are, but the
/// failure directions are chosen separately and on purpose:
///
///  * a failed **read** of the counter reports "unknown", and the caller treats
///    unknown as *exhausted* — a storage failure must not become free
///    enhancements.
///  * a failed **read** of the onboarding flag reports "already seen", so a
///    broken store cannot make the paywall appear on every launch.
class AccessStore {
  AccessStore._();

  /// Versioned so a future change to what "used" means can migrate rather than
  /// silently reinterpret an old number.
  static const String _usedKey = 'free_generations_used_v1';
  static const String _onboardingKey = 'onboarding_paywall_seen_v1';

  /// How many free enhancements have been spent, or null if storage could not
  /// answer.
  static Future<int?> readFreeUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_usedKey) ?? 0;
    } catch (_) {
      return null;
    }
  }

  /// Records [value]. Returns whether it was actually persisted, so a caller
  /// can decline to hand out something it could not record.
  static Future<bool> writeFreeUsed(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_usedKey, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether the first-launch paywall has already been offered. Defaults to
  /// `true` on a storage failure — see the class doc.
  static Future<bool> readOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> writeOnboardingSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (_) {
      // Worst case the paywall is offered once more on the next launch. That
      // is the mild failure; nagging forever is prevented by the read above
      // defaulting to "seen" when storage is broken outright.
    }
  }
}
