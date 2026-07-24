import 'package:shared_preferences/shared_preferences.dart';

class UserStatsService {
  static const String _keyQuestions = 'stats_questions_solved';
  static const String _keyMocks = 'stats_mocks_attempted';
  static const String _keyBookmarks = 'stats_bookmarks_count';
  static const String _keyStreak = 'stats_study_streak';
  static const String _keyLastDate = 'stats_last_active_date';

  // 1️⃣ Get All Live Stats
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    await updateStreak(); // Daily streak auto update check

    return {
      'questions': prefs.getInt(_keyQuestions) ?? 0,
      'mocks': prefs.getInt(_keyMocks) ?? 0,
      'bookmarks': prefs.getInt(_keyBookmarks) ?? 0,
      'streak': prefs.getInt(_keyStreak) ?? 1,
    };
  }

  // 2️⃣ Record Completed Mock Test
  static Future<void> recordMockTest({required int questionsAttempted}) async {
    final prefs = await SharedPreferences.getInstance();

    int currentMocks = prefs.getInt(_keyMocks) ?? 0;
    int currentQuestions = prefs.getInt(_keyQuestions) ?? 0;

    await prefs.setInt(_keyMocks, currentMocks + 1);
    await prefs.setInt(_keyQuestions, currentQuestions + questionsAttempted);
  }

  // 3️⃣ Update Bookmarks Count
  static Future<void> updateBookmarkCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBookmarks, count);
  }

  // 4️⃣ Smart Daily Study Streak Calculator
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
}
