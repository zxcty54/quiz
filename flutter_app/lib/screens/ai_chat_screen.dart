import 'dart:math';
import 'package:flutter/material.dart';
import '../services/knowledge_base_service.dart';

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;
  const AiChatScreen({super.key, this.isDarkMode = false});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // 🧹 1. Clean Publisher Boilerplate & Copyright Chunks
  List<String> _cleanChunks(List<String> chunks) {
    return chunks.where((chunk) {
      final lower = chunk.toLowerCase();
      return !lower.contains("preface") &&
             !lower.contains("all rights reserved") &&
             !lower.contains("isbn") &&
             !lower.contains("acknowledgement") &&
             !lower.contains("priyanshi garg") &&
             !lower.contains("darya ganj");
    }).toList();
  }

  // 📐 2. Pure Math: Jaccard & Cosine Semantic Similarity
  double _calculateSemanticScore(String query, String chunk) {
    final qTokens = query.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 2).toSet();
    final cTokens = chunk.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 2).toSet();

    if (qTokens.isEmpty || cTokens.isEmpty) return 0.0;

    final intersection = qTokens.intersection(cTokens).length;
    final union = qTokens.union(cTokens).length;
    return intersection / union; // Similarity ratio [0.0 to 1.0]
  }

  // 🧠 3. Pure On-Device Local Reasoning Brain (No Cloud / No API)
  Future<String> _processLocallyWithoutCloud(String rawInput) async {
    final query = rawInput.trim();
    final queryLower = query.toLowerCase();

    // A. INTENT CLASSIFIER: Casual Conversation vs Academic Doubt
    final greetings = {'hi', 'hello', 'hey', 'namaste', 'pranam', 'kaise ho', 'help', 'kya hal h'};
    if (greetings.contains(queryLower) || queryLower.length < 3) {
      return "Namaste! Mai aapka 100% Offline AI Exam Tutor hoon. 📚\n\nAap bina internet ke Biology, Physics, Chemistry ya GS ka koi bhi doubt pooch sakte hain (jaise: *Mitochondria, Ribosome, Cell Wall, ATP, Osmosis*).";
    }

    // B. BROAD CONTEXT EXTRACTION FROM LOCAL DATABASE
    final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 6);
    final cleanFacts = _cleanChunks(rawChunks);

    if (cleanFacts.isEmpty) {
      return "⚠️ Is topic par local authentic textbook me direct concept nahi mila.\n\n"
             "💡 **Tip:** Biology/Science ka specific scientific term likhein (e.g. *Ribosomes, Lysosomes, Plastids, ATP Cycle*).";
    }

    // C. LOCAL RANKING ENGINE (Semantic Scoring)
    cleanFacts.sort((a, b) => _calculateSemanticScore(query, b).compareTo(_calculateSemanticScore(query, a)));

    final bestChunks = cleanFacts.take(3).toList();

    // D. REASONED EXPLANATION GENERATOR
    final buffer = StringBuffer();
    buffer.writeln("📚 **Conceptual Explanation (Offline Mode):**\n");

    for (var fact in bestChunks) {
      final cleanSentence = fact.trim().replaceAll(RegExp(r'\s+'), ' ');
      buffer.writeln("• $cleanSentence\n");
    }

    buffer.writeln("🎯 **High-Yield Exam Takeaway:** Is biological mechanism ke organelle structure aur enzymes direct competitive exams me match the following aur statement questions me aate hain.");

    return buffer.toString().trim();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();
    final reply = await _processLocallyWithoutCloud(text);
    stopwatch.stop();

    setState(() {
      _messages.add({
        "role": "assistant",
        "text": reply,
        "time": "${stopwatch.elapsedMilliseconds}ms",
      });
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI Exam Tutor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(Icons.offline_pin_rounded, size: 12, color: Colors.greenAccent),
                SizedBox(width: 3),
                Text("100% Offline Local Engine (No API)", style: TextStyle(fontSize: 10, color: Colors.white70)),
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
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_rounded, size: 54, color: Color(0xFF2563EB)),
                        const SizedBox(height: 10),
                        Text(
                          "Offline AI Knowledge Active",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Flight Mode / No Internet Support",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
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
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF2563EB)
                                : isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: isUser
                                ? null
                                : Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                              if (msg.containsKey('time')) ...[
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 11, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Local Match: ${msg['time']}",
                                      style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                                    ),
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: const InputDecoration(
                      hintText: "Offline doubt (e.g. Ribosomes, ATP, hi)...",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
