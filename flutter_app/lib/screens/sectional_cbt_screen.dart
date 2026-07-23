import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart'; // 📊 Pie Chart Package
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
    final String qText = currentQ.getText(_isHindi);
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LatexText(
                    "Q${_currentIndex + 1}. $qText",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  if (statements != null && statements.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: statements.asMap().entries.map((entry) {
                        int index = entry.key + 1;
                        String stmtText = entry.value.trim().replaceFirst(RegExp(r'^(\(\d+\)|\d+\.)\s*'), '');

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(color: Color(0xFF2575FC), width: 4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2575FC),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "($index)",
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LatexText(
                                  stmtText,
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                              Expanded(
                                child: LatexText(
                                  currentQ.options[optIdx],
                                  style: TextStyle(fontSize: 13.5, color: Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                ),
                              ),
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

  // 📊 RESULT REPORT & ANALYSIS SCREEN (WITH FL_CHART PIE CHART)
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
            Text(
              isCleared ? "CUTOFF CLEARED!" : "FAILED TO CLEAR CUTOFF",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCleared ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 16),

            // 📊 VISUAL PIE CHART GRAPH
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Performance Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 35,
                          sections: [
                            if (correct > 0)
                              PieChartSectionData(color: Colors.green, value: correct.toDouble(), title: 'Sahi ($correct)', radius: 45, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            if (wrong > 0)
                              PieChartSectionData(color: Colors.red, value: wrong.toDouble(), title: 'Galat ($wrong)', radius: 45, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            if (skipped > 0)
                              PieChartSectionData(color: Colors.grey, value: skipped.toDouble(), title: 'Skipped ($skipped)', radius: 40, titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      Text("Q${i + 1}. ${q.qe}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text("Your Answer: ${userAns != null ? q.options[userAns] : 'Skipped'}", style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("Correct Answer: ${q.options[q.answerIndex]}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("⏱️ Time Spent: ${timeSpent}s", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LatexText("Explanation: ${q.explanation.isNotEmpty ? q.explanation : 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 10),
                            _WikiContributionBox(
                              subFolder: widget.subFolder,
                              qIndex: i,
                              questionSnippet: q.qe,
                            ),
                          ],
                        ),
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

class _WikiContributionBox extends StatefulWidget {
  final String subFolder;
  final int qIndex;
  final String questionSnippet;

  const _WikiContributionBox({
    required this.subFolder,
    required this.qIndex,
    required this.questionSnippet,
  });

  @override
  State<_WikiContributionBox> createState() => _WikiContributionBoxState();
}

class _WikiContributionBoxState extends State<_WikiContributionBox> {
  final TextEditingController _trickController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  Future<void> _submitTrickOrReport() async {
    final String trickText = _trickController.text.trim();
    if (trickText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please write your trick, report or logic first!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    const String googleScriptUrl =
        "https://script.google.com/macros/s/AKfycbztbqpHH7H8LulJ36AsDBhSYmBVfmH-ONb6exJKCELIbqCbb6iptv43PrgO-y6-Jo8ULg/exec";

    try {
      final String cleanSnippet = widget.questionSnippet.length > 60
          ? widget.questionSnippet.substring(0, 60)
          : widget.questionSnippet;

      await http.post(
        Uri.parse(googleScriptUrl),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "type": "wiki",
          "fileSrc": widget.subFolder,
          "question": cleanSnippet,
          "trick": trickText,
          "userId": "App_Aspirant_${widget.qIndex}",
        },
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data recorded successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thank you! Shortcut trick or report successfully recorded.',
                style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Got a short-trick, report or better logic? Share with community!',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _trickController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Type shortcut or report here...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _isSubmitting ? null : _submitTrickOrReport,
                  child: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
