import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

  // 🧹 Filter out publisher disclaimers, copyright text & ISBN chunks
  List<String> _cleanChunks(List<String> chunks) {
    return chunks.where((chunk) {
      final lower = chunk.toLowerCase();
      return !lower.contains("all rights reserved") &&
             !lower.contains("isbn") &&
             !lower.contains("darya ganj") &&
             !lower.contains("no part of this publication") &&
             !lower.contains("meerut (up)");
    }).toList();
  }

  // 🧠 Pure AI Decision & Synthesis Engine
  Future<String> _executeAiDecisionMaking({
    required String rawUserDoubt,
    required String textbookContext,
  }) async {
    const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

    if (groqApiKey.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {
            "Authorization": "Bearer $groqApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "llama-3.3-70b-versatile",
            "messages": [
              {
                "role": "system",
                "content": """
You are an expert, highly intelligent Science & Exam Tutor for BPSC/BSSC candidates.
The student might ask queries in broken Hinglish, slang, or complex technical terms.

YOUR TASK:
1. Understand the student's exact doubt and intent.
2. Synthesize the provided Textbook Context into a structured, crystal-clear explanation in Hinglish.
3. If the context does not fully cover the mechanism, use your core knowledge to explain it clearly.
4. Highlight high-yield exam takeaways.
"""
              },
              {
                "role": "user",
                "content": """
[AUTHENTIC DATABASE CONTEXT]:
$textbookContext

[STUDENT DOUBT]:
$rawUserDoubt
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

    // Fallback: If offline, structure the direct context cleanly
    if (textbookContext.trim().isNotEmpty) {
      return "📚 **Authentic Notes Summary:**\n\n$textbookContext";
    } else {
      return "Is topic par specific factual data direct match nahi mila. Kripya term verify karein.";
    }
  }

  Future<void> _sendMessage() async {
    final rawQuery = _textController.text.trim();
    if (rawQuery.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": rawQuery});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final dbStopwatch = Stopwatch()..start();
      // 1. Fetch broad textbook context (Raw Query)
      final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(rawQuery, limit: 3);
      dbStopwatch.stop();

      final chunks = _cleanChunks(rawChunks);
      final String contextText = chunks.isNotEmpty ? chunks.join("\n\n") : "General concepts";

      // 2. Pass to AI Brain for Comprehension & Decision Making
      final String aiResponse = await _executeAiDecisionMaking(
        rawUserDoubt: rawQuery,
        textbookContext: contextText,
      );

      setState(() {
        _messages.add({
          "role": "assistant",
          "text": aiResponse.trim(),
          "db_time": "${dbStopwatch.elapsedMilliseconds}ms",
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": "❌ Error: $e",
          "db_time": "0ms",
        });
        _isLoading = false;
      });
    }
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
                Icon(Icons.bolt_rounded, size: 13, color: Colors.greenAccent),
                SizedBox(width: 3),
                Text("AI Decision & Reasoning Engine Active", style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                          "Ask Any Complex Doubt",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Natural language, Hinglish or complex mechanisms...",
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
                              if (msg.containsKey('db_time') && msg['db_time'] != '0ms') ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 12, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      "Context DB: ${msg['db_time']}",
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                      hintText: "Apna doubt likhein...",
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
