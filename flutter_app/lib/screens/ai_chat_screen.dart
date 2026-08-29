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

  List<String> _cleanChunks(List<String> chunks) {
    return chunks.where((chunk) {
      final lower = chunk.toLowerCase();
      return !lower.contains("preface") &&
          !lower.contains("all rights reserved") &&
          !lower.contains("isbn") &&
          !lower.contains("acknowledgement") &&
          !lower.contains("priyanshi garg");
    }).toList();
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
    return intersection / union;
  }

  Future<String> _processOfflineQuery(String rawInput) async {
    final query = rawInput.trim();
    final queryLower = query.toLowerCase();

    // 1. Natural Intent Handling
    final casualGreetings = {
      'hi',
      'hello',
      'hey',
      'namaste',
      'pranam',
      'kaise ho',
      'help',
      'kya haal hai'
    };

    if (casualGreetings.contains(queryLower) || queryLower.length < 3) {
      return "Namaste! Mai aapka 100% Offline AI Study Tutor hoon. 📚\n\nAap bina internet ke Biology, Physics, Chemistry ya GS ka koi bhi topic pooch sakte hain (jaise: *Mitochondria, Ribosome, Cell Wall, ATP, Lysosome*).";
    }

    // 2. Fetch Relevant Context from Local SQLite Database
    final rawChunks =
        await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 5);
    final cleanFacts = _cleanChunks(rawChunks);

    if (cleanFacts.isEmpty) {
      return "⚠️ Is topic par local textbook database mein direct match nahi mila.\n\n"
          "💡 **Tip:** Specific scientific keyword likhein (jaise *Ribosome, Mitochondria, Plastids, DNA*).";
    }

    // 3. Rank Chunks Locally
    cleanFacts.sort((a, b) =>
        _calculateMatchScore(query, b).compareTo(_calculateMatchScore(query, a)));

    final bestFacts = cleanFacts.take(3).toList();

    // 4. Construct Formatted Output
    final buffer = StringBuffer();
    buffer.writeln("📚 **Conceptual Notes (100% Offline):**\n");

    for (var fact in bestFacts) {
      final cleanText = fact.trim().replaceAll(RegExp(r'\s+'), ' ');
      buffer.writeln("• $cleanText\n");
    }

    buffer.writeln("🎯 **High-Yield Exam Takeaway:** Is topic se related organelle function aur scientific terms direct objective questions mein aate hain.");

    return buffer.toString().trim();
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": query});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();
    final reply = await _processOfflineQuery(query);
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
            Text("AI Exam Tutor",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Icon(Icons.offline_pin_rounded, size: 12, color: Colors.greenAccent),
                SizedBox(width: 4),
                Text("100% Offline Engine Active",
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
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
                        const Icon(Icons.psychology_rounded,
                            size: 54, color: Color(0xFF2563EB)),
                        const SizedBox(height: 10),
                        Text(
                          "Offline Study Engine Ready",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Bina internet ke koi bhi concept search karein...",
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
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85),
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
                                    const Icon(Icons.flash_on_rounded,
                                        size: 11, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Time: ${msg['time']}",
                                      style: const TextStyle(
                                          fontSize: 9.5, color: Colors.grey),
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
                      hintText: "Offline doubt likhein (e.g. Ribosome, hi)...",
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
