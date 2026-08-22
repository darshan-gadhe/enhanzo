import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's type scale.
///
/// Every role is **locked**: each returns a fully-specified [TextStyle] and
/// takes nothing but a colour. There are deliberately no `size:` or `weight:`
/// parameters — an override at a call site is how a scale quietly acquires a
/// 13pt and a 15pt variant of the same role on different screens. If a size
/// you need isn't here, add a named role rather than passing a number.
///
/// Weights run one step heavier than a system default would: titles sit at
/// w800–w900 and body copy at w500, giving the app a bold, high-contrast voice.
///
/// Multi-line roles (`body*`, `caption*`) carry their own line-height; single-
/// line roles (titles, badges, buttons) deliberately don't.
class AppText {
  AppText._();

  /// Text & Display face — Outfit: a modern, rounded, ultra-bold geometric
  /// sans-serif from Google Fonts.
  static const String _text = 'Outfit';

  /// Display face — uses Outfit's Black (w900) & ExtraBold (w800) weights.
  static const String _display = 'Outfit';

  // ---- Display / titles ----

  /// Big marketing/paywall heading — ultra-bulky heavy headline.
  static TextStyle heroTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 46,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.05,
    color: color,
  );

  /// Screen large title (Settings, Tools, History) — heavy & boldest.
  static TextStyle largeTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 37,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    height: 1.08,
    color: color,
  );

  /// App wordmark in the home top bar — boldest heavy.
  static TextStyle wordmark(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 31,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.6,
    color: color,
  );

  /// Section heading within a screen — boldest heavy.
  static TextStyle sectionTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 27,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.1,
    color: color,
  );

  /// Compact brand lockup title.
  static TextStyle brandTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: color,
  );

  /// Sheet / dialog heading.
  static TextStyle sheetTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: color,
  );

  /// Centered nav/step title on full-screen overlays.
  static TextStyle navTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: color,
  );

  /// Headline of an empty state.
  static TextStyle emptyTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: color,
  );

  // ---- Cards / list rows ----

  /// Card heading — boldest heavy.
  static TextStyle cardTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 21,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: color,
  );

  /// Image-card title (tool tiles and cards with copy overlaid on artwork).
  static TextStyle cardTitleOnImage(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 21,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    height: 1.15,
    color: color,
  );

  /// Tool / row title.
  static TextStyle toolTitle(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 21,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: color,
  );

  /// Settings row label.
  static TextStyle settingLabel(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: color,
  );

  /// Small grid-card title (history).
  static TextStyle tileTitle(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    height: 1.15,
    color: color,
  );

  /// Sentence-case heading that introduces a group of items in a list.
  static TextStyle groupLabel(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: color,
  );

  /// A numeric readout presented as its own object.
  static TextStyle metric(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.4,
    color: color,
  );

  /// Compact label under a tool glyph.
  static TextStyle toolLabel(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.1,
    color: color,
  );

  // ---- Body copy ----

  /// Default running text — bulky heavy.
  static TextStyle body(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.45,
    color: color,
  );

  /// Running text in dense contexts — bulky heavy.
  static TextStyle bodyCompact(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.4,
    color: color,
  );

  /// [bodyCompact] carrying extra emphasis.
  static TextStyle bodyCompactStrong(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    height: 1.4,
    color: color,
  );

  /// Smallest running text — bulky heavy.
  static TextStyle bodySmall(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.4,
    color: color,
  );

  // ---- Captions / supporting text ----

  /// Supporting text under a title or beside a row label — bulky heavy.
  static TextStyle captionLg(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.4,
    color: color,
  );

  /// Metadata beside a heading (counts, timestamps) — bulky heavy.
  static TextStyle captionMd(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.35,
    color: color,
  );

  /// Default caption — bulky heavy.
  static TextStyle caption(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.35,
    color: color,
  );

  /// Smallest supporting text — bulky heavy.
  static TextStyle captionSm(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    height: 1.3,
    color: color,
  );

  /// Uppercase group label above a set of controls — heavy black.
  static TextStyle overline(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: color,
  );

  // ---- Buttons / actions ----

  /// High-contrast primary CTA label — heavy black.
  static TextStyle cta(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: color,
  );

  /// Standard filled-button label — heavy black.
  static TextStyle button(Color color) => TextStyle(
    fontFamily: _display,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: color,
  );

  /// Affirmative text action in a nav bar — heavy black.
  static TextStyle navAction(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: color,
  );

  /// Dismissive text action in a nav bar (Cancel, Back) — heavy.
  static TextStyle navActionQuiet(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: color,
  );

  // ---- Badges / pills / tags ----

  /// Largest pill label — heavy black.
  static TextStyle badgeLg(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: color,
  );

  /// Selectable chip label — heavy black.
  static TextStyle badgeMd(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: color,
  );

  /// Default badge / pill text — heavy black.
  static TextStyle badge(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: color,
  );

  /// Smallest badge — corner counters on thumbnails.
  static TextStyle badgeSm(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: color,
  );

  /// Bottom-navigation tab label. Base weight is the quieter of the pair — the
  /// active tab bumps to w900 so the label genuinely gets heavier when selected.
  static TextStyle navLabel(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.1,
    color: color,
  );

  /// Tiny uppercase overlay tag (BEFORE / AFTER).
  static TextStyle tag(Color color) => TextStyle(
    fontFamily: _text,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: color,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light, AppPalette.light);
  static ThemeData dark() => _base(Brightness.dark, AppPalette.dark);

  static ThemeData _base(Brightness brightness, AppPalette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.screenBg,
      // Any text that doesn't go through an AppText role still defaults to the
      // app's text face rather than the platform default.
      fontFamily: AppText._text,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        surface: p.elevated,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: p.accent),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
