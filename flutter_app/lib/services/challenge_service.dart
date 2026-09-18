import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

class ChallengeService {
  // Saare core files ki list jahan se balance 10 questions uthane hain
  static final List<String> challengePoolFiles = [
    'assets/static/history/ancient.json',
    'assets/static/history/modern.json',
    'assets/static/polity/rights.json',
    'assets/static/polity/parliament.json',
    'assets/static/geography/mapping.json',
    'assets/static/economy/schemes.json',
    'assets/static/biology/disease.json',
    'assets/static/biology/cell.json',
    'assets/static/physics/light.json',
    'assets/static/chemistry/acidbase.json',
  ];

  // 🎲 1. Solo Player ke liye Random 10 Questions Pick Karna
  static Future<Map<String, dynamic>> generateDailyChallenge() async {
    final random = Random();
    List<Map<String, dynamic>> selectedQuestions = [];
    List<String> encodedIds = []; // e.g. "0:4", "2:11" (fileIndex : questionIndex)

    // Pool se 10 alag-alag files choose karke 1-1 question pick karna (Diversified GK)
    for (int i = 0; i < 10; i++) {
      int fileIdx = i % challengePoolFiles.length;
      String filePath = challengePoolFiles[fileIdx];

      try {
        final String jsonStr = await rootBundle.loadString(filePath);
        final List<dynamic> list = jsonDecode(jsonStr);
        if (list.isNotEmpty) {
          int qIdx = random.nextInt(list.length);
          var q = Map<String, dynamic>.from(list[qIdx]);
          q['encoded_ref'] = '$fileIdx:$qIdx';
          selectedQuestions.add(q);
          encodedIds.add('$fileIdx:$qIdx');
        }
      } catch (e) {
        // Fallback if file load fails
      }
    }

    return {
      'questions': selectedQuestions,
      'challenge_code': encodedIds.join('-'), // "0:2-1:5-2:8..." -> WhatsApp link ke liye
    };
  }

  // 🔗 2. WhatsApp Link se exact wahi 10 Questions wapas nikalna
  static Future<List<Map<String, dynamic>>> loadQuestionsFromCode(String challengeCode) async {
    List<Map<String, dynamic>> questions = [];
    List<String> tokens = challengeCode.split('-');

    for (String token in tokens) {
      final parts = token.split(':');
      if (parts.length == 2) {
        int fileIdx = int.parse(parts[0]);
        int qIdx = int.parse(parts[1]);

        if (fileIdx < challengePoolFiles.length) {
          String filePath = challengePoolFiles[fileIdx];
          final String jsonStr = await rootBundle.loadString(filePath);
          final List<dynamic> list = jsonDecode(jsonStr);
          if (qIdx < list.length) {
            questions.add(Map<String, dynamic>.from(list[qIdx]));
          }
        }
      }
    }
    return questions;
  }
}
