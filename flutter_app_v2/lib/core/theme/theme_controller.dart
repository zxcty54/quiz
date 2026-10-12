import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// App-wide theme mode holder.
///
/// v1 kept a top-level `ValueNotifier` inside `main.dart`, which forced
/// `profile_screen.dart` to `import 'package:mocktester_v2/core/main.dart'` — a layering violation that
/// made the whole app impossible to unit test. The notifier now lives in core,
/// and [setDark] also persists the choice so the toggle and the stored flag
/// can never drift apart (v1 duplicated that logic in two screens).
class ThemeController {
  ThemeController._();

  static const String prefKey = 'is_dark_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => mode.value == ThemeMode.dark;

  /// Reads the saved preference. Called once during bootstrap.
  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isDark = prefs.getBool(prefKey) ?? false;
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  /// Persists and applies the new value.
  static Future<void> setDark(bool isDark) async {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, isDark);
  }

  static Future<void> toggle() => setDark(!isDark);
}
