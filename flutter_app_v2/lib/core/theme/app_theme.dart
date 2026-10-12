import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/constants/app_colors.dart';
import 'package:mocktester_v2/core/theme/app_tokens.dart';

/// MockTester v2 theme.
///
/// v1 configured five properties (`scaffoldBackgroundColor`, `cardColor`, a
/// seeded `ColorScheme`, an app bar and a card) in `main.dart` and then every
/// screen overrode colours by hand — that is why the app bar was `#1E293B` on
/// one screen and `Colors.white` on the next, and why a dialog could come out
/// purple (seed colour) on a blue app.
///
/// v2 defines **every** Material component once, here. Screens should not pass
/// colours at all; when they must, they read from [AppColors]. The palette
/// deliberately keeps v1's brand hue (`#2563EB`) so the screens that are still
/// being migrated stay in harmony with the rest of the app.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color scaffold =
        isDark ? AppColors.darkScaffold : AppColors.lightScaffold;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color elevated =
        isDark ? AppColors.darkElevated : AppColors.lightSurface;
    final Color ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final Color muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final Color border = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final Color faint = isDark ? const Color(0xFF8EA0BF) : const Color(0xFF8A94A6);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.brandBlue,
      onPrimary: Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF1A2A5C) : const Color(0xFFE4EBFF),
      onPrimaryContainer: isDark ? Colors.white : AppColors.brandBlueDeep,
      secondary: AppColors.brandIndigo,
      tertiary: AppColors.accentCyan,
      error: AppColors.danger,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
      surfaceContainerHighest: elevated,
    );

    final TextTheme text = _textTheme(ink, muted, faint);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: text,
      primaryTextTheme: text,
      // ------------------------------------------------------------ app bar --
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        iconTheme: IconThemeData(color: isDark ? Colors.white : ink, size: 22),
        actionsIconTheme:
            IconThemeData(color: isDark ? Colors.white : ink, size: 22),
        shape: Border(bottom: BorderSide(color: border)),
        systemOverlayStyle: null,
      ),
      // ----------------------------------------------------------- buttons ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark ? const Color(0xFF2A3550) : border,
          disabledForegroundColor: faint,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.brandBlueDeep,
          side: BorderSide(color: border, width: 1.2),
          minimumSize: const Size(0, 50),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandBlue,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isDark ? Colors.white : ink,
          highlightColor: AppColors.brandBlue.withOpacity(0.10),
        ),
      ),
      // ------------------------------------------------------------- cards ---
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(isDark ? 0.45 : 0.10),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardAll,
          side: BorderSide(color: border),
        ),
      ),
      // ------------------------------------------------------------ inputs ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : const Color(0xFFF4F6FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: faint),
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        floatingLabelStyle:
            text.labelMedium?.copyWith(color: AppColors.brandBlue),
        prefixIconColor: isDark ? const Color(0xFF9FB0CC) : const Color(0xFF6B7688),
        suffixIconColor: isDark ? const Color(0xFF9FB0CC) : const Color(0xFF6B7688),
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdAll,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      ),
      // ------------------------------------------------------------- chips ---
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : const Color(0xFFF4F6FB),
        selectedColor: AppColors.brandBlue.withOpacity(isDark ? 0.26 : 0.14),
        disabledColor: border,
        side: BorderSide(color: border),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pillAll),
        showCheckmark: false,
      ),
      // ------------------------------------------------------ navigation -----
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandBlue.withOpacity(isDark ? 0.22 : 0.12),
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? text.labelSmall!.copyWith(
                  color: isDark ? Colors.white : AppColors.brandBlueDeep,
                  fontWeight: FontWeight.w700,
                )
              : text.labelSmall!.copyWith(color: faint),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppColors.accentCyan : AppColors.brandBlue)
                : faint,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.brandBlue,
        unselectedItemColor: faint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? Colors.white : AppColors.brandBlueDeep,
        unselectedLabelColor: faint,
        indicatorColor: AppColors.brandBlue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: border,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),
      // --------------------------------------------------------- overlays ----
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: elevated,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: border,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF243050) : const Color(0xFF131A2A),
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white),
        actionTextColor: AppColors.accentCyan,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF243050) : const Color(0xFF131A2A),
          borderRadius: AppRadii.xsAll,
        ),
        textStyle: text.bodySmall!.copyWith(color: Colors.white),
      ),
      // ------------------------------------------------------------ lists ----
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? const Color(0xFF9FB0CC) : const Color(0xFF5A6478),
        textColor: ink,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      // -------------------------------------------------------- feedback -----
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandBlue,
        linearMinHeight: 6,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brandBlue,
        thumbColor: AppColors.brandBlue,
        inactiveTrackColor: AppColors.brandBlue.withOpacity(0.18),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? Colors.white
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : null,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xsAll),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : null,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: Radius.circular(AppRadii.pill),
        thumbColor: WidgetStateProperty.all(
          isDark ? const Color(0xFF3B4A6B) : const Color(0xFFC7CFDE),
        ),
      ),
    );
  }

  /// Type scale: v1 sizes were set per widget with no rhythm (9, 10.5, 11.5,
  /// 13.5, 16.5 …). The scale below keeps the same visual weight but rounds the
  /// steps and gives every level a fixed line height.
  static TextTheme _textTheme(Color ink, Color muted, Color faint) => TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.14,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontSize: 23,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 18.5,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 15.5,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleSmall: TextStyle(
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
        bodySmall: TextStyle(
          fontSize: 11.5,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: muted,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: faint,
        ),
      );

  /// All-caps section label used above lists and forms ("MY NAME IS", "SELECT
  /// YOUR DISTRICT", …). v1 repeated this style literal twelve times inside the
  /// onboarding screen alone.
  static TextStyle sectionLabel(BuildContext context) =>
      Theme.of(context)
          .textTheme
          .labelSmall!
          .copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w900);
}
