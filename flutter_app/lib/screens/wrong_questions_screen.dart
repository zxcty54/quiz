import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/ai_explainer_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';

class WrongQuestionsScreen extends StatefulWidget {
  final bool isDarkMode;
  const WrongQuestionsScreen({super.key, this.isDarkMode = false});

  @override
  State<WrongQuestionsScreen> createState() => _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends State<WrongQuestionsScreen> {
  late Future<List<Map<String, dynamic>>> _wrongQuestionsFuture;
  List<Map<String, dynamic>> _wrongListMemory = [];
  bool _isHindi = true;

  // Filter selection: 'ALL', 'REVISION', 'MOCK'
  String _selectedFilter = 'ALL';

  final Map<String, bool> _isExplanationExpanded = {};

  // Store "Why Wrong" fast AI responses (QuestionId -> Text)
  final Map<String, String> _whyWrongAiResponses = {};
  final Map<String, bool> _whyWrongLoading = {};

  // ⏳ Global Anti-Spam Cooldown for Analyze Trap (15 Seconds)
  static DateTime? _lastVaultAiCallTime;
  static const int _vaultCooldownSeconds = 15;

  int _getVaultCooldownRemaining() {
    if (_lastVaultAiCallTime == null) return 0;
    final int diff = DateTime.now().difference(_lastVaultAiCallTime!).inSeconds;
    if (diff < _vaultCooldownSeconds) {
      return _vaultCooldownSeconds - diff;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _wrongQuestionsFuture = UserStatsService.getWrongQuestions().then((list) {
        _wrongListMemory = List.from(list);
        return list;
      });
    });
  }

  // Sawal ki pehchan (identity) — number (index) se nahi, sawal ke text se.
  // Filter lagne ya beech me sawal hatne par index badal jata hai, text nahi —
  // isliye tag, mastery aur AI jawab hamesha sahi sawal par lagta hai.
  String _questionId(Map<String, dynamic> qJson) =>
      (qJson['qe'] ?? qJson['qh'] ?? '').toString();

  // 🎯 SMART DETECTION FOR SECTIONAL MOCK ("Set 1", "Set 2", "Set-01", etc.)
  bool _isMockQuestion(Map<String, dynamic> qJson) {
    String chapter = (qJson['chapterName'] ?? qJson['chapter'] ?? '').toString().toLowerCase().trim();
    String source = (qJson['sourceType'] ?? qJson['source'] ?? '').toString().toLowerCase().trim();
    bool isMockFlag = qJson['isMock'] == true || qJson['isSectional'] == true;

    bool isSetPattern = RegExp(r'\bset[\s\-_]*\d+').hasMatch(chapter);

    return isMockFlag ||
        isSetPattern ||
        chapter.contains('set') ||
        chapter.contains('mock') ||
        chapter.contains('sectional') ||
        chapter.contains('cbt') ||
        source.contains('mock') ||
        source.contains('sectional') ||
        chapter.isEmpty;
  }

  // ⚡ ONE-CLICK RE-QUIZ ENGINE DIALOG (Resume Fix Mode)
  void _startReQuiz(List<Map<String, dynamic>> wrongList) {
    if (wrongList.isEmpty) return;
    final bool quizDark = widget.isDarkMode;

    int qIndex = 0;
    int? selectedOption;
    bool isAnswered = false;
    int score = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setQuizState) {
            final currentJson = wrongList[qIndex];
            final q = Question.fromJson(currentJson);

            return AlertDialog(
              backgroundColor: quizDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("🛠️ Fix Error (${qIndex + 1}/${wrongList.length})", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: quizDark ? Colors.white : Colors.black87)),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: quizDark ? Colors.white : Colors.black87),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadData();
                    },
                  )
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathFormattedText(
                      text: q.getText(_isHindi),
                      textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: quizDark ? Colors.white : Colors.black87, height: 1.3),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(q.options.length, (optIdx) {
                      bool isCorrect = optIdx == q.answerIndex;
                      bool isSelected = selectedOption == optIdx;

                      Color bg = quizDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
                      Color border = quizDark ? const Color(0xFF334155) : Colors.grey.shade300;

                      if (isAnswered) {
                        if (isCorrect) {
                          bg = const Color(0xFFDCFCE7);
                          border = Colors.green;
                        } else if (isSelected) {
                          bg = const Color(0xFFFEE2E2);
                          border = Colors.red;
                        }
                      }

                      return GestureDetector(
                        onTap: isAnswered
                            ? null
                            : () async {
                                setQuizState(() {
                                  selectedOption = optIdx;
                                  isAnswered = true;
                                });

                                if (isCorrect) {
                                  score++;
                                  bool graduated = await UserStatsService.incrementQuestionMasteryByText(_questionId(currentJson));
                                  if (graduated && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("🎉 Question Cleared from Vault!"), duration: Duration(seconds: 1)),
                                    );
                                  }
                                }
                              },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${String.fromCharCode(65 + optIdx)}. ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isAnswered && isCorrect ? Colors.green.shade900 : (isAnswered && isSelected ? Colors.red.shade900 : (quizDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                                ),
                              ),
                              Expanded(
                                child: MathFormattedText(
                                  text: q.options[optIdx],
                                  textStyle: TextStyle(
                                    fontSize: 12,
                                    color: isAnswered && isCorrect ? Colors.green.shade900 : (isAnswered && isSelected ? Colors.red.shade900 : (quizDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    if (isAnswered && q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: quizDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: MathFormattedText(
                          text: "💡 Solution: ${q.explanation}",
                          textStyle: TextStyle(fontSize: 11.5, color: quizDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A), height: 1.3),
                        ),
                      )
                    ]
                  ],
                ),
              ),
              actions: [
                if (isAnswered)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: () {
                      if (qIndex < wrongList.length - 1) {
                        setQuizState(() {
                          qIndex++;
                          selectedOption = null;
                          isAnswered = false;
                        });
                      } else {
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("🏆 Re-Quiz Finished! Score: $score/${wrongList.length}")),
                        );
                      }
                    },
                    child: Text(qIndex < wrongList.length - 1 ? "Next Question ➔" : "Finish Re-Quiz 🏁"),
                  )
              ],
            );
          },
        );
      },
    );
  }

  // 🎯 PURE LIVE AI TRIGGER FOR "WHY WRONG" (WITH 15s COOLDOWN PROTECTION)
  void _fetchWhyWrongAi(Question q, String userChoice, String userTag, String qid) async {
    if (_whyWrongLoading[qid] == true || _whyWrongAiResponses[qid] != null) return;

    final int cooldown = _getVaultCooldownRemaining();
    if (cooldown > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Please wait ${cooldown}s before analyzing trap again!'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    _lastVaultAiCallTime = DateTime.now();
    setState(() => _whyWrongLoading[qid] = true);

    String selectedOpt = (userChoice.trim().isNotEmpty && 
                          userChoice != "Attempted Option" && 
                          userChoice != "No Option Selected")
        ? userChoice
        : "";

    String result = await AiExplainerService.explainWhyWrong(
      question: q.getText(_isHindi),
      options: q.options,
      userChoice: selectedOpt,
      correctAnswer: q.options[q.answerIndex],
      userTag: userTag,
    );

    if (mounted) {
      bool isSuccess = result.isNotEmpty && !result.contains("⚠️ AI Service busy hai");

      setState(() {
        if (isSuccess) {
          _whyWrongAiResponses[qid] = result;
        }
        _whyWrongLoading[qid] = false;
      });

      if (!isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int globalCooldown = _getVaultCooldownRemaining();
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('❌ Wrong Questions Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () async {
              // Galti se tap ho jaye to poora vault na ude — pehle pakka karo
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  title: Text('Poora Vault saaf karein?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87)),
                  content: Text('Saare wrong questions hamesha ke liye delete ho jayenge. Ye wapas nahi aayega.', style: TextStyle(fontSize: 12.5, height: 1.4, color: widget.isDarkMode ? const Color(0xFFCBD5E1) : Colors.black87)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await UserStatsService.clearWrongQuestions();
                _loadData();
              }
            },
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
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _wrongQuestionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _wrongListMemory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawList = snapshot.data ?? _wrongListMemory;
          if (rawList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 10),
                  Text('Vault Zero Cleared!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Aapka koi bhi wrong question pending nahi hai.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          final filteredList = rawList.where((item) {
            bool isMock = _isMockQuestion(item);
            if (_selectedFilter == 'REVISION') {
              return !isMock;
            } else if (_selectedFilter == 'MOCK') {
              return isMock;
            }
            return true;
          }).toList();

          final mockCount = rawList.where((item) => _isMockQuestion(item)).length;
          final streakCount = rawList.where((item) => (item['masteryStreak'] ?? 0) > 0).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 📊 0. SUMMARY STRIP — ek nazar me poora vault
              Row(
                children: [
                  _summaryBox('⏳', '${rawList.length}', 'Pending', isDark),
                  const SizedBox(width: 8),
                  _summaryBox('🎯', '$mockCount', 'Mock', isDark),
                  const SizedBox(width: 8),
                  _summaryBox('⚡', '${rawList.length - mockCount}', 'Revision', isDark),
                  const SizedBox(width: 8),
                  _summaryBox('🔥', '$streakCount', 'Streak par', isDark),
                ],
              ),
              const SizedBox(height: 12),

              // 🛠️ 1. RESUME FIX CARD
              Card(
                color: isDark ? const Color(0xFF052E16) : const Color(0xFFECFDF5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("⏳ ${filteredList.length} Questions Waiting", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _startReQuiz(filteredList),
                            icon: const Icon(Icons.build_circle_rounded, size: 16),
                            label: const Text("Resume Fix 🛠️", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 🏷️ 2. FILTER TABS
              Row(
                children: [
                  _filterChip('ALL', 'All (${rawList.length})'),
                  const SizedBox(width: 8),
                  _filterChip('REVISION', '⚡ Revision Hub'),
                  const SizedBox(width: 8),
                  _filterChip('MOCK', '🎯 Sectional Mock'),
                ],
              ),
              const SizedBox(height: 14),

              // 📋 3. COMPACT WRONG QUESTION CARDS
              ...List.generate(filteredList.length, (index) {
                final qJson = filteredList[index];
                final String qid = _questionId(qJson);
                final q = Question.fromJson(qJson);
                final List<String>? statements = _isHindi ? q.sh : q.se;

                String sourceName = qJson['chapterName'] ?? qJson['chapter'] ?? 'Sectional Mock';
                bool isMock = _isMockQuestion(qJson);
                String dateStr = qJson['dateAdded'] ?? 'Recently';
                int masteryStreak = qJson['masteryStreak'] ?? 0;
                String savedTag = qJson['errorTag'] ?? '';
                String userSelectedOpt = (qJson['userSelectedOption'] ?? '').toString();

                bool isExpanded = _isExplanationExpanded[qid] ?? false;
                bool isWhyWrongLoading = _whyWrongLoading[qid] ?? false;
                String? whyWrongAiText = _whyWrongAiResponses[qid];

                bool hasSpecificChoice = userSelectedOpt.trim().isNotEmpty && 
                                         userSelectedOpt != "Attempted Option" && 
                                         userSelectedOpt != "No Option Selected";

                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isMock ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMock ? (sourceName.toLowerCase().contains('set') ? '🎯 Sectional $sourceName' : '🎯 Sectional Mock') : '⚡ $sourceName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isMock ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: masteryStreak > 0 ? (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7)) : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: masteryStreak > 0 ? Colors.green : (isDark ? const Color(0xFF475569) : Colors.grey.shade300)),
                                    ),
                                    child: Text(
                                      "🎯 Streak: $masteryStreak/2",
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: masteryStreak > 0 ? Colors.green.shade800 : (isDark ? const Color(0xFF94A3B8) : Colors.grey)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('📅 $dateStr', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        MathFormattedText(
                          text: q.getText(_isHindi),
                          textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? Colors.white : Colors.black87, height: 1.3),
                        ),

                        if (statements != null && statements.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...statements.map((stmt) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: MathFormattedText(
                                  text: "• $stmt",
                                  textStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800, height: 1.25),
                                ),
                              )),
                        ],

                        const SizedBox(height: 10),

                        ...List.generate(q.options.length, (optIdx) {
                          bool isCorrect = optIdx == q.answerIndex;
                          // Student ka apna galat jawab bhi laal dikhao — sirf sahi wala hara nahi
                          bool isUserWrong = hasSpecificChoice && !isCorrect && q.options[optIdx].trim() == userSelectedOpt.trim();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? (isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4))
                                  : isUserWrong
                                      ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                                      : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isCorrect ? const Color(0xFF86EFAC) : isUserWrong ? const Color(0xFFF87171) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${String.fromCharCode(65 + optIdx)}. ", style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? (isDark ? Colors.green.shade300 : Colors.green.shade800) : isUserWrong ? Colors.red.shade400 : (isDark ? const Color(0xFFCBD5E1) : Colors.black87), fontSize: 12)),
                                Expanded(
                                  child: MathFormattedText(
                                    text: q.options[optIdx],
                                    textStyle: TextStyle(fontSize: 12, color: isCorrect ? (isDark ? Colors.green.shade200 : Colors.green.shade900) : isUserWrong ? (isDark ? const Color(0xFFFCA5A5) : Colors.red.shade900) : (isDark ? const Color(0xFFCBD5E1) : Colors.black87)),
                                  ),
                                ),
                                if (isCorrect) const Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
                                if (isUserWrong) const Icon(Icons.close_rounded, size: 15, color: Colors.red),
                              ],
                            ),
                          );
                        }),

                        // 🎯 LIVE AI "❌ WHY WRONG?" BOX
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF331420) : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF9F1239) : const Color(0xFFFECDD3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text('❌ Why Wrong?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C))),
                                        if (hasSpecificChoice) ...[
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '(Selected: "$userSelectedOpt")',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.black54),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  // 🔒 ANALYZE TRAP BUTTON (Fail-Safe + Cooldown Support)
                                  InkWell(
                                    onTap: (isWhyWrongLoading || whyWrongAiText != null) 
                                        ? null 
                                        : () => _fetchWhyWrongAi(q, userSelectedOpt, savedTag, qid),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: whyWrongAiText != null 
                                            ? Colors.grey.shade400 
                                            : const Color(0xFFBE123C),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: isWhyWrongLoading
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                                          : Text(
                                              whyWrongAiText != null 
                                                  ? 'Analyzed ✓' 
                                                  : (globalCooldown > 0 ? 'Wait ${globalCooldown}s' : 'Analyze Trap ⚡'),
                                              style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                    ),
                                  )
                                ],
                              ),

                              if (whyWrongAiText != null) ...[
                                const SizedBox(height: 8),
                                Divider(height: 1, color: isDark ? const Color(0xFF9F1239) : const Color(0xFFFECDD3)),
                                const SizedBox(height: 6),
                                MathFormattedText(
                                  text: whyWrongAiText,
                                  textStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFFECDD3) : const Color(0xFF881337), height: 1.35),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                Text(
                                  savedTag == '50-50'
                                      ? '🟡 Tag selected: "50-50 Trap". Tap "Analyze Trap ⚡" to reveal the Professor\'s distractor trap.'
                                      : savedTag == 'concept'
                                          ? '🔴 Tag selected: "Didn\'t Know". Tap "Analyze Trap ⚡" for a zero-level concept explanation.'
                                          : '👆 Pehle niche se tag select karein (🟡 50-50 Trap ya 🔴 Didn\'t Know), phir "Analyze Trap ⚡" dabaayein!',
                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFF9F1239), fontStyle: FontStyle.italic),
                                ),
                              ]
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 🏷️ TAGGING BAR
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _tagChip(
                                  label: '🟡 50-50 Trap',
                                  isSelected: savedTag == '50-50',
                                  color: Colors.amber.shade800,
                                  onTap: () async {
                                    String newTag = savedTag == '50-50' ? '' : '50-50';
                                    setState(() {
                                      qJson['errorTag'] = newTag;
                                    });
                                    await UserStatsService.updateWrongQuestionTagByText(qid, newTag);
                                  },
                                ),
                                const SizedBox(width: 6),
                                _tagChip(
                                  label: '🔴 Didn\'t Know',
                                  isSelected: savedTag == 'concept',
                                  color: Colors.red.shade700,
                                  onTap: () async {
                                    String newTag = savedTag == 'concept' ? '' : 'concept';
                                    setState(() {
                                      qJson['errorTag'] = newTag;
                                    });
                                    await UserStatsService.updateWrongQuestionTagByText(qid, newTag);
                                  },
                                ),
                              ],
                            ),

                            if (q.explanation.isNotEmpty)
                              InkWell(
                                onTap: () => setState(() => _isExplanationExpanded[qid] = !isExpanded),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text(
                                    isExpanded ? 'Hide Solution ∧' : '💡 Solution ∨',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              )
                          ],
                        ),

                        if (isExpanded && q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
                            ),
                            child: MathFormattedText(
                              text: q.explanation,
                              textStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A), height: 1.35),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBox(String emoji, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text('$emoji $value', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final bool isDark = widget.isDarkMode;
    bool isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF475569) : Colors.grey.shade300)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _tagChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : (widget.isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (widget.isDarkMode ? const Color(0xFF475569) : Colors.grey.shade300), width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? color : (widget.isDarkMode ? const Color(0xFF94A3B8) : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
