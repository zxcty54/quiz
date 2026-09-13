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
  State<RevisionPracticeScreen> createState() =>
      _RevisionPracticeScreenState();
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

  // ---------------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------------

  Future<void> _saveCurrentProgress(int index) async {
    if (widget.storageKey == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (index >= widget.questions.length - 1) {
      await prefs.remove(widget.storageKey!);
    } else {
      await prefs.setInt(widget.storageKey!, index);
    }
  }

  // ---------------------------------------------------------------------------
  // RESTART
  // ---------------------------------------------------------------------------

  void _restartChapter() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF172033) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: Color(0xFF2563EB),
                ),
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
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF475569),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              child: const Text(
                'Restart Q.1',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKMARK
  // ---------------------------------------------------------------------------

  Future<void> _checkBookmarkStatus() async {
    if (widget.questions.isEmpty) return;

    final savedList = await UserStatsService.getSavedQuestions();

    final currentQ = widget.questions[_currentIndex];

    final currentText = currentQ.getText(_isHindi);

    final exists = savedList.any((item) {
      final qText =
          item['qe'] ?? item['qh'] ?? item['question'] ?? '';

      return qText == currentText || qText == currentQ.question;
    });

    if (mounted) {
      setState(() {
        _isBookmarked = exists;
      });
    }
  }

  Future<void> _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];

    final qJson = currentQ.toJson();

    final saved = await UserStatsService.toggleBookmark(qJson);

    if (!mounted) return;

    setState(() {
      _isBookmarked = saved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          saved
              ? '📌 Question saved to bookmarks'
              : '🗑️ Removed from bookmarks',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();

    if (!mounted) return;

    setState(() {
      _timeLeft = _questionTime;
      _isAnswered = false;
      _selectedOptionIndex = null;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_timeLeft > 0) {
          setState(() {
            _timeLeft--;
          });
        } else {
          timer.cancel();

          setState(() {
            _isAnswered = true;
          });

          final currentQ = widget.questions[_currentIndex];

          UserStatsService.recordQuestionAttempt(
            isCorrect: false,
            chapterName: widget.testTitle,
            chapterPath: '',
            wrongQuestionJson: currentQ.toJson(),
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ANSWER
  // ---------------------------------------------------------------------------

  void _onOptionTap(int index) {
    if (_isAnswered) return;

    _timer?.cancel();

    final currentQ = widget.questions[_currentIndex];

    final isCorrect = index == currentQ.answerIndex;

    setState(() {
      _selectedOptionIndex = index;
      _isAnswered = true;
    });

    UserStatsService.recordQuestionAttempt(
      isCorrect: isCorrect,
      chapterName: widget.testTitle,
      chapterPath: '',
      wrongQuestionJson: isCorrect ? null : currentQ.toJson(),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // COMPLETION
  // ---------------------------------------------------------------------------

  void _showCompletionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF172033) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '🎉 Revision Complete!',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Aapne "${widget.testTitle}" ke saare '
            '${widget.questions.length} questions revise kar liye hain.',
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF475569),
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text(
                'Done & Go Back',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ENHANCED EXPLANATION
  // ---------------------------------------------------------------------------

  Widget _buildEnhancedExplanation(
    String rawExplanation,
    Question currentQ,
    bool isDark,
  ) {
    if (rawExplanation.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    String cleaned = rawExplanation
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\text', r'\text')
        .replaceAll(r'\\frac', r'\frac')
        .replaceAll(r'\\mu', r'\mu')
        .replaceAll(r'\\lambda', r'\lambda')
        .replaceAll(r'\\nu', r'\nu')
        .replaceAll(r'\\theta', r'\theta')
        .replaceAll(r'\\rho', r'\rho')
        .replaceAll(r'\\approx', r'\approx')
        .replaceAll(r'\\rightarrow', r'\rightarrow')
        .replaceAll(r'\\%', '%')
        .replaceAll(r'\%', '%');

    final Map<String, String> chemSubscripts = {
      r'($CO_2$)': 'CO₂',
      r'$CO_2$': 'CO₂',
      r'CO_2': 'CO₂',
      r'($H_2O$)': 'H₂O',
      r'$H_2O$': 'H₂O',
      r'H_2O': 'H₂O',
      r'($CH_4$)': 'CH₄',
      r'$CH_4$': 'CH₄',
      r'CH_4': 'CH₄',
      r'($O_2$)': 'O₂',
      r'$O_2$': 'O₂',
      r'O_2': 'O₂',
      r'($O_3$)': 'O₃',
      r'$O_3$': 'O₃',
      r'O_3': 'O₃',
      r'($N_2$)': 'N₂',
      r'$N_2$': 'N₂',
      r'N_2': 'N₂',
      r'($H_2$)': 'H₂',
      r'$H_2$': 'H₂',
      r'H_2': 'H₂',
      r'($Cl_2$)': 'Cl₂',
      r'$Cl_2$': 'Cl₂',
      r'Cl_2': 'Cl₂',
      r'($NO_2$)': 'NO₂',
      r'$NO_2$': 'NO₂',
      r'NO_2': 'NO₂',
      r'($SO_2$)': 'SO₂',
      r'$SO_2$': 'SO₂',
      r'SO_2': 'SO₂',
      r'($H_2SO_4$)': 'H₂SO₄',
      r'$H_2SO_4$': 'H₂SO₄',
      r'H_2SO_4': 'H₂SO₄',
      r'($HNO_3$)': 'HNO₃',
      r'$HNO_3$': 'HNO₃',
      r'HNO_3': 'HNO₃',
      r'($CaCO_3$)': 'CaCO₃',
      r'$CaCO_3$': 'CaCO₃',
      r'CaCO_3': 'CaCO₃',
      r'($NH_3$)': 'NH₃',
      r'$NH_3$': 'NH₃',
      r'NH_3': 'NH₃',
      r'($C_6H_{12}O_6$)': 'C₆H₁₂O₆',
      r'$C_6H_{12}O_6$': 'C₆H₁₂O₆',
      r'C_6H_{12}O_6': 'C₆H₁₂O₆',
      r'($Fe_2O_3$)': 'Fe₂O₃',
      r'$Fe_2O_3$': 'Fe₂O₃',
      r'Fe_2O_3': 'Fe₂O₃',
      r'($Al_2O_3$)': 'Al₂O₃',
      r'$Al_2O_3$': 'Al₂O₃',
      r'Al_2O_3': 'Al₂O₃',
      r'($KMnO_4$)': 'KMnO₄',
      r'$KMnO_4$': 'KMnO₄',
      r'KMnO_4': 'KMnO₄',
      r'($Na_2CO_3$)': 'Na₂CO₃',
      r'$Na_2CO_3$': 'Na₂CO₃',
      r'($NaHCO_3$)': 'NaHCO₃',
      r'$NaHCO_3$': 'NaHCO₃',
      r'($Si$)': 'Si',
      r'$Si$': 'Si',
      r'($Ge$)': 'Ge',
      r'$Ge$': 'Ge',
      r'($Ga$)': 'Ga',
      r'$Ga$': 'Ga',
      r'($GaAs$)': 'GaAs',
      r'$GaAs$': 'GaAs',
    };

    chemSubscripts.forEach((key, val) {
      cleaned = cleaned.replaceAll(key, val);
    });

    final Map<String, String> physReplacements = {
      r'($\lambda$)': 'λ',
      r'$\lambda$': 'λ',
      r'\lambda': 'λ',
      r'($\mu$)': 'μ',
      r'$\mu$': 'μ',
      r'\mu': 'μ',
      r'($\nu$)': 'ν',
      r'$\nu$': 'ν',
      r'\nu': 'ν',
      r'($\theta$)': 'θ',
      r'$\theta$': 'θ',
      r'\theta': 'θ',
      r'($\alpha$)': 'α',
      r'$\alpha$': 'α',
      r'\alpha': 'α',
      r'($\beta$)': 'β',
      r'$\beta$': 'β',
      r'\beta': 'β',
      r'($\gamma$)': 'γ',
      r'$\gamma$': 'γ',
      r'\gamma': 'γ',
      r'($\rho$)': 'ρ',
      r'$\rho$': 'ρ',
      r'\rho': 'ρ',
      r'($\omega$)': 'ω',
      r'$\omega$': 'ω',
      r'\omega': 'ω',
      r'($\Omega$)': 'Ω',
      r'$\Omega$': 'Ω',
      r'\Omega': 'Ω',
      r'($\Delta$)': 'Δ',
      r'$\Delta$': 'Δ',
      r'\Delta': 'Δ',
      r'($\pi$)': 'π',
      r'$\pi$': 'π',
      r'\pi': 'π',
      r'($\phi$)': 'φ',
      r'$\phi$': 'φ',
      r'\phi': 'φ',
      r'\approx': '≈',
      r'$\approx$': '≈',
      r'\neq': '≠',
      r'$\neq$': '≠',
      r'\leq': '≤',
      r'$\leq$': '≤',
      r'\geq': '≥',
      r'$\geq$': '≥',
      r'\pm': '±',
      r'$\pm$': '±',
      r'\times': '×',
      r'$\times$': '×',
      r'\rightarrow': '→',
      r'$\rightarrow$': '→',
      r'\leftarrow': '←',
      r'$\leftarrow$': '←',
      r'\infty': '∞',
      r'$\infty$': '∞',
      r'\propto': '∝',
      r'$\propto$': '∝',
    };

    physReplacements.forEach((key, val) {
      cleaned = cleaned.replaceAll(key, val);
    });

    cleaned = cleaned
        .replaceAll(r'^\circ\text{C}', '°C')
        .replaceAll(r'^\circ\text{ C}', '°C')
        .replaceAll(r'^\circ C', '°C')
        .replaceAll(r'^\circ\text{F}', '°F')
        .replaceAll(r'^\circ\text{ F}', '°F')
        .replaceAll(r'^\circ F', '°F')
        .replaceAll(r'^\circ', '°')
        .replaceAll(r'\circ', '°')
        .replaceAllMapped(
          RegExp(
            r'\$\s*([0-9.]+)\s*\\text\{\s*to\s*\}\s*([0-9.]+)\s*\\text\{\s*([A-Za-z]+)\s*\}\s*\$',
          ),
          (m) =>
              '${m.group(1)} ${m.group(3)} to ${m.group(2)} ${m.group(3)}',
        )
        .replaceAllMapped(
          RegExp(r'\\text\{\s*([^}]+)\s*\}'),
          (m) => m.group(1) ?? '',
        )
        .replaceAll(r'$10^{-3}$', '10⁻³')
        .replaceAll(r'$10^{-6}$', '10⁻⁶')
        .replaceAll(r'$10^3$', '10³')
        .replaceAll(r'$10^5$', '10⁵')
        .replaceAll(r'$10^8$', '10⁸')
        .replaceAll(r'm/s^2', 'm/s²')
        .replaceAll(r'm/s^1', 'm/s')
        .replaceAll(r'cm^3', 'cm³')
        .replaceAll(r'm^3', 'm³')
        .replaceAll(r'cm^2', 'cm²')
        .replaceAll(r'm^2', 'm²')
        .replaceAll(r'$$', '')
        .trim();

    final rawLines = cleaned
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final List<String> distinctBlocks = [];

    String currentBlock = '';

    for (final line in rawLines) {
      final isNewBlockHeader =
          line.startsWith('•') ||
          line.startsWith('-') ||
          line.toLowerCase().startsWith('option') ||
          line.toLowerCase().startsWith('statement') ||
          line.startsWith('📌') ||
          line.toLowerCase().startsWith('key takeaway') ||
          line.toLowerCase().startsWith('conclusion') ||
          RegExp(r'^\d+[\.\)]').hasMatch(line);

      if (isNewBlockHeader && currentBlock.isNotEmpty) {
        distinctBlocks.add(currentBlock.trim());
        currentBlock = line;
      } else {
        if (currentBlock.isEmpty) {
          currentBlock = line;
        } else {
          currentBlock += '\n$line';
        }
      }
    }

    if (currentBlock.isNotEmpty) {
      distinctBlocks.add(currentBlock.trim());
    }

    final List<String> primaryCorrectBlocks = [];
    final List<String> trapOptionBlocks = [];
    final List<String> takeawayBlocks = [];

    for (final block in distinctBlocks) {
      final lower = block.trim().toLowerCase();
      final firstLine = lower.split('\n').first;

      final isExplicitCorrect =
          firstLine.contains('is correct') ||
          firstLine.contains('sahi hai') ||
          firstLine.contains('bilkul sahi');

      final isExplicitIncorrect =
          firstLine.contains('is incorrect') ||
          firstLine.contains('galat hai') ||
          firstLine.contains('is false') ||
          firstLine.contains('trap');

      final isTakeaway =
          firstLine.startsWith('key takeaway') ||
          firstLine.startsWith('summary') ||
          firstLine.startsWith('📌') ||
          firstLine.startsWith('exam takeaway') ||
          firstLine.startsWith('conclusion');

      if (isTakeaway) {
        takeawayBlocks.add(block);
      } else if (isExplicitIncorrect && !isExplicitCorrect) {
        trapOptionBlocks.add(block);
      } else {
        primaryCorrectBlocks.add(block);
      }
    }

    final cardBg = isDark
        ? const Color(0xFF172033)
        : Colors.white;

    final cardBorder = isDark
        ? const Color(0xFF29364D)
        : const Color(0xFFE2E8F0);

    final textColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              isDark ? 0.18 : 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF064E3B).withOpacity(0.28)
                  : const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF065F46)
                      : const Color(0xFFA7F3D0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF065F46)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    '💡',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isHindi
                      ? 'मुख्य व्याख्या'
                      : 'Detailed Solution',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFF065F46),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (primaryCorrectBlocks.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF101827)
                          : const Color(0xFFFAFFFC),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF065F46)
                            : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: primaryCorrectBlocks.map((block) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MathFormattedText(
                            text: block,
                            textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF0F172A),
                              height: 1.55,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                ...takeawayBlocks.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: MathFormattedText(
                      text: point,
                      textStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                if (trapOptionBlocks.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF101827)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: ExpansionTile(
                        dense: true,
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        leading: const Icon(
                          Icons.alt_route_rounded,
                          size: 19,
                          color: Color(0xFF2563EB),
                        ),
                        title: Text(
                          _isHindi
                              ? 'बाकी विकल्प गलत क्यों हैं?'
                              : 'Why other options are incorrect?',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              children: trapOptionBlocks.map((item) {
                                return Container(
                                  width: double.infinity,
                                  margin:
                                      const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF172033)
                                        : Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(9),
                                    border: Border.all(
                                      color: cardBorder,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding:
                                            EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.cancel_outlined,
                                          size: 15,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: MathFormattedText(
                                          text: item,
                                          textStyle: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.grey.shade300
                                                : const Color(
                                                    0xFF334155,
                                                  ),
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
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Divider(
                  height: 24,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),

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

  // ---------------------------------------------------------------------------
  // TIMER WIDGET
  // ---------------------------------------------------------------------------

  Widget _buildTimer(bool isDark) {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;

    final formatted =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    final danger = _timeLeft <= 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: danger
            ? (isDark
                ? const Color(0xFF450A0A)
                : const Color(0xFFFEF2F2))
            : (isDark
                ? const Color(0xFF172033)
                : const Color(0xFFEFF6FF)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: danger
              ? Colors.red.shade400
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            danger
                ? Icons.timer_rounded
                : Icons.timer_outlined,
            size: 16,
            color: danger
                ? Colors.red.shade500
                : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 5),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: danger
                  ? Colors.red.shade500
                  : const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP ACTION BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildTopAction({
    required Widget child,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 38,
        minHeight: 38,
      ),
      icon: child,
    );
  }

  // ---------------------------------------------------------------------------
  // OPTION CARD
  // ---------------------------------------------------------------------------

  Widget _buildOptionCard({
    required int index,
    required String optionText,
    required Question currentQ,
    required bool isDark,
  }) {
    final isCorrect = index == currentQ.answerIndex;
    final isSelected = index == _selectedOptionIndex;

    Color borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Color backgroundColor =
        isDark ? const Color(0xFF172033) : Colors.white;

    Color letterBackground =
        isDark ? const Color(0xFF29364D) : const Color(0xFFF1F5F9);

    Color letterColor =
        isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    Widget trailing = const SizedBox.shrink();

    if (_isAnswered) {
      if (isCorrect) {
        borderColor = const Color(0xFF22C55E);
        backgroundColor = isDark
            ? const Color(0xFF052E16)
            : const Color(0xFFF0FDF4);

        letterBackground = const Color(0xFF22C55E);
        letterColor = Colors.white;

        trailing = const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF22C55E),
          size: 21,
        );
      } else if (isSelected) {
        borderColor = const Color(0xFFEF4444);
        backgroundColor = isDark
            ? const Color(0xFF450A0A)
            : const Color(0xFFFEF2F2);

        letterBackground = const Color(0xFFEF4444);
        letterColor = Colors.white;

        trailing = const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFEF4444),
          size: 21,
        );
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
            constraints: const BoxConstraints(
              minHeight: 58,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: _isAnswered &&
                        (isCorrect || isSelected)
                    ? 1.7
                    : 1,
              ),
              boxShadow: [
                if (!_isAnswered)
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.08 : 0.025,
                    ),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: letterBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: letterColor,
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
                      height: 1.4,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF0F172A),
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

  // ---------------------------------------------------------------------------
  // FLOATING BOTTOM NAVIGATION
  // ---------------------------------------------------------------------------

  Widget _buildBottomNavigation(bool isDark) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.questions.length - 1;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF172033).withOpacity(0.98)
              : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? const Color(0xFF29364D)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                isDark ? 0.30 : 0.10,
              ),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            // PREVIOUS
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      isFirst ? null : _goToPreviousQuestion,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                    disabledForegroundColor: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1),
                    side: BorderSide(
                      color: isFirst
                          ? (isDark
                              ? const Color(0xFF29364D)
                              : const Color(0xFFE2E8F0))
                          : (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFCBD5E1)),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    disabledBackgroundColor: isDark
                        ? const Color(0xFF131B2B)
                        : const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Previous',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 9),

            // NEXT / FINISH
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _goToNextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: isLast
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  label: Text(
                    isLast ? 'Finish' : 'Next',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: Icon(
                    isLast
                        ? Icons.flag_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No questions available.'),
        ),
      );
    }

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF0B1120)
        : const Color(0xFFF6F8FC);

    final cardBg = isDark
        ? const Color(0xFF172033)
        : Colors.white;

    final textColor = isDark
        ? Colors.white
        : const Color(0xFF0F172A);

    final subTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final stmtBg = isDark
        ? const Color(0xFF141D2E)
        : const Color(0xFFF8FAFC);

    final stmtBorder = isDark
        ? const Color(0xFF29364D)
        : const Color(0xFFE2E8F0);

    final currentQ = widget.questions[_currentIndex];

    final statements =
        _isHindi ? currentQ.sh : currentQ.se;

    final currentOptions =
        currentQ.getOptions(_isHindi);

    final currentExplanation =
        currentQ.getExplanation(_isHindi);

    final progress =
        (_currentIndex + 1) / widget.questions.length;

    final progressPercent =
        (progress * 100).round();

    return Scaffold(
      backgroundColor: bgColor,

      // ---------------------------------------------------------------------
      // APP BAR
      // ---------------------------------------------------------------------

      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 64,
        iconTheme: IconThemeData(
          color: textColor,
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.testTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  'Revision Practice',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: subTextColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Q${_currentIndex + 1}/${widget.questions.length}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildTopAction(
            tooltip: 'Restart from Q.1',
            onTap: _restartChapter,
            child: Icon(
              Icons.restart_alt_rounded,
              size: 21,
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF475569),
            ),
          ),

          _buildTopAction(
            tooltip: 'Bookmark Question',
            onTap: _toggleBookmarkQuestion,
            child: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 22,
              color: _isBookmarked
                  ? const Color(0xFF2563EB)
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ),

          // Language
          Container(
            margin: const EdgeInsets.only(
              left: 1,
              right: 6,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () {
                setState(() {
                  _isHindi = !_isHindi;
                });

                _checkBookmarkStatus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE),
                  ),
                ),
                child: Text(
                  _isHindi ? 'हि' : 'EN',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
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

      // ---------------------------------------------------------------------
      // BODY
      // ---------------------------------------------------------------------

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 105),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Keep going — you are doing great!',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1B4B)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFA5B4FC)
                          : const Color(0xFF4F46E5),
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
                backgroundColor: isDark
                    ? const Color(0xFF29364D)
                    : const Color(0xFFE2E8F0),
                color: const Color(0xFF2563EB),
              ),
            ),

            const SizedBox(height: 17),

            // Revision badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF312E81).withOpacity(0.35)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'REVISION MODE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark
                              ? const Color(0xFFA5B4FC)
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF29364D)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.12 : 0.035,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: MathFormattedText(
                text: currentQ.getText(_isHindi),
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.48,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Statements
            if (statements != null &&
                statements.isNotEmpty) ...[
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children:
                    statements.asMap().entries.map((entry) {
                  final index = entry.key + 1;

                  final stmtText = entry.value
                      .trim()
                      .replaceFirst(
                        RegExp(
                          r'^([\(\[]?\d+[\)\]\.]?|•|-)\s*',
                        ),
                        '',
                      );

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 9,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: stmtBg,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: stmtBorder,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 29,
                          height: 25,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFF1E293B),
                            borderRadius:
                                BorderRadius.circular(7),
                          ),
                          child: Text(
                            '$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: MathFormattedText(
                            text: stmtText,
                            textStyle: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF0F172A),
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

              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: Text(
                      _isHindi
                          ? 'विकल्प चुनें'
                          : 'SELECT AN OPTION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: subTextColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 11),
            ] else
              const SizedBox(height: 7),

            // Options
            ...List.generate(
              currentOptions.length,
              (index) => _buildOptionCard(
                index: index,
                optionText: currentOptions[index],
                currentQ: currentQ,
                isDark: isDark,
              ),
            ),

            // Explanation
            if (_isAnswered)
              _buildEnhancedExplanation(
                currentExplanation,
                currentQ,
                isDark,
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // ---------------------------------------------------------------------
      // FIXED FLOATING BOTTOM NAVIGATION
      // ---------------------------------------------------------------------

      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }
}

// =============================================================================
// TELEGRAM TRICK SUBMIT BOX
// =============================================================================

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
  State<RevisionTrickSubmitBox> createState() =>
      _RevisionTrickSubmitBoxState();
}

class _RevisionTrickSubmitBoxState
    extends State<RevisionTrickSubmitBox> {
  final TextEditingController _trickController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isOpen = false;

  // IMPORTANT:
  // Keep your existing Telegram token/configuration here.
  // Do not commit the real bot token to a public repository.
  static const String _botToken =
      "YOUR_EXISTING_TELEGRAM_BOT_TOKEN";

  static const String _chatId = "785009742";

  Future<void> _submitTrickToTelegram() async {
    final trickText =
        _trickController.text.trim();

    if (trickText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '⚠️ Please write your trick or data first!',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final cleanSnippet =
        widget.questionSnippet.length > 70
            ? "${widget.questionSnippet.substring(0, 70)}..."
            : widget.questionSnippet;

    final telegramMsg = """
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
        Uri.parse(
          "https://api.telegram.org/bot$_botToken/sendMessage",
        ),
        headers: {
          "Content-Type": "application/json",
        },
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
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                '❌ Could not send. Please try again.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '❌ Network error. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _trickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    if (_isSubmitted) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF052E16)
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? const Color(0xFF166534)
                : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '✅ Thank you! Trick/Data Telegram par bhej diya gaya hai.',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFF16A34A),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF101827)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark
              ? const Color(0xFF29364D)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 2,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          '💡 ',
                          style: TextStyle(fontSize: 13),
                        ),
                        Flexible(
                          child: Text(
                            'Got a short-trick or better logic?',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOpen ? 'Close ▲' : 'Share ➜',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isOpen) ...[
            const SizedBox(height: 9),

            TextField(
              controller: _trickController,
              maxLines: 3,
              minLines: 2,
              textInputAction:
                  TextInputAction.newline,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white
                    : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText:
                    'Apni trick, mnemonic code ya logic yahan likhein...',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white38
                      : Colors.grey,
                ),
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF172033)
                    : Colors.white,
                contentPadding:
                    const EdgeInsets.all(11),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: Color(0xFF24A1DE),
                    width: 1.3,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 9),

            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF24A1DE),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : _submitTrickToTelegram,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 14,
                        ),
                  label: Text(
                    _isSubmitting
                        ? 'Sending...'
                        : 'Send to Telegram',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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