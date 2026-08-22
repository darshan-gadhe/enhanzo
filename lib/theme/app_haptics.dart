import 'package:flutter/services.dart';

/// The app's haptic vocabulary.
///
/// Haptics are *modulated*, not uniform: a tap that happens dozens of times a
/// session must feel lighter than one that commits work, or the whole app turns
/// into a buzzing annoyance. Every call site picks a role from this list rather
/// than reaching for [HapticFeedback] directly, so the intensity ladder stays
/// consistent across screens.
///
/// The ladder, quietest → loudest:
///
/// * [tick]      — moving through options (chips, tabs, segmented controls).
/// * [select]    — choosing a thing (a tool, a plan, a card that opens).
/// * [commit]    — starting real work (generate, process, purchase).
/// * [success]   — that work finished.
/// * [warn]      — a destructive or failed action.
class AppHaptics {
  AppHaptics._();

  /// Passing over / between options. The lightest thing the OS offers.
  static void tick() => HapticFeedback.selectionClick();

  /// Committing to one option — a tool tile, a plan row, an opened card.
  static void select() => HapticFeedback.lightImpact();

  /// Kicking off substantial work: generate, process, purchase.
  static void commit() => HapticFeedback.mediumImpact();

  /// A job completed successfully (download saved, purchase granted).
  static void success() => HapticFeedback.mediumImpact();

  /// Something destructive or failed — deletion, a rejected purchase.
  static void warn() => HapticFeedback.heavyImpact();
}
