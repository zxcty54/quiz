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
      'options': currentQ.options,
      'answerIndex': currentQ.answerIndex,
      'explanation': currentQ.explanation,
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
            'options': currentQ.options,
            'answerIndex': currentQ.answerIndex,
            'explanation': currentQ.explanation,
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

    // 📊 Record detailed question attempt for Profile Stats & Wrong Vault
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
              'options': currentQ.options,
              'answerIndex': currentQ.answerIndex,
              'explanation': currentQ.explanation,
            },
    );
  }

  // 💬 BOTTOM SHEET DIALOG FOR AI DOUBT SOLVER
  void _openAiDoubtDialog(Question currentQ) {
    int asksLeft = _asksRemainingPerQuestion[_currentIndex] ?? 2;
    TextEditingController doubtController = TextEditingController();
    bool isAsking = false;

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
                            asksLeft > 0 ? '$asksLeft Asks Left' : '🔒 Limit Reached',
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
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type your exact doubt (e.g. Methane kyu nahi hua answer?)',
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
                                    options: currentQ.options,
                                    correctAnswer: currentQ.options[currentQ.answerIndex],
                                    explanation: currentQ.explanation,
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
                          '🔒 Question-wise 2 doubts limit complete ho chuki hai.',
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

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[_currentIndex];
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          // 🔖 BOOKMARK TOGGLE BUTTON
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

            // Question Box
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathFormattedText(
                      text: currentQ.getText(_isHindi),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4, color: Colors.black87),
                    ),
                    if (statements != null && statements.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...statements.map((stmt) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: MathFormattedText(
                          text: "• $stmt",
                          textStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.3),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Options List
            ...List.generate(currentQ.options.length, (index) {
              final optionText = currentQ.options[index];
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

            // Detailed Solution Card + 🤖 Ask AI Button
            if (_isAnswered) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('💡', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text('Detailed Solution', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 13)),
                          ],
                        ),
                        // 🤖 ASK AI BUTTON
                        InkWell(
                          onTap: () => _openAiDoubtDialog(currentQ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Text('🤖 Ask AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    MathFormattedText(
                      text: currentQ.explanation,
                      textStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF14532D), height: 1.4),
                    ),
                  ],
                ),
              ),
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
