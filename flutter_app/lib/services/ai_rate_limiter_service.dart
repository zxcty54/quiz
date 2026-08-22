import 'package:shared_preferences/shared_preferences.dart';

class AiRateLimiterService {
  static const int maxInputChars = 3500; // ~500-600 words / 15 questions max
  static const int cooldownSeconds = 30;  // 30 seconds wait between calls
  static const int dailyGenerationLimit = 6; // Max 6 AI generations per day

  /// Check whether the creator can make an AI request
  static Future<Map<String, dynamic>> checkEligibility() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check Cooldown (30 seconds)
    final lastCall = prefs.getInt('ai_last_call_timestamp') ?? 0;
    final diffSeconds = (now - lastCall) ~/ 1000;
    if (diffSeconds < cooldownSeconds) {
      return {
        'allowed': false,
        'message': '⏱️ Cooldown active! Please wait ${cooldownSeconds - diffSeconds}s before next AI generation.',
      };
    }

    // 2. Check Daily Limit
    final todayKey = 'ai_usage_${DateTime.now().toIso8601String().split('T').first}';
    final currentUsage = prefs.getInt(todayKey) ?? 0;
    if (currentUsage >= dailyGenerationLimit) {
      return {
        'allowed': false,
        'message': '🚫 Daily AI Limit Reached ($dailyGenerationLimit/$dailyGenerationLimit). Try manual card addition or come back tomorrow.',
      };
    }

    return {
      'allowed': true,
      'remainingToday': dailyGenerationLimit - currentUsage,
    };
  }

  /// Register successful generation
  static Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final todayKey = 'ai_usage_${DateTime.now().toIso8601String().split('T').first}';
    final currentUsage = prefs.getInt(todayKey) ?? 0;

    await prefs.setInt('ai_last_call_timestamp', now);
    await prefs.setInt(todayKey, currentUsage + 1);
  }
}
