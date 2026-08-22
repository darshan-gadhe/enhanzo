import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/components/components.dart';

/// A full-screen, scrollable legal document (Privacy Policy / Terms of Use).
///
/// Pushed as a real route rather than shown in a bottom sheet: these run to
/// several screens of text, and a sheet would either clip them or turn into a
/// scroll-within-a-scroll. It is also the only place in the app that uses the
/// Navigator for a top-level view — the tab screens live in [AppShell]'s
/// Stack — which is fine precisely because this is a leaf the user backs out
/// of rather than a destination they switch between.
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;

  const LegalScreen({super.key, required this.title, required this.body});

  /// Opens [title]/[body] as a page. Kept here so callers don't each rebuild
  /// the same route.
  static Future<void> open(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Scaffold(
      backgroundColor: p.screenBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.x8,
                  AppSpacing.screenH,
                  AppSpacing.x32,
                ),
                children: [
                  SelectableText(
                    body.trim(),
                    style: AppText.bodyCompact(p.textSecondary).copyWith(
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.x12,
        AppSpacing.screenH,
        AppSpacing.x12,
      ),
      child: Row(
        children: [
          AppCircleIconButton(
            icon: AppIcons.close,
            semanticLabel: 'Close',
            background: p.secondarySurface,
            iconColor: p.textPrimary,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.itemGap),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.navTitle(p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
