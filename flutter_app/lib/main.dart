import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/knowledge_base_service.dart'; // 📦 Added Knowledge Base Service
import 'screens/home_screen.dart';

// 🌓 Poore App ke liye Global Theme Controller
final ValueNotifier<ThemeMode> globalThemeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 1. Firebase Initialization (For Push Notifications)
  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // ⚡ 2. Supabase Initialization (For App Database)
  await Supabase.initialize(
    url: 'https://tglidhzsjxfppyrmlwxf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnbGlkaHpzanhmcHB5cm1sd3hmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczNzA3ODEsImV4cCI6MjEwMjk0Njc4MX0.5re2plUdwg9pCIqi7jAYR3KIHTeZ-zG4ifltLScNsbk',
  );

  // 🔍 3. LOCAL KNOWLEDGE BASE (FTS5) AUTOMATIC VERIFICATION TEST
  try {
    debugPrint("🚀 [DB TEST] Starting decompression & FTS5 search check...");
    final stopwatch = Stopwatch()..start();
    
    // Sample search keyword test (Mitochondria / BPSC term)
    final chunks = await KnowledgeBaseService.instance.searchRelevantChunks("Mitochondria", limit: 2);
    stopwatch.stop();

    if (chunks.isNotEmpty) {
      debugPrint("--------------------------------------------------");
      debugPrint("✅ [DB TEST PASSED] Extracted Chunks: ${chunks.length} in ${stopwatch.elapsedMilliseconds}ms");
      debugPrint("📄 [SAMPLE CHUNK]: ${chunks.first.substring(0, chunks.first.length > 120 ? 120 : chunks.first.length)}...");
      debugPrint("--------------------------------------------------");
    } else {
      debugPrint("⚠️ [DB WARNING] Database opened successfully, but 0 chunks matched query 'Mitochondria'.");
    }
  } catch (e) {
    debugPrint("❌ [DB ERROR] KnowledgeBase Extraction/Search Failed: $e");
  }

  // 📱 4. SharedPreferences: Theme Check
  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  
  globalThemeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

          // 🚀 Initial Screen: Seedha HomeScreen open hoga
          home: const HomeScreen(),
        );
      },
    );
  }
}
