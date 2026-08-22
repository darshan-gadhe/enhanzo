import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the user's light/dark theme choice.
///
/// The app ships only two themes and no "match system" option, so the
/// preference is stored as a single boolean (`true` = dark). Reads/writes are
/// best-effort: a storage failure falls back to "no stored preference" rather
/// than crashing, and the app keeps its default light theme.
class ThemeStore {
  ThemeStore._();

  /// Versioned key so a future schema change can migrate rather than clash.
  static const String _darkKey = 'theme_is_dark_v1';

  /// Reads the stored preference. Returns null when nothing has been saved yet
  /// (first launch) or on any error, so the caller keeps its default.
  static Future<bool?> readIsDark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_darkKey);
    } catch (_) {
      return null;
    }
  }

  /// Persists the preference. Best-effort: a write failure is swallowed so the
  /// in-memory theme (already applied this session) still reflects the choice.
  static Future<void> writeIsDark(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkKey, value);
    } catch (_) {
      // Intentionally ignored — persistence is non-critical for this session.
    }
  }
}
