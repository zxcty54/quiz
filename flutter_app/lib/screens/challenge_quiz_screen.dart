import 'dart:async';
import 'package:flutter/material.dart';
import 'challenge_result_screen.dart';

class ChallengeQuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String challengeCode;
  final String challengerName;
  final int challengerScore;
  final bool isDarkMode;

  const ChallengeQuizScreen({
    super.key,
    required this.questions,
    required this.challengeCode,
    this.challengerName = '',
    this.challengerScore = 0,
    required this.isDarkMode,
  });

  @override
  State<ChallengeQuizScreen> createState() => _ChallengeQuizScreenState();
}

class _ChallengeQuizScreenState extends State<ChallengeQuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int _timeLeft = 15;
  int _totalTimeTaken = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timeLeft = 15;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
          _totalTimeTaken++;
        });
      } else {
        _nextQuestion();
      }
    });
  }

  void _onSelectOption(int selectedIdx) {
    if (widget.questions.isEmpty) return;
    final currentQ = widget.questions[_currentIndex];

    // Aapke JSON format me correct answer key "a" hai
    final dynamic correctAns = currentQ['a'] ?? currentQ['answer_index'];

    if (correctAns != null) {
      if (correctAns is int && selectedIdx == correctAns) {
        _score++;
      } else if (correctAns is String) {
        int? parsedIdx = int.tryParse(correctAns);
        if (parsedIdx != null && selectedIdx == parsedIdx) {
          _score++;
        }
      }
    }
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
      _startTimer();
    } else {
      _timer?.cancel();
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeResultScreen(
          challengerName: widget.challengerName,
          challengerScore: widget.challengerScore,
          myScore: _score,
          totalTimeTaken: _totalTimeTaken,
          challengeCode: widget.challengeCode,
          isDarkMode: widget.isDarkMode,
        ),
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
    final bgColor = widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);

    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text('Challenge')),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wapas Jayein'),
          ),
        ),
      );
    }

    final q = widget.questions[_currentIndex];

    // Aapke format ke hisaab se: pehle "qh" agar khali na ho, warna "qe"
    String questionText = '';
    if (q['qh'] != null && q['qh'].toString().trim().isNotEmpty) {
      questionText = q['qh'].toString().trim();
    } else if (q['qe'] != null && q['qe'].toString().trim().isNotEmpty) {
      questionText = q['qe'].toString().trim();
    } else {
      questionText = (q['question'] ?? 'Question ${_currentIndex + 1}').toString();
    }

    // Options list "o" se fetch hogi
    final List<dynamic> options = (q['o'] is List) ? q['o'] : (q['options'] ?? []);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Challenge (${_currentIndex + 1}/${widget.questions.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_timeLeft <= 5 ? Colors.redAccent : const Color(0xFF10B981)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⏱ $_timeLeft s',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _timeLeft <= 5 ? Colors.redAccent : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 24),
              Text(
                questionText,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        backgroundColor: cardColor,
                        foregroundColor: textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: widget.isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _onSelectOption(idx),
                      child: Text(
                        '${String.fromCharCode(65 + idx)}. ${options[idx]}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
