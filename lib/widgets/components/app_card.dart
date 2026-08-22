import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'pressable.dart';

/// A rounded surface container — the app's single elevated-card primitive.
///
/// **Elevated by default.** On the light theme a white card sits on a white
/// canvas, so without a lift it would vanish; every card therefore carries a
/// hairline [AppPalette.cardBorder] frame plus a soft [AppShadows.cardResting]
/// shadow unless it opts out with `elevated: false`. On the dark theme the
/// shadow is invisible (black on black) and the card lifts by surface tone
/// instead — the same code path reads correctly in both. An explicit [shadow]
/// or [border] always wins over the default.
///
/// When [onTap] is set the whole card becomes a tap target with press feedback
/// via [AppPressable] — cards are the app's most-tapped surface, so an inert
/// one is the most visible place a UI can feel dead.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final Color? color;

  /// Whether the card carries the default resting lift (hairline + soft
  /// shadow). Leave true for any surface raised off the canvas; pass false for
  /// a card nested inside another surface, where a second frame would read as
  /// clutter.
  final bool elevated;

  /// Overrides the default resting shadow. Null keeps the default when
  /// [elevated]; pass `const []` to force no shadow while keeping the frame.
  final List<BoxShadow>? shadow;

  /// Overrides the default hairline frame. Null keeps the default when
  /// [elevated].
  final Border? border;
  final bool clip;
  final VoidCallback? onTap;

  /// Haptic fired when a tap lands. Defaults to [AppHaptics.select]; pass null
  /// for a card inside a surface that already gives feedback at a higher level.
  final VoidCallback? haptic;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.brXxl,
    this.color,
    this.elevated = true,
    this.shadow,
    this.border,
    this.clip = false,
    this.onTap,
    this.haptic = AppHaptics.select,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final surface = color ?? p.elevated;
    // Resolve the resting lift once: an explicit value always wins; otherwise
    // an elevated card gets the default frame + shadow and a flat one gets
    // neither.
    final resolvedShadow =
        shadow ?? (elevated ? AppShadows.cardResting : null);
    final resolvedBorder =
        border ??
        (elevated
            ? Border.all(
                color: p.cardBorder,
                width: AppSizing.strokeHairline,
              )
            : null);

    Widget card = Container(
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: borderRadius,
        border: resolvedBorder,
        boxShadow: resolvedShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      card = AppPressable(
        onTap: onTap,
        haptic: haptic,
        depth: PressDepth.card,
        child: card,
      );
    }
    return card;
  }
}
