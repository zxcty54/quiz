import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CbtProgressService {
  static const String _prefix = 'cbt_progress_';

  static String _getKey(String testId) => '$_prefix$testId';

  // 💾 1. Mid-Test State Auto-Save (Jab student koi question attempt kare ya screen switch ho)
  static Future<void> saveProgress({
    required String testId,
    required int currentIndex,
    required Map<int, int> userAnswers,
    required int remainingSeconds,
    required int totalQuestions,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Integer keys ko JSON compatible format (String) me convert kiya
      final answersMap = userAnswers.map((k, v) => MapEntry(k.toString(), v));

      final data = {
        'status': 'IN_PROGRESS',
        'currentIndex': currentIndex,
        'userAnswers': answersMap,
        'remainingSeconds': remainingSeconds,
        'totalQuestions': totalQuestions,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_getKey(testId), jsonEncode(data));
    } catch (_) {}
  }

  // 🏆 2. Mark Completed (Jab student final submit dabaye)
  static Future<void> markCompleted({
    required String testId,
    required double score,
    required int correct,
    required int wrong,
    required int total,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'status': 'COMPLETED',
        'score': score,
        'correct': correct,
        'wrong': wrong,
        'total': total,
        'completedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_getKey(testId), jsonEncode(data));
    } catch (_) {}
  }

  // 🔍 3. Get Test Status (Card aur Resume check karne ke liye)
  static Future<Map<String, dynamic>?> getTestStatus(String testId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_getKey(testId));
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      // Map ke keys ko wapas String se Integer me format karna (agar In-Progress ho)
      if (decoded.containsKey('userAnswers') && decoded['userAnswers'] is Map) {
        final rawAnswers = decoded['userAnswers'] as Map;
        final Map<int, int> parsedAnswers = {};
        rawAnswers.forEach((k, v) {
          final intKey = int.tryParse(k.toString());
          if (intKey != null && v is int) {
            parsedAnswers[intKey] = v;
          }
        });
        decoded['parsedUserAnswers'] = parsedAnswers;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  // 🔄 4. Clear/Reset Progress (Agar student test ko dubara fresh attempt karna chahe)
  static Future<void> clearProgress(String testId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getKey(testId));
    } catch (_) {}
  }
}
