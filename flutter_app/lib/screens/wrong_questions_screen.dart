import 'package:flutter/material.dart';
import '../models/question_model.dart';
import '../services/ai_explainer_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/math_text.dart';

class WrongQuestionsScreen extends StatefulWidget {
  const WrongQuestionsScreen({super.key});

  @override
  State<WrongQuestionsScreen> createState() => _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends State<WrongQuestionsScreen> {
  late Future<List<Map<String, dynamic>>> _wrongQuestionsFuture;
  bool _isHindi = true;

  bool _isAnalyzing = false;
  String? _aiAnalysisReport;

  // Filter selection: 'ALL', 'REVISION', 'MOCK'
  String _selectedFilter = 'ALL';

  final Map<int, bool> _isExplanationExpanded = {}; 
  final Map<int, List<Map<String, String>>> _vaultAiChatHistory = {};
  final Map<int, bool> _vaultAskedStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _wrongQuestionsFuture = UserStatsService.getWrongQuestions();
      _aiAnalysisReport = null;
    });
  }

  void _runAiAnalysis(List<Map<String, dynamic>> list) async {
    setState(() => _isAnalyzing = true);
    String report = await AiExplainerService.analyzeWrongQuestions(list);
    if (mounted) {
      setState(() {
        _aiAnalysisReport = report;
        _isAnalyzing = false;
      });
    }
  }

  // ⚡ ONE-CLICK RE-QUIZ ENGINE DIALOG (Active Recall Test Mode)
  void _startReQuiz(List<Map<String, dynamic>> wrongList) {
    if (wrongList.isEmpty) return;

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("⚡ Re-Quiz (${qIndex + 1}/${wrongList.length})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
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
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(q.options.length, (optIdx) {
                      bool isCorrect = optIdx == q.answerIndex;
                      bool isSelected = selectedOption == optIdx;

                      Color bg = Colors.grey.shade100;
                      Color border = Colors.grey.shade300;

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
                                  bool graduated = await UserStatsService.incrementQuestionMastery(qIndex);
                                  if (graduated && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("🎉 Question Mastered & Cleared from Vault!"), duration: Duration(seconds: 1)),
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
                            children: [
                              Text("${String.fromCharCode(65 + optIdx)}. ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Expanded(child: MathFormattedText(text: q.options[optIdx], textStyle: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (isAnswered && q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: MathFormattedText(
                          text: "💡 ${q.explanation}",
                          textStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A)),
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

  // 💬 BOTTOM SHEET FOR VAULT QUESTION CUSTOM DOUBT (Max 1 Ask)
  void _openVaultAiDoubtDialog(Question currentQ, int qIndex) {
    bool hasAsked = _vaultAskedStatus[qIndex] ?? false;
    TextEditingController doubtController = TextEditingController();
    bool isAsking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final history = _vaultAiChatHistory[qIndex] ?? [];

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
                            color: !hasAsked ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            !hasAsked ? '1 Ask Allowed' : '🔒 Limit Reached',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: !hasAsked ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

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

                    if (!hasAsked) ...[
                      TextField(
                        controller: doubtController,
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type your exact doubt (e.g. Yeh formula yahan kyu apply hua?)',
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
                                    _vaultAskedStatus[qIndex] = true;
                                    _vaultAiChatHistory[qIndex] = [
                                      ...history,
                                      {'doubt': userQuery, 'response': aiResp}
                                    ];
                                  });

                                  setModalState(() {
                                    hasAsked = true;
                                    isAsking = false;
                                    doubtController.clear();
                                  });
                                },
                          icon: isAsking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(isAsking ? 'Analyzing Deep Logic...' : 'Get AI Explanation 🚀'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('❌ Wrong Questions Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () async {
              await UserStatsService.clearWrongQuestions();
              _loadData();
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawList = snapshot.data ?? [];
          if (rawList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🎉', style: TextStyle(fontSize: 50)),
                  SizedBox(height: 10),
                  Text('Vault is Empty! (Vault Zero)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Aapka koi bhi galat question saved nahi hai.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          // Filter logic
          final filteredList = rawList.where((item) {
            String chapter = (item['chapterName'] ?? item['chapter'] ?? '').toString();
            if (_selectedFilter == 'REVISION') {
              return chapter.isNotEmpty && !chapter.toLowerCase().contains('mock');
            } else if (_selectedFilter == 'MOCK') {
              return chapter.toLowerCase().contains('mock') || chapter.isEmpty;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 🤖 1. AI MENTOR AUDIT & RE-QUIZ HEADER
              Card(
                color: const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('🤖', style: TextStyle(fontSize: 22)),
                              SizedBox(width: 8),
                              Text('AI Mentor Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
                            ],
                          ),
                          if (_isAnalyzing)
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              onPressed: () => _runAiAnalysis(rawList),
                              child: const Text('Analyze ⚡', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ⚡ 1-CLICK RE-QUIZ BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _startReQuiz(filteredList),
                          icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                          label: Text("Start Vault Re-Quiz (${filteredList.length} Questions)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),

                      if (_aiAnalysisReport != null) ...[
                        const Divider(height: 20),
                        MathFormattedText(
                          text: _aiAnalysisReport!,
                          textStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.4),
                        ),
                      ],
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
                final q = Question.fromJson(qJson);
                final List<String>? statements = _isHindi ? q.sh : q.se;

                String sourceName = qJson['chapterName'] ?? qJson['chapter'] ?? 'Sectional Mock';
                bool isMock = sourceName.toLowerCase().contains('mock') || sourceName.isEmpty;
                String dateStr = qJson['dateAdded'] ?? 'Recently';
                int masteryStreak = qJson['masteryStreak'] ?? 0;
                String savedTag = qJson['errorTag'] ?? '';

                bool isExpanded = _isExplanationExpanded[index] ?? false;
                bool hasAsked = _vaultAskedStatus[index] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER: Source Badge + Date + Mastery Streak + Ask AI
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isMock ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isMock ? '🎯 Sectional Mock' : '⚡ $sourceName',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isMock ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // 🎯 SMART LADDER BADGE
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: masteryStreak > 0 ? const Color(0xFFDCFCE7) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: masteryStreak > 0 ? Colors.green : Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    "🎯 Streak: $masteryStreak/2",
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: masteryStreak > 0 ? Colors.green.shade800 : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text('📅 $dateStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openVaultAiDoubtDialog(q, index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text('🤖', style: TextStyle(fontSize: 10)),
                                        const SizedBox(width: 2),
                                        Text(
                                          hasAsked ? 'AI Ans' : 'Ask AI',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),

                        // QUESTION TITLE
                        MathFormattedText(
                          text: q.getText(_isHindi),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87, height: 1.3),
                        ),

                        // STATEMENTS
                        if (statements != null && statements.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...statements.map((stmt) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: MathFormattedText(
                                  text: "• $stmt",
                                  textStyle: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.25),
                                ),
                              )),
                        ],

                        const SizedBox(height: 10),

                        // OPTIONS LIST
                        ...List.generate(q.options.length, (optIdx) {
                          bool isCorrect = optIdx == q.answerIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCorrect ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isCorrect ? const Color(0xFF86EFAC) : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Text("${String.fromCharCode(65 + optIdx)}. ", style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green.shade800 : Colors.black87, fontSize: 12)),
                                Expanded(
                                  child: MathFormattedText(
                                    text: q.options[optIdx],
                                    textStyle: TextStyle(fontSize: 12, color: isCorrect ? Colors.green.shade900 : Colors.black87),
                                  ),
                                ),
                                if (isCorrect) const Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),

                        // 🏷️ PERSISTENT SILLY VS CONCEPT TAGGING BAR
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _tagChip(
                                  label: '🟡 Silly',
                                  isSelected: savedTag == 'silly',
                                  color: Colors.amber.shade700,
                                  onTap: () async {
                                    String newTag = savedTag == 'silly' ? '' : 'silly';
                                    await UserStatsService.updateWrongQuestionTag(index, newTag);
                                    _loadData();
                                  },
                                ),
                                const SizedBox(width: 6),
                                _tagChip(
                                  label: '🔴 Didn\'t Know',
                                  isSelected: savedTag == 'concept',
                                  color: Colors.red.shade700,
                                  onTap: () async {
                                    String newTag = savedTag == 'concept' ? '' : 'concept';
                                    await UserStatsService.updateWrongQuestionTag(index, newTag);
                                    _loadData();
                                  },
                                ),
                              ],
                            ),

                            // COMPACT SOLUTION TOGGLE BUTTON
                            if (q.explanation.isNotEmpty)
                              InkWell(
                                onTap: () => setState(() => _isExplanationExpanded[index] = !isExpanded),
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

                        // COLLAPSIBLE EXPLANATION BOX
                        if (isExpanded && q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: MathFormattedText(
                              text: q.explanation,
                              textStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
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

  Widget _filterChip(String filterKey, String label) {
    bool isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
