import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question_model.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';

class RevisionPracticeScreen extends StatefulWidget {
  final String testTitle;
  final List<Question> questions;
  final int initialIndex;
  final String? storageKey;

  const RevisionPracticeScreen({
    super.key,
    required this.testTitle,
    required this.questions,
    this.initialIndex = 0,
    this.storageKey,
  });

  @override
  State<RevisionPracticeScreen> createState() => _RevisionPracticeScreenState();
}

class _RevisionPracticeScreenState extends State<RevisionPracticeScreen> {
  late int _currentIndex;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  bool _isHindi = false;
  bool _isBookmarked = false;

  Timer? _timer;
  int _timeLeft = 30; // ⏱️ 30 Seconds Timer

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startTimer();
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 💾 SAVE PROGRESS TO DISK
  void _saveCurrentProgress(int index) async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (index >= widget.questions.length - 1) {
      await prefs.remove(widget.storageKey!); // Chapter complete -> Reset
    } else {
      await prefs.setInt(widget.storageKey!, index);
    }
  }

  // 🔄 1-CLICK CLEAN RESTART CHAPTER TO Q.1
  void _restartChapter() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text('🔄 ', style: TextStyle(fontSize: 18)),
            Text('Restart Chapter?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Kya aap is chapter ko wapas Question 1 se shuru karna chahte hain?',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              
              if (widget.storageKey != null) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(widget.storageKey!);
              }

              setState(() {
                _currentIndex = 0;
                _selectedOptionIndex = null;
                _isAnswered = false;
              });
              
              _startTimer();
              _checkBookmarkStatus();
            },
            child: const Text('Restart (Q.1) 🚀'),
          ),
        ],
      ),
    );
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
      _timeLeft = 30;
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

  void _goToNextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
      _checkBookmarkStatus();
      _saveCurrentProgress(_currentIndex);
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
      _saveCurrentProgress(_currentIndex);
    }
  }

  void _showCompletionDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '🎉 Revision Complete!',
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Aapne "${widget.testTitle}" ke saare ${widget.questions.length} questions revise kar liye hain.',
          style: TextStyle(color: isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
        ),
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

  // 🛡️ Helper method to identify option/statement points
  bool _isOptionPoint(String line) {
    String clean = line.trim().toLowerCase();
    return clean.startsWith('• option') ||
        clean.startsWith('- option') ||
        clean.startsWith('option a') ||
        clean.startsWith('option b') ||
        clean.startsWith('option c') ||
        clean.startsWith('option d') ||
        clean.startsWith('option 0') ||
        clean.startsWith('option 1') ||
        clean.startsWith('option 2') ||
        clean.startsWith('option 3') ||
        clean.startsWith('• 1.') ||
        clean.startsWith('• 2.') ||
        clean.startsWith('• 3.') ||
        clean.startsWith('• 4.');
  }

// 🛡️ UNIVERSAL AUTO-CLEANING EXPLANATION PARSER (Zero Manual JSON Editing Needed)
  Widget _buildEnhancedExplanation(String rawExplanation, Question currentQ, bool isDark) {
    // 1️⃣ Live Global Sanitization (Fixes Option 0, Part A/B labels, Escaped Slashing)
    String cleaned = rawExplanation
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\text', r'\text')
        .replaceAll(r'\\frac', r'\frac')
        .replaceAll(RegExp(r'Part\s+[A-Z]\s*:\s*', caseSensitive: false), '') // Cleans Part A/B
        .replaceAll(RegExp(r'\bOption\s+0\b', caseSensitive: false), 'Option A')
        .replaceAll(RegExp(r'\bOption\s+1\b', caseSensitive: false), 'Option B')
        .replaceAll(RegExp(r'\bOption\s+2\b', caseSensitive: false), 'Option C')
        .replaceAll(RegExp(r'\bOption\s+3\b', caseSensitive: false), 'Option D')
        .replaceAll(RegExp(r'•\s*Option\s+0', caseSensitive: false), '• Option A')
        .replaceAll(RegExp(r'•\s*Option\s+1', caseSensitive: false), '• Option B')
        .replaceAll(RegExp(r'•\s*Option\s+2', caseSensitive: false), '• Option C')
        .replaceAll(RegExp(r'•\s*Option\s+3', caseSensitive: false), '• Option D')
        .replaceAll(RegExp(r'^\s*1\.\s*Option\s+A', multiLine: true, caseSensitive: false), '• Option A')
        .replaceAll(RegExp(r'^\s*2\.\s*Option\s+B', multiLine: true, caseSensitive: false), '• Option B')
        .replaceAll(RegExp(r'^\s*3\.\s*Option\s+C', multiLine: true, caseSensitive: false), '• Option C')
        .replaceAll(RegExp(r'^\s*4\.\s*Option\s+D', multiLine: true, caseSensitive: false), '• Option D');

    // 2️⃣ Multi-Delimiter Smart Splitter
    List<String> rawLines = cleaned
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    List<String> distinctPoints = [];
    for (String line in rawLines) {
      if (line.contains('•') && line.indexOf('•') != line.lastIndexOf('•')) {
        List<String> subParts = line
            .split(RegExp(r'(?=•)'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        distinctPoints.addAll(subParts);
      } else {
        distinctPoints.add(line);
      }
    }

    // Fallback: Single paragraph split by options or statements
    if (distinctPoints.length <= 1) {
      distinctPoints = cleaned
          .split(RegExp(r'(?=•|\bOption\s+[A-D]|\bStatement\s+\d+|\([A-D0-9]\)|📌)'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // 3️⃣ Question Type Detection
    bool isStatementQuestion = (currentQ.sh != null && currentQ.sh!.isNotEmpty) ||
        (currentQ.se != null && currentQ.se!.isNotEmpty) ||
        cleaned.contains('Statement 1') ||
        cleaned.contains('Statement 2');

    List<String> correctPoints = [];
    List<String> otherOptionPoints = [];
    List<String> generalPoints = [];

    for (String point in distinctPoints) {
      final String lower = point.toLowerCase();

      bool isCorrectOption = (lower.contains('is correct') ||
              lower.contains('bilkul sahi') ||
              lower.contains('correct hai') ||
              lower.contains('sahi hai')) &&
          _isOptionPoint(point);

      bool isIncorrectOption = (lower.contains('incorrect') ||
              lower.contains('galat') ||
              lower.contains('false') ||
              lower.contains('sasta hai') ||
              lower.contains('trap assign')) &&
          _isOptionPoint(point);

      if (!isStatementQuestion && isCorrectOption) {
        correctPoints.add(point);
      } else if (!isStatementQuestion && isIncorrectOption) {
        otherOptionPoints.add(point);
      } else {
        generalPoints.add(point);
      }
    }

    // Agar koi specific point match na ho to first point ko core solution maanein
    if (correctPoints.isEmpty && otherOptionPoints.isNotEmpty && !isStatementQuestion) {
      correctPoints.add(otherOptionPoints.removeAt(0));
    }

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('💡', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text(
                  _isHindi ? 'व्याख्या एवं विश्लेषण' : 'Detailed Solution',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟢 1. Core Correct Logic Box
                if (correctPoints.isNotEmpty) ...[
                  ...correctPoints.map((point) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: MathFormattedText(
                                text: point,
                                textStyle: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF14532D),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],

                // 📄 2. General / Statement Breakdown
                ...generalPoints.map((point) {
                  bool isStatement = point.toLowerCase().contains('statement');
                  bool isStatementCorrect = isStatement &&
                      (point.toLowerCase().contains('correct hai') ||
                          point.toLowerCase().contains('sahi hai') ||
                          point.contains('सही है'));
                  bool isStatementIncorrect = isStatement &&
                      (point.toLowerCase().contains('incorrect') ||
                          point.toLowerCase().contains('galat') ||
                          point.contains('गलत'));

                  if (isStatement && (isStatementCorrect || isStatementIncorrect)) {
                    Color borderC = isStatementCorrect
                        ? (isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0))
                        : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECDD3));
                    Color bgC = isStatementCorrect
                        ? (isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4))
                        : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2));
                    Color textC = isStatementCorrect
                        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF14532D))
                        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B));
                    IconData iconD = isStatementCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
                    Color iconC = isStatementCorrect ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgC,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderC),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(iconD, size: 16, color: iconC),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MathFormattedText(
                              text: point,
                              textStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: textC,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: MathFormattedText(
                      text: point,
                      textStyle: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        height: 1.45,
                      ),
                    ),
                  );
                }),

                // 🔽 3. Traps / Other Options Accordion
                if (otherOptionPoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(Icons.alt_route_rounded, size: 18, color: Color(0xFF2563EB)),
                        title: Text(
                          _isHindi ? 'बाकी विकल्प गलत क्यों हैं? (Option Traps)' : 'Why other options are incorrect?',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: otherOptionPoints.map((item) {
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: MathFormattedText(
                                          text: item,
                                          textStyle: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Telegram Trick Submission Box
                RevisionTrickSubmitBox(
                  testTitle: widget.testTitle,
                  qIndex: _currentIndex,
                  questionSnippet: currentQ.getText(_isHindi),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;
    final Color stmtBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color stmtBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color dividerColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;

    final currentQ = widget.questions[_currentIndex];
    final List<String>? statements = _isHindi ? currentQ.sh : currentQ.se;
    final List<String> currentOptions = currentQ.getOptions(_isHindi);
    final String currentExplanation = currentQ.getExplanation(_isHindi);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.testTitle, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor)),
            Text(
              "Question ${_currentIndex + 1} / ${widget.questions.length}",
              style: TextStyle(fontSize: 10.5, color: subTextColor),
            ),
          ],
        ),
        backgroundColor: cardBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: "Restart from Q.1",
            color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
            onPressed: _restartChapter,
          ),
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
              color: _isBookmarked ? const Color(0xFF2563EB) : (isDark ? Colors.grey.shade400 : Colors.grey),
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
              color: _timeLeft <= 5 
                  ? (isDark ? const Color(0xFF7F1D1D) : Colors.red.shade100)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: subTextColor, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ REVISION MODE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                minHeight: 5,
                backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),

            // 🎯 1. MAIN QUESTION CARD
            Card(
              elevation: 1,
              color: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MathFormattedText(
                  text: currentQ.getText(_isHindi),
                  textStyle: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: textColor,
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
                    margin: const EdgeInsets.only(bottom: 9.0),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: stmtBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: stmtBorder, width: 1.1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: MathFormattedText(
                            text: stmtText,
                            textStyle: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // 🌟 VISUAL DIVIDER & SEPARATION
              Container(
                margin: const EdgeInsets.only(top: 14, bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: dividerColor, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _isHindi ? 'विकल्प चुनें' : 'SELECT OPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subTextColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: dividerColor, thickness: 1)),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
            ],

            // 🔘 3. BILINGUAL OPTIONS LIST
            ...List.generate(currentOptions.length, (index) {
              final optionText = currentOptions[index];
              final isCorrect = index == currentQ.answerIndex;
              final isSelected = index == _selectedOptionIndex;

              Color optBorderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
              Color optBgColor = cardBg;
              Widget icon = const SizedBox.shrink();

              if (_isAnswered) {
                if (isCorrect) {
                  optBorderColor = Colors.green;
                  optBgColor = isDark ? const Color(0xFF052E16) : Colors.green.shade50;
                  icon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
                } else if (isSelected) {
                  optBorderColor = Colors.red;
                  optBgColor = isDark ? const Color(0xFF450A0A) : Colors.red.shade50;
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
                      color: optBgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: optBorderColor, width: _isAnswered && (isCorrect || isSelected) ? 2 : 1),
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
                                : (_isAnswered && isSelected 
                                    ? Colors.red 
                                    : (isDark ? const Color(0xFF334155) : Colors.grey.shade100)),
                          ),
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _isAnswered && (isCorrect || isSelected) 
                                  ? Colors.white 
                                  : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MathFormattedText(
                            text: optionText,
                            textStyle: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        icon,
                      ],
                    ),
                  ),
                ),
              );
            }),

            // 💡 4. DETAILED SOLUTION (2-STAGE COLLAPSIBLE ACCORDION)
            if (_isAnswered) ...[
              _buildEnhancedExplanation(currentExplanation, currentQ, isDark),
            ],
            const SizedBox(height: 70),
          ],
        ),
      ),

      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 5)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                foregroundColor: isDark ? Colors.white : Colors.black87,
              ),
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

// 💡 COMMUNITY TRICK / DATA SUBMISSION WIDGET (Direct to Telegram)
class RevisionTrickSubmitBox extends StatefulWidget {
  final String testTitle;
  final int qIndex;
  final String questionSnippet;

  const RevisionTrickSubmitBox({
    super.key,
    required this.testTitle,
    required this.qIndex,
    required this.questionSnippet,
  });

  @override
  State<RevisionTrickSubmitBox> createState() => _RevisionTrickSubmitBoxState();
}

class _RevisionTrickSubmitBoxState extends State<RevisionTrickSubmitBox> {
  final TextEditingController _trickController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isOpen = false;

  static const String _botToken = "1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo";
  static const String _chatId = "785009742";

  Future<void> _submitTrickToTelegram() async {
    final String trickText = _trickController.text.trim();
    if (trickText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please write your trick or data first!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final String cleanSnippet = widget.questionSnippet.length > 70
        ? "${widget.questionSnippet.substring(0, 70)}..."
        : widget.questionSnippet;

    final String telegramMsg = """
💡 *NEW TRICK / DATA SUBMITTED!*
━━━━━━━━━━━━━━━━━━━━━
📁 *Chapter:* ${widget.testTitle}
❓ *Q#: * Q${widget.qIndex + 1}
📝 *Snippet:* $cleanSnippet
━━━━━━━━━━━━━━━━━━━━━
✨ *User Trick/Logic:*
$trickText
""";

    try {
      final res = await http.post(
        Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": _chatId,
          "text": telegramMsg,
          "parse_mode": "Markdown",
        }),
      );

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });
      } else {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSubmitted) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '✅ Thank you! Trick/Data Telegram par bhej diya gaya hai.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isOpen = !_isOpen),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 13)),
                    Text(
                      'Got a short-trick or better logic?',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                Text(
                  _isOpen ? 'Close ▲' : 'Share ➔',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (_isOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _trickController,
              maxLines: 2,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Apni trick, mnemonic code ya logic yahan likhein...',
                hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 28,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF24A1DE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _isSubmitting ? null : _submitTrickToTelegram,
                  icon: _isSubmitting
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 12),
                  label: Text(
                    _isSubmitting ? 'Sending...' : 'Send to Telegram',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
