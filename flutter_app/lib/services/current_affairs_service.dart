import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import '../screens/revision_practice_screen.dart';

class CurrentAffairsService {
  static const String jsonUrl =
      "https://raw.githubusercontent.com/zxcty54/quiz/main/current_affair/august_2026.json";

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
          return Question(
            qe: item['qe'] ?? '',
            qh: item['qh'] ?? '',
            oe: List<String>.from(item['oe'] ?? []),
            oh: List<String>.from(item['oh'] ?? []),
            answerIndex: item['a'] ?? 0,
            ee: item['e'] ?? '',
            eh: item['e'] ?? '',
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
