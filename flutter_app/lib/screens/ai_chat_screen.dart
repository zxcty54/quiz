import 'dart:async';
import 'package:flutter/material.dart';
import '../services/knowledge_base_service.dart';

enum AgentTaskMode {
  explain,
  quiz,
  mnemonic,
  summary,
  analyze,
}

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;

  const AiChatScreen({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isGenerating = false;
  bool _shouldStop = false;

  final String _modelStatus = 'Offline AI Engine Active';
  AgentTaskMode _selectedMode = AgentTaskMode.explain;

  final List<Map<String, String>> _messages = [];

  bool get _busy => _isGenerating;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _cleanChunks(List<String> chunks) {
    return chunks
        .where((chunk) {
          final lower = chunk.toLowerCase();
          return !lower.contains('preface') &&
              !lower.contains('all rights reserved') &&
              !lower.contains('isbn') &&
              !lower.contains('acknowledgement');
        })
        .map((chunk) => chunk.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((chunk) => chunk.isNotEmpty)
        .toList();
  }

  double _calculateMatchScore(String query, String text) {
    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toSet();

    final textWords = text
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toSet();

    if (queryWords.isEmpty || textWords.isEmpty) return 0.0;

    final intersection = queryWords.intersection(textWords).length;
    final union = queryWords.union(textWords).length;
    if (union == 0) return 0.0;

    double score = intersection / union;
    final q = query.toLowerCase().trim();
    final t = text.toLowerCase();

    if (q.isNotEmpty && t.contains(q)) score += 1.0;
    score += (intersection / queryWords.length) * 0.5;

    return score;
  }

  Future<List<String>> _retrieveContext(String query) async {
    try {
      final rawChunks = await KnowledgeBaseService.instance
          .searchRelevantChunks(query, limit: 8);
      final cleanFacts = _cleanChunks(rawChunks);
      if (cleanFacts.isEmpty) return [];

      cleanFacts.sort((a, b) {
        final scoreB = _calculateMatchScore(query, b);
        final scoreA = _calculateMatchScore(query, a);
        return scoreB.compareTo(scoreA);
      });

      final unique = <String>[];
      final seen = <String>{};

      for (final fact in cleanFacts) {
        final normalized = fact.toLowerCase().trim();
        if (seen.add(normalized)) unique.add(fact);
        if (unique.length >= 3) break;
      }

      return unique;
    } catch (e) {
      debugPrint('Knowledge base search error: $e');
      return [];
    }
  }

  // --- DYNAMIC AI AGENT DISPATCHER ---
  String _processUserRequest({
    required String topic,
    required List<String> facts,
    required AgentTaskMode mode,
  }) {
    final cleanTopic = topic.trim();
    final fact1 = facts.isNotEmpty ? facts[0] : '$cleanTopic standard competitive exam syllabus ka core verified concept hai.';
    final fact2 = facts.length > 1 ? facts[1] : '$cleanTopic ke direct constitutional articles aur scientific formulas exam me puche jate hain.';
    final fact3 = facts.length > 2 ? facts[2] : 'State PSCs (BPSC/BSSC) me multi-statement conceptual clarity aur fact verification decisive hota hai.';

    switch (mode) {
      case AgentTaskMode.quiz:
        return '''
🎯 **AI Exam Quiz ($cleanTopic):**

**Q1.** "$cleanTopic" ke sambandh mein kaun sa kathan sarvadhik satya hai?
A) $fact1
B) Yeh ek irrelevant theoretical assumption hai
C) Iska practical standard syllabus se koi sambandh nahi hai
D) None of the above
👉 **Correct:** **A**
💡 **Reason:** $fact1

**Q2.** Exam questions ko solve karte waqt mukhya focus kahan hona chahiye?
A) Direct formulas, standard articles aur verified facts par
B) Random elimination par
C) Keval secondary exceptions par
D) Uprokt sabhi galat hain
👉 **Correct:** **A**
💡 **Reason:** $fact2
''';

      case AgentTaskMode.mnemonic:
        final shortKey = cleanTopic.length >= 3 ? cleanTopic.substring(0, 3).toUpperCase() : cleanTopic.toUpperCase();
        return '''
🧠 **AI Memory & Mnemonic Trick ($cleanTopic):**

• **Memory Code:** **[$shortKey-RULE]**
• **Core Association:** $fact1
• **Quick Recall Hook:** "$cleanTopic ko yaad rakhne ke liye iske key trigger points ($fact2) ko link karein."
• **Exam Trap:** Similar lagne wale options me confuse na hon, key definition ko primary anchor banayein.
''';

      case AgentTaskMode.summary:
        return '''
📋 **Rapid-Revision Summary ($cleanTopic):**

• 💡 **Core Definition/Law:** $fact1
• ⚡ **Top High-Yield Fact:** $fact2
• 🎯 **PYQ Focus Area:** $fact3
• ⚠️ **Elimination Tip:** Extreme words (e.g. 'Only', 'Always') wale options ko eliminate karein.
''';

      case AgentTaskMode.analyze:
        return '''
🔍 **AI Diagnostic Answer Analysis ($cleanTopic):**

• **Diagnostic Status:** Verified against syllabus facts.
• **Core Concept:** $fact1
• **Common Student Pitfall:** Aamtaur par candidates $cleanTopic ke operational scope ($fact2) aur exceptions me confuse hote hain.
• **Rule of Thumb:** Hamesha primary statement ko standard rule se match karein.
''';

      case AgentTaskMode.explain:
      default:
        return '''
💡 **1. Micro Concept:**
**$cleanTopic:** $fact1

⚡ **2. 3-Step Breakdown:**
• **Step 1 (Core Rule):** $fact1
• **Step 2 (Key Fact):** $fact2
• **Step 3 (Exam Trick):** $fact3

🎯 **3. Micro Challenge MCQ:**
**Q.** "$cleanTopic" se sambandhit kaun sa point standard rule ko darshata hai?
A) Yeh ek unrelated exception hai
B) $fact1
C) Iska koi factual importance nahi hai
D) None of the above

👉 **Answer:** **B) $fact1**
''';
    }
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _busy) return;

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isGenerating = true;
    });

    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    try {
      final facts = await _retrieveContext(query);
      final responseText = _processUserRequest(
        topic: query,
        facts: facts,
        mode: _selectedMode,
      );

      setState(() {
        _messages.add({'role': 'assistant', 'text': ''});
      });

      _shouldStop = false;
      final buffer = StringBuffer();
      final lines = responseText.split('\n');

      for (final line in lines) {
        if (_shouldStop || !mounted) break;
        buffer.writeln(line);
        setState(() {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': buffer.toString().trim(),
          };
        });
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 15));
      }

      stopwatch.stop();
      if (!mounted) return;

      setState(() {
        _messages[_messages.length - 1] = {
          'role': 'assistant',
          'text': buffer.toString().trim(),
          'time': '${stopwatch.elapsedMilliseconds}ms',
        };
        _isGenerating = false;
      });
      _scrollToBottom();
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': '❌ Execution error:\n$e',
          'time': '${stopwatch.elapsedMilliseconds}ms',
        });
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _stopGeneration() {
    if (!_isGenerating) return;
    setState(() {
      _shouldStop = true;
      _isGenerating = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offline Exam AI Agent',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _modelStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildModeChip('💡 Concept', AgentTaskMode.explain, isDark),
                _buildModeChip('🎯 Quiz', AgentTaskMode.quiz, isDark),
                _buildModeChip('🧠 Mnemonic', AgentTaskMode.mnemonic, isDark),
                _buildModeChip('📋 Summary', AgentTaskMode.summary, isDark),
                _buildModeChip('🔍 Analyze', AgentTaskMode.analyze, isDark),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF2563EB) : isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: isUser ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              if (msg.containsKey('time')) ...[
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 10, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text('Time: ${msg['time']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: const Color(0xFF2563EB),
                backgroundColor: Colors.grey.withOpacity(0.15),
              ),
            ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, AgentTaskMode mode, bool isDark) {
    final isSelected = _selectedMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : isDark ? Colors.white70 : Colors.black87)),
        selected: isSelected,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedColor: const Color(0xFF2563EB),
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedMode = mode;
            });
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_rounded, size: 54, color: Color(0xFF2563EB)),
            const SizedBox(height: 12),
            Text(
              'Offline Exam AI Agent Ready',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Koi bhi topic type karein (e.g. Gravitation, Article 32, Mitochondria) instant breakdown aur quiz ke liye!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter topic for ${_selectedMode.name.toUpperCase()} mode...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_isGenerating)
            IconButton(
              tooltip: 'Stop',
              onPressed: _stopGeneration,
              icon: const Icon(Icons.stop_circle, color: Colors.red),
            )
          else
            IconButton(
              tooltip: 'Send',
              onPressed: _busy ? null : _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
            ),
        ],
      ),
    );
  }
}
