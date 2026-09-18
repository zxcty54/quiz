import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChallengeService {
  // Saare 10 core files ke paths
  static final List<String> challengePoolFiles = [
    'static/history/ancient.json',
    'static/history/modern.json',
    'static/polity/rights.json',
    'static/polity/parliament.json',
    'static/geography/mapping.json',
    'static/economy/schemes.json',
    'static/biology/disease.json',
    'static/biology/cell.json',
    'static/physics/light.json',
    'static/chemistry/acidbase.json',
  ];

  // 🌐 GitHub se live fetch karega
  static Future<dynamic> _fetchOnline(String relativePath) async {
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/$relativePath",
      "https://raw.githack.com/zxcty54/content_base/main/$relativePath",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/$relativePath",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String rawBody = utf8.decode(res.bodyBytes).trim();
          if (rawBody.startsWith('\uFEFF')) rawBody = rawBody.substring(1).trim();
          return jsonDecode(rawBody);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // 🎲 Random 10 Sawaal Pick Karna
  static Future<Map<String, dynamic>> generateDailyChallenge() async {
    final random = Random();
    List<Map<String, dynamic>> selectedQuestions = [];
    List<String> encodedIds = [];

    for (int i = 0; i < challengePoolFiles.length; i++) {
      String filePath = challengePoolFiles[i];
      final dynamic data = await _fetchOnline(filePath);

      if (data != null) {
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['questions'] ?? data['data'] ?? data['items'] ?? [];
        }

        if (list.isNotEmpty) {
          int qIdx = random.nextInt(list.length);
          var q = Map<String, dynamic>.from(list[qIdx]);
          q['encoded_ref'] = '$i:$qIdx';
          selectedQuestions.add(q);
          encodedIds.add('$i:$qIdx');
        }
      }
    }

    return {
      'questions': selectedQuestions,
      'challenge_code': encodedIds.join('-'),
    };
  }

  // 🔗 WhatsApp link se wahi 10 sawaal reload karna
  static Future<List<Map<String, dynamic>>> loadQuestionsFromCode(String challengeCode) async {
    List<Map<String, dynamic>> questions = [];
    List<String> tokens = challengeCode.split('-');

    for (String token in tokens) {
      final parts = token.split(':');
      if (parts.length == 2) {
        int fileIdx = int.tryParse(parts[0]) ?? -1;
        int qIdx = int.tryParse(parts[1]) ?? -1;

        if (fileIdx >= 0 && fileIdx < challengePoolFiles.length) {
          String filePath = challengePoolFiles[fileIdx];
          final dynamic data = await _fetchOnline(filePath);
          if (data != null) {
            List<dynamic> list = (data is List) ? data : (data['questions'] ?? []);
            if (qIdx >= 0 && qIdx < list.length) {
              questions.add(Map<String, dynamic>.from(list[qIdx]));
            }
          }
        }
      }
    }
    return questions;
  }
}
