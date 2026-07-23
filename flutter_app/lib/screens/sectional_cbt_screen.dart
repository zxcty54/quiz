import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../widgets/latex_text.dart';

class SectionalCbtScreen extends StatefulWidget {
  final String testTitle;
  final List<Question> questions;
  final String subFolder;

  const SectionalCbtScreen({
    super.key,
    required this.testTitle,
    required this.questions,
    required this.subFolder,
  });

  @override
  State<SectionalCbtScreen> createState() => _SectionalCbtScreenState();
}

class _SectionalCbtScreenState extends State<SectionalCbtScreen> {
  int _currentIndex = 0;
  int _totalTimeSeconds = 25 * 60; // 25 Minutes Default CBT Timer
  Timer? _examTimer;

  bool _isHindi = false;
  final Map<int, int> _userAnswers = {};
  final Set<int> _markedForReview = {};
  final Map<int, int> _questionTimers = {};
  int _currentQTime = 0;
  Timer? _qTimer;

  bool _isExamSubmitted = false;

  @override
  void initState() {
    super.initState();
    _isHindi = widget.subFolder.contains('bssc') || widget.subFolder.contains('bpsc');
    _startTimers();
  }

  void _startTimers() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_totalTimeSeconds > 0) {
        setState(() => _totalTimeSeconds--);
      } else {
        _submitExam();
      }
    });

    _qTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentQTime++;
      _questionTimers[_currentIndex] = (_questionTimers[_currentIndex] ?? 0) + 1;
    });
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    _qTimer?.cancel();
    super.dispose();
  }

  void _selectOption(int optionIndex) {
    setState(() {
      _userAnswers[_currentIndex] = optionIndex;
    });
  }

  void _toggleReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  void _submitExam() {
    _examTimer?.cancel();
    _qTimer?.cancel();
    setState(() {
      _isExamSubmitted = true;
    });
  }

  String _formatTime(int totalSec) {
    int m = totalSec ~/ 60;
    int s = totalSec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (_isExamSubmitted) {
      return _buildResultReportScreen();
    }

    final currentQ = widget.questions[_currentIndex];
    final String qText = _isHindi ? (currentQ.qh ?? currentQ.qe) : currentQ.qe;
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          // ⏱️ CBT TIMER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(6)),
            child: Text(
              _formatTime(_totalTimeSeconds),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _isHindi = !_isHindi),
            child: Text(_isHindi ? "EN 🇬🇧" : "HI 🇮🇳", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            onPressed: _openPaletteDrawer,
          )
        ],
      ),
      body: Column(
        children: [
          // TOP TAG STRIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("QUESTION ${_currentIndex + 1} OF ${widget.questions.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                IconButton(
                  icon: Icon(
                    _markedForReview.contains(_currentIndex) ? Icons.bookmark : Icons.bookmark_border,
                    color: _markedForReview.contains(_currentIndex) ? const Color(0xFF8E44AD) : Colors.grey,
                  ),
                  onPressed: _toggleReview,
                )
              ],
            ),
          ),
          const Divider(height: 1),

          // QUESTION CONTENT AREA
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LatexText("Q${_currentIndex + 1}. $qText", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4)),
                  const SizedBox(height: 12),

                  if (statements != null && statements.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: statements.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: LatexText(s, style: const TextStyle(fontSize: 13)))).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // OPTIONS LIST
                  ...List.generate(currentQ.options.length, (optIdx) {
                    final isSelected = _userAnswers[_currentIndex] == optIdx;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _selectOption(optIdx),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            border: Border.all(color: isSelected ? const Color(0xFF2575FC) : const Color(0xFFE2E8F0), width: isSelected ? 2 : 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isSelected ? const Color(0xFF2575FC) : Colors.grey.shade200,
                                child: Text(
                                  String.fromCharCode(65 + optIdx),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: LatexText(currentQ.options[optIdx], style: TextStyle(fontSize: 13.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // BOTTOM CONTROL BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                  child: const Text("← PREV"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ED573), foregroundColor: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Submit Mock Test?"),
                        content: Text("Attempted: ${_userAnswers.length} / ${widget.questions.length}"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _submitExam();
                            },
                            child: const Text("Submit 🚀"),
                          )
                        ],
                      ),
                    );
                  },
                  child: const Text("SUBMIT TEST"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2575FC), foregroundColor: Colors.white),
                  onPressed: () {
                    if (_currentIndex < widget.questions.length - 1) {
                      setState(() => _currentIndex++);
                    } else {
                      _submitExam();
                    }
                  },
                  child: Text(_currentIndex < widget.questions.length - 1 ? "SAVE & NEXT →" : "FINISH"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📱 PALETTE DRAWER (TCS 1 to N GRID)
  void _openPaletteDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("QUESTION PALETTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.questions.length,
                itemBuilder: (context, index) {
                  final isAnswered = _userAnswers.containsKey(index);
                  final isReview = _markedForReview.contains(index);
                  final isCurrent = _currentIndex == index;

                  Color btnColor = Colors.white;
                  Color textColor = Colors.black87;

                  if (isReview) {
                    btnColor = const Color(0xFF8E44AD);
                    textColor = Colors.white;
                  } else if (isAnswered) {
                    btnColor = const Color(0xFF2ED573);
                    textColor = Colors.white;
                  } else if (isCurrent) {
                    btnColor = const Color(0xFFEFF6FF);
                    textColor = const Color(0xFF2575FC);
                  }

                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _currentIndex = index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: btnColor,
                        border: Border.all(color: isCurrent ? const Color(0xFF2575FC) : const Color(0xFFE2E8F0), width: isCurrent ? 2 : 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text("${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  // 📊 RESULT REPORT & ANALYSIS SCREEN (CALCULATOR MATCHING YOUR WEBSITE)
  Widget _buildResultReportScreen() {
    int total = widget.questions.length;
    int correct = 0;
    int wrong = 0;

    _userAnswers.forEach((qIdx, userAns) {
      if (userAns == widget.questions[qIdx].answerIndex) {
        correct++;
      } else {
        wrong++;
      }
    });

    int attempted = _userAnswers.length;
    int skipped = total - attempted;

    double score = 0.0;
    double cutoffTarget = 22.00;
    String examName = "SSC / Central Exams";

    if (widget.subFolder.contains('bssc')) {
      score = (correct * 4) - (wrong * 1.0);
      cutoffTarget = 88.00;
      examName = "BSSC Graduate Level";
    } else if (widget.subFolder.contains('bpsc')) {
      score = (correct * 1.0) - (wrong * 0.33);
      cutoffTarget = 21.00;
      examName = "BPSC Prelims";
    } else {
      score = (correct * 1.0) - (wrong * 0.25);
      cutoffTarget = 22.00;
    }

    bool isCleared = score >= cutoffTarget;

    return Scaffold(
      appBar: AppBar(title: const Text("Performance Summary")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(isCleared ? "CUTOFF CLEARED!" : "FAILED TO CLEAR CUTOFF", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCleared ? Colors.green : Colors.red)),
            const SizedBox(height: 16),

            // SCORE CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _scoreRow("Total Questions", "$total"),
                    _scoreRow("Attempted", "$attempted"),
                    _scoreRow("Correct Answers", "$correct", color: Colors.green),
                    _scoreRow("Wrong Answers", "$wrong", color: Colors.red),
                    _scoreRow("Skipped", "$skipped"),
                    const Divider(),
                    _scoreRow("Exam Cutoff", "$cutoffTarget Marks ($examName)"),
                    _scoreRow("Your Final Score", score.toStringAsFixed(2), color: const Color(0xFF2575FC), isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // DETAILED REVIEW SOLUTIONS
            const Align(alignment: Alignment.centerLeft, child: Text("Detailed Review & Explanations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),

            ...List.generate(widget.questions.length, (i) {
              final q = widget.questions[i];
              final userAns = _userAnswers[i];
              final isCorrect = userAns == q.answerIndex;
              final timeSpent = _questionTimers[i] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Q${i + 1}. ${q.qe}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text("Your Answer: ${userAns != null ? q.options[userAns] : 'Skipped'}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Correct Answer: ${q.options[q.answerIndex]}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("⏱️ Time Spent: ${timeSpent}s", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: LatexText("Explanation: ${q.explanation.isNotEmpty ? q.explanation : 'N/A'}", style: const TextStyle(fontSize: 12)),
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _scoreRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
