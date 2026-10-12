// v1 source: flutter_app/lib/services/challenge_service.dart

import 'package:mocktester_v2/core/network/json_fetcher.dart';
import 'dart:math';

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

  /// Single-file fetcher — delegates to the shared multi-mirror loader.
  static Future<dynamic> _fetchOnline(String relativePath) {
    return JsonFetcher.instance.fetchRobust(
      relativePath,
      timeout: const Duration(seconds: 3),
    );
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
