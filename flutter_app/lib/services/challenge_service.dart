import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChallengeService {
  // Core pool files
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

  // 🌐 Single File Fetcher
  static Future<dynamic> _fetchOnline(String relativePath) async {
    final List<String> urls = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/$relativePath",
      "https://raw.githack.com/zxcty54/content_base/main/$relativePath",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/$relativePath",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
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

  // ⚡ 10 Files Ek Sath Parallel Fetch
  static Future<Map<String, dynamic>> generateDailyChallenge() async {
    final random = Random();

    // 🚀 Sabhi 10 files ki requests parallel fire hongi
    final List<Future<dynamic>> fetchFutures = challengePoolFiles
        .map((path) => _fetchOnline(path))
        .toList();

    // Ek sath response receive hoga
    final List<dynamic> results = await Future.wait(fetchFutures);

    List<Map<String, dynamic>> selectedQuestions = [];
    List<String> encodedIds = [];

    for (int i = 0; i < results.length; i++) {
      final data = results[i];
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

  // 🔗 WhatsApp link se wahi 10 questions parallel reload
  static Future<List<Map<String, dynamic>>> loadQuestionsFromCode(String challengeCode) async {
    List<String> tokens = challengeCode.split('-');
    
    // Sabhi requested index files ko map karein
    List<Future<Map<String, dynamic>?>> tasks = tokens.map((token) async {
      final parts = token.split(':');
      if (parts.length == 2) {
        int fileIdx = int.tryParse(parts[0]) ?? -1;
        int qIdx = int.tryParse(parts[1]) ?? -1;

        if (fileIdx >= 0 && fileIdx < challengePoolFiles.length) {
          final data = await _fetchOnline(challengePoolFiles[fileIdx]);
          if (data != null) {
            List<dynamic> list = (data is List) ? data : (data['questions'] ?? []);
            if (qIdx >= 0 && qIdx < list.length) {
              return Map<String, dynamic>.from(list[qIdx]);
            }
          }
        }
      }
      return null;
    }).toList();

    final results = await Future.wait(tasks);
    return results.whereType<Map<String, dynamic>>().toList();
  }
}
