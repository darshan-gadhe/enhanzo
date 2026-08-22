import 'package:flutter/widgets.dart';

/// Elevation tokens. Two card levels and one floating level, plus the neutral
/// shadow used by draggable handles. No colored/glow shadows — drop shadows
/// only, so nothing reads as a neon glow on interactive surfaces.
class AppShadows {
  AppShadows._();

  /// Resting elevation for a raised card on the app canvas — the app's default
  /// card lift. Soft and low-spread so a whole list of white cards on the white
  /// canvas reads as gently floated rather than heavily shadowed. On the dark
  /// canvas a black shadow on black is invisible by design: there, cards
  /// separate by surface tone and this simply does nothing.
  static const List<BoxShadow> cardResting = [
    BoxShadow(
      color: Color(0x14000000), // 8% black
      blurRadius: 18,
      offset: Offset(0, 8),
      spreadRadius: -12,
    ),
  ];

  /// A firmer card lift for a surface that must read as clearly raised on its
  /// own (a floating sheet header, a pressed-through element).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -6,
    ),
  ];

  /// Small floating chrome — handles, thumbs, chips lifted off imagery.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x59000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  /// A thin hairline shadow for a 1px divider drawn over imagery.
  static const List<BoxShadow> hairline = [
    BoxShadow(color: Color(0x59000000), blurRadius: 6),
  ];

  /// Floating bottom-nav island — a paired ambient + directional shadow that
  /// lifts the pill off the screen without feeling heavy.
  /// Carries most of the separation on the light theme, where a white pill on
  /// a white canvas has no tonal step to rely on — so this is deliberately
  /// deeper than a resting card shadow.
  static const List<BoxShadow> navBar = [
    BoxShadow(
      color: Color(0x24000000), // 14% ambient
      blurRadius: 28,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x33000000), // 20% directional
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: -6,
    ),
  ];
}
