/// Fixed dimensions: icon sizes, control heights, stroke widths and the
/// accessibility tap-target floor.
///
/// The counterpart to [AppSpacing] — that scale governs the space *between*
/// things, this one governs how big the things themselves are. Every width,
/// height, icon `size:` and `strokeWidth:` in the UI should resolve to a token
/// here rather than a literal, so a control can't drift a point or two away
/// from its siblings on one screen.
class AppSizing {
  AppSizing._();

  // ---- Icon glyphs ----
  //
  // The whole scale runs one step heavier than a system default would, to match
  // the app's big, bold voice — glyphs read as confident marks, never thin
  // hints. Bumped up together so their proportions stay consistent.

  /// Inline with small text (trailing chevrons, pill glyphs).
  static const double iconXs = 16;

  /// Standard small glyph — settings rows, list chevrons, overlay chrome.
  static const double iconSm = 18;

  /// Slider handles and other compact controls.
  static const double iconMd = 20;

  /// Default glyph — button leading icons, sheet actions, icon buttons.
  static const double iconLg = 22;

  /// Large action glyph — the result step's "apply another" control.
  static const double iconXl = 26;

  /// The raised centre action.
  static const double iconXxl = 30;

  /// Empty-state and other decorative glyphs.
  static const double iconXxxl = 36;

  // ---- Control heights / square controls ----
  /// Tinted glyph tile inside a settings row.
  static const double controlXs = 32;

  /// Circular overlay chrome (close / share / back).
  static const double controlSm = 36;

  /// Rounded-square icon button.
  static const double controlMd = 42;

  /// Primary filled button / CTA.
  static const double controlLg = 54;

  /// The iOS-style toggle's fixed optical height.
  static const double switchHeight = 34;

  /// Minimum tap target — the iOS 44pt / Android 48dp accessibility floor.
  /// Never let an interactive element's hit area fall below this.
  static const double minTapTarget = 44;

  // ---- Named component dimensions ----
  /// Bottom-nav tab glyph. A step up from [iconXl]: Lucide's single-weight
  /// outline reads lighter than a filled glyph at the same point size, so the
  /// tabs need a little more size to carry the bar.
  static const double navIcon = 28;

  /// Bottom navigation bar height, excluding the bottom safe-area inset.
  static const double navBarHeight = 64;

  /// Width of one bottom-nav slot; also the raised centre action's diameter.
  static const double navSlot = 56;


  /// Circular backdrop behind an empty state's glyph.
  static const double emptyGlyph = 76;

  /// Draggable divider handle on the before/after comparison.
  static const double compareHandle = 34;

  /// Bottom-sheet drag grabber.
  static const double grabberWidth = 38;
  static const double grabberHeight = 4;

  // ---- Strokes ----
  /// Single-pixel divider / list separator.
  static const double strokeHairline = 1;

  /// Selection border — the outline that marks a chosen plan, quality or
  /// aspect tile. Deliberately between [strokeHairline] and [strokeThin]:
  /// heavy enough to read as active, light enough not to shift the layout.
  static const double strokeMedium = 1.5;

  /// Standard border and comparison divider.
  static const double strokeThin = 2;

  /// Heavier decorative stroke — progress spinners, glyph rings.
  static const double strokeThick = 2.5;
}
