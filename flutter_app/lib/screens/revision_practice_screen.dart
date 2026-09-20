import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question_model.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';
import '../widgets/revision_explanation_card.dart';

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
  static const int _questionTime = 90;
  int _timeLeft = _questionTime;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.questions.isEmpty ? 0 : widget.questions.length - 1,
    );
    _startTimer();
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveCurrentProgress(int index) async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (index >= widget.questions.length - 1) {
      await prefs.remove(widget.storageKey!);
    } else {
      await prefs.setInt(widget.storageKey!, index);
    }
  }

  void _restartChapter() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF172033) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.restart_alt_rounded, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Restart Chapter?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Kya aap is chapter ko Question 1 se dobara shuru karna chahte hain?',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (widget.storageKey != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(widget.storageKey!);
                }
                if (!mounted) return;
                setState(() {
                  _currentIndex = 0;
                  _selectedOptionIndex = null;
                  _isAnswered = false;
                });
                _startTimer();
                _checkBookmarkStatus();
              },
              child: const Text('Restart Q.1', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkBookmarkStatus() async {
    if (widget.questions.isEmpty) return;
    final savedList = await UserStatsService.getSavedQuestions();
    final currentQ = widget.questions[_currentIndex];
    final currentText = currentQ.getText(_isHindi);

    final exists = savedList.any((item) {
      final qText = item['qe'] ?? item['qh'] ?? item['question'] ?? '';
      return qText == currentText || qText == currentQ.question;
    });

    if (mounted) setState(() => _isBookmarked = exists);
  }

  Future<void> _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];
    final qJson = currentQ.toJson();
    final saved = await UserStatsService.toggleBookmark(qJson);

    if (!mounted) return;
    setState(() => _isBookmarked = saved);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(saved ? '📌 Question saved to bookmarks' : '🗑️ Removed from bookmarks'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted) return;

    setState(() {
      _timeLeft = _questionTime;
      _isAnswered = false;
      _selectedOptionIndex = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        setState(() => _isAnswered = true);
        final currentQ = widget.questions[_currentIndex];

        // ⏱️ Timeout attempt logged with full question details
       final String qTextClean = (currentQ.qe != null && currentQ.qe!.isNotEmpty)
    ? currentQ.qe!
    : ((currentQ.qh != null && currentQ.qh!.isNotEmpty) ? currentQ.qh! : currentQ.getText(_isHindi));

        UserStatsService.recordQuestionAttempt(
          isCorrect: false,
          chapterName: widget.testTitle,
          chapterPath: widget.storageKey ?? '',
          questionText: qTextClean,
          timeTakenSeconds: _questionTime,
          testType: 'revision',
          wrongQuestionJson: currentQ.toJson(),
        );
      }
    });
  }

  void _onOptionTap(int index) {
    if (_isAnswered) return;
    _timer?.cancel();

    final currentQ = widget.questions[_currentIndex];
    final isCorrect = index == currentQ.answerIndex;
    final int timeSpent = (_questionTime - _timeLeft).clamp(1, _questionTime);

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
    });

    final String qTextClean = (currentQ.qe != null && currentQ.qe!.isNotEmpty)
    ? currentQ.qe!
    : ((currentQ.qh != null && currentQ.qh!.isNotEmpty) ? currentQ.qh! : currentQ.getText(_isHindi));

    final currentOptions = currentQ.getOptions(_isHindi);
    final String selectedOpt = (index >= 0 && index < currentOptions.length) ? currentOptions[index] : '';

    // 🚀 HOOK CONNECTED: Correct & Wrong both logged to Supabase and Local Vault
    UserStatsService.recordQuestionAttempt(
      isCorrect: isCorrect,
      chapterName: widget.testTitle,
      chapterPath: widget.storageKey ?? '',
      questionText: qTextClean,
      timeTakenSeconds: timeSpent,
      testType: 'revision',
      wrongQuestionJson: isCorrect ? null : currentQ.toJson(),
      userSelectedOption: selectedOpt,
    );
  }

  void _goToNextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() => _currentIndex++);
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
      setState(() => _currentIndex--);
      _startTimer();
      _checkBookmarkStatus();
      _saveCurrentProgress(_currentIndex);
    }
  }

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF172033) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '🎉 Revision Complete!',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Aapne "${widget.testTitle}" ke saare ${widget.questions.length} questions revise kar liye hain.',
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done & Go Back', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimer(bool isDark) {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    final formatted = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final danger = _timeLeft <= 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: danger
            ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF172033) : const Color(0xFFEFF6FF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: danger ? Colors.red.shade400 : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            danger ? Icons.timer_rounded : Icons.timer_outlined,
            size: 16,
            color: danger ? Colors.red.shade500 : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 5),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: danger ? Colors.red.shade500 : const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAction({required Widget child, required VoidCallback onTap, required String tooltip}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      icon: child,
    );
  }

  Widget _buildOptionCard({
    required int index,
    required String optionText,
    required Question currentQ,
    required bool isDark,
  }) {
    final isCorrect = index == currentQ.answerIndex;
    final isSelected = index == _selectedOptionIndex;

    Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color backgroundColor = isDark ? const Color(0xFF172033) : Colors.white;
    Color letterBackground = isDark ? const Color(0xFF29364D) : const Color(0xFFF1F5F9);
    Color letterColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    Widget trailing = const SizedBox.shrink();

    if (_isAnswered) {
      if (isCorrect) {
        borderColor = const Color(0xFF22C55E);
        backgroundColor = isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);
        letterBackground = const Color(0xFF22C55E);
        letterColor = Colors.white;
        trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 21);
      } else if (isSelected) {
        borderColor = const Color(0xFFEF4444);
        backgroundColor = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
        letterBackground = const Color(0xFFEF4444);
        letterColor = Colors.white;
        trailing = const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 21);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onOptionTap(index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: _isAnswered && (isCorrect || isSelected) ? 1.7 : 1,
              ),
              boxShadow: [
                if (!_isAnswered)
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.08 : 0.025),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: letterBackground, shape: BoxShape.circle),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: letterColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MathFormattedText(
                    text: optionText,
                    textStyle: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.questions.length - 1;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF172033).withOpacity(0.98) : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: isFirst ? null : _goToPreviousQuestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                    side: BorderSide(
                      color: isFirst
                          ? (isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0))
                          : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    disabledBackgroundColor: isDark ? const Color(0xFF131B2B) : const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Previous', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _goToNextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: Text(
                    isLast ? 'Finish' : 'Next',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  icon: Icon(isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('No questions available.')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFFF6F8FC);
    final cardBg = isDark ? const Color(0xFF172033) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final stmtBg = isDark ? const Color(0xFF141D2E) : const Color(0xFFF8FAFC);
    final stmtBorder = isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0);

    final currentQ = widget.questions[_currentIndex];
    final statements = _isHindi ? currentQ.sh : currentQ.se;
    final currentOptions = currentQ.getOptions(_isHindi);
    final currentExplanation = currentQ.getExplanation(_isHindi);
    final progress = (_currentIndex + 1) / widget.questions.length;
    final progressPercent = (progress * 100).round();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: textColor),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.testTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  'Revision Practice',
                  style: TextStyle(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 5),
                Container(width: 3, height: 3, decoration: BoxDecoration(color: subTextColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  'Q${_currentIndex + 1}/${widget.questions.length}',
                  style: TextStyle(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildTopAction(
            tooltip: 'Restart from Q.1',
            onTap: _restartChapter,
            child: Icon(Icons.restart_alt_rounded, size: 21, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
          _buildTopAction(
            tooltip: 'Bookmark Question',
            onTap: _toggleBookmarkQuestion,
            child: Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 22,
              color: _isBookmarked ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 1, right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () {
                setState(() => _isHindi = !_isHindi);
                _checkBookmarkStatus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  _isHindi ? 'हि' : 'EN',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildTimer(isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      const SizedBox(height: 3),
                      Text('Keep going — you are doing great!', style: TextStyle(fontSize: 10.5, color: subTextColor)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0),
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0)),
              ),
              child: MathFormattedText(
                text: currentQ.getText(_isHindi),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.48, color: textColor),
              ),
            ),
            const SizedBox(height: 12),
            if (statements != null && statements.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: statements.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final stmtText = entry.value.trim().replaceFirst(RegExp(r'^([\(\[]?\d+[\)\]\.]?|•|-)\s*'), '');

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                    decoration: BoxDecoration(
                      color: stmtBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stmtBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 29,
                          height: 25,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: MathFormattedText(
                            text: stmtText,
                            textStyle: TextStyle(
                              fontSize: 13.5,
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
              const SizedBox(height: 5),
            ] else
              const SizedBox(height: 7),
            ...List.generate(
              currentOptions.length,
              (index) => _buildOptionCard(
                index: index,
                optionText: currentOptions[index],
                currentQ: currentQ,
                isDark: isDark,
              ),
            ),
            if (_isAnswered)
              RevisionExplanationCard(
                rawExplanation: currentExplanation,
                currentQ: currentQ,
                isHindi: _isHindi,
                isDark: isDark,
                testTitle: widget.testTitle,
                currentIndex: _currentIndex,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }
}
