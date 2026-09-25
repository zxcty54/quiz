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

// 🌓 Global Theme Controller
final ValueNotifier<ThemeMode> globalThemeNotifier = ValueNotifier(ThemeMode.light);

// 🔄 GitHub Remote Config Fetcher
Future<void> _syncAppConfig() async {
  try {
    final Uri url = Uri.parse(
      'https://raw.githubusercontent.com/zxcty54/content_base/refs/heads/main/app_config.json',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

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

          // 🎨 Light Theme
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          // 🌙 Dark Theme
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B0F19),
            cardColor: const Color(0xFF1E293B),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E293B),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E293B),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E293B),
              titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          home: isOnboarded
              ? const HomeScreen()
              : OnboardingWelcomeScreen(nextScreen: const HomeScreen()),
        );
      },
    );
  }
}
