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

  // 💬 Track AI Doubt State per Question in Vault
  final Map<int, List<Map<String, String>>> _vaultAiChatHistory = {};
  final Map<int, bool> _vaultAskedStatus = {}; // Index -> true if 1 ask used

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

  // 💬 BOTTOM SHEET FOR VAULT QUESTION CUSTOM DOUBT (Max 1 Ask Limit)
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

                    // Previous Chat Response
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

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('🎉', style: TextStyle(fontSize: 50)),
                  SizedBox(height: 10),
                  Text('Vault is Empty!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  SizedBox(height: 4),
                  Text('Aapka koi bhi galat question saved nahi hai.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 🤖 1. AI MENTOR PERFORMANCE AUDIT
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
                final List<String>? statements = _isHindi ? q.sh : q.se;
                final bool hasAsked = _vaultAskedStatus[index] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Wrong Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                            // 🤖 ASK AI BUTTON ON QUESTION CARD
                            InkWell(
                              onTap: () => _openVaultAiDoubtDialog(q, index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Text('🤖', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      hasAsked ? 'View AI Answer' : 'Ask AI',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Question Title with Math / KaTeX Support
                        MathFormattedText(
                          text: q.getText(_isHindi),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87, height: 1.35),
                        ),

                        // Statements List if Available
                        if (statements != null && statements.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...statements.map((stmt) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: MathFormattedText(
                                  text: "• $stmt",
                                  textStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.3),
                                ),
                              )),
                        ],

                        const SizedBox(height: 12),

                        // Options with Math / KaTeX Support
                        ...List.generate(q.options.length, (optIdx) {
                          bool isCorrect = optIdx == q.answerIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCorrect ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isCorrect ? const Color(0xFF86EFAC) : Colors.grey.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${String.fromCharCode(65 + optIdx)}. ", style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green.shade800 : Colors.black87, fontSize: 12.5)),
                                Expanded(
                                  child: MathFormattedText(
                                    text: q.options[optIdx],
                                    textStyle: TextStyle(fontSize: 12.5, color: isCorrect ? Colors.green.shade900 : Colors.black87, fontWeight: isCorrect ? FontWeight.w60
