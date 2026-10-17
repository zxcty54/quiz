import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/question_model.dart';
import 'sectional_cbt_screen.dart';

// --- Content Proxy (Private content_base ka darwaza: Cloudflare Worker) ---
const String _contentProxyBase =
    'https://content-proxy.nitesh-skyhigh.workers.dev';
const String _contentAppKey = 'mt_4bd7ba22c736af380d9d3905';


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
      // 🚀 Updated Base URL to content_base repository
      final url = "$_contentProxyBase/${widget.jsonPath}";
      final res = await http.get(Uri.parse(url), headers: {'X-App-Key': _contentAppKey});

      if (res.statusCode == 200) {
        List body = jsonDecode(utf8.decode(res.bodyBytes));
        List<Question> questions = body.map((i) => Question.fromJson(i)).toList();

        if (mounted && questions.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
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
