import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Small uppercase overline that labels a group of controls (settings groups,
/// composer sections).
class SectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const SectionLabel(
    this.text, {
    super.key,
    this.color,
    this.padding = const EdgeInsets.only(
      left: AppSpacing.x6,
      bottom: AppSpacing.titleToContent,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? PaletteScope.of(context).textSecondary;
    return Padding(
      padding: padding,
      child: Text(text, style: AppText.overline(c)),
    );
  }
}

/// The masthead at the top of a tab screen: a large, **centered** screen title
/// with an optional centered [subtitle] and an optional [trailing] accessory
/// pinned to the trailing edge.
///
/// The title stays optically centered across the full screen width no matter
/// how wide the accessory is — an invisible clone of [trailing] balances the
/// leading edge — so every tab's masthead lines up on the same axis. This is
/// the one place screen titles are set; use it on every top-level tab instead
/// of a bare [Text] so their treatment can never drift apart.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// The title's type role. Defaults to the screen large title; Home overrides
  /// it with the wordmark so the brand keeps its own voice while still centring
  /// on the shared axis.
  final TextStyle Function(Color) titleStyle;

  /// Hairline under the masthead, separating the header from the content it
  /// sits over. On by default so every tab screen carries the same seam; the
  /// full-bleed surfaces (the paywall, the edit-flow steps) don't use this
  /// header at all.
  final bool divider;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleStyle = AppText.largeTitle,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);

    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle(p.textPrimary),
    );

    final Widget titleRow;
    if (trailing == null) {
      titleRow = titleText;
    } else {
      final accessory = trailing!;
      titleRow = Row(
        children: [
          // A weightless, inert clone of the accessory mirrors its width on the
          // leading edge, so the centred title sits on the true screen centre
          // rather than being pushed off it by the real accessory.
          ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: IgnorePointer(child: accessory),
            ),
          ),
          Expanded(child: titleText),
          accessory,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleRow,
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.tightGap),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.captionMd(p.textSecondary),
          ),
        ],
        if (divider) ...[
          const SizedBox(height: AppSpacing.titleToContent),
          const _FullBleedHairline(),
        ],
      ],
    );
  }
}

/// The hairline under a [ScreenHeader], drawn edge to edge.
///
/// Every tab screen pads its content in by [AppSpacing.screenH], so a plain
/// divider inside that padding would stop short of both edges and read as a
/// rule under the title rather than as the seam between the header and the
/// content. This one is laid out at the screen's own width and allowed to
/// overflow its slot on both sides — the header is centred in a symmetric
/// inset, so the overhang lands exactly on the two screen edges.
class _FullBleedHairline extends StatelessWidget {
  const _FullBleedHairline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizing.strokeHairline,
      child: OverflowBox(
        maxWidth: double.infinity,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: AppSizing.strokeHairline,
          child: ColoredBox(color: PaletteScope.of(context).border2),
        ),
      ),
    );
  }
}

/// A section heading that can carry a supporting subtitle and a trailing
/// action, for the top of a content group richer than a bare title + count.
///
/// The title/subtitle absorb the row's slack so the [trailing] widget (a "See
/// all" text button, a filter pill) keeps its natural width and never pushes
/// the heading into an overflow. Use [SectionTitleRow] for the common
/// title-plus-count case; reach here when the group needs a second line of
/// context or an action of its own.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sectionTitle(p.textPrimary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.tightGap),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.captionLg(p.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.itemGap),
          trailing!,
        ],
      ],
    );
  }
}

/// A section title with an optional muted trailing count ("8 tools").
class SectionTitleRow extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionTitleRow(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Flexible so a long title (or a large text scale) ellipsises instead of
        // overrunning the trailing count and overflowing the row.
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sectionTitle(p.textPrimary),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.innerGap),
          Text(trailing!, style: AppText.captionMd(p.textTertiary)),
        ],
      ],
    );
  }
}
