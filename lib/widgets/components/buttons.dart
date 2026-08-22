import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_pill.dart';
import 'pressable.dart';
import 'tap_target.dart';

/// The app's filled button / CTA. Handles the press-scale micro-interaction,
/// an in-flight loading spinner, disabled state and screen-reader semantics.
///
/// Used for every primary action — the paywall CTA, the Generate button, the
/// Download buttons — by varying [color], [height], [borderRadius] and
/// [labelStyle]. Expands to fill width unless [width] is given.
///
/// **Deliberately label-only.** It used to accept a leading icon, and the one
/// call site that passed one put a sparkle on "Generate". A CTA is the clearest
/// element on its screen already; a glyph beside the verb adds decoration, not
/// meaning. There is no icon parameter so that decision can't quietly return.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color labelColor;
  final TextStyle? labelStyle;
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final bool loading;

  /// Haptic fired when a tap lands. Defaults to [AppHaptics.commit] because
  /// this component *is* the app's primary action — Generate, Download, the
  /// paywall CTA — and those all start real work.
  final VoidCallback? haptic;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    this.labelColor = AppColors.onColor,
    this.labelStyle,
    this.height = AppSizing.controlLg,
    this.width,
    this.borderRadius = AppRadius.brPill,
    this.loading = false,
    this.haptic = AppHaptics.commit,
  });

  /// Taps are refused while a job is in flight, so a double-tap can't fire the
  /// action (or a purchase) twice.
  bool get _enabled => onTap != null && !loading;

  @override
  Widget build(BuildContext context) {
    final style = labelStyle ?? AppText.button(labelColor);
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: AppPressable(
        onTap: _enabled ? onTap : null,
        haptic: haptic,
        child: AnimatedContainer(
          duration: context.motion(AppDurations.base),
          height: height,
          width: width,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
          child: loading
              ? SizedBox(
                  width: AppSizing.iconXl,
                  height: AppSizing.iconXl,
                  child: CircularProgressIndicator(
                    strokeWidth: AppSizing.strokeThick,
                    valueColor: AlwaysStoppedAnimation<Color>(labelColor),
                  ),
                )
              : Padding(
                  // Keeps a long label off the pill's rounded ends before it
                  // ellipsizes.
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x16,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A rounded-square icon tile. Decorative when [onTap] is null (e.g. the icon
/// inside a settings row), tappable otherwise.
class AppSquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color iconColor;
  final double size;
  final double iconSize;
  final BorderRadius borderRadius;
  final Border? border;

  /// Haptic fired when a tap lands (ignored when [onTap] is null).
  final VoidCallback? haptic;

  const AppSquareIconButton({
    super.key,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.onTap,
    this.size = AppSizing.controlMd,
    this.iconSize = AppSizing.iconLg,
    this.borderRadius = AppRadius.brLg,
    this.border,
    this.haptic = AppHaptics.select,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: border,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
    if (onTap == null) return tile;
    return AppPressable(
      onTap: onTap,
      haptic: haptic,
      child: AppTapTarget(child: tile),
    );
  }
}

/// A circular icon button — the close / share / back chrome on overlays.
class AppCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color iconColor;
  final double size;
  final double iconSize;

  /// Accessibility label. Circular chrome is icon-only, so without this a
  /// screen reader announces nothing useful.
  final String? semanticLabel;

  /// Haptic fired when a tap lands (ignored when [onTap] is null).
  final VoidCallback? haptic;

  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
    this.size = AppSizing.controlSm,
    this.iconSize = AppSizing.iconSm,
    this.semanticLabel,
    this.haptic = AppHaptics.select,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: AppPressable(
        onTap: onTap,
        haptic: haptic,
        child: AppTapTarget(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}

/// A quiet, outlined pill used to cancel / back out of a full-screen step
/// (processing, error). Palette-driven so it reads correctly whether the step
/// is showing on a light or a dark canvas.
class GhostPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const GhostPill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return AppPill(
      color: p.secondarySurface,
      border: Border.all(color: p.border2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x24,
        vertical: AppSpacing.x12,
      ),
      onTap: onTap,
      child: Text(label, style: AppText.badgeLg(p.textPrimary)),
    );
  }
}

/// A text-only tap target (nav bar actions like Cancel / Next).
///
/// [prominent] picks the weight: the affirmative action in a nav row keeps the
/// default, a dismissive one (Cancel, Back) passes `false` so it recedes.
class AppTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool prominent;

  const AppTextButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.prominent = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: AppPressable(
        onTap: onTap,
        // Text has no surface to scale convincingly; the haptic carries the
        // feedback instead.
        depth: PressDepth.none,
        child: AppTapTarget(
          child: Text(
            label,
            style: prominent
                ? AppText.navAction(color)
                : AppText.navActionQuiet(color),
          ),
        ),
      ),
    );
  }
}
