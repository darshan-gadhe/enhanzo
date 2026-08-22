import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// How far a control shrinks while held.
enum PressDepth {
  /// Large surfaces — cards, tiles, image panels. A big element needs a
  /// smaller ratio to travel the same visible distance.
  card(0.98),

  /// Buttons, pills, chips, rows.
  control(0.96),

  /// Small dense chrome where a visible scale would read as a glitch.
  none(1.0);

  final double scale;
  const PressDepth(this.scale);
}

/// Wraps a widget so it responds to touch: it scales down while held, springs
/// back on release, **cancels if the finger slides off before lifting**, and
/// fires a haptic on the tap that lands.
///
/// This is the app's single press-feedback primitive. Cards, pills, chips and
/// buttons all route through it so "what a press feels like" is defined once.
///
/// Two details do most of the work:
///
/// * **Cancel-on-drag-out.** Sliding off before release aborts the tap *and*
///   returns the scale — the user can see they escaped the action. A plain
///   `GestureDetector` gives the escape but no feedback that it worked.
/// * **A haptic on tap, not on tap-down.** Firing at press start would buzz for
///   gestures the user then cancels; firing on the completed tap means the
///   haptic and the action always agree.
///
/// Honours reduced motion via [AppMotion] — the haptic and the cancel semantics
/// stay, only the visible travel is removed.
class AppPressable extends StatefulWidget {
  final Widget child;

  /// Null renders the child inert (no press feedback, no haptic, no hit test).
  final VoidCallback? onTap;

  /// How far to shrink while held.
  final PressDepth depth;

  /// Haptic fired on a completed tap. Pass null for controls that would be
  /// noisy — anything the user drags across, or a row inside a list that
  /// already vibrates at a higher level.
  final VoidCallback? haptic;

  /// Passed through to the underlying gesture detector.
  final HitTestBehavior behavior;

  /// Background painted behind the child while held, instead of (or alongside)
  /// the scale. For elements that can't travel without disturbing what they
  /// sit against — a row inside a grouped card, where a shrinking row would
  /// slide away from its neighbours. Pair it with [PressDepth.none].
  final Color? highlight;

  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.depth = PressDepth.control,
    this.haptic = AppHaptics.select,
    this.behavior = HitTestBehavior.opaque,
    this.highlight,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    widget.haptic?.call();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    final scale = _pressed ? widget.depth.scale : 1.0;
    Widget content = widget.child;
    if (widget.highlight != null) {
      content = AnimatedContainer(
        duration: context.motion(AppDurations.fast),
        curve: AppDurations.easeOut,
        color: _pressed ? widget.highlight : const Color(0x00000000),
        child: content,
      );
    }
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      // Fires when the finger slides off the widget or the gesture is stolen
      // by a scrollable — the press must visibly release either way.
      onTapCancel: () => _set(false),
      onTap: _handleTap,
      child: RepaintBoundary(
        child: AnimatedScale(
          scale: scale,
          duration: context.motion(AppDurations.fast),
          curve: AppDurations.easeOut,
          child: content,
        ),
      ),
    );
  }
}
