import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _answered = false;
  int? _selectedIndex;
  bool _isCorrect = false;

  @override
  void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 15;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _answered) return;

      if (_timeLeft > 1) {
        setState(() {
          _timeLeft--;
          _totalTimeTaken++;
        });
      } else {
        setState(() {
          _timeLeft = 0;
          _totalTimeTaken++;
        });
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    if (_answered) return;
    _timer?.cancel();
    HapticFeedback.heavyImpact();

    setState(() {
      _answered = true;
      _selectedIndex = null;
      _isCorrect = false;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _nextQuestion();
    });
  }

  // 🚪 Exit Confirmation Dialog (Back gesture aur Close button dono ke liye)
  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Quiz chhodna chahte hain?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Agar aap abhi exit karenge toh aapka score leaderboard par save nahi hoga.',
          style: TextStyle(
            fontSize: 14,
            color: widget.isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nahi, Continue', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ha, Exit karein', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return true;
    }
    return false;
  }

  int? _getCorrectAnswer(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final text = value.trim();
      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;
      if (text.length == 1) {
        final code = text.toUpperCase().codeUnitAt(0);
        if (code >= 65 && code <= 90) return code - 65;
      }
    }
    return null;
  }

  void _onSelectOption(int selectedIdx) {
    if (_answered || widget.questions.isEmpty) return;
    _timer?.cancel();

    final currentQ = widget.questions[_currentIndex];
    final correctAnswer = _getCorrectAnswer(currentQ['a'] ?? currentQ['answer_index']);
    final correct = correctAnswer != null && selectedIdx == correctAnswer;

    if (correct) {
      _score++;
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _answered = true;
      _selectedIndex = selectedIdx;
      _isCorrect = correct;
    });

    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedIndex = null;
        _isCorrect = false;
      });
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

  String _getQuestionText(Map<String, dynamic> q) {
    if (q['qe'] != null && q['qe'].toString().trim().isNotEmpty) {
      return q['qe'].toString().trim();
    }
    if (q['q'] != null && q['q'].toString().trim().isNotEmpty) {
      return q['q'].toString().trim();
    }
    if (q['question'] != null && q['question'].toString().trim().isNotEmpty) {
      return q['question'].toString().trim();
    }
    return 'Question ${_currentIndex + 1}';
  }

  List<dynamic> _getOptions(Map<String, dynamic> q) {
    if (q['o'] is List) return q['o'];
    if (q['options'] is List) return q['options'];
    return [];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final scaffoldBg = isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
    final subTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final borderColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wapas Jayein'),
          ),
        ),
      );
    }

    final q = widget.questions[_currentIndex];
    final options = _getOptions(q);
    final questionText = _getQuestionText(q);
    final correctAnswer = _getCorrectAnswer(q['a'] ?? q['answer_index']);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
            tooltip: 'Exit Quiz',
            onPressed: _confirmExit,
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Text(
                'Question ${_currentIndex + 1}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                ' / ${widget.questions.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _timeLeft <= 4
                    ? const Color(0xFFFEF2F2)
                    : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _timeLeft <= 4
                      ? const Color(0xFFF87171)
                      : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alarm,
                    size: 16,
                    color: _timeLeft <= 4 ? const Color(0xFFDC2626) : subTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '00:${_timeLeft.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: _timeLeft <= 4 ? const Color(0xFFDC2626) : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.questions.length,
              minHeight: 3,
              backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Question Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        questionText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options List
                    ...List.generate(
                      options.length,
                      (idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildEdutechOption(
                          idx,
                          options[idx],
                          correctAnswer,
                          cardBg,
                          textColor,
                          subTextColor,
                          borderColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Confirmation Strip
              if (_answered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isCorrect
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
                    border: Border(
                      top: BorderSide(
                        color: _isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCorrect ? Icons.check_circle : Icons.cancel,
                        color: _isCorrect ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCorrect ? 'Correct Answer' : (_selectedIndex == null ? 'Time Expired' : 'Incorrect Answer'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _isCorrect ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdutechOption(
    int index,
    dynamic text,
    int? correctAnswer,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    Color defaultBorderColor,
  ) {
    final selected = _selectedIndex == index;
    final isCorrect = correctAnswer == index;

    Color itemBg = cardBg;
    Color itemBorder = defaultBorderColor;
    Color labelBg = widget.isDarkMode ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    Color labelTextColor = subTextColor;
    Color contentColor = textColor;

    if (_answered) {
      if (isCorrect) {
        itemBg = widget.isDarkMode ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4);
        itemBorder = const Color(0xFF16A34A);
        labelBg = const Color(0xFF16A34A);
        labelTextColor = Colors.white;
        contentColor = widget.isDarkMode ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
      } else if (selected && !_isCorrect) {
        itemBg = widget.isDarkMode ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2);
        itemBorder = const Color(0xFFDC2626);
        labelBg = const Color(0xFFDC2626);
        labelTextColor = Colors.white;
        contentColor = widget.isDarkMode ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      } else {
        itemBg = cardBg;
        itemBorder = defaultBorderColor;
        contentColor = subTextColor;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _answered ? null : () => _onSelectOption(index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: itemBorder,
              width: _answered && (isCorrect || selected) ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: labelBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: labelTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: contentColor,
                    height: 1.35,
                  ),
                ),
              ),
              if (_answered && isCorrect)
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
              else if (_answered && selected && !_isCorrect)
                const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
