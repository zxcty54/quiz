import 'package:flutter/material.dart';

/// Design tokens for MockTester v2.
///
/// v1 had no scale at all: radii were `8/12/16/18/20/24` chosen per screen,
/// paddings were written inline, and the same shadow literal appeared in
/// dozens of files. Everything visual that is *not* a colour lives here so a
/// screen can say `AppRadii.card` or `AppSpacing.lg` instead of inventing a
/// number.
class AppRadii {
  AppRadii._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double card = 18;
  static const double lg = 22;
  static const double sheet = 28;
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get sheetTop =>
      const BorderRadius.vertical(top: Radius.circular(sheet));
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// 4-point spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;

  /// Standard horizontal gutter of a page.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 16);
}

/// Motion tokens — one place to keep animation speeds consistent.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 520);

  static const Curve entrance = Curves.easeOutCubic;
  static const Curve emphasised = Curves.easeOutQuart;
}

/// Elevation / shadow recipes (the same soft shadow v1 pasted everywhere, now
/// once, and a slightly stronger one for hero surfaces).
class AppElevation {
  AppElevation._();

  static List<BoxShadow> soft({bool dark = false}) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.30 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> lifted({bool dark = false}) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.40 : 0.09),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];

  /// Coloured glow used behind primary actions (brand-tinted shadow).
  static List<BoxShadow> glow(Color color, {double opacity = 0.34}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];
}
