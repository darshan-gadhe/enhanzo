/// Spacing scale for the whole app.
///
/// Two layers:
///
/// * The **step ladder** ([x2]–[x48]) — raw gaps, for one-off distances inside
///   a component where no named relationship applies.
/// * The **rhythm tokens** ([sectionGap], [titleToContent], [itemGap],
///   [innerGap]) — the vertical relationships that repeat on every screen.
///   Prefer these: they are what keeps two screens feeling like one app. Reach
///   for a raw step only when the gap genuinely isn't one of these relationships.
///
/// The rhythm values follow a tight 4pt family, chosen because the app reads
/// dense rather than airy. Changing one of these four numbers re-times the
/// whole app on purpose — that's the point of them being here.
class AppSpacing {
  AppSpacing._();

  // ---- Step ladder ----
  static const double x2 = 2;
  static const double x4 = 4;
  static const double x6 = 6;
  static const double x8 = 8;
  static const double x10 = 10;
  static const double x12 = 12;
  static const double x14 = 14;
  static const double x16 = 16;
  static const double x20 = 20;
  static const double x24 = 24;
  static const double x28 = 28;
  static const double x32 = 32;
  static const double x40 = 40;
  static const double x48 = 48;

  // ---- Vertical rhythm ----
  //
  // A strict, monotonic ladder — each step reads as a distinct level of
  // grouping: tight(4) < inner(8) < titleToContent(12) < item(16) < section(32).
  // The two that used to collide are the important pair: a section title now
  // sits *closer* to its content (12) than sibling cards sit to each other
  // (16), so a heading reads as bound to the block it introduces rather than as
  // just another item in the stack.

  /// Section → section. The largest routine gap on a screen.
  static const double sectionGap = x32;

  /// A section title / label → the content it introduces. Deliberately tighter
  /// than [itemGap] so the title groups with what follows it.
  static const double titleToContent = x12;

  /// Sibling → sibling within a list, grid or stack of cards.
  static const double itemGap = x16;

  /// Tightly-bound lines inside one component (title → subtitle, icon → label).
  static const double innerGap = x8;

  /// The tightest pairing — a label stacked directly over its sub-label inside
  /// a dense row, where [innerGap] would read as two separate lines.
  static const double tightGap = x4;

  // ---- Semantic layout values ----

  /// Default screen horizontal padding.
  static const double screenH = x20;

  /// Default top gap under the safe-area on tab screens.
  static const double screenTop = x8;

  /// Top offset for a centered empty state, so it sits below the optical
  /// centre rather than floating against the header.
  static const double emptyStateTop = 72;

  /// Bottom list padding so scrollable content clears the floating bottom nav.
  static const double bottomNavClearance = 130;
}
