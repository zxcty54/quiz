// v1 source: flutter_app/lib/screens/quiz_screen.dart
import 'package:flutter/material.dart';

import 'package:mocktester_v2/core/models/question_model.dart';
import 'package:mocktester_v2/features/sectional/presentation/sectional_cbt_screen.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';

class QuizScreen extends StatefulWidget {
  final String title;
  final String jsonPath;

  const QuizScreen({
    super.key,
    required this.title,
    required this.jsonPath,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final List<dynamic>? body =
          await JsonFetcher.instance.fetchList(widget.jsonPath);

      if (body != null && body.isNotEmpty) {
        final List<Question> questions = body
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> item) =>
                Question.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        if (mounted && questions.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<Widget>(
              builder: (ctx) => SectionalCbtScreen(
                testTitle: widget.title,
                questions: questions,
                subFolder: widget.jsonPath,
              ),
            ),
          );
          return;
        }
      }
      if (mounted) {
        setState(() {
          _errorMessage = "Questions load nahi ho paye.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Loading Quiz Questions..."),
                ],
              )
            : Text(_errorMessage),
      ),
    );
  }
}
