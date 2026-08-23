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
  int _timeLeft = 30;

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

  void _saveCurrentProgress(int index) async {
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

  void _checkBookmarkStatus() async {
    final savedList = await UserStatsService.getSavedQuestions();
    final currentQ = widget.questions[_currentIndex];
    String currentText = currentQ.getText(_isHindi);

    bool exists = savedList.any((item) {
      String qText = item['qe'] ?? item['qh'] ?? item['question'] ?? '';
      return qText == currentText || qText == currentQ.question;
    });

    if (mounted) {
      setState(() => _isBookmarked = exists);
    }
  }

  void _toggleBookmarkQuestion() async {
    final currentQ = widget.questions[_currentIndex];
    Map<String, dynamic> qJson = currentQ.toJson();

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
          wrongQuestionJson: currentQ.toJson(),
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
      wrongQuestionJson: isCorrect ? null : currentQ.toJson(),
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

  // ✨ COMPREHENSIVE PHYSICS & CHEMISTRY OCR SANITIZER
  Widget _buildEnhancedExplanation(String rawExplanation, Question currentQ, bool isDark) {
    if (rawExplanation.trim().isEmpty) return const SizedBox.shrink();

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
        .replaceAll(r'\\rightarrow', r'\rightarrow');

    // 🧪 1. Comprehensive Chemistry Subscripts (Common OCR Glitches)
    final Map<String, String> chemSubscripts = {
      r'($CO_2$)': 'CO₂', r'$CO_2$': 'CO₂', r'CO_2': 'CO₂',
      r'($H_2O$)': 'H₂O', r'$H_2O$': 'H₂O', r'H_2O': 'H₂O',
      r'($CH_4$)': 'CH₄', r'$CH_4$': 'CH₄', r'CH_4': 'CH₄',
      r'($O_2$)': 'O₂', r'$O_2$': 'O₂', r'O_2': 'O₂',
      r'($O_3$)': 'O₃', r'$O_3$': 'O₃', r'O_3': 'O₃',
      r'($N_2$)': 'N₂', r'$N_2$': 'N₂', r'N_2': 'N₂',
      r'($H_2$)': 'H₂', r'$H_2$': 'H₂', r'H_2': 'H₂',
      r'($Cl_2$)': 'Cl₂', r'$Cl_2$': 'Cl₂', r'Cl_2': 'Cl₂',
      r'($NO_2$)': 'NO₂', r'$NO_2$': 'NO₂', r'NO_2': 'NO₂',
      r'($SO_2$)': 'SO₂', r'$SO_2$': 'SO₂', r'SO_2': 'SO₂',
      r'($H_2SO_4$)': 'H₂SO₄', r'$H_2SO_4$': 'H₂SO₄', r'H_2SO_4': 'H₂SO₄',
      r'($HNO_3$)': 'HNO₃', r'$HNO_3$': 'HNO₃', r'HNO_3': 'HNO₃',
      r'($CaCO_3$)': 'CaCO₃', r'$CaCO_3$': 'CaCO₃', r'CaCO_3': 'CaCO₃',
      r'($NH_3$)': 'NH₃', r'$NH_3$': 'NH₃', r'NH_3': 'NH₃',
      r'($C_6H_{12}O_6$)': 'C₆H₁₂O₆', r'$C_6H_{12}O_6$': 'C₆H₁₂O₆', r'C_6H_{12}O_6': 'C₆H₁₂O₆',
      r'($Fe_2O_3$)': 'Fe₂O₃', r'$Fe_2O_3$': 'Fe₂O₃', r'Fe_2O_3': 'Fe₂O₃',
      r'($Al_2O_3$)': 'Al₂O₃', r'$Al_2O_3$': 'Al₂O₃', r'Al_2O_3': 'Al₂O₃',
      r'($KMnO_4$)': 'KMnO₄', r'$KMnO_4$': 'KMnO₄', r'KMnO_4': 'KMnO₄',
      r'($Na_2CO_3$)': 'Na₂CO₃', r'$Na_2CO_3$': 'Na₂CO₃',
      r'($NaHCO_3$)': 'NaHCO₃', r'$NaHCO_3$': 'NaHCO₃',
      r'($Si$)': 'Si', r'$Si$': 'Si',
      r'($Ge$)': 'Ge', r'$Ge$': 'Ge',
      r'($Ga$)': 'Ga', r'$Ga$': 'Ga',
      r'($GaAs$)': 'GaAs', r'$GaAs$': 'GaAs',
    };
    chemSubscripts.forEach((key, val) {
      cleaned = cleaned.replaceAll(key, val);
    });

    // 🔬 2. Physics Symbols, Range & Operators
    final Map<String, String> physReplacements = {
      r'($\lambda$)': 'λ', r'$\lambda$': 'λ', r'\lambda': 'λ',
      r'($\mu$)': 'μ', r'$\mu$': 'μ', r'\mu': 'μ',
      r'($\nu$)': 'ν', r'$\nu$': 'ν', r'\nu': 'ν',
      r'($\theta$)': 'θ', r'$\theta$': 'θ', r'\theta': 'θ',
      r'($\alpha$)': 'α', r'$\alpha$': 'α', r'\alpha': 'α',
      r'($\beta$)': 'β', r'$\beta$': 'β', r'\beta': 'β',
      r'($\gamma$)': 'γ', r'$\gamma$': 'γ', r'\gamma': 'γ',
      r'($\rho$)': 'ρ', r'$\rho$': 'ρ', r'\rho': 'ρ',
      r'($\omega$)': 'ω', r'$\omega$': 'ω', r'\omega': 'ω',
      r'($\Omega$)': 'Ω', r'$\Omega$': 'Ω', r'\Omega': 'Ω',
      r'($\Delta$)': 'Δ', r'$\Delta$': 'Δ', r'\Delta': 'Δ',
      r'($\pi$)': 'π', r'$\pi$': 'π', r'\pi': 'π',
      r'($\phi$)': 'φ', r'$\phi$': 'φ', r'\phi': 'φ',
      r'\approx': '≈', r'$\approx$': '≈',
      r'\neq': '≠', r'$\neq$': '≠',
      r'\leq': '≤', r'$\leq$': '≤',
      r'\geq': '≥', r'$\geq$': '≥',
      r'\pm': '±', r'$\pm$': '±',
      r'\times': '×', r'$\times$': '×',
      r'\rightarrow': '→', r'$\rightarrow$': '→',
      r'\leftarrow': '←', r'$\leftarrow$': '←',
      r'\infty': '∞', r'$\infty$': '∞',
      r'\propto': '∝', r'$\propto$': '∝',
    };
    physReplacements.forEach((key, val) {
      cleaned = cleaned.replaceAll(key, val);
    });

    // 🌡️ 3. Temperature, Units & Exponents (Regex)
    cleaned = cleaned
        // Degree Fixes
        .replaceAll(r'^\circ\text{C}', '°C')
        .replaceAll(r'^\circ\text{ C}', '°C')
        .replaceAll(r'^\circ C', '°C')
        .replaceAll(r'^\circ\text{F}', '°F')
        .replaceAll(r'^\circ\text{ F}', '°F')
        .replaceAll(r'^\circ F', '°F')
        .replaceAll(r'^\circ', '°')
        .replaceAll(r'\circ', '°')
        // Voltage / Current Range ($0.5 \text{ to } 1 \text{ V}$ -> 0.5 V to 1 V)
        .replaceAllMapped(RegExp(r'\$\s*([0-9.]+)\s*\\text\{\s*to\s*\}\s*([0-9.]+)\s*\\text\{\s*([A-Za-z]+)\s*\}\s*\$'), 
            (m) => '${m.group(1)} ${m.group(3)} to ${m.group(2)} ${m.group(3)}')
        // Generic \text{...} inside math block
        .replaceAllMapped(RegExp(r'\\text\{\s*([^}]+)\s*\}'), (m) => m.group(1) ?? '')
        // Exponents ($10^5$ -> 10⁵, $m/s^2$ -> m/s², $cm^3$ -> cm³)
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
        // Clean leftover empty dollar blocks
        .replaceAll(r'$$', '')
        .trim();

    List<String> rawLines = cleaned
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    List<String> distinctBlocks = [];
    String currentBlock = "";

    for (String line in rawLines) {
      bool isNewBlockHeader = line.startsWith('•') ||
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
          currentBlock += "\n$line";
        }
      }
    }
    if (currentBlock.isNotEmpty) distinctBlocks.add(currentBlock.trim());

    List<String> primaryCorrectBlocks = [];
    List<String> trapOptionBlocks = [];
    List<String> takeawayBlocks = [];

    for (String block in distinctBlocks) {
      final String lower = block.trim().toLowerCase();
      final String firstLine = lower.split('\n').first;

      bool isExplicitCorrect = firstLine.contains('is correct') ||
          firstLine.contains('sahi hai') ||
          firstLine.contains('bilkul sahi');

      bool isExplicitIncorrect = firstLine.contains('is incorrect') ||
          firstLine.contains('galat hai') ||
          firstLine.contains('is false') ||
          firstLine.contains('trap');

      bool isTakeaway = firstLine.startsWith('key takeaway') ||
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

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFFECFDF5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('💡', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text(
                  _isHindi ? 'मुख्य व्याख्या (Core Solution)' : 'Detailed Solution',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
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
                if (primaryCorrectBlocks.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : const Color(0xFF059669).withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: primaryCorrectBlocks.map((block) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: MathFormattedText(
                            text: block,
                            textStyle: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                ...takeawayBlocks.map((point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: MathFormattedText(
                        text: point,
                        textStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.45,
                        ),
                      ),
                    )),

                if (trapOptionBlocks.isNotEmpty) ...[
                  const SizedBox(height: 6),
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
                              children: trapOptionBlocks.map((item) {
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
