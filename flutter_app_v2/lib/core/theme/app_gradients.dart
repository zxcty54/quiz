import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/constants/app_colors.dart';

/// The v2 gradient library.
///
/// v1 only had one gradient (`splashGradient`) and every screen that wanted a
/// "premium" surface hand-rolled its own `LinearGradient`, so the app looked
/// like five different products. Every gradient now comes from here, and they
/// are all built out of the same two brand hues so they cannot clash.
class AppGradients {
  AppGradients._();

  /// Primary brand sweep — buttons, active pills, progress fills.
  static const LinearGradient brand = LinearGradient(
    colors: <Color>[AppColors.brandBlue, AppColors.brandIndigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Slightly deeper variant for hero headers that already sit on white.
  static const LinearGradient brandDeep = LinearGradient(
    colors: <Color>[AppColors.brandBlueDeep, Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cyan → blue → indigo: the "study" gradient (Learn Hub, tips).
  static const LinearGradient study = LinearGradient(
    colors: <Color>[Color(0xFF0EA5E9), AppColors.brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Success / streak gradient.
  static const LinearGradient success = LinearGradient(
    colors: <Color>[Color(0xFF22C55E), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm gradient for "jobs / alerts" surfaces.
  static const LinearGradient warm = LinearGradient(
    colors: <Color>[Color(0xFFF59E0B), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark hero gradient behind the onboarding / splash brand mark.
  static const LinearGradient midnight = LinearGradient(
    colors: <Color>[AppColors.onboardingBg, Color(0xFF101A33)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Aurora ribbon colours used by the animated background painter.
  static const List<Color> aurora = <Color>[
    Color(0xFF1D4ED8),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  /// Top-of-page wash: transparent → subtle brand tint (light + dark).
  static LinearGradient pageWash(bool isDark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const <Color>[Color(0x332563EB), Color(0x000B0F19)]
            : const <Color>[Color(0x142563EB), Color(0x00F8FAFC)],
      );

  /// A translucent white glass overlay (used on top of gradient surfaces).
  static LinearGradient glass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Colors.white.withOpacity(0.22),
      Colors.white.withOpacity(0.04),
    ],
  );
}
