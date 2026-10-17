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
      // Do raste: 1) Cloudflare Worker  2) GitHub CDN mirrors (raw aakhir me)
      final List<String> urls = [
        "$_contentProxyBase/${widget.jsonPath}",
        "https://raw.githack.com/zxcty54/content_base/main/${widget.jsonPath}",
        "https://cdn.statically.io/gh/zxcty54/content_base/main/${widget.jsonPath}",
        "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/${widget.jsonPath}",
        "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/${widget.jsonPath}",
        "https://raw.githubusercontent.com/zxcty54/content_base/main/${widget.jsonPath}",
      ];
      http.Response? okRes;
      for (final u in urls) {
        try {
          final r = await http.get(Uri.parse(u), headers: {'X-App-Key': _contentAppKey});
          if (r.statusCode == 200) {
            okRes = r;
            break;
          }
        } catch (_) {}
      }
      final res = okRes;

      if (res != null && res.statusCode == 200) {
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
