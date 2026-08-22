import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's single icon vocabulary.
///
/// Every glyph in Enhanzo is a [Lucide](https://lucide.dev) icon, and every
/// screen reaches it through a **semantic** name here — [close], [share],
/// [delete] — never a raw `LucideIcons.x` inline. One concept therefore has one
/// glyph across the whole app: the share action can't be `ios_share` on one
/// screen and `share2` on another, and swapping the mark for a concept is a
/// one-line change in this file rather than a hunt through the widgets.
///
/// Lucide is a single-weight outline set drawn on a 24px grid with a 2px
/// stroke, so the iconography reads as one bold, consistent family regardless of
/// where a glyph appears — there is no thin/filled drift to police. Size is
/// still owned by [AppSizing]; this registry owns only *which* glyph.
class AppIcons {
  AppIcons._();

  // ---- Bottom navigation ----
  /// Home tab.
  static const IconData home = LucideIcons.house;

  /// History tab.
  static const IconData history = LucideIcons.history;

  /// Settings tab.
  static const IconData settings = LucideIcons.settings;

  // ---- Appearance ----
  /// Dark theme active / dark-mode row.
  static const IconData dark = LucideIcons.moon;

  /// Light theme active.
  static const IconData light = LucideIcons.sun;

  // ---- Universal actions ----
  /// Dismiss a full-screen flow or sheet.
  static const IconData close = LucideIcons.x;

  /// Share — the OS share sheet, everywhere.
  static const IconData share = LucideIcons.share2;

  /// Forward affordance on a row or card.
  static const IconData chevronRight = LucideIcons.chevronRight;

  /// "Continue" / proceed arrow on banners and tool cards.
  static const IconData forward = LucideIcons.arrowRight;

  /// Confirmation / benefit check.
  static const IconData check = LucideIcons.check;

  /// Run the edit again on a fresh photo (result step).
  static const IconData refresh = LucideIcons.refreshCw;

  /// Restore previous purchases.
  static const IconData restore = LucideIcons.rotateCcw;

  /// Delete a history entry.
  static const IconData delete = LucideIcons.trash2;

  /// Re-edit / adjust an existing result (history detail).
  static const IconData adjust = LucideIcons.slidersHorizontal;

  /// The before/after divider grip — points along its travel axis (L↔R).
  static const IconData compare = LucideIcons.chevronsLeftRight;

  // ---- Choosing a photo ----
  /// The photo library — both a share destination and a source for an edit.
  static const IconData photos = LucideIcons.images;

  /// Shoot a new photo for an edit.
  static const IconData camera = LucideIcons.camera;

  // ---- Share sheet targets ----

  /// Copy a shareable link.
  static const IconData link = LucideIcons.link;

  /// More share destinations.
  static const IconData more = LucideIcons.ellipsis;

  // ---- Settings & informational ----
  /// Privacy / secure-processing row.
  static const IconData privacy = LucideIcons.lock;

  /// Terms of Use row.
  static const IconData terms = LucideIcons.fileText;

  /// Help & support row.
  static const IconData help = LucideIcons.circleHelp;

  /// Rate the app.
  static const IconData rate = LucideIcons.star;

  /// Informational note (share-sheet footnote, info sheets).
  static const IconData info = LucideIcons.info;

  /// Watch a rewarded ad.
  static const IconData playCircle = LucideIcons.circlePlay;

  /// Premium / unlock affordance next to an ad-gated action.
  static const IconData sparkles = LucideIcons.sparkles;

  // ---- Status ----
  /// Something went wrong (processing failure).
  static const IconData error = LucideIcons.circleAlert;
}
