import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// How long [openExternalUrl] waits for the platform to respond before
/// treating the attempt as failed. `launchUrl` has no built-in timeout of its
/// own — with no resolver willing to handle the URL, the platform call can
/// hang indefinitely rather than rejecting quickly, which would otherwise
/// leave the tapped row looking frozen with no feedback at all.
const Duration _launchTimeout = Duration(seconds: 5);

/// Opens [url] in an external browser/app, reporting failure rather than
/// doing nothing silently. Shared by the paywall's legal links and Settings'
/// Privacy/Terms rows so both fail the same honest way — most commonly
/// because the destination site doesn't have a real page at that path yet,
/// not because the link itself is broken.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  bool launched = false;
  if (uri != null) {
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).timeout(_launchTimeout);
    } catch (_) {
      // Covers both a thrown PlatformException (no app can handle the URL)
      // and the timeout above — either way, falls through to the failure
      // message below rather than hanging or crashing the caller.
    }
  }
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("Couldn't open that link right now."),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
