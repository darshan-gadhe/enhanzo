import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'pressable.dart';
import 'tap_target.dart';

/// A rounded (stadium) container — the shape primitive behind every badge,
/// tag, chip and label pill in the app. Holds any [child]; use [AppPill.label]
/// for the common text-only case.
class AppPill extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  /// Haptic fired when a tap lands (ignored when [onTap] is null).
  final VoidCallback? haptic;

  const AppPill({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.x12,
      vertical: AppSpacing.x6,
    ),
    this.border,
    this.borderRadius = AppRadius.brPill,
    this.onTap,
    this.haptic = AppHaptics.select,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border,
      ),
      child: child,
    );
    if (onTap != null) {
      // A pill is typically ~30pt tall — below the touch floor — so the
      // gesture gets a padded target while the pill keeps its size.
      pill = AppPressable(
        onTap: onTap,
        haptic: haptic,
        child: AppTapTarget(child: pill),
      );
    }
    return pill;
  }

  /// Text-only pill/badge.
  factory AppPill.label(
    String text, {
    Key? key,
    required Color color,
    required TextStyle textStyle,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.x12,
      vertical: AppSpacing.x6,
    ),
    Border? border,
    VoidCallback? onTap,
    bool ellipsize = false,
  }) {
    return AppPill(
      key: key,
      color: color,
      padding: padding,
      border: border,
      onTap: onTap,
      child: Text(
        text,
        maxLines: ellipsize ? 1 : null,
        overflow: ellipsize ? TextOverflow.ellipsis : null,
        style: textStyle,
      ),
    );
  }
}

/// A selectable pill toggle (aspect-ratio / export-size selectors). Colors are
/// injected so the same control works on light surfaces and dark overlays.
class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color activeColor;
  final Color activeLabel;
  final Color inactiveColor;
  final Color inactiveLabel;
  final EdgeInsetsGeometry padding;

  const AppChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.activeLabel,
    required this.inactiveColor,
    required this.inactiveLabel,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.x14,
      vertical: AppSpacing.x8,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: AppPressable(
        onTap: onTap,
        // Chips are swept across while comparing options, so they get the
        // lightest step on the ladder rather than a selection thud each time.
        haptic: AppHaptics.tick,
        child: AppTapTarget(
          child: AnimatedContainer(
            duration: context.motion(AppDurations.quick),
            padding: padding,
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: AppRadius.brPill,
            ),
            child: Text(
              label,
              style: AppText.badgeMd(active ? activeLabel : inactiveLabel),
            ),
          ),
        ),
      ),
    );
  }
}
