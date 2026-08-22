import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import 'app_pill.dart';

/// What a badge asserts about the item it sits on. The kind carries the colour
/// and default caption; each one is a claim the app must be able to back up, so
/// only apply the one that is *true* (a `pro` badge belongs on a genuinely
/// gated item, `featured` on a slot the app actually curates). A badge invented
/// to add urgency is exactly the fabricated cue the design system rejects.
enum BadgeKind {
  /// Genuinely new capability.
  isNew,

  /// Locked behind Pro.
  pro,

  /// The curated highlight slot on a hub.
  featured,

  /// Something happening now.
  live,
}

/// A small uppercase status pill — the reusable counterpart to the paywall's
/// plan badge, for flagging content on cinematic surfaces (feature banners,
/// history cards). Text-only and high-contrast: over imagery a badge has to
/// read at a glance without a glyph crowding three characters.
class AppBadge extends StatelessWidget {
  final BadgeKind kind;

  /// Overrides the default caption for the kind. Keep it to one short word —
  /// the pill is sized for a status, not a sentence.
  final String? label;

  const AppBadge(this.kind, {super.key, this.label});

  String get _defaultText => switch (kind) {
    BadgeKind.isNew => 'NEW',
    BadgeKind.pro => 'PRO',
    BadgeKind.featured => 'FEATURED',
    BadgeKind.live => 'LIVE',
  };

  /// Pill fill. `pro` is a solid near-black ink chip and `live` a semantic
  /// green; the neutral kinds use a solid white chip. All three stay legible
  /// over any scene, in either theme, without a hue.
  Color get _background => switch (kind) {
    BadgeKind.pro => AppOverlay.ink,
    BadgeKind.live => AppColors.success,
    BadgeKind.isNew || BadgeKind.featured => AppColors.onColor,
  };

  /// Caption colour — near-black ink on the white chips, white on the dark/green.
  Color get _foreground => switch (kind) {
    BadgeKind.pro || BadgeKind.live => AppColors.onColor,
    BadgeKind.isNew || BadgeKind.featured => AppOverlay.ink,
  };

  @override
  Widget build(BuildContext context) {
    return AppPill.label(
      label ?? _defaultText,
      color: _background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x10,
        vertical: AppSpacing.x4,
      ),
      textStyle: AppText.tag(_foreground),
    );
  }
}
