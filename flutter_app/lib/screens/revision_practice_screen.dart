import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/ai_explainer_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';

class RevisionPracticeScreen extends StatefulWidget {
  final String testTitle;
  final List<Question> questions;

  const RevisionPracticeScreen({
    super.key,
    required this.testTitle,
    required this.questions,
  });

  @override
  State<RevisionPracticeScreen> createState() => _RevisionPracticeScreenState();
}

class _RevisionPracticeScreenState extends State<RevisionPracticeScreen> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  bool _isHindi = false;
  bool _isBookmarked = false;

  Timer? _timer;
  int _timeLeft = 30; // ⏱️ 30 Seconds Timer

  // 💬 AI Custom Doubt State Tracking
  final Map<int, int> _asksRemainingPerQuestion = {}; 
  final Map<int, List<Map<String, String>>> _aiChatHistory = {}; 

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 📌 Check if current question is saved in Bookmarks
  void _checkBookmarkStatus() async {
    final savedList = await UserStatsService.getSavedQuestions();
    final currentQ = widget.questions[_currentIndex];
    String currentText = currentQ.getText(_isHindi);

    bool exists = savedList.any((item) {
      String qText = item['qe'] ?? item['qh'] ?? '';
      return qText == currentText || qText == currentQ.qe;
    });

    if (mounted) {
      setState(() => _isBookmarked = exists);
    }
  }

  // 📌 Toggle Bookmark Action
  void _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];
    Map<String, dynamic> qJson = {
      'qe': currentQ.qe,
      'qh': currentQ.qh,
      'se': currentQ.se,
      'sh': currentQ.sh,
      'oe': currentQ.oe,
      'oh': currentQ.oh,
      'options': currentQ.getOptions(_isHindi),
      'answerIndex': currentQ.answerIndex,
      'explanation': currentQ.getExplanation(_isHindi),
      'ee': currentQ.ee,
      'eh': currentQ.eh,
    };

    bool saved = await UserStatsService.toggleBookmark(qJson);

    if (mounted) {
      setState(() => _isBookmarked = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? '📌 Question Saved to Bookmarks!' : '🗑️ Removed from Bookmarks'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 30; // ⏱️ Reset to 30 Seconds
      _isAnswered = false;
      _selectedOptionIndex = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        setState(() {
          _isAnswered = true;
        });

        // ⏱️ Timeout counts as incorrect -> Save to Wrong Vault
        final currentQ = widget.questions[_currentIndex];
        UserStatsService.recordQuestionAttempt(
          isCorrect: false,
          chapterName: widget.testTitle,
          chapterPath: '',
          wrongQuestionJson: {
            'qe': currentQ.qe,
            'qh': currentQ.qh,
            'se': currentQ.se,
            'sh': currentQ.sh,
            'oe': currentQ.oe,
            'oh': currentQ.oh,
            'options': currentQ.getOptions(_isHindi),
            'answerIndex': currentQ.answerIndex,
            'explanation': currentQ.getExplanation(_isHindi),
            'ee': currentQ.ee,
            'eh': currentQ.eh,
          },
        );
      }
    });
  }

  void _onOptionTap(int index) {
    if (_isAnswered) return;
    _timer?.cancel();

    final currentQ = widget.questions[_currentIndex];
    final bool isCorrect = index == currentQ.answerIndex;

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
    });

    UserStatsService.recordQuestionAttempt(
      isCorrect: isCorrect,
      chapterName: widget.testTitle,
      chapterPath: '',
      wrongQuestionJson: isCorrect
          ? null
          : {
              'qe': currentQ.qe,
              'qh': currentQ.qh,
              'se': currentQ.se,
              'sh': currentQ.sh,
              'oe': currentQ.oe,
              'oh': currentQ.oh,
              'options': currentQ.getOptions(_isHindi),
              'answerIndex': currentQ.answerIndex,
              'explanation': currentQ.getExplanation(_isHindi),
              'ee': currentQ.ee,
              'eh': currentQ.eh,
            },
    );
  }

  // 💬 BOTTOM SHEET DIALOG FOR AI DOUBT SOLVER (1 ASK & 100 CHARS)
  void _openAiDoubtDialog(Question currentQ) {
    int asksLeft = _asksRemainingPerQuestion[_currentIndex] ?? 1; // 🛑 STRICT 1 ASK LIMIT
    TextEditingController doubtController = TextEditingController();
    bool isAsking = false;
    final currentOptions = currentQ.getOptions(_isHindi);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final history = _aiChatHistory[_currentIndex] ?? [];

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🤖', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 6),
                            Text('Ask AI Custom Doubt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: asksLeft > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            asksLeft > 0 ? '$asksLeft Ask Left' : '🔒 Limit Reached',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: asksLeft > 0 ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chat History for this question
                    ...history.map((chat) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "❓ Your Doubt: ${chat['doubt']}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2563EB)),
                              ),
                              const Divider(height: 12),
                              MathFormattedText(
                                text: chat['response']!,
                                textStyle: const TextStyle(fontSize: 12.5, height: 1.4, color: Colors.black87),
                              ),
                            ],
                          ),
                        )),

                    if (asksLeft > 0) ...[
                      TextField(
                        controller: doubtController,
                        maxLength: 100, // 🛑 STRICT 100 CHARACTERS LIMIT
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type your exact doubt (Max 100 chars)...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: isAsking
                              ? null
                              : () async {
                                  if (doubtController.text.trim().isEmpty) return;
                                  setModalState(() => isAsking = true);

                                  String userQuery = doubtController.text.trim();

                                  String aiResp = await AiExplainerService.askCustomDoubt(
                                    question: currentQ.getText(_isHindi),
                                    options: currentOptions,
                                    correctAnswer: currentOptions[currentQ.answerIndex],
                                    userDoubt: userQuery,
                                  );

                                  setState(() {
                                    _asksRemainingPerQuestion[_currentIndex] = asksLeft - 1;
                                    _aiChatHistory[_currentIndex] = [
                                      ...history,
                                      {'doubt': userQuery, 'response': aiResp}
                                    ];
                                  });

                                  setModalState(() {
                                    asksLeft--;
                                    isAsking = false;
                                    doubtController.clear();
                                  });
                                },
                          icon: isAsking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(isAsking ? 'Generating Deep Explanation...' : 'Get AI Explanation 🚀'),
                        ),
                      )
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: const Text(
                          '🔒 Question-wise 1 doubt limit complete ho chuki hai.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      )
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _goToNextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
      _checkBookmarkStatus();
    } else {
      _timer?.cancel();
      _showCompletionDialog();
    }
  }

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startTimer();
      _checkBookmarkStatus();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 Revision Complete!'),
        content: Text('Aapne "${widget.testTitle}" ke saare ${widget.questions.length} questions revise kar liye hain.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done & Go Back'),
          )
        ],
      ),
    );
  }

  // ✨ PREMIUM VISUAL EXPLANATION BUILDER
  Widget _buildEnhancedExplanation(String rawExplanation, Question currentQ) {
    List<String> rawParagraphs = rawExplanation
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏆 1. HEADER STRIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('💡', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Detailed Solution',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 13.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _openAiDoubtDialog(currentQ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🤖 Ask AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),

          // 📖 2. SMART BREAKDOWN POINTS
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rawParagraphs.map((para) {
                bool isCorrectPoint = para.toLowerCase().contains('is correct') || para.contains('सही है');
                bool isIncorrectPoint = para.toLowerCase().contains('is incorrect') || 
                                        para.toLowerCase().contains('is false') || 
                                        para.contains('गलत है');

                Color stripBg = const Color(0xFFF8FAFC);
                Color stripBorder = const Color(0xFFE2E8F0);
                Color badgeBg = const Color(0xFF64748B);
                String badgeIcon = '📌';

                if (isCorrectPoint) {
                  stripBg = const Color(0xFFF0FDF4);
                  stripBorder = const Color(0xFFBBF7D0);
                  badgeBg = const Color(0xFF16A34A);
                  badgeIcon = '✓';
                } else if (isIncorrectPoint) {
                  stripBg = const Color(0xFFFEF2F2);
                  stripBorder = const Color(0xFFFECDD3);
                  badgeBg = const Color(0xFFDC2626);
                  badgeIcon = '✕';
                }

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(11.0),
                  decoration: BoxDecoration(
                    color: stripBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: stripBorder, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badgeIcon,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MathFormattedText(
                          text: para,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[_currentIndex];
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;
    final List<String> currentOptions = currentQ.getOptions(_isHindi);
    final String currentExplanation = currentQ.getExplanation(_isHindi);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: _isBookmarked ? const Color(0xFF2563EB) : Colors.grey,
            ),
            onPressed: _toggleBookmarkQuestion,
            tooltip: "Bookmark Question",
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2563EB)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isHindi ? 'हिंदी' : 'ENG',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
            onPressed: () => setState(() => _isHindi = !_isHindi),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _timeLeft <= 5 ? Colors.red.shade100 : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _timeLeft <= 5 ? Colors.red : const Color(0xFF2563EB)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 15, color: _timeLeft <= 5 ? Colors.red : const Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _timeLeft <= 5 ? Colors.red : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentIndex + 1} / ${widget.questions.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(8)),
                  child: const Text('⚡ REVISION MODE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                )
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),

            // 🎯 1. MAIN QUESTION CARD
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MathFormattedText(
                  text: currentQ.getText(_isHindi),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 📋 2. DEDICATED SEPARATE STATEMENT CARDS (Numbered Badges)
            if (statements != null && statements.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: statements.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  String stmtText = entry.value.trim().replaceFirst(RegExp(r'^([\(\[]?\d+[\)\]\.]?|•|-)\s*'), '');

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "($index)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MathFormattedText(
                            text: stmtText,
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF334155),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // 🔘 3. BILINGUAL OPTIONS LIST (Dynamic oe/oh)
            ...List.generate(currentOptions.length, (index) {
              final optionText = currentOptions[index];
              final isCorrect = index == currentQ.answerIndex;
              final isSelected = index == _selectedOptionIndex;

              Color borderColor = Colors.grey.shade300;
              Color bgColor = Colors.white;
              Widget icon = const SizedBox.shrink();

              if (_isAnswered) {
                if (isCorrect) {
                  borderColor = Colors.green;
                  bgColor = Colors.green.shade50;
                  icon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
                } else if (isSelected) {
                  borderColor = Colors.red;
                  bgColor = Colors.red.shade50;
                  icon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _onOptionTap(index),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: _isAnswered && (isCorrect || isSelected) ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isAnswered && isCorrect
                                ? Colors.green
                                : (_isAnswered && isSelected ? Colors.red : Colors.grey.shade100),
                          ),
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _isAnswered && (isCorrect || isSelected) ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MathFormattedText(
                            text: optionText,
                            textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                        icon,
                      ],
                    ),
                  ),
                ),
              );
            }),

            // 💡 4. UPGRADED HIGH-CONTRAST DETAILED SOLUTION
            if (_isAnswered) ...[
              _buildEnhancedExplanation(currentExplanation, currentQ),
            ],
            const SizedBox(height: 70),
          ],
        ),
      ),

      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _currentIndex > 0 ? _goToPreviousQuestion : null,
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
              label: const Text('Previous'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              onPressed: _goToNextQuestion,
              label: Text(_currentIndex == widget.questions.length - 1 ? 'Finish 🏁' : 'Next ➔'),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
