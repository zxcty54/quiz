import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/knowledge_base_service.dart';

class AiDoubtScreen extends StatefulWidget {
  final bool isDarkMode;
  const AiDoubtScreen({super.key, this.isDarkMode = false});

  @override
  State<AiDoubtScreen> createState() => _AiDoubtScreenState();
}

class _AiDoubtScreenState extends State<AiDoubtScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  String _activeEngine = "Checking Engine...";
  String _retrievedContext = "";
  List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _checkEngineMode();
  }

  // 🔍 Check whether Local Model exists in Downloads folder or fallback to Groq
  Future<void> _checkEngineMode() async {
    const localModelPath = '/storage/emulated/0/Download/gemma-2-2b-it-Q4_K_M.gguf';
    final hasLocalModel = await File(localModelPath).exists();

    setState(() {
      if (hasLocalModel) {
        _activeEngine = "📱 Local On-Device (Gemma-2B)";
      } else {
        _activeEngine = "⚡ Cloud Fallback (Groq Fast Testing)";
      }
    });
  }

  // 🚀 Core Execution Pipeline (SQLite RAG + Inference)
  Future<void> _processQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"sender": "user", "text": query});
      _isLoading = true;
      _retrievedContext = "";
      _queryController.clear();
    });

    try {
      // 1. SQLite FTS5 Database Search (Local Retrieval)
      final stopwatch = Stopwatch()..start();
      final chunks = await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 2);
      stopwatch.stop();

      final contextText = chunks.isNotEmpty ? chunks.join("\n---\n") : "No direct textbook match found.";
      
      setState(() {
        _retrievedContext = "Retrieved in ${stopwatch.elapsedMilliseconds}ms:\n$contextText";
      });

      // 2. Inference Execution (Cloud Groq Testing Pipeline)
      final aiResponse = await _fetchGroqInference(query, contextText);

      setState(() {
        _messages.add({"sender": "ai", "text": aiResponse});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"sender": "ai", "text": "❌ Error generating response: $e"});
        _isLoading = false;
      });
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<String> _fetchGroqInference(String question, String context) async {
    const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    
    // Assembled Master RAG Prompt
    final prompt = """
You are an expert exam tutor for BPSC/SSC candidates.
Explain the answer in clear, crystal-clear Hinglish using the context provided if relevant.
Keep explanation step-by-step with zero fluff.

Context:
$context

Question:
$question
""";

    if (groqApiKey.isEmpty) {
      return "⚠️ GROQ_API_KEY dart-define secret missing. Context retrieved:\n$context";
    }

    final response = await http.post(
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
      headers: {
        "Authorization": "Bearer $groqApiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "llama-3.1-8b-instant",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] ?? "No response generated.";
    } else {
      return "API Error (${response.statusCode}): ${response.body}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("AI Exam Tutor & Doubts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_activeEngine, style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
          ],
        ),
      ),
      body: Column(
        children: [
          // 📄 Retrieved Chunks Accordion Box
          if (_retrievedContext.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                "📚 Context: ${_retrievedContext.substring(0, _retrievedContext.length > 180 ? 180 : _retrievedContext.length)}...",
                style: const TextStyle(fontSize: 11, color: Colors.brown),
              ),
            ),

          // 💬 Chat Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // ✍️ Input Bar
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
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: "Koi bhi science/GS sawal puchein (e.g. Mitochondria)...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _processQuery(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                  onPressed: _processQuery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
