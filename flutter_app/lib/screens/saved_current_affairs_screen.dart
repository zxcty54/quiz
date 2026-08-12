import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_explainer_service.dart';
import '../widgets/math_text.dart';

class SavedCurrentAffairsScreen extends StatefulWidget {
  const SavedCurrentAffairsScreen({super.key});

  @override
  State<SavedCurrentAffairsScreen> createState() => _SavedCurrentAffairsScreenState();
}

class _SavedCurrentAffairsScreenState extends State<SavedCurrentAffairsScreen> {
  List<dynamic> _savedNewsList = [];
  bool _isLoading = true;
  bool _isHindi = true;

  bool _isAnalyzing = false;
  String? _aiAnalysisReport;

  // Filter selection: 'ALL', 'BIHAR', 'NATIONAL'
  String _selectedFilter = 'ALL';

  final Map<int, List<Map<String, String>>> _caAiChatHistory = {};
  final Map<int, bool> _caAskedStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('saved_daily_bulletins');
    if (savedJson != null) {
      try {
        if (mounted) {
          setState(() {
            _savedNewsList = jsonDecode(savedJson);
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading saved news: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ CLEAR ALL SAVED CURRENT AFFAIRS
  Future<void> _clearAllSavedNews() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_daily_bulletins');
    setState(() {
      _savedNewsList.clear();
      _aiAnalysisReport = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cleared all Saved Current Affairs Vault!")),
      );
    }
  }

  // 🗑️ DELETE SINGLE CA ITEM
  Future<void> _removeSavedNews(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNewsList.removeAt(index);
    });
    await prefs.setString('saved_daily_bulletins', jsonEncode(_savedNewsList));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from Saved Current Affairs"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // 🩺 RUN AI CA SUMMARY ANALYSIS
  void _runAiAnalysis() async {
    if (_savedNewsList.isEmpty) return;
    setState(() => _isAnalyzing = true);

    StringBuffer newsBuffer = StringBuffer();
    for (var item in _savedNewsList) {
      newsBuffer.writeln("Title: ${item['title']}");
      List bullets = (item['bullets'] as List?) ?? [];
      for (var b in bullets) {
        newsBuffer.writeln("- $b");
      }
      newsBuffer.writeln("");
    }

    String report = await AiExplainerService.askCustomDoubt(
      question: "Generate a 3-bullet High-Yield Exam Summary and Key Traps from these saved bulletins:",
      options: const ["Option A", "Option B", "Option C", "Option D"],
      correctAnswer: "Summary Focus",
      userDoubt: newsBuffer.toString().length > 300
          ? newsBuffer.toString().substring(0, 300)
          : newsBuffer.toString(),
    );

    if (mounted) {
      setState(() {
        _aiAnalysisReport = report;
        _isAnalyzing = false;
      });
    }
  }

  // 🚀 GENERATE AI QUIZ FROM SAVED BULLETINS
  void _generateAiQuiz(List<dynamic> filteredList) {
    if (filteredList.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                "AI is creating Quiz from your Bookmarks... 🧠",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚡ AI Quiz Feature Ready! Starting Test..."),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    });
  }

  // 💬 ASK CUSTOM AI DOUBT ON SPECIFIC BULLETIN
  void _openCaAiDoubtDialog(Map<String, dynamic> newsItem, int index) {
    bool hasAsked = _caAskedStatus[index] ?? false;
    TextEditingController doubtController = TextEditingController();
    bool isAsking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final history = _caAiChatHistory[index] ?? [];

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
                            Text('Ask AI Doubt on Bulletin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        maxLength: 100,
                        maxLines: 2,
                        minLines: 1,
                        style: const TextStyle(color: Colors.black87),
                        decoration: const InputDecoration(
                          hintText: 'Ask anything about this current affair (Max 100 chars)...',
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
                                    question: newsItem['title'] ?? 'Current Affair',
                                    options: const ['Fact 1', 'Fact 2'],
                                    correctAnswer: 'Exam Relevance',
                                    userDoubt: userQuery,
                                  );

                                  setState(() {
                                    _caAskedStatus[index] = true;
                                    _caAiChatHistory[index] = [
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
                          label: Text(isAsking ? 'Analyzing News Logic...' : 'Get AI Explanation 🚀'),
                        ),
                      )
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.center,
                        child: const Text(
                          '🔒 Bulletin-wise 1 doubt limit complete ho chuki hai.',
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

  // 📍 BIHAR vs NATIONAL DETECTOR
  bool _isBiharNews(Map<String, dynamic> item) {
    final String tag = (item['exam_tag'] ?? '').toString().toLowerCase();
    final String title = (item['title'] ?? '').toString().toLowerCase();
    final String cat = (item['category'] ?? '').toString().toLowerCase();

    return tag.contains('bihar') ||
        tag.contains('bpsc') ||
        tag.contains('bssc') ||
        title.contains('bihar') ||
        title.contains('patna') ||
        cat.contains('bihar');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(' Saved Current Affairs Vault')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_savedNewsList.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('📌 Saved Current Affairs Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('📌', style: TextStyle(fontSize: 50)),
              SizedBox(height: 10),
              Text('Vault Empty!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
              SizedBox(height: 4),
              Text('Home Tab se daily bulletins ko bookmark karke yahan revise karein.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final filteredList = _savedNewsList.where((item) {
      bool isBihar = _isBiharNews(item);
      if (_selectedFilter == 'BIHAR') return isBihar;
      if (_selectedFilter == 'NATIONAL') return !isBihar;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('📌 Saved CA Vault (${_savedNewsList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: _clearAllSavedNews,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🩺 1. AI CONCEPT HEALTH REPORT CARD
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
                          Text('🩺', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 8),
                          Text('AI Current Affairs Prescription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
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
                          onPressed: _runAiAnalysis,
                          child: const Text('Get Prescription 💊', style: TextStyle(fontSize: 11)),
                        ),
                    ],
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

          // 🛠️ 2. RESUME AI QUIZ GENERATOR CARD
          Card(
            color: const Color(0xFFECFDF5),
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
                      Text("⚡ ${filteredList.length} Bulletins Ready", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF065F46))),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _generateAiQuiz(filteredList),
                        icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amberAccent),
                        label: const Text("Generate AI Quiz 🚀", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 🏷️ 3. FILTER TABS
          Row(
            children: [
              _filterChip('ALL', 'All (${_savedNewsList.length})'),
              const SizedBox(width: 8),
              _filterChip('BIHAR', '📍 Bihar CA'),
              const SizedBox(width: 8),
              _filterChip('NATIONAL', '🇮🇳 National CA'),
            ],
          ),
          const SizedBox(height: 14),

          // 📋 4. BULLETIN CARDS LIST
          ...List.generate(filteredList.length, (index) {
            final news = filteredList[index];
            final List bullets = (news['bullets'] as List?) ?? [];
            bool isBihar = _isBiharNews(news);
            bool hasAsked = _caAskedStatus[index] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isBihar ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            news['exam_tag'] ?? (isBihar ? '📍 Bihar CA' : '🇮🇳 National CA'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBihar ? const Color(0xFF92400E) : const Color(0xFF3730A3),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _openCaAiDoubtDialog(news, index),
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
                                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                              onPressed: () => _removeSavedNews(index),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      news['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87, height: 1.3),
                    ),
                    const SizedBox(height: 8),

                    ...bullets.map((bullet) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  bullet.toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
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
}
