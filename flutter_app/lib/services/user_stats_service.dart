import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStatsService {
  static const String _keyQuestions = 'stats_questions_solved';
  static const String _keyCorrect = 'stats_correct_answers';
  static const String _keyMocks = 'stats_mocks_attempted';
  static const String _keyStreak = 'stats_study_streak';
  static const String _keyLastDate = 'stats_last_active_date';
  
  static const String _keyLastChapterName = 'stats_last_chapter_name';
  static const String _keyLastChapterPath = 'stats_last_chapter_path';
  
  static const String _keyWrongQuestions = 'stats_wrong_questions_json';
  static const String _keySavedQuestions = 'stats_saved_questions_json';

  // 1️⃣ Get All Live Dynamic Stats
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    await updateStreak();

    int totalQ = prefs.getInt(_keyQuestions) ?? 0;
    int correctQ = prefs.getInt(_keyCorrect) ?? 0;

    int accuracy = totalQ > 0 ? ((correctQ / totalQ) * 100).round() : 100;

    List<int> weeklyProgress = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String dateKey = "day_qs_${day.year}-${day.month}-${day.day}";
      weeklyProgress.add(prefs.getInt(dateKey) ?? 0);
    }

    List<String> savedList = prefs.getStringList(_keySavedQuestions) ?? [];

    return {
      'questions': totalQ,
      'mocks': prefs.getInt(_keyMocks) ?? 0,
      'bookmarks': savedList.length,
      'streak': prefs.getInt(_keyStreak) ?? 1,
      'accuracy': accuracy,
      'last_chapter_name': prefs.getString(_keyLastChapterName) ?? 'Cell Biology',
      'last_chapter_path': prefs.getString(_keyLastChapterPath) ?? '',
      'weekly_progress': weeklyProgress,
    };
  }

  // 2️⃣ Record Question Attempt & Wrong Vault Auto-Save (With Date & Metadata)
  static Future<void> recordQuestionAttempt({
    required bool isCorrect,
    required String chapterName,
    required String chapterPath,
    Map<String, dynamic>? wrongQuestionJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    int total = prefs.getInt(_keyQuestions) ?? 0;
    await prefs.setInt(_keyQuestions, total + 1);

    if (isCorrect) {
      int correct = prefs.getInt(_keyCorrect) ?? 0;
      await prefs.setInt(_keyCorrect, correct + 1);
    } else if (wrongQuestionJson != null) {
      List<String> wrongList = prefs.getStringList(_keyWrongQuestions) ?? [];
      
      // Auto-add Date & Default Vault Metadata
      DateTime now = DateTime.now();
      wrongQuestionJson['dateAdded'] = "${now.day}/${now.month}/${now.year}";
      wrongQuestionJson['chapterName'] = chapterName;
      wrongQuestionJson['masteryStreak'] = wrongQuestionJson['masteryStreak'] ?? 0;
      wrongQuestionJson['errorTag'] = wrongQuestionJson['errorTag'] ?? '';

      String encoded = jsonEncode(wrongQuestionJson);
      
      // Prevent duplicates by checking Question text
      String qText = wrongQuestionJson['qe'] ?? wrongQuestionJson['qh'] ?? '';
      bool alreadyExists = wrongList.any((item) {
        try {
          var m = jsonDecode(item);
          return (m['qe'] ?? m['qh'] ?? '') == qText;
        } catch (_) {
          return false;
        }
      });

      if (!alreadyExists) {
        wrongList.add(encoded);
        await prefs.setStringList(_keyWrongQuestions, wrongList);
      }
    }

    if (chapterName.isNotEmpty) {
      await prefs.setString(_keyLastChapterName, chapterName);
      await prefs.setString(_keyLastChapterPath, chapterPath);
    }

    DateTime today = DateTime.now();
    String dateKey = "day_qs_${today.year}-${today.month}-${today.day}";
    int todayCount = prefs.getInt(dateKey) ?? 0;
    await prefs.setInt(dateKey, todayCount + 1);
  }

  // 3️⃣ Update Error Tag Persistent (Silly vs Concept Gap)
  static Future<void> updateWrongQuestionTag(int index, String tag) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    if (index < 0 || index >= rawList.length) return;

    try {
      Map<String, dynamic> qMap = jsonDecode(rawList[index]);
      qMap['errorTag'] = tag;
      rawList[index] = jsonEncode(qMap);
      await prefs.setStringList(_keyWrongQuestions, rawList);
    } catch (_) {}
  }

  // 4️⃣ Smart Revision Ladder: Increment Mastery Streak & Auto-Graduate on 2/2
  static Future<bool> incrementQuestionMastery(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    if (index < 0 || index >= rawList.length) return false;

    try {
      Map<String, dynamic> qMap = jsonDecode(rawList[index]);
      int currentStreak = (qMap['masteryStreak'] ?? 0) + 1;

      if (currentStreak >= 2) {
        // 🎯 Auto-Graduate / Delete from Vault on 2/2
        rawList.removeAt(index);
        await prefs.setStringList(_keyWrongQuestions, rawList);
        return true; // Indicates graduated!
      } else {
        qMap['masteryStreak'] = currentStreak;
        rawList[index] = jsonEncode(qMap);
        await prefs.setStringList(_keyWrongQuestions, rawList);
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  // 5️⃣ Toggle Save/Bookmark Question
  static Future<bool> toggleBookmark(Map<String, dynamic> questionJson) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList(_keySavedQuestions) ?? [];
    String encoded = jsonEncode(questionJson);

    bool isSaved;
    if (savedList.contains(encoded)) {
      savedList.remove(encoded);
      isSaved = false;
    } else {
      savedList.add(encoded);
      isSaved = true;
    }
    await prefs.setStringList(_keySavedQuestions, savedList);
    return isSaved;
  }

  // 6️⃣ Get Bookmarked Questions
  static Future<List<Map<String, dynamic>>> getSavedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keySavedQuestions) ?? [];
    return rawList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  // 7️⃣ Get Wrong Questions
  static Future<List<Map<String, dynamic>>> getWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    return rawList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  // 8️⃣ Clear Wrong Vault Questions
  static Future<void> clearWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyWrongQuestions);
  }

  // Record Completed Mock
  static Future<void> recordMockTest({int questionsAttempted = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    int currentMocks = prefs.getInt(_keyMocks) ?? 0;
    await prefs.setInt(_keyMocks, currentMocks + 1);
  }

  // Streak Calculator
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
        await prefs.setInt(_keyStreak, currentStreak + 1);
      } else if (difference > 1) {
        await prefs.setInt(_keyStreak, 1);
      }
      await prefs.setString(_keyLastDate, today);
    }
  }

  static Future<void> incrementQuestions(int count) async {
    final prefs = await SharedPreferences.getInstance();
    int total = prefs.getInt(_keyQuestions) ?? 0;
    await prefs.setInt(_keyQuestions, total + count);
  }
}
