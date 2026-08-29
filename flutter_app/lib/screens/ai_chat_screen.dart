import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // 🧹 Clean boilerplate from local database chunks
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

  // 🧠 Autonomous AI Reasoning & Explanation Engine
  Future<String> _processWithAiBrain(String userDoubt) async {
    const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    const String groqApiKey2 = String.fromEnvironment('GROQ_API_KEY2', defaultValue: '');
    final activeKey = groqApiKey.isNotEmpty ? groqApiKey : groqApiKey2;

    // 1. Fetch relevant factual context from local SQLite
    final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(userDoubt, limit: 3);
    final cleanFacts = _cleanChunks(rawChunks);
    final String contextText = cleanFacts.isNotEmpty ? cleanFacts.join("\n\n") : "General science concepts";

    // 2. Pure Cloud AI Agent Execution (If API key injected)
    if (activeKey.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {
            "Authorization": "Bearer $activeKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "llama-3.1-8b-instant",
            "messages": [
              {
                "role": "system",
                "content": """
You are an expert AI Study Agent & Exam Tutor for BPSC, SSC, Railway & Competitive Exams.

BEHAVIOR RULES:
1. NATURAL CONVERSATION: If the user greets (hi, hello, namaste) or chats casually, reply politely and casually in friendly Hinglish like a real tutor. Do NOT dump study notes.
2. CONCEPT EXPLANATION: If the user asks ANY academic doubt or complex biological/scientific mechanism, explain it clearly step-by-step in easy Hinglish.
3. CONTEXT INTEGRATION: Use the provided Reference Context to ensure 100% factual accuracy.
4. FORMATTING: Use concise bullet points, bold key terms, and exam takeaways.
"""
              },
              {
                "role": "user",
                "content": """
[REFERENCE DATABASE CONTEXT]:
$contextText

[STUDENT DOUBT]:
$userDoubt
"""
              }
            ],
            "temperature": 0.2,
            "max_tokens": 500,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return data['choices'][0]['message']['content'] ?? "";
        }
      } catch (_) {}
    }

    // 3. Fallback Offline Engine (Zero Internet)
    final lower = userDoubt.toLowerCase().trim();
    if (['hi', 'hello', 'hey', 'namaste', 'kaise ho', 'help'].contains(lower)) {
      return "Namaste! Mai aapka AI Study Companion hoon. 📚\n\nAap Biology, Physics, Chemistry ya GS ka koi bhi topic pooch sakte hain (jaise: *Ribosomes, Mitochondria, ATP, Cell Wall*).";
    }

    if (cleanFacts.isNotEmpty) {
      return "📚 **Authentic Notes Summary:**\n\n" + cleanFacts.map((c) => "• ${c.trim()}").join("\n\n");
    }

    return "⚠️ Is topic par local notes me direct match nahi mila. Kripya specific keyword (jaise *Ribosome, Lysosome, DNA*) likhein.";
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
    final reply = await _processWithAiBrain(query);
    stopwatch.stop();

    setState(() {
      _messages.add({
        "role": "assistant",
        "text": reply.trim(),
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
                Icon(Icons.bolt_rounded, size: 12, color: Colors.greenAccent),
                SizedBox(width: 3),
                Text("Smart Reasoning & Knowledge Engine", style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                          "Ask Any Academic Doubt",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Type casually or ask complex science mechanisms...",
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
                                      "Response: ${msg['time']}",
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
                    decoration: InputDecoration(
                      hintText: "Ask doubt (e.g. Ribosome kya hai, hi)...",
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
