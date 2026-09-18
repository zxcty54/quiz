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

class _ChallengeQuizScreenState extends State<ChallengeQuizScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int _timeLeft = 15;
  int _totalTimeTaken = 0;

  Timer? _timer;

  bool _answered = false;
  int? _selectedIndex;
  bool _isCorrect = false;

  late AnimationController _questionController;
  late AnimationController _timerController;
  late Animation<double> _questionAnimation;
  late Animation<double> _timerAnimation;

  @override
  void initState() {
    super.initState();

    _questionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _questionAnimation = CurvedAnimation(
      parent: _questionController,
      curve: Curves.easeOutBack,
    );

    _timerAnimation = CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    );

    if (widget.questions.isNotEmpty) {
      _questionController.forward();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timeLeft = 15;
    _timerController
      ..stop()
      ..reset()
      ..forward();

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

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  int? _getCorrectAnswer(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is String) {
      final text = value.trim();

      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;

      // Supports A/B/C/D as well.
      if (text.length == 1) {
        final upper = text.toUpperCase();
        final code = upper.codeUnitAt(0);

        if (code >= 65 && code <= 90) {
          return code - 65;
        }
      }
    }

    return null;
  }

  void _onSelectOption(int selectedIdx) {
    if (_answered || widget.questions.isEmpty) return;

    _timer?.cancel();
    _timerController.stop();

    final currentQ = widget.questions[_currentIndex];

    final correctAnswer = _getCorrectAnswer(
      currentQ['a'] ?? currentQ['answer_index'],
    );

    final correct = correctAnswer != null &&
        selectedIdx == correctAnswer;

    if (correct) {
      _score++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    setState(() {
      _answered = true;
      _selectedIndex = selectedIdx;
      _isCorrect = correct;
    });

    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) {
        _nextQuestion();
      }
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

      _questionController
        ..reset()
        ..forward();

      _startTimer();
    } else {
      _timer?.cancel();
      _timerController.stop();
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
    if (q['qh'] != null &&
        q['qh'].toString().trim().isNotEmpty) {
      return q['qh'].toString().trim();
    }

    if (q['qe'] != null &&
        q['qe'].toString().trim().isNotEmpty) {
      return q['qe'].toString().trim();
    }

    return (q['question'] ?? 'Question ${_currentIndex + 1}')
        .toString();
  }

  List<dynamic> _getOptions(Map<String, dynamic> q) {
    if (q['o'] is List) {
      return q['o'];
    }

    if (q['options'] is List) {
      return q['options'];
    }

    return [];
  }

  Color _optionColor(int index, int? correctAnswer) {
    if (!_answered) {
      return widget.isDarkMode
          ? const Color(0xFF1E293B)
          : Colors.white;
    }

    if (correctAnswer != null && index == correctAnswer) {
      return const Color(0xFF16A34A);
    }

    if (_selectedIndex == index && !_isCorrect) {
      return const Color(0xFFDC2626);
    }

    return widget.isDarkMode
        ? const Color(0xFF172033)
        : const Color(0xFFF1F5F9);
  }

  Color _optionBorderColor(int index, int? correctAnswer) {
    if (!_answered) {
      return widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0);
    }

    if (correctAnswer != null && index == correctAnswer) {
      return const Color(0xFF22C55E);
    }

    if (_selectedIndex == index && !_isCorrect) {
      return const Color(0xFFEF4444);
    }

    return Colors.transparent;
  }

  Color _optionTextColor(int index, int? correctAnswer) {
    if (!_answered) {
      return widget.isDarkMode
          ? Colors.white
          : const Color(0xFF0F172A);
    }

    if ((correctAnswer != null && index == correctAnswer) ||
        (_selectedIndex == index && !_isCorrect)) {
      return Colors.white;
    }

    return widget.isDarkMode
        ? Colors.white70
        : const Color(0xFF64748B);
  }

  String _letter(int index) {
    if (index < 26) {
      return String.fromCharCode(65 + index);
    }
    return '${index + 1}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    final bgColor = isDark
        ? const Color(0xFF080D1A)
        : const Color(0xFFF6F8FC);

    final textColor = isDark
        ? Colors.white
        : const Color(0xFF0F172A);

    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
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

    final correctAnswer = _getCorrectAnswer(
      q['a'] ?? q['answer_index'],
    );

    final progress =
        (_currentIndex + 1) / widget.questions.length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(textColor, progress),

              Expanded(
                child: AnimatedBuilder(
                  animation: _questionAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _questionAnimation,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          25 * (1 - _questionAnimation.value),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      20,
                    ),
                    child: Column(
                      children: [
                        _buildQuestionCard(
                          questionText,
                          textColor,
                        ),

                        const SizedBox(height: 20),

                        Expanded(
                          child: options.isEmpty
                              ? Center(
                                  child: Text(
                                    'Options available nahi hain',
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  physics:
                                      const BouncingScrollPhysics(),
                                  itemCount: options.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _buildOption(
                                      index,
                                      options[index],
                                      correctAnswer,
                                    );
                                  },
                                ),
                        ),

                        const SizedBox(height: 8),

                        _buildBottomStatus(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor, double progress) {
    final danger = _timeLeft <= 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF151D30)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.quiz_rounded,
                      color: Color(0xFF6366F1),
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_currentIndex + 1}/${widget.questions.length}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: danger
                      ? Colors.red.withValues(alpha: 0.14)
                      : const Color(0xFF10B981)
                          .withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: danger
                        ? Colors.red.withValues(alpha: 0.25)
                        : const Color(0xFF10B981)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 18,
                      color: danger
                          ? Colors.redAccent
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_timeLeft s',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: danger
                            ? Colors.redAccent
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 9),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C3AED),
                      Color(0xFF4F46E5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    String questionText,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF7C3AED),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1)
                .withValues(alpha: 0.28),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'QUESTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.bolt_rounded,
                color: Colors.amber,
                size: 24,
              ),
            ],
          ),

          const SizedBox(height: 17),

          Text(
            questionText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    int index,
    dynamic option,
    int? correctAnswer,
  ) {
    final selected = _selectedIndex == index;

    final bg = _optionColor(index, correctAnswer);
    final border = _optionBorderColor(
      index,
      correctAnswer,
    );

    final optionTextColor = _optionTextColor(
      index,
      correctAnswer,
    );

    IconData? trailingIcon;

    if (_answered && correctAnswer == index) {
      trailingIcon = Icons.check_circle_rounded;
    } else if (_answered && selected && !_isCorrect) {
      trailingIcon = Icons.cancel_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _answered
              ? null
              : () => _onSelectOption(index),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 68,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: border,
                width: _answered &&
                        (correctAnswer == index || selected)
                    ? 2
                    : 1,
              ),
              boxShadow: !_answered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: widget.isDarkMode
                              ? 0.10
                              : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  width: 43,
                  height: 43,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _answered
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFF6366F1)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    _letter(index),
                    style: TextStyle(
                      color: _answered
                          ? Colors.white
                          : const Color(0xFF6366F1),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    option.toString(),
                    style: TextStyle(
                      color: optionTextColor,
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                if (trailingIcon != null)
                  Icon(
                    trailingIcon,
                    color: Colors.white,
                    size: 25,
                  )
                else if (!_answered)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: widget.isDarkMode
                        ? Colors.white24
                        : Colors.black26,
                    size: 15,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomStatus() {
    if (!_answered) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 17,
            color: widget.isDarkMode
                ? Colors.white38
                : Colors.black38,
          ),
          const SizedBox(width: 6),
          Text(
            'Answer choose karein',
            style: TextStyle(
              color: widget.isDarkMode
                  ? Colors.white38
                  : Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (_isCorrect) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.celebration_rounded,
            color: Color(0xFF22C55E),
            size: 19,
          ),
          SizedBox(width: 7),
          Text(
            'Correct! 🔥',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    if (_selectedIndex == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.access_time_filled_rounded,
            color: Colors.orange,
            size: 18,
          ),
          SizedBox(width: 7),
          Text(
            'Time Up! ⏰',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.close_rounded,
          color: Color(0xFFEF4444),
          size: 19,
        ),
        SizedBox(width: 7),
        Text(
          'Wrong Answer',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}