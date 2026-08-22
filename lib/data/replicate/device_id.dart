import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// This install's identifier, sent as `X-Device-Id` on every proxy call.
///
/// The Cloudflare proxy keys its rate limiter and daily quota on this value —
/// see `cloudflare/replicate-proxy/src/limits.ts`. It identifies an
/// installation, not a person: there is no account system, it is generated
/// locally with no server round-trip, and it carries no personal data. A
/// reinstall gets a new one, which simply resets that install's quota.
class DeviceId {
  DeviceId._();

  static const String _key = 'replicate_device_id_v1';
  static const _uuid = Uuid();

  static String? _cached;

  /// Returns this install's id, generating and persisting one on first call.
  ///
  /// Cached in memory after the first read so a run of predictions doesn't
  /// each pay for a `SharedPreferences` round-trip.
  static Future<String> get() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final generated = _uuid.v4();
    // Best-effort: a write failure just means the next launch generates a new
    // id, which only resets this install's own quota — not a correctness bug.
    unawaited(prefs.setString(_key, generated));
    _cached = generated;
    return generated;
  }
}
