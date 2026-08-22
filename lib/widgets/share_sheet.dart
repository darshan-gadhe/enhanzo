import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/theme.dart';
import 'components/components.dart';

/// One destination offered by the share sheet.
class _ShareTarget {
  final IconData icon;
  final String label;
  const _ShareTarget(this.icon, this.label);
}

const List<_ShareTarget> _targets = [
  _ShareTarget(AppIcons.photos, 'Photos'),
  _ShareTarget(AppIcons.link, 'Copy link'),
  _ShareTarget(AppIcons.more, 'More'),
];

/// Shares a finished edit.
///
/// With a [file] — an image a model really returned — this hands straight off
/// to the platform share sheet, where every destination the device offers
/// (Photos, Messages, another app) is already listed and works.
///
/// Without one there is nothing to share: a simulated edit is drawn on the fly
/// and has no bitmap behind it. That case falls back to the explanatory sheet
/// below rather than opening an OS sheet with no attachment, or a control that
/// silently does nothing.
Future<void> showShareSheet(
  BuildContext context, {
  required String subject,
  File? file,
}) async {
  // Read before any await: the sheet anchors to this rectangle on iPad, where
  // a popover with no source rect is undefined behaviour, and the render object
  // must be looked up while the context is known to be current.
  final box = context.findRenderObject() as RenderBox?;

  if (file != null && await file.exists()) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    builder: (sheetContext) => _ShareSheet(subject: subject),
  );
}

/// The fallback for an edit with no file behind it: the real destinations,
/// disabled, with the reason stated — so the greying-out reads as a state
/// rather than a bug. A control that silently does nothing is worse than one
/// that explains itself.
class _ShareSheet extends StatelessWidget {
  final String subject;

  const _ShareSheet({required this.subject});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);

    return AppBottomSheet(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share',
          textAlign: TextAlign.center,
          style: AppText.sheetTitle(p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.tightGap),
        Text(
          subject,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.captionMd(p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        Row(
          children: [
            for (int i = 0; i < _targets.length; i++) ...[
              Expanded(child: _TargetTile(target: _targets[i])),
              if (i != _targets.length - 1)
                const SizedBox(width: AppSpacing.itemGap),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.titleToContent),
        // Says why the options are inert, so the greying-out reads as a state
        // rather than a bug.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIcons.info,
              size: AppSizing.iconSm,
              color: p.textSecondary,
            ),
            const SizedBox(width: AppSpacing.innerGap),
            Expanded(
              child: Text(
                'This preview was generated on the device, so there is no '
                'file to share yet. Run the edit on one of your own photos '
                'and every destination here opens.',
                style: AppText.caption(p.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single share destination, rendered in its unavailable state.
class _TargetTile extends StatelessWidget {
  final _ShareTarget target;

  const _TargetTile({required this.target});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    // Greyed-out is a signifier: "this exists, it just can't act right now."
    final color = p.textTertiary;

    return Semantics(
      button: true,
      enabled: false,
      label: '${target.label}, not available yet',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
        constraints: const BoxConstraints(minHeight: AppSizing.minTapTarget),
        decoration: BoxDecoration(
          color: p.fieldBg,
          borderRadius: AppRadius.brLg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(target.icon, size: AppSizing.iconLg, color: color),
            const SizedBox(height: AppSpacing.x6),
            Text(
              target.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.badge(color),
            ),
          ],
        ),
      ),
    );
  }
}
