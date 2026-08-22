import 'package:flutter/widgets.dart';

/// Brand + semantic colors from the Enhanzo design tokens.
///
/// The app's identity is **monochrome**: there is no fixed brand hue. The single
/// accent — the ink that carries every selected state, primary action and the
/// upgrade path — is *theme-flipping* (near-black on light, white on dark) and
/// therefore lives on [AppPalette.accent] / [AppPalette.onAccent], not here.
/// Only theme-independent constants belong in this class.
class AppColors {
  AppColors._();

  /// Affirmative state — the only place it appears is a switch that is on.
  static const Color success = Color(0xFF34C759);

  /// Destructive actions (Delete).
  static const Color danger = Color(0xFFFF453A);

  /// Disabled fill for a control that can't be pressed yet.
  static const Color gray = Color(0xFF8E8E93);

  /// Neutral white used for content and chrome that sits on top of imagery
  /// (labels, icons, upload glyphs) — always white regardless of theme, because
  /// imagery is scrimmed dark. Kept as a named token so the UI never hardcodes
  /// `Colors.white` inline. For an accent fill that must invert with the theme,
  /// use [AppPalette.onAccent] instead.
  static const Color onColor = Color(0xFFFFFFFF);
}

/// Fixed tokens for the always-dark surfaces (the premium paywall and the
/// generate / edit overlays) and for content layered over imagery. These are
/// independent of the light/dark [AppPalette] because those surfaces are dark
/// in every theme.
class AppOverlay {
  AppOverlay._();

  // Dark canvases.
  static const Color black = Color(0xFF000000);
  static const Color canvas = Color(0xFF0B0B0F);

  /// Near-black ink for text/spinners on a white CTA.
  static const Color ink = Color(0xFF0A0A0A);

  // White content ladder (opacity steps on white).
  //
  // The ladder stops at 0.60 on purpose. It used to run down to 0.45 and 0.40,
  // and every rung below 0.60 falls under the 4.5:1 contrast floor against
  // these near-black canvases — those two steps existed only to make text
  // quieter, and the quietest they got was illegible. Full white lives in
  // [AppColors.onColor]; there is no duplicate of it here.
  //
  // If a piece of text needs to recede further than [onDarkLo], it needs less
  // prominence in the layout, not less contrast.
  static const Color onDarkHi = Color(0xE6FFFFFF); // 0.90
  static const Color onDarkStrong = Color(0xC7FFFFFF); // 0.78
  static const Color onDarkMed = Color(0xB8FFFFFF); // 0.72
  static const Color onDarkLo = Color(0x99FFFFFF); // 0.60 — contrast floor

  // White surface / stroke fills on dark.
  static const Color fill = Color(0x0FFFFFFF); // 0.06
  static const Color fillMed = Color(0x1AFFFFFF); // 0.10
  static const Color fillStrong = Color(0x24FFFFFF); // 0.14
  static const Color stroke = Color(0x29FFFFFF); // 0.16
  static const Color strokeStrong = Color(0x33FFFFFF); // 0.20

  // Black scrim fills for legibility over imagery.
  static const Color scrimSoft = Color(0x40000000); // 0.25
  static const Color scrimMed = Color(0x73000000); // 0.45
  static const Color scrimTag = Color(0x80000000); // 0.50

  /// Faint dim applied to the "before" side of a comparison.
  static const Color beforeDim = Color(0x14000000); // 0.08

  /// Bottom-up readability scrim for text over imagery.
  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x9E000000)], // transparent -> 0.62
  );

  /// Stronger, later-starting bottom scrim (large hero/category cards).
  static const LinearGradient bottomScrimStrong = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.45, 1.0],
    colors: [Color(0x00000000), Color(0x99000000)], // transparent -> 0.60
  );

  /// Compact label scrim used on small tiles (style/variation chips).
  static const LinearGradient labelScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB8000000)], // transparent -> 0.72
  );

  /// Fades hero imagery into the solid surface underneath it — the paywall's
  /// plan section.
  ///
  /// Takes that surface's colour rather than assuming black, so the seam lands
  /// on the screen background in whichever theme is running. Interpolating
  /// from the surface's own transparent value (not a bare `0x00000000`) keeps
  /// the ramp from passing through grey on the light theme.
  static LinearGradient fadeTo(Color surface) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.55, 1.0],
    colors: [surface.withValues(alpha: 0), surface],
  );

  /// Left-weighted cinematic scrim for a full-width feature banner. Darkens the
  /// leading edge — where the glyph chip, title and subtitle sit — while
  /// leaving the far side of the artwork visible. Pair with [bottomScrimStrong]
  /// so text stays legible over any scene.
  static const LinearGradient bannerScrim = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.5, 1.0],
    colors: [
      Color(0xD9000000), // 0.85
      Color(0x73000000), // 0.45
      Color(0x1A000000), // 0.10
    ],
  );
}

/// A resolved set of surface/text colors for a given brightness.
@immutable
class AppPalette {
  final Color screenBg;
  final Color elevated;
  final Color secondarySurface;
  final Color fieldBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color border2;

  /// The hairline that frames a raised card against the app canvas. On the
  /// light theme the canvas and the card are both white, so this outline is the
  /// only thing separating them — it is deliberately a touch stronger than a
  /// plain [border] divider. On dark the card already lifts off the black
  /// canvas by surface tone, so this is a quiet crispening edge.
  final Color cardBorder;

  final Color navBar;

  /// The single monochrome accent — the "ink" that carries every primary
  /// action, selected state and the upgrade path. It flips with the theme
  /// (near-black on light, white on dark) so the brand reads as
  /// black-and-white rather than a fixed hue.
  final Color accent;

  /// Content that sits *on* an [accent] fill (a filled CTA, a selected chip,
  /// the upgrade banner). Inverts [accent], so a near-black button carries
  /// white text on light and a white button carries near-black text on dark.
  final Color onAccent;

  const AppPalette({
    required this.screenBg,
    required this.elevated,
    required this.secondarySurface,
    required this.fieldBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.border2,
    required this.cardBorder,
    required this.navBar,
    required this.accent,
    required this.onAccent,
  });

  static const AppPalette light = AppPalette(
    // Pure white canvas. Cards are white too and lift off it by hairline
    // ([cardBorder]) + a soft resting shadow rather than by a tonal step.
    screenBg: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    secondarySurface: Color(0xFFF2F2F7),
    fieldBg: Color(0xFFE9E9EC),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0x993C3C43), // rgba(60,60,67,0.6)
    textTertiary: Color(0x4D3C3C43), // rgba(60,60,67,0.3)
    border: Color(0x0F000000), // rgba(0,0,0,0.06)
    border2: Color(0x24000000), // rgba(0,0,0,0.14)
    cardBorder: Color(0x14000000), // rgba(0,0,0,0.08) — card frame on white
    // Fully opaque: the nav is a solid bar on the bottom edge, not a frosted
    // island, so nothing is meant to show through it. On this theme it shares
    // the canvas colour and is separated by its top divider alone.
    navBar: Color(0xFFFFFFFF),
    accent: Color(0xFF1C1C1E), // near-black ink
    onAccent: Color(0xFFFFFFFF), // white on the ink fill
  );

  static const AppPalette dark = AppPalette(
    screenBg: Color(0xFF000000),
    elevated: Color(0xFF1C1C1E),
    secondarySurface: Color(0xFF2C2C2E),
    fieldBg: Color(0xFF1C1C1E),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0x99EBEBF5), // rgba(235,235,245,0.6)
    textTertiary: Color(0x4DEBEBF5), // rgba(235,235,245,0.3)
    border: Color(0x17FFFFFF), // rgba(255,255,255,0.09)
    border2: Color(0x29FFFFFF), // rgba(255,255,255,0.16)
    cardBorder: Color(0x1FFFFFFF), // rgba(255,255,255,0.12) — crispens card edge
    // A real tonal step above the pure-black [screenBg]: on this theme the
    // bar is told apart by being lighter than the page, not by its divider.
    navBar: Color(0xFF1C1C1E),
    accent: Color(0xFFFFFFFF), // white ink
    onAccent: Color(0xFF0A0A0A), // near-black on the white fill
  );

  /// Neutral surface gradient for image placeholders.
  LinearGradient get placeholderGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondarySurface, fieldBg],
  );
}

/// Access the current [AppPalette] via [BuildContext].
class PaletteScope extends InheritedWidget {
  final AppPalette palette;

  const PaletteScope({super.key, required this.palette, required super.child});

  static AppPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaletteScope>();
    assert(scope != null, 'No PaletteScope found in context');
    return scope!.palette;
  }

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      oldWidget.palette != palette;
}
