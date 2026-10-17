import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/ai_explainer_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_welcome_screen.dart';
import 'screens/splash_screen.dart';

// --- Content Proxy (Private content_base ka darwaza: Cloudflare Worker) ---
const String _contentProxyBase =
    'https://content-proxy.nitesh-skyhigh.workers.dev';
const String _contentAppKey = 'mt_4bd7ba22c736af380d9d3905';


// 🌓 Global Theme Controller
final ValueNotifier<ThemeMode> globalThemeNotifier = ValueNotifier(ThemeMode.light);

// 🔄 GitHub Remote Config Fetcher
Future<void> _syncAppConfig() async {
  try {
    final Uri url = Uri.parse('$_contentProxyBase/app_config.json');

    final response =
        await http.get(url, headers: {'X-App-Key': _contentAppKey}).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final Map<String, dynamic> config = jsonDecode(utf8.decode(response.bodyBytes));
      AiExplainerService.updateModelFromConfig(config);
      debugPrint("✅ App config successfully synced with AiExplainerService");
    } else {
      debugPrint("⚠️ Failed to load app_config.json: Status ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("Config sync network error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 1. Firebase Initialization
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // ⚡ 2. Supabase Initialization (Safe Injection via --dart-define)
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 📱 3. SharedPreferences: Theme & Onboarding Check
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  final bool isOnboarded = prefs.getBool('is_onboarded') ?? false;

  globalThemeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  // 🌐 4. Background Remote Config Sync
  unawaited(_syncAppConfig());

  runApp(MyApp(isOnboarded: isOnboarded));
}

class MyApp extends StatelessWidget {
  final bool isOnboarded;

  const MyApp({super.key, required this.isOnboarded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: globalThemeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'MockTester',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // 🎨 Ek hi design bhasha: rounded surfaces, blue–violet
          // identity aur amber highlights — light/dark dono me.
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),

          // The splash is the first screen in both cases; a first-time user
          // goes on to the onboarding, a returning user straight home.
          home: isOnboarded
              ? const SplashScreen()
              : const SplashScreen(nextScreen: OnboardingWelcomeScreen()),
        );
      },
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: brightness,
      primary: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      secondary: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
      tertiary: const Color(0xFFF59E0B),
      surface: isDark ? const Color(0xFF111C30) : Colors.white,
    );

    final surface = scheme.surface;
    final border = isDark ? const Color(0xFF263449) : const Color(0xFFE3E9F5);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFF5F7FF),
      cardColor: surface,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            size: 23,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1A2740) : const Color(0xFFEFF4FF),
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E3A8A),
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1628) : const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
        contentTextStyle: TextStyle(color: isDark ? const Color(0xFF0F172A) : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: isDark ? const Color(0xFF263449) : const Color(0xFFE2E8F0),
        circularTrackColor: isDark ? const Color(0xFF263449) : const Color(0xFFE2E8F0),
      ),
    );
  }
}
