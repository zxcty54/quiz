import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../widgets/latex_text.dart';

class QuizScreen extends StatefulWidget {
  final String chapterName;
  final List<Question> questions;
  final String fileName;

  const QuizScreen({
    super.key,
    required this.chapterName,
    required this.questions,
    required this.fileName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _secondsLeft = 30;
  Timer? _timer;
  bool _isHindi = false;
  int? _selectedOption;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 30;
      _isAnswered = false;
      _selectedOption = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        setState(() => _isAnswered = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectOption(int index) {
    if (_isAnswered) return;
    _timer?.cancel();
    setState(() {
      _selectedOption = index;
      _isAnswered = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
      _startTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[_currentIndex];
    final String qText = _isHindi ? (currentQ.qh ?? currentQ.qe) : currentQ.qe;
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      appBar: AppBar(
        title: Text("${_currentIndex + 1} / ${widget.questions.length}"),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isHindi = !_isHindi),
            child: Text(
              _isHindi ? "EN 🇬🇧" : "HI 🇮🇳",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Bar
            LinearProgressIndicator(
              value: _secondsLeft / 30,
              backgroundColor: Colors.grey.shade300,
              color: _secondsLeft > 10 ? Colors.blue : Colors.red,
            ),
            const SizedBox(height: 8),
            Text("⏱️ Time Remaining: $_secondsLeft s", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Question Text with LaTeX
            LatexText(
              "Q${_currentIndex + 1}. $qText",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
            ),
            const SizedBox(height: 12),

            // Statements Box (If present)
            if (statements != null && statements.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: statements
                      .map((stmt) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: LatexText(stmt, style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Options List
            ...List.generate(currentQ.options.length, (index) {
              final optionText = currentQ.options[index];
              Color btnColor = Colors.white;
              Color borderColor = Colors.grey.shade300;

              if (_isAnswered) {
                if (index == currentQ.answerIndex) {
                  btnColor = Colors.green.shade100;
                  borderColor = Colors.green;
                } else if (_selectedOption == index) {
                  btnColor = Colors.red.shade100;
                  borderColor = Colors.red;
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: InkWell(
                  onTap: () => _selectOption(index),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: btnColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LatexText(
                            optionText,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Explanation Box
            if (_isAnswered) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("💡 Explanation / व्याख्या:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    LatexText(
                      currentQ.explanation.isNotEmpty ? currentQ.explanation : "No explanation available.",
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _currentIndex > 0 ? _prevQuestion : null,
              child: const Text("← Prev"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: _nextQuestion,
              child: Text(_currentIndex < widget.questions.length - 1 ? "Next →" : "Finish 🚀"),
            ),
          ],
        ),
      ),
    );
  }
}
