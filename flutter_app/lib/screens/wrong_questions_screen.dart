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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              child: Text(_isHindi ? 'हिंदी' : 'ENG', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
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

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🎉', style: TextStyle(fontSize: 50)),
                  SizedBox(height: 10),
                  Text('Vault is Empty!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Aapka koi bhi galat question saved nahi hai.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 🤖 1. AI MENTOR AUDIT BUTTON & REPORT CARD
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
                              Text('AI Mentor Performance Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
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
                              onPressed: () => _runAiAnalysis(list),
                              child: const Text('Analyze Mistakes ⚡', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      if (_aiAnalysisReport != null) ...[
                        const Divider(height: 20),
                        MathFormattedText(
                          text: _aiAnalysisReport!,
                          textStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.4),
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        const Text(
                          'AI aapke saare wrong questions ko scan karke aapki weak topics aur mistakes ki report dega.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 📋 2. LIST OF WRONG QUESTIONS
              ...List.generate(list.length, (index) {
                final qJson = list[index];
                final q = Question.fromJson(qJson);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wrong Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                        const SizedBox(height: 4),
                        MathFormattedText(
                          text: q.getText(_isHindi),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(q.options.length, (optIdx) {
                          bool isCorrect = optIdx == q.answerIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isCorrect ? Colors.green : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Text("${String.fromCharCode(65 + optIdx)}. ", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(child: MathFormattedText(text: q.options[optIdx], textStyle: const TextStyle(fontSize: 12.5))),
                                if (isCorrect) const Icon(Icons.check_circle, size: 16, color: Colors.green),
                              ],
                            ),
                          );
                        }),
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('💡 Correct Solution: ${q.explanation}', style: const TextStyle(fontSize: 11.5, color: Colors.green)),
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
}
