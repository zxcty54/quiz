import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 3️⃣ Subject-Wise Accuracy Tracker
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

  // 4️⃣ Record Question Attempt & Wrong Vault Auto-Save + Supabase Cloud Logger
  static Future<void> recordQuestionAttempt({
    required bool isCorrect,
    required String chapterName,
    required String chapterPath,
    Map<String, dynamic>? wrongQuestionJson,
    String? userSelectedOption,
    String? questionText,
    int timeTakenSeconds = 0,
    String testType = 'revision',
    bool deferCloudSync = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // --- A. Local Stats Counters ---
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

      String qText = wrongQuestionJson['qe'] ?? wrongQuestionJson['qh'] ?? '';
      int existingIndex = -1;
      for (int i = 0; i < wrongList.length; i++) {
        try {
          var m = jsonDecode(wrongList[i]);
          if ((m['qe'] ?? m['qh'] ?? '') == qText) {
            existingIndex = i;
            break;
          }
        } catch (_) {}
      }

      if (existingIndex >= 0) {
        // Wahi sawal phir galat — ginti badhao, streak zero, aaj hi due
        try {
          Map<String, dynamic> existing = jsonDecode(wrongList[existingIndex]);
          existing['timesWrong'] = ((existing['timesWrong'] ?? 1) as num).toInt() + 1;
          existing['masteryStreak'] = 0;
          existing['nextDueDate'] = _dateKey(now);
          existing['dateAdded'] = wrongQuestionJson['dateAdded'];
          if (userSelectedOption != null && userSelectedOption.isNotEmpty) {
            existing['userSelectedOption'] = userSelectedOption;
          }
          wrongList[existingIndex] = jsonEncode(existing);
          await prefs.setStringList(_keyWrongQuestions, wrongList);
        } catch (_) {}
      } else {
        // Naya galat sawal — pehli baar, aaj hi due
        wrongQuestionJson['timesWrong'] = 1;
        wrongQuestionJson['nextDueDate'] = _dateKey(now);
        wrongList.add(jsonEncode(wrongQuestionJson));
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

    // --- B. 🚀 Supabase Cloud Usage Logger (For 24h AI Diagnostics) ---
    final String qClean = questionText ??
        (wrongQuestionJson != null
            ? (wrongQuestionJson['qe'] ?? wrongQuestionJson['qh'] ?? '')
            : '');

    if (qClean.trim().isNotEmpty) {
      final String? userId = prefs.getString('user_id');
      final String userName = prefs.getString('user_name') ?? 'Aspirant';
      final String district = prefs.getString('user_district') ?? 'Patna';

      final Map<String, dynamic> cloudRow = {
        'user_id': userId ?? 'usr_guest',
        'user_name': userName,
        'district': district,
        'test_type': testType,
        'question_text': qClean.trim(),
        'topic': chapterName.isNotEmpty ? chapterName : 'General',
        'is_correct': isCorrect,
        'time_taken_seconds': timeTakenSeconds,
        'is_analyzed': false,
        'attempted_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (deferCloudSync) {
        // CBT submit loop ke liye: row abhi sirf queue me, end me ek saath jayegi
        _pendingCloudRows.add(cloudRow);
      } else {
        try {
          await Supabase.instance.client.from('user_question_attempts').insert(cloudRow);
        } catch (e) {
          debugPrint('Usage tracking silent log error: $e');
        }
      }
    }
  }

  // 🚀 Batch Cloud Sync: CBT submit par 100 sawal = 100 request ki jagah
  // 100-100 ke chunks me ek-ek request. Submit screen tez khulti hai.
  static final List<Map<String, dynamic>> _pendingCloudRows = [];

  static Future<void> flushPendingCloudAttempts() async {
    if (_pendingCloudRows.isEmpty) return;
    final List<Map<String, dynamic>> rows = List.from(_pendingCloudRows);
    _pendingCloudRows.clear();
    try {
      for (int i = 0; i < rows.length; i += 100) {
        final int end = (i + 100 > rows.length) ? rows.length : i + 100;
        await Supabase.instance.client
            .from('user_question_attempts')
            .insert(rows.sublist(i, end));
      }
      debugPrint('Batch cloud sync: ${rows.length} attempts ek saath bheje');
    } catch (e) {
      debugPrint('Batch cloud sync error: $e');
    }
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

  // 5️⃣b Update Error Tag — sawal ki pehchan (uske text) se, number (index) se nahi.
  // Filter lagi hui list me index badal jata hai, sawal ka text nahi badalta —
  // isliye tag hamesha sahi sawal par lagta hai.
  static Future<void> updateWrongQuestionTagByText(String questionText, String tag) async {
    if (questionText.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];

    for (int i = 0; i < rawList.length; i++) {
      try {
        Map<String, dynamic> qMap = jsonDecode(rawList[i]);
        final key = (qMap['qe'] ?? qMap['qh'] ?? '').toString();
        if (key == questionText) {
          qMap['errorTag'] = tag;
          rawList[i] = jsonEncode(qMap);
          await prefs.setStringList(_keyWrongQuestions, rawList);
          return;
        }
      } catch (_) {}
    }
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

  // 6️⃣b Mastery badhao — pehchan (text) se, index se nahi (upar wali wajah).
  // Beech me koi sawal vault se hat bhi jaye to bhi sahi sawal hi update hoga.
  static Future<bool> incrementQuestionMasteryByText(String questionText) async {
    if (questionText.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];

    for (int i = 0; i < rawList.length; i++) {
      try {
        Map<String, dynamic> qMap = jsonDecode(rawList[i]);
        final key = (qMap['qe'] ?? qMap['qh'] ?? '').toString();
        if (key == questionText) {
          int currentStreak = (qMap['masteryStreak'] ?? 0) + 1;

          if (currentStreak >= 2) {
            rawList.removeAt(i);
            await prefs.setStringList(_keyWrongQuestions, rawList);
            return true;
          } else {
            qMap['masteryStreak'] = currentStreak;
            // Sahi kiya — agli baar 3 din baad due
            qMap['nextDueDate'] = _dateKey(DateTime.now().add(const Duration(days: 3)));
            rawList[i] = jsonEncode(qMap);
            await prefs.setStringList(_keyWrongQuestions, rawList);
            return false;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  // 6️⃣c Re-quiz me phir galat — streak zero, kal due
  static Future<void> markReQuizWrongByText(String questionText) async {
    if (questionText.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = prefs.getStringList(_keyWrongQuestions) ?? [];

    for (int i = 0; i < rawList.length; i++) {
      try {
        Map<String, dynamic> qMap = jsonDecode(rawList[i]);
        final key = (qMap['qe'] ?? qMap['qh'] ?? '').toString();
        if (key == questionText) {
          qMap['masteryStreak'] = 0;
          qMap['nextDueDate'] = _dateKey(DateTime.now().add(const Duration(days: 1)));
          rawList[i] = jsonEncode(qMap);
          await prefs.setStringList(_keyWrongQuestions, rawList);
          return;
        }
      } catch (_) {}
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

  // 📅 Due System (Level 2) — har galat sawal ki "phir kab dikhana hai" wali date
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? wrongDueDate(Map<String, dynamic> q) {
    final raw = q['nextDueDate']?.toString() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  // Bina date wala purana sawal bhi due mana jata hai (purana backlog)
  static bool isWrongDue(Map<String, dynamic> q) {
    final due = wrongDueDate(q);
    if (due == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(due.year, due.month, due.day).isAfter(today);
  }

  static Future<int> getDueWrongCount() async {
    final list = await getWrongQuestions();
    return list.where((q) => isWrongDue(q)).length;
  }

  // Mock pehchan — Wrong Vault screen wali hi tarkeeb (chapter/source dekh kar)
  static bool _isMockEntry(Map<String, dynamic> qJson) {
    String chapter = (qJson['chapterName'] ?? qJson['chapter'] ?? '').toString().toLowerCase().trim();
    String source = (qJson['sourceType'] ?? qJson['source'] ?? '').toString().toLowerCase().trim();
    bool isMockFlag = qJson['isMock'] == true || qJson['isSectional'] == true;
    bool isSetPattern = RegExp(r'\bset[\s\-_]*\d+').hasMatch(chapter);

    return isMockFlag ||
        isSetPattern ||
        chapter.contains('set') ||
        chapter.contains('mock') ||
        chapter.contains('sectional') ||
        chapter.contains('cbt') ||
        source.contains('mock') ||
        source.contains('sectional') ||
        chapter.isEmpty;
  }

  // 📊 Home ke Due card ke liye hisaab — kul due, mock due, revision due, repeat due
  static Future<Map<String, int>> getDueWrongStats() async {
    final list = await getWrongQuestions();
    int due = 0, mock = 0, repeat = 0;
    for (final q in list) {
      if (!isWrongDue(q)) continue;
      due++;
      if (_isMockEntry(q)) mock++;
      if (((q['timesWrong'] ?? 1) as num).toInt() >= 2) repeat++;
    }
    return {'due': due, 'mock': mock, 'revision': due - mock, 'repeat': repeat};
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
