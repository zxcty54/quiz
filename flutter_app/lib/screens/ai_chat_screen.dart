import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _isOfflineModelReady = false;

  @override
  void initState() {
    super.initState();
    _verifyOfflineEngine();
  }

  Future<void> _verifyOfflineEngine() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final localModel = File('${appDocDir.path}/gemma-2-2b-it-Q4_K_M.gguf');
    final devModel = File('/storage/emulated/0/Download/gemma-2-2b-it-Q4_K_M.gguf');

    final bool hasModel = await localModel.exists() || await devModel.exists();
    if (mounted) {
      setState(() {
        _isOfflineModelReady = hasModel;
      });
    }
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

    try {
      // 1. Local SQLite FTS5 Database Retrieval (0ms Internet Required)
      final dbStopwatch = Stopwatch()..start();
      final chunks = await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 3);
      dbStopwatch.stop();

      String formattedResponse = "";

      if (chunks.isNotEmpty) {
        // 2. Local Knowledge Base Synthesizer
        formattedResponse = "⚡ **Offline Textbook Match (${dbStopwatch.elapsedMilliseconds}ms):**\n\n";
        for (int i = 0; i < chunks.length; i++) {
          formattedResponse += "${chunks[i]}\n\n";
        }
      } else {
        formattedResponse = "⚠️ Local database me '${query}' se related direct textbook reference nahi mila.\n\n"
            "💡 **Tip:** Science ya General Studies ke topics search karein (e.g. Mitochondria, Cell Wall, ATP, Plasma Membrane).";
      }

      setState(() {
        _messages.add({
          "role": "assistant",
          "text": formattedResponse.trim(),
          "db_time": "${dbStopwatch.elapsedMilliseconds}ms",
          "mode": _isOfflineModelReady ? "Offline AI Engine" : "Offline DB Index",
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": "❌ Offline Engine Error: $e",
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Exam Tutor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text("100% Offline Mode (Zero Internet)", style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        Icon(Icons.offline_bolt_rounded, size: 52, color: Colors.blue.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "Offline Knowledge Base Active",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Koi bhi science ya exam topic type karein (e.g. Mitochondria)",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                              if (msg.containsKey('db_time')) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 12, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      "DB Fetch: ${msg['db_time']}",
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
                      hintText: "Offline search (e.g. Mitochondria, Cell Wall)...",
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
