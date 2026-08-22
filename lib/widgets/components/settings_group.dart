import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';
import 'buttons.dart';
import 'pressable.dart';

/// A single row inside a [SettingsGroup]: a leading glyph, a label with an
/// optional second line, and either a custom [trailing] widget or a value plus
/// a chevron.
///
/// The glyph tile is neutral. It used to take a per-row colour, which produced
/// a column of five unrelated hues — indigo, blue, green, red, pink — none of
/// which carried meaning: red on "Notifications" is the same red the app uses
/// for deleting things. With a single accent, colour is reserved for state and
/// action, and structure is carried by the tile shape.
///
/// A row highlights rather than shrinks while held: it sits inside a card, and
/// a scaling row would slide away from the two rows it is stacked against.
class SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Optional supporting line under [label] — what the row does, when the name
  /// alone doesn't say it.
  final String? subtitle;

  /// The row's current setting, shown before the chevron.
  final String? value;

  /// Replaces the value + chevron entirely (a switch, a spinner).
  final Widget? trailing;

  final VoidCallback? onTap;

  /// A row that exists but can't act right now (a restore already running).
  /// It dims and stops taking taps rather than disappearing, so the list
  /// doesn't reflow underneath the user.
  final bool enabled;

  const SettingTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final active = enabled && onTap != null;
    // Everything in a disabled row recedes together, so the state reads as one
    // change rather than as a row with a greyed-out word in it.
    final opacity = enabled ? 1.0 : 0.45;

    final row = Opacity(
          opacity: opacity,
          child: AppPressable(
            onTap: active ? onTap : null,
            // A row inside a card highlights instead of scaling. The group's
            // surface is already secondarySurface, so the press wash steps to
            // fieldBg to stay visible against it.
            depth: PressDepth.none,
            highlight: p.fieldBg,
            child: Container(
              // A settings row is a primary tap target and must clear the
              // accessibility floor even when its content is short.
              constraints: const BoxConstraints(
                minHeight: AppSizing.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x16,
                vertical: AppSpacing.x12,
              ),
              child: Row(
                children: [
                  AppSquareIconButton(
                    icon: icon,
                    background: p.fieldBg,
                    iconColor: p.textPrimary,
                    size: AppSizing.controlXs,
                    iconSize: AppSizing.iconSm,
                    borderRadius: AppRadius.brMd,
                  ),
                  const SizedBox(width: AppSpacing.itemGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppText.settingLabel(p.textPrimary),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.tightGap),
                          Text(
                            subtitle!,
                            style: AppText.caption(p.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else ...[
                    if (value != null && value!.isNotEmpty)
                      // The row's current value is real content, not
                      // decoration — it reads at the secondary step so it
                      // clears 4.5:1.
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.innerGap,
                          ),
                          child: Text(
                            value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppText.captionLg(p.textSecondary),
                          ),
                        ),
                      ),
                    // Only a row that leads somewhere gets the chevron: on an
                    // inert row it promises a destination that isn't there.
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.x6),
                      Icon(
                        AppIcons.chevronRight,
                        size: AppSizing.iconSm,
                        color: p.textTertiary,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );

    // A row whose trailing accessory is a control of its own (a switch) keeps
    // that control's semantics: it must be announced and operated as a toggle,
    // not flattened into one "button" with the label. Every other row is a
    // single destination, so it merges into one node.
    if (trailing != null) return row;

    return Semantics(
      button: onTap != null,
      enabled: enabled,
      label: [
        label,
        if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
        if (value != null && value!.isNotEmpty) value!,
      ].join(', '),
      child: ExcludeSemantics(child: row),
    );
  }
}

/// A grouped, borderless block of [SettingTile]s with inset hairline dividers
/// between rows (iOS-style inset list).
///
/// **Flat, not framed.** The group reads as one block through a filled
/// [AppPalette.secondarySurface] tint against the canvas rather than a hairline
/// frame or a drop shadow — separation by surface contrast is the house
/// standard, and it keeps Settings feeling calm rather than boxed-in.
///
/// An optional [title] renders a small overline above the card so the caller
/// can segment settings into labelled sections without building the label
/// externally.
///
/// The dividers start where the labels do rather than running the full width,
/// so the leading glyphs read as one column down the card instead of being
/// chopped into separate cells.
class SettingsGroup extends StatelessWidget {
  final List<SettingTile> tiles;

  /// Optional section label rendered above the card (e.g. "Appearance",
  /// "Account"). When null the card stands alone as before.
  final String? title;

  const SettingsGroup({super.key, required this.tiles, this.title});

  /// Where a divider begins: past the row's leading inset, its glyph tile and
  /// the gap after it, so the rule lines up with the labels.
  static const double _dividerInset =
      AppSpacing.x16 + AppSizing.controlXs + AppSpacing.itemGap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.x6,
              bottom: AppSpacing.innerGap,
            ),
            child: Text(
              title!.toUpperCase(),
              style: AppText.overline(p.textSecondary),
            ),
          ),
        ],
        AppCard(
          clip: true,
          // Borderless: a flat tinted surface, no frame and no shadow.
          elevated: false,
          color: p.secondarySurface,
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i != tiles.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: _dividerInset),
                    child: Container(
                      height: AppSizing.strokeHairline,
                      // A touch stronger than [AppPalette.border] so the rule stays
                      // visible sitting on the group's own tinted surface.
                      color: p.border2,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
