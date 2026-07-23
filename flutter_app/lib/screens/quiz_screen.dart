import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../widgets/report_error_dialog.dart';

class QuizScreen extends StatefulWidget {
  final String chapterName;
  final String fileName;
  final List<Question> questions;

  const QuizScreen({
    super.key,
    required this.chapterName,
    required this.fileName,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  bool _isHindi = true;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  
  // Timer State
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        if (!_isAnswered) {
          setState(() {
            _isAnswered = true; // Auto-lock options when timer expires
          });
        }
      }
    });
  }

  void _onOptionSelected(int index) {
    if (_isAnswered) return;
    _timer?.cancel();
    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
      _startTimer();
    } else {
      _showFinishDialog();
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
      _startTimer();
    }
  }

  void _showFinishDialog() {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Test Completed!'),
        content: const Text('You have reached the end of this chapter test.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Back to Chapter list
            },
            child: const Text('Back to Chapters'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.chapterName)),
        body: const Center(child: Text('No questions available in this file.')),
      );
    }

    final currentQ = widget.questions[_currentIndex];
    final String qText = _isHindi ? currentQ.questionHi : currentQ.questionEn;
    final List<String>? statements = _isHindi ? currentQ.statementsHi : currentQ.statementsEn;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / ${widget.questions.length}'),
        actions: [
          // Language Switcher (EN / HI)
          ActionChip(
            label: Text(_isHindi ? 'HI 🇮🇳' : 'EN 🇬🇧'),
            onPressed: () => setState(() => _isHindi = !_isHindi),
          ),
          // Report Error Button
          IconButton(
            icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ReportErrorDialog(
                  fileName: widget.fileName,
                  questionIndex: _currentIndex,
                  questionSnippet: qText.length > 50 ? '${qText.substring(0, 50)}...' : qText,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ⏱️ Linear Progress Countdown Timer
          LinearProgressIndicator(
            value: _secondsLeft / 30,
            backgroundColor: Colors.grey.shade300,
            color: _secondsLeft < 10 ? Colors.red : const Color(0xFF2563EB),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer Banner text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⏱️ Time Remaining: $_secondsLefts',
                        style: TextStyle(
                          color: _secondsLeft < 10 ? Colors.red : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Question Text
                  Text(
                    'Q${_currentIndex + 1}. $qText',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Statements Container (If available)
                  if (statements != null && statements.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: statements
                            .map((stmt) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text('• $stmt', style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Interactive Options
                  ...List.generate(currentQ.options.length, (index) {
                    Color optionColor = Theme.of(context).cardColor;
                    Color borderColor = Colors.grey.shade300;

                    if (_isAnswered) {
                      if (index == currentQ.answerIndex) {
                        optionColor = const Color(0xFF10B981).withOpacity(0.15); // Correct Green
                        borderColor = const Color(0xFF10B981);
                      } else if (_selectedOptionIndex == index) {
                        optionColor = const Color(0xFFF43F5E).withOpacity(0.15); // Wrong Red
                        borderColor = const Color(0xFFF43F5E);
                      }
                    }

                    return GestureDetector(
                      onTap: () => _onOptionSelected(index),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: optionColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: borderColor,
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentQ.options[index],
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // 💡 Explanation Box
                  if (_isAnswered && currentQ.explanation.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡 Explanation / व्याख्या:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentQ.explanation,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Controls (Prev / Next)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _currentIndex > 0 ? _prevQuestion : null,
                  child: const Text('← Prev'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _nextQuestion,
                  child: Text(
                    _currentIndex == widget.questions.length - 1 ? 'Finish Test 🚀' : 'Next →',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
