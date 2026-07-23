import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'quiz_screen.dart';
import '../models/question_model.dart';

class ChapterSelectScreen extends StatefulWidget {
  final String categoryTitle;
  final Map<String, String> chapterMapping;

  const ChapterSelectScreen({
    super.key,
    required this.categoryTitle,
    required this.chapterMapping,
  });

  @override
  State<ChapterSelectScreen> createState() => _ChapterSelectScreenState();
}

class _ChapterSelectScreenState extends State<ChapterSelectScreen> {
  bool _isLoading = false;

  Future<void> _loadAndStartQuiz(String chapterName, String jsonFileName) async {
    setState(() => _isLoading = true);

    // 🌐 Dual Endpoint URLs for 100% Reliability
    final String rawUrl = Uri.encodeFull("https://raw.githubusercontent.com/zxcty54/quiz/main/$jsonFileName");
    final String cdnUrl = Uri.encodeFull("https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/$jsonFileName");

    http.Response? response;

    try {
      // 1️⃣ Attempt 1: Fetch from GitHub Raw (5 Second Timeout)
      try {
        response = await http.get(Uri.parse(rawUrl)).timeout(const Duration(seconds: 5));
      } catch (_) {
        // If GitHub Raw fails or times out, silently try CDN
        response = null;
      }

      // 2️⃣ Attempt 2: Fallback to jsDelivr CDN if Primary failed
      if (response == null || response.statusCode != 200) {
        response = await http.get(Uri.parse(cdnUrl)).timeout(
          const Duration(seconds: 7),
          onTimeout: () {
            throw TimeoutException("Connection timed out. Check your Internet/Wi-Fi.");
          },
        );
      }

      // 3️⃣ Parse JSON Questions
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Question> questions = body.map((dynamic item) => Question.fromJson(item)).toList();

        if (!mounted) return;

        if (questions.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizScreen(
                chapterName: chapterName,
                questions: questions,
                fileName: jsonFileName,
              ),
            ),
          );
        } else {
          _showErrorDialog("No questions found in this chapter.");
        }
      } else {
        throw Exception("Server Error (Code: ${response.statusCode})");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Internet Connection Issue:\n\n$e");
    } finally {
      // 🔒 CRITICAL: Guaranteed Loader Reset
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Connection Alert"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterEntries = widget.chapterMapping.entries.toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryTitle)),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chapterEntries.length,
            itemBuilder: (context, index) {
              final chapter = chapterEntries[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text("${index + 1}"),
                  ),
                  title: Text(chapter.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("File: ${chapter.value}", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _showInstructionModal(chapter.key, chapter.value),
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading Questions...", style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Connecting to Fast Server", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showInstructionModal(String chapterName, String jsonFileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(chapterName),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("⏱️ Time Limit: 30 Seconds / Question"),
            Text("🎯 Format: Latest Exam MCQ Pattern"),
            Text("💡 Tip: Read detailed explanations"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadAndStartQuiz(chapterName, jsonFileName);
            },
            child: const Text("Start Test 🚀"),
          ),
        ],
      ),
    );
  }
}
