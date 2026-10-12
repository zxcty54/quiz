import 'package:flutter/material.dart';

/// Single source of truth for the app palette.
///
/// v1 hardcoded the same hex literals (`0xFF2563EB`, `0xFF1E293B`, …) in more
/// than 60 files. New code should read from here; the constants below are
/// byte-identical to the v1 values, so nothing changes visually.
class AppColors {
  AppColors._();

  // ------------------------------------------------------------- brand -----
  static const Color brandBlue = Color(0xFF2563EB);
  static const Color brandBlueDeep = Color(0xFF1D4ED8);
  static const Color brandIndigo = Color(0xFF4F46E5);
  static const Color brandIndigoDeep = Color(0xFF6366F1);
  static const Color brandCyan = Color(0xFF0284C7);
  static const Color brandTeal = Color(0xFF0D9488);
  static const Color whatsappGreen = Color(0xFF075E54);

  // ------------------------------------------------------------ status -----
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color purple = Color(0xFF7C3AED);

  // ------------------------------------------------------------- light -----
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightInk = Color(0xFF0F172A);
  static const Color lightMuted = Color(0xFF334155);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // -------------------------------------------------------------- dark -----
  static const Color darkScaffold = Color(0xFF0B0F19);
  static const Color darkScaffoldAlt = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkInk = Color(0xFFF8FAFC);
  static const Color darkMuted = Color(0xFFCBD5E1);
  static const Color darkBorder = Color(0xFF263449);

  // --------------------------------------------------------------- misc ----
  /// Onboarding hero background (obsidian midnight navy).
  static const Color onboardingBg = Color(0xFF070B14);
  static const Color onboardingGlow = Color(0xFF0E1C38);
  static const Color onboardingAccent = Color(0xFF38BDF8);

  /// The launch / splash gradient.
  static const List<Color> splashGradient = <Color>[
    Color(0xFF2563EB),
    Color(0xFF1E40AF),
  ];
}
