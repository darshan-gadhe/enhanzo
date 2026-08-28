// Generates the publishable copies of the legal documents.
//
//   dart run tool/build_legal.dart
//
// `lib/data/legal.dart` is the single source of truth — the app shows that
// text directly in Settings. This script writes the same text to `docs/` as
// standalone HTML so it can be hosted somewhere public, which two things
// require and an in-app copy cannot satisfy:
//
//  * Play Console → App content → Privacy policy needs a reachable URL.
//  * RevenueCat's paywall footer links are URLs configured in its dashboard.
//    `presentPaywall()` exposes no callback for them, so there is no way to
//    point those buttons at in-app content — they must resolve to real pages.
//
// `docs/` rather than `store/` because that is one of the two folders GitHub
// Pages will serve a branch from, so hosting these is a setting rather than a
// pipeline. Everything else under `store/` is listing copy that is pasted into
// Play Console by hand and must NOT be published; keeping the public pages in
// their own directory is what makes "serve this folder" safe to switch on.
//
// Run this after editing legal.dart so the hosted copies never drift from
// what the app itself displays.

import 'dart:io';

import 'package:ai_enhancer/data/legal.dart';

const _appName = 'Enhanzo: AI Photo Enhancer';

/// Shared by every generated page, so the index and the documents cannot
/// drift apart.
const _style = '''<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0 auto; padding: 2rem 1.25rem 4rem; max-width: 46rem;
    font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: #1c1c1e; background: #fff;
  }
  h1 { font-size: 1.5rem; margin: 0 0 .25rem; }
  .app { color: #6b6b70; margin: 0 0 2rem; font-size: .95rem; }
  pre {
    white-space: pre-wrap; word-wrap: break-word; margin: 0;
    font: inherit;
  }
  a { color: #0a58ca; }
  @media (prefers-color-scheme: dark) {
    body { color: #f2f2f7; background: #000; }
    .app { color: #9a9aa0; }
    a { color: #6ea8fe; }
  }
</style>''';

String _html(String title, String body) {
  final escaped = body
      .trim()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title — $_appName</title>
$_style
</head>
<body>
<h1>$title</h1>
<p class="app">$_appName</p>
<pre>$escaped</pre>
</body>
</html>
''';
}

/// The landing page. Play reviewers and users who tap a footer link arrive at
/// one of the documents directly, but a bare directory that 404s looks like a
/// dead site, so the root answers with both links.
String _index() => '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$_appName — Legal</title>
$_style
</head>
<body>
<h1>$_appName</h1>
<p class="app">Legal documents</p>
<ul>
<li><a href="privacy-policy.html">Privacy Policy</a></li>
<li><a href="terms-of-use.html">Terms of Use</a></li>
</ul>
</body>
</html>
''';

void main() {
  final dir = Directory('docs')..createSync(recursive: true);

  final files = <String, String>{
    'index.html': _index(),
    'privacy-policy.html': _html('Privacy Policy', Legal.privacyPolicy),
    'terms-of-use.html': _html('Terms of Use', Legal.termsOfUse),
    // Stops GitHub Pages running these through Jekyll, which would otherwise
    // try to interpret the documents' own punctuation as templating.
    '.nojekyll': '',
  };

  files.forEach((name, contents) {
    File('${dir.path}/$name').writeAsStringSync(contents);
    stdout.writeln('wrote docs/$name');
  });

  stdout.writeln(
    '\nPublish by enabling GitHub Pages on this repo:\n'
    '  Settings → Pages → Source: Deploy from a branch → main → /docs\n'
    '\nThen paste the resulting URLs into:\n'
    '  • Play Console → App content → Privacy policy\n'
    '  • RevenueCat → Paywalls → your paywall → footer links\n'
    '\nVerify each returns HTTP 200 before pasting it anywhere.',
  );
}
