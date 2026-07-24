import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStatsService {
  // 🔑 Storage Keys
  static const String _keyQuestions = 'stats_questions_solved';
  static const String _keyCorrect = 'stats_correct_answers';
  static const String _keyMocks = 'stats_mocks_attempted';
  static const String _keyBookmarks = 'stats_bookmarks_count';
  static const String _keyStreak = 'stats_study_streak';
  static const String _keyLastDate = 'stats_last_active_date';
  
  static const String _keyLastChapterName = 'stats_last_chapter_name';
  static const String _keyLastChapterPath = 'stats_last_chapter_path';
  static const String _keyWrongQuestions = 'stats_wrong_questions_json';

  // 1️⃣ GET ALL LIVE DYNAMIC STATS FOR PROFILE SCREEN
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    await updateStreak(); // Auto update streak on daily app open

    int totalQ = prefs.getInt(_keyQuestions) ?? 0;
    int correctQ = prefs.getInt(_keyCorrect) ?? 0;

    // ⚡ Real Accuracy Percentage Calculation
    int accuracy = totalQ > 0 ? ((correctQ / totalQ) * 100).round() : 100;

    // 📈 Pichle 7 Dino Ka Daily Question Counts (For Bar Graph)
    List<int> weeklyProgress = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String dateKey = "day_qs_${day.year}-${day.month}-${day.day}";
      weeklyProgress.add(prefs.getInt(dateKey) ?? 0);
    }

    return {
      'questions': totalQ,
      'mocks': prefs.getInt(_keyMocks) ?? 0,
      'bookmarks': prefs.getInt(_keyBookmarks) ?? 0,
      'streak': prefs.getInt(_keyStreak) ?? 1,
      'accuracy': accuracy,
      'last_chapter_name': prefs.getString(_keyLastChapterName) ?? 'Cell Biology',
      'last_chapter_path': prefs.getString(_keyLastChapterPath) ?? '',
      'weekly_progress': weeklyProgress, // Array of 7 integers
    };
  }

  // 2️⃣ RECORD QUESTION ATTEMPT (Sahi/Galat, Chapter Name, and Daily Activity)
  static Future<void> recordQuestionAttempt({
    required bool isCorrect,
    required String chapterName,
    required String chapterPath,
    Map<String, dynamic>? wrongQuestionJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Increment Total Questions Solved
    int total = prefs.getInt(_keyQuestions) ?? 0;
    await prefs.setInt(_keyQuestions, total + 1);

    // Increment Correct / Save Wrong Question
    if (isCorrect) {
      int correct = prefs.getInt(_keyCorrect) ?? 0;
      await prefs.setInt(_keyCorrect, correct + 1);
    } else if (wrongQuestionJson != null) {
      // ❌ Save to Wrong Questions Vault
      List<String> wrongList = prefs.getStringList(_keyWrongQuestions) ?? [];
      String encoded = jsonEncode(wrongQuestionJson);
      if (!wrongList.contains(encoded)) {
        wrongList.add(encoded);
        await prefs.setStringList(_keyWrongQuestions, wrongList);
      }
    }

    // 📖 Save Last Chapter for "Continue Last Chapter"
    if (chapterName.isNotEmpty) {
      await prefs.setString(_keyLastChapterName, chapterName);
      await prefs.setString(_keyLastChapterPath, chapterPath);
    }

    // 📊 Save Today's Question Count for Weekly Graph
    DateTime today = DateTime.now();
    String dateKey = "day_qs_${today.year}-${today.month}-${today.day}";
    int todayCount = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todayCount + 1);
  }

  // 3️⃣ RECORD COMPLETED MOCK TEST
  static Future<void> recordMockTest({int questionsAttempted = 0}) async {
    final prefs = await SharedPreferences.getInstance();

    int currentMocks = prefs.getInt(_keyMocks) ?? 0;
    await prefs.setInt(_keyMocks, currentMocks + 1);

    if (questionsAttempted > 0) {
      int currentQuestions = prefs.getInt(_keyQuestions) ?? 0;
      await prefs.setInt(_keyQuestions, currentQuestions + questionsAttempted);
    }
  }

  // 4️⃣ INCREMENT SINGLE/MULTIPLE QUESTIONS (Simple Helper)
  static Future<void> incrementQuestions(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int currentQuestions = prefs.getInt(_keyQuestions) ?? 0;
    await prefs.setInt(_keyQuestions, currentQuestions + count);

    // Also update today's activity
    DateTime today = DateTime.now();
    String dateKey = "day_qs_${today.year}-${today.month}-${today.day}";
    int todayCount = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todayCount + count);
  }

  // 5️⃣ UPDATE BOOKMARKS COUNT
  static Future<void> updateBookmarkCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBookmarks, count);
  }

  // 6️⃣ SMART DAILY STUDY STREAK CALCULATOR
  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().substring(0, 10);
    final String? lastActive = prefs.getString(_keyLastDate);

    if (lastActive == null) {
      await prefs.setString(_keyLastDate, today);
      await prefs.setInt(_keyStreak, 1);
      return;
    }

    if (lastActive != today) {
      final lastDate = DateTime.parse(lastActive);
      final difference = DateTime.now().difference(lastDate).inDays;

      int currentStreak = prefs.getInt(_keyStreak) ?? 1;

      if (difference == 1) {
        // Consecutive Day
        await prefs.setInt(_keyStreak, currentStreak + 1);
      } else if (difference > 1) {
        // Streak Broken
        await prefs.setInt(_keyStreak, 1);
      }
      await prefs.setString(_keyLastDate, today);
    }
  }

  // 📂 GET WRONG QUESTIONS LIST (For Wrong Questions Vault Screen)
  static Future<List<Map<String, dynamic>>> getWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    return rawList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }
}
