import 'package:flutter/material.dart';
import '../services/knowledge_base_service.dart';
import '../services/ai_explainer_service.dart';
import '../services/ai_data_disclosure_service.dart';
import '../widgets/report_ai_response_button.dart';

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
  String _activeEngine = "☁️ Cloud AI (question/context sent to AI service)";
  bool _isConsentPending = false;
  String _retrievedContext = "";
  List<Map<String, String>> _messages = [];

  // 🚀 Core Execution Pipeline (SQLite RAG + Inference)
  Future<void> _processQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isLoading || _isConsentPending) return;

    setState(() => _isConsentPending = true);
    final consented = await AiDataDisclosureService.requireConsent(context);
    if (!mounted) return;
    setState(() => _isConsentPending = false);
    if (!consented) return;

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

      // 2. Inference runs through the server-side AI proxy.
      final aiResponse = await _fetchAiInference(query, contextText);

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

  Future<String> _fetchAiInference(String question, String context) {
    return AiExplainerService.answerWithContext(
      question: question,
      context: context,
    );
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
                final messageText = msg['text'] ?? '';
                final isGeneratedAnswer = !isUser &&
                    !messageText.startsWith('❌ Error generating response:');
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          messageText,
                          style: TextStyle(
                            color: isUser ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (isGeneratedAnswer)
                        ReportAiResponseButton(
                          response: messageText,
                          source: 'ai_doubt_tutor',
                          isDarkMode: widget.isDarkMode,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          if (_isLoading || _isConsentPending)
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
