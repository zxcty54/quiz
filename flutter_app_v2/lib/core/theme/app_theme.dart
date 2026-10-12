import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/constants/app_colors.dart';

/// Light + dark themes for MockTester.
///
/// The values are ported 1:1 from v1 `main.dart` so the visual result is
/// identical; the only change is that Material 3 is configured explicitly with
/// `useMaterial3: true` and a coherent `ColorScheme` (v1 mixed `cardColor`,
/// `scaffoldBackgroundColor` and a seeded scheme, which produced mismatched
/// tones in dialogs and bottom sheets).
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightScaffold,
        cardColor: AppColors.lightSurface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          brightness: Brightness.light,
          surface: AppColors.lightSurface,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: AppColors.lightSurface,
          foregroundColor: AppColors.lightInk,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightSurface,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightBorder,
          thickness: 1,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkScaffold,
        cardColor: AppColors.darkSurface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandBlue,
          brightness: Brightness.dark,
          surface: AppColors.darkSurface,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: AppColors.darkSurface,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkBorder,
          thickness: 1,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      );
}
