import 'package:flutter/widgets.dart';

/// Reduced-motion support for the whole app.
///
/// iOS "Reduce Motion" and Android "Remove animations" both surface through
/// [MediaQueryData.disableAnimations]. Flutter honours it for its own route
/// transitions but *not* for anything the app animates itself — every
/// `AnimatedContainer`, `AnimatedScale`, ticker and autoplay timer in this
/// codebase keeps running unless it asks.
///
/// So every animation reads its duration through [AppMotion.duration] (or the
/// [BuildContext] extension below) instead of using an [AppDurations] constant
/// directly. When the user has asked for less motion, the duration collapses to
/// zero: the widget still lands on its final state, it just gets there without
/// travelling. Continuous, decorative or auto-advancing motion checks
/// [AppMotion.enabled] and stops altogether.
class AppMotion {
  AppMotion._();

  /// Whether self-driven animation should play at all.
  ///
  /// False when the platform reports reduced-motion. Gate *continuous* or
  /// *unprompted* motion on this — spinners, autoplay carousels, intro sweeps,
  /// staggered entrances — since those have no user action to acknowledge.
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);

  /// [full] normally, [Duration.zero] under reduced motion.
  ///
  /// Use for *responsive* motion — the state change a user's own tap caused.
  /// The change still happens instantly; only the travel is removed.
  static Duration duration(BuildContext context, Duration full) =>
      enabled(context) ? full : Duration.zero;
}

/// Ergonomic access to [AppMotion] from a build method.
extension AppMotionContext on BuildContext {
  /// Whether self-driven animation should play. See [AppMotion.enabled].
  bool get motionEnabled => AppMotion.enabled(this);

  /// [full], or [Duration.zero] under reduced motion. See [AppMotion.duration].
  Duration motion(Duration full) => AppMotion.duration(this, full);
}
