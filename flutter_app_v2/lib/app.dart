import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/theme/app_theme.dart';
import 'package:mocktester_v2/core/theme/theme_controller.dart';
import 'package:mocktester_v2/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:mocktester_v2/features/shell/presentation/home_shell_screen.dart';

/// Root widget of the production app.
///
/// v1 built `MaterialApp` inside `main.dart` together with the bootstrap code,
/// which made both untestable. Bootstrap now lives in `core/bootstrap`, theming
/// in `core/theme`, and this widget only decides what the user sees first.
class MockTesterApp extends StatelessWidget {
  const MockTesterApp({super.key, required this.isOnboarded});

  /// When false the user is taken through the first-run onboarding flow.
  final bool isOnboarded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (BuildContext context, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'MockTester',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: isOnboarded
              ? const HomeScreen()
              : const OnboardingWelcomeScreen(nextScreen: HomeScreen()),
        );
      },
    );
  }
}
