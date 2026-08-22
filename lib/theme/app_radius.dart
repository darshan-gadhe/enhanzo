import 'package:flutter/widgets.dart';

/// Corner-radius scale. A discrete set of clean steps plus a `pill` value for
/// fully-rounded (stadium) shapes. Prefer the `br*` [BorderRadius] helpers at
/// call sites so no raw `BorderRadius.circular(n)` remains in the UI.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 28;

  /// Fully rounded — resolves to a stadium shape on any finite-height box.
  static const double pill = 999;

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rXxl = Radius.circular(xxl);
  static const Radius rXxxl = Radius.circular(xxxl);
  static const Radius rPill = Radius.circular(pill);

  static const BorderRadius brXs = BorderRadius.all(rXs);
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius brXxl = BorderRadius.all(rXxl);
  static const BorderRadius brXxxl = BorderRadius.all(rXxxl);
  static const BorderRadius brPill = BorderRadius.all(rPill);
}
