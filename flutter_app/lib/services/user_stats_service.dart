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

  // 🎯 Student Identity Keys
  static const String _keyStudentName = 'custom_aspirant_name';
  static const String _keyStudentContact = 'student_contact_id';
  static const String _keySubjectPerformance = 'stats_subject_performance_map';

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
      'last_chapter_name': prefs.getString(_keyLastChapterName) ?? 'General Studies',
      'last_chapter_path': prefs.getString(_keyLastChapterPath) ?? '',
      'weekly_progress': weeklyProgress,
      'student_name': prefs.getString(_keyStudentName) ?? 'Aspirant',
      'student_contact': prefs.getString(_keyStudentContact) ?? '',
    };
  }

  // 2️⃣ Student Profile Identity Helper
  static Future<void> saveStudentProfile({
    required String name,
    required String contactOrRoll,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStudentName, name.trim());
    await prefs.setString(_keyStudentContact, contactOrRoll.trim());
  }

  static Future<Map<String, String>> getStudentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyStudentName) ?? 'Aspirant',
      'contact': prefs.getString(_keyStudentContact) ?? '',
    };
  }

  // 3️⃣ Subject-Wise Accuracy Tracker (For Suresh's Deep Analytics)
  static Future<void> recordSubjectPerformance({
    required String subject,
    required int correct,
    required int total,
  }) async {
    if (total <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final cleanSubject = subject.trim().toUpperCase();

    Map<String, dynamic> perfMap = {};
    final raw = prefs.getString(_keySubjectPerformance);
    if (raw != null) {
      try {
        perfMap = jsonDecode(raw);
      } catch (_) {}
    }

    int prevCorrect = (perfMap[cleanSubject]?['correct'] as int?) ?? 0;
    int prevTotal = (perfMap[cleanSubject]?['total'] as int?) ?? 0;

    perfMap[cleanSubject] = {
      'correct': prevCorrect + correct,
      'total': prevTotal + total,
      'accuracy': (((prevCorrect + correct) / (prevTotal + total)) * 100).round(),
    };

    await prefs.setString(_keySubjectPerformance, jsonEncode(perfMap));
  }

  static Future<Map<String, dynamic>> getSubjectAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySubjectPerformance);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // 4️⃣ Record Question Attempt & Wrong Vault Auto-Save
  static Future<void> recordQuestionAttempt({
    required bool isCorrect,
    required String chapterName,
    required String chapterPath,
    Map<String, dynamic>? wrongQuestionJson,
    String? userSelectedOption,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    int total = prefs.getInt(_keyQuestions) ?? 0;
    await prefs.setInt(_keyQuestions, total + 1);

    if (isCorrect) {
      int correct = prefs.getInt(_keyCorrect) ?? 0;
      await prefs.setInt(_keyCorrect, correct + 1);
    } else if (wrongQuestionJson != null) {
      List<String> wrongList = prefs.getStringList(_keyWrongQuestions) ?? [];
      
      DateTime now = DateTime.now();
      wrongQuestionJson['dateAdded'] = "${now.day}/${now.month}/${now.year}";
      wrongQuestionJson['chapterName'] = chapterName;
      wrongQuestionJson['masteryStreak'] = wrongQuestionJson['masteryStreak'] ?? 0;
      wrongQuestionJson['errorTag'] = wrongQuestionJson['errorTag'] ?? '';
      
      if (userSelectedOption != null && userSelectedOption.isNotEmpty) {
        wrongQuestionJson['userSelectedOption'] = userSelectedOption;
      }

      String encoded = jsonEncode(wrongQuestionJson);
      
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

  // 5️⃣ Update Error Tag Persistent
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

  // 6️⃣ Smart Revision Ladder: Auto-Graduate on 2/2
  static Future<bool> incrementQuestionMastery(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    if (index < 0 || index >= rawList.length) return false;

    try {
      Map<String, dynamic> qMap = jsonDecode(rawList[index]);
      int currentStreak = (qMap['masteryStreak'] ?? 0) + 1;

      if (currentStreak >= 2) {
        rawList.removeAt(index);
        await prefs.setStringList(_keyWrongQuestions, rawList);
        return true;
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

  // 7️⃣ Toggle Save/Bookmark Question
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

  // 8️⃣ Get Bookmarked Questions
  static Future<List<Map<String, dynamic>>> getSavedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keySavedQuestions) ?? [];
    return rawList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  // 9️⃣ Get Wrong Questions
  static Future<List<Map<String, dynamic>>> getWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];
    return rawList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  // 🔟 Clear Wrong Vault Questions
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
