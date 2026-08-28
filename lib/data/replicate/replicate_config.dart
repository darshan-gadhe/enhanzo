import 'package:flutter/foundation.dart';

/// Where the app's inference requests go, and what they authenticate with.
///
/// Two ways to reach a model, chosen by which defines are set. Both come from
/// `.env` through `--dart-define-from-file`, so no credential is ever
/// committed to the repo:
///
/// ```sh
/// # Development only: your own Replicate token, compiled straight in.
/// flutter run --dart-define-from-file=.env   # .env: REPLICATE_API_TOKEN=r8_xxx
///
/// # Production: the Cloudflare Worker proxy holds the token instead.
/// flutter run --dart-define-from-file=.env   # .env: REPLICATE_PROXY_URL=…
/// #                                                   REPLICATE_APP_KEY=…
/// ```
///
/// **A Replicate token compiled into a mobile binary is extractable.** `.env`
/// hides it from source control, not from anyone holding the app bundle, and a
/// leaked token bills whatever account it belongs to — directly, with no
/// ceiling. [proxyBaseUrl] points the same client at `cloudflare/replicate-proxy`
/// instead: the real token lives only in that Worker's encrypted secret store,
/// and this app ships with no Replicate credential at all.
///
/// [appKey] is a *different* kind of secret — see its own doc comment — and is
/// still extractable from the app bundle by design. It exists to bound the
/// damage a stolen build can do, not to prevent extraction.
///
/// With nothing set the app is unconfigured and the edit flow falls back to its
/// simulated pipeline, so the prototype still runs end to end.
class ReplicateConfig {
  ReplicateConfig._();

  /// Replicate's own API root, used when no proxy is configured.
  static const String directBaseUrl = 'https://api.replicate.com';

  /// Personal API token. Empty unless supplied at build time.
  ///
  /// The argument is the *name* of the define, never the key itself: the value
  /// comes from `.env` through `--dart-define-from-file`, so no credential is
  /// ever written into source. Pasting a real `r8_…` key here would both leak
  /// it and leave this empty, since nothing defines a variable by that name.
  ///
  /// Development-only. A production build should leave this empty and set
  /// [proxyBaseUrl] instead — see the class doc for why.
  static const String apiToken = String.fromEnvironment('REPLICATE_API_TOKEN');

  /// Base URL of the Cloudflare Worker proxy (`cloudflare/replicate-proxy`)
  /// that forwards to Replicate and holds the real token.
  ///
  /// It exposes the same paths the direct API does (`/v1/predictions`,
  /// `/v1/files`, …); everything below only swaps the origin. Trailing slashes
  /// are tolerated.
  static const String proxyBaseUrl = String.fromEnvironment(
    'REPLICATE_PROXY_URL',
  );

  /// The shared secret the proxy checks before forwarding anything.
  ///
  /// This is not a Replicate credential and cannot spend Replicate's API
  /// directly — the proxy is what holds that token, and this key only opens
  /// the door to *asking the proxy* to spend it. It is still an extractable
  /// app-bundle secret, so the proxy backs it with rate limits, a daily quota
  /// and strict input validation (see `cloudflare/replicate-proxy/src/auth.ts`)
  /// rather than treating it as the actual security boundary. Required
  /// whenever [proxyBaseUrl] is set; the proxy rejects requests without it.
  static const String appKey = String.fromEnvironment('REPLICATE_APP_KEY');

  /// True when a proxy is configured — the mode a shipped build should use.
  static bool get usesProxy => proxyBaseUrl.isNotEmpty;

  /// The origin requests are actually sent to.
  static String get baseUrl {
    if (!usesProxy) return directBaseUrl;
    return proxyBaseUrl.endsWith('/')
        ? proxyBaseUrl.substring(0, proxyBaseUrl.length - 1)
        : proxyBaseUrl;
  }

  /// True when this build can reach a model, direct or by proxy.
  static bool get isConfigured => apiToken.isNotEmpty || usesProxy;

  /// Whether requests carry an `Authorization` header of our own. False in
  /// proxy mode, where sending one would only leak a token we shouldn't have —
  /// the proxy attaches its own.
  static bool get sendsToken => !usesProxy && apiToken.isNotEmpty;

  /// Absolute URL for an API path such as `/v1/predictions`.
  static Uri endpoint(String path) => Uri.parse('$baseUrl$path');

  /// Stops a release build that has no credentials from ever reaching a user.
  ///
  /// `--dart-define` values are compile-time and vanish **silently** when the
  /// flag is forgotten: `flutter build appbundle --release` succeeds, produces
  /// a signed, uploadable bundle, and the app it installs cannot enhance a
  /// single photo — the one thing it exists to do. That has already shipped
  /// once, and nothing in the build output hinted at it.
  ///
  /// Throwing here converts that silent, uploadable failure into a loud one at
  /// startup, so a build without credentials cannot be tested, signed or
  /// uploaded without someone noticing immediately.
  ///
  /// Release only. Debug and profile builds are left alone so the app still
  /// runs its simulated pipeline for UI work without credentials.
  static void assertConfigured() {
    if (!kReleaseMode || isConfigured) return;
    throw StateError(
      'Release build has no Replicate credentials. '
      'REPLICATE_PROXY_URL (or REPLICATE_API_TOKEN) was not compiled in — '
      'rebuild with: flutter build appbundle --release '
      '--dart-define-from-file=.env',
    );
  }
}
