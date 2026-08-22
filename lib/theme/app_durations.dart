import 'package:flutter/animation.dart';

/// Motion tokens. A small set of durations and curves so every animation in the
/// app pulls from the same timing scale instead of ad-hoc millisecond literals.
class AppDurations {
  AppDurations._();

  /// Press / scale feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// Small state changes (selection, opacity, chip toggles).
  static const Duration quick = Duration(milliseconds: 180);

  /// Container morphs, switches, ratio glyphs.
  static const Duration base = Duration(milliseconds: 250);

  /// Screen reveals and card scale transitions.
  static const Duration slow = Duration(milliseconds: 320);

  /// Carousel page settle.
  static const Duration xSlow = Duration(milliseconds: 550);

  /// Staggered entrance sequence.
  static const Duration entrance = Duration(milliseconds: 900);

  /// Continuous processing ring rotation.
  static const Duration ring = Duration(milliseconds: 1100);

  /// One-shot intro sweep of the before/after divider.
  static const Duration sweep = Duration(milliseconds: 1400);

  static const Curve easeOut = Curves.easeOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Overshoot spring — nav selection, interactive element bounce-back.
  static const Curve spring = Curves.easeOutBack;

  /// Gentle decelerate for staggered entrance animations.
  static const Curve decelerate = Curves.decelerate;
}
