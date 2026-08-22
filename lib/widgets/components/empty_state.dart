import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'buttons.dart';

/// Reusable empty-state block: a tinted circular glyph, a title, a short
/// supporting message, and — for a first-use state — the action that fills it.
///
/// An empty state has to answer three questions: why is this empty, what do I
/// do about it, and where do I tap. The glyph and copy cover the first two;
/// [actionLabel] covers the third. Leave the action off only for states the
/// user can't act on from here (a no-results state usually offers "clear
/// search" instead, which is still an action).
///
/// Portable — depends only on the theme tokens and [AppButton].
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Glyph / action tint. Defaults to the theme's monochrome [AppPalette.accent]
  /// when null — pass a semantic colour only for a state that means something
  /// specific (e.g. an error).
  final Color? accent;

  /// Label for the primary action. Both this and [onAction] must be set for
  /// the button to render.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Widest the action button is allowed to grow — a full-bleed button under a
  /// centred column reads as a page CTA rather than part of the empty state.
  static const double _actionMaxWidth = 240;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final accent = this.accent ?? p.accent;
    // A filled action on an ink accent needs the inverting on-accent colour;
    // a custom semantic accent keeps white, which reads on any tint.
    final onAccent = this.accent == null ? p.onAccent : AppColors.onColor;
    final hasAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x32,
        AppSpacing.emptyStateTop,
        AppSpacing.x32,
        0,
      ),
      child: Column(
        children: [
          Container(
            width: AppSizing.emptyGlyph,
            height: AppSizing.emptyGlyph,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSizing.iconXxxl, color: accent),
          ),
          const SizedBox(height: AppSpacing.titleToContent),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.emptyTitle(p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.innerGap),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.captionLg(p.textSecondary),
          ),
          if (hasAction) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _actionMaxWidth),
              child: AppButton(
                label: actionLabel!,
                onTap: onAction,
                color: accent,
                labelColor: onAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
