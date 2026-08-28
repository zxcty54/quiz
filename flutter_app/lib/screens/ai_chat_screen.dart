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

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": query});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      // 1. Local SQLite Database FTS5 Query (Local Context Retrieval)
      final dbStopwatch = Stopwatch()..start();
      final chunks = await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 2);
      dbStopwatch.stop();

      final contextText = chunks.isNotEmpty 
          ? chunks.join("\n\n---\n\n") 
          : "Direct textbook reference not matched.";

      // 2. Groq Cloud Engine Inference (Testing Prompt)
      const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
      
      String aiResponse = "";
      if (groqApiKey.isNotEmpty) {
        final res = await http.post(
          Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
          headers: {
            "Authorization": "Bearer $groqApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "llama-3.1-8b-instant",
            "messages": [
              {
                "role": "system",
                "content": "You are an expert exam tutor for BPSC/SSC aspirants. Explain in concise, step-by-step Hinglish using the provided textbook context."
              },
              {
                "role": "user",
                "content": "Textbook Context:\n$contextText\n\nQuestion:\n$query"
              }
            ],
            "temperature": 0.3,
            "max_tokens": 400,
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          aiResponse = data['choices'][0]['message']['content'] ?? "No response generated.";
        } else {
          aiResponse = "API Error (${res.statusCode}): ${res.body}";
        }
      } else {
        // Agar API key nahi hai toh local retrieved context hi display hoga
        aiResponse = "📚 Local DB Matched Chunks (${dbStopwatch.elapsedMilliseconds}ms):\n\n$contextText";
      }

      setState(() {
        _messages.add({
          "role": "assistant",
          "text": aiResponse,
          "db_time": "${dbStopwatch.elapsedMilliseconds}ms"
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "text": "❌ Error: $e"});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ask Doubt / DB Chat Test", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text("Koi bhi topic puchein (e.g. Mitochondria, Cell Wall)", style: TextStyle(color: Colors.grey)),
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
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                              if (msg.containsKey('db_time')) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "⚡ DB Fetch: ${msg['db_time']}",
                                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Type topic (e.g. Mitochondria, ATP)...",
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
