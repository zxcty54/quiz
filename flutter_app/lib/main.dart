import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_welcome_screen.dart';

// 🌓 Global Theme Controller
final ValueNotifier<ThemeMode> globalThemeNotifier = ValueNotifier(ThemeMode.light);

// 📝 Public Download Folder Crash Logger
Future<void> _saveCrashToPublicDownloads(String error, String stackTrace) async {
  try {
    final downloadDir = Directory('/storage/emulated/0/Download');
    if (await downloadDir.exists()) {
      final logFile = File('${downloadDir.path}/MockTester_Crash_Logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      
      final logData = '''
=====================================================
CRASH TIMESTAMP: $timestamp
ERROR:
$error

STACKTRACE:
$stackTrace
=====================================================

''';

      await logFile.writeAsString(logData, mode: FileMode.append);
      debugPrint('Crash report written to: ${logFile.path}');
    }
  } catch (e) {
    debugPrint('Crash logger error: $e');
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Flutter Framework / Rendering Error Handler
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _saveCrashToPublicDownloads(
        details.exceptionAsString(),
        details.stack.toString(),
      );
    };

    // 🔥 2. Firebase Initialization (For Push Notifications)
    try {
      await Firebase.initializeApp();
      await NotificationService.initialize();
    } catch (e) {
      debugPrint("Firebase init error: $e");
    }

    // ⚡ 3. Supabase Initialization (Secure via Dart-Define / Environment)
    const String supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://tglidhzsjxfppyrmlwxf.supabase.co',
    );
    const String supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnbGlkaHpzanhmcHB5cm1sd3hmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczNzA3ODEsImV4cCI6MjEwMjk0Njc4MX0.5re2plUdwg9pCIqi7jAYR3KIHTeZ-zG4ifltLScNsbk',
    );

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // 📱 4. SharedPreferences: Theme & Onboarding Check
    final prefs = await SharedPreferences.getInstance();
    final bool isDark = prefs.getBool('is_dark_mode') ?? false;
    final bool isOnboarded = prefs.getBool('is_onboarded') ?? false;
    
    globalThemeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    runApp(MyApp(isOnboarded: isOnboarded));
  }, (error, stackTrace) {
    // 5. Global Async Crash Handler
    debugPrint("Caught Global Async Crash: $error");
    _saveCrashToPublicDownloads(error.toString(), stackTrace.toString());
  });
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

          // 🎨 Light Theme (Material 3)
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

          // 🌙 Dark Theme (Material 3 Deep Slate)
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
