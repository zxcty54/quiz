// v1 source: flutter_app/lib/services/current_affairs_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:mocktester_v2/core/config/content_sources.dart';
import 'package:mocktester_v2/core/models/question_model.dart';
import 'package:mocktester_v2/features/revision/presentation/revision_practice_screen.dart';

class CurrentAffairsService {
  static String get jsonUrl =>
      ContentSources.rawQuiz('current_affair/august_2026.json');

  static Future<void> openCurrentAffairs({
    required BuildContext context,
    required bool isBihar,
    required String title,
  }) async {
    // ⏳ Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Current Affairs load ho raha hai...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final res = await http.get(
        Uri.parse('$jsonUrl?t=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      
      if (res.statusCode == 200) {
        String body = utf8.decode(res.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1); // Clean BOM

        final Map<String, dynamic> data = jsonDecode(body);
        final List<dynamic> rawQuestions = isBihar
            ? (data['bihar_questions'] ?? [])
            : (data['national_questions'] ?? []);

        // 🔄 Question Model conversion
        final List<Question> questions = rawQuestions.map((item) {
          // v1 left `options` and `explanation` out of this constructor call,
          // so the file never compiled. Both are derived here from the same
          // fields Question.fromJson reads, and the answer index is guarded
          // because these JSON files sometimes use "A"/"B" strings.
          final List<String> optsEn =
              item['oe'] != null ? List<String>.from(item['oe']) : <String>[];
          final List<String> optsHi =
              item['oh'] != null ? List<String>.from(item['oh']) : <String>[];
          final String expl = '${item['e'] ?? ''}';
          final dynamic rawAns = item['a'];

          return Question(
            qe: item['qe'] ?? '',
            qh: item['qh'] ?? '',
            oe: optsEn,
            oh: optsHi,
            options: optsEn.isNotEmpty ? optsEn : (optsHi.isNotEmpty ? optsHi : <String>[]),
            answerIndex: rawAns is int ? rawAns : 0,
            explanation: expl,
            ee: expl,
            eh: expl,
          );
        }).toList();

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          
          if (questions.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => RevisionPracticeScreen(
                  testTitle: title,
                  questions: questions,
                  storageKey: isBihar ? "ca_bihar_aug_2026" : "ca_national_aug_2026",
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Koi question nahi mila!')),
            );
          }
        }
      } else {
        throw Exception('Server Error: ${res.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Data load nahi ho paya: $e')),
        );
      }
    }
  }
}
