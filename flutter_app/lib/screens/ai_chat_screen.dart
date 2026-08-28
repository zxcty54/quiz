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

  Future<void> _sendMessage() async {
    final rawQuery = _textController.text.trim();
    if (rawQuery.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": rawQuery});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final queryLower = rawQuery.toLowerCase();

    // 🤖 1. Handle Greetings & Casual queries without searching book chunks
    if (queryLower == 'hi' ||
        queryLower == 'hello' ||
        queryLower == 'hey' ||
        queryLower == 'namaste' ||
        queryLower == 'help') {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": "Namaste! Mai aapka Offline BPSC/SSC AI Tutor hoon. 📚\n\nAap Science, History, Geography ya Polity ka koi bhi concept ya doubt pooch sakte hain (jaise: *Mitochondria, Cell Division, 1857 Kranti, Fundamental Rights*).",
          "db_time": "0ms",
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      // 2. Local SQLite FTS5 Database Retrieval
      final dbStopwatch = Stopwatch()..start();
      final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(rawQuery, limit: 3);
      dbStopwatch.stop();

      final chunks = _cleanChunks(rawChunks);
      String formattedResponse = "";

      if (chunks.isNotEmpty) {
        // Clean structured concept output
        formattedResponse = "📖 **Key Concept & Notes:**\n\n";
        for (int i = 0; i < chunks.length; i++) {
          formattedResponse += "• ${chunks[i].trim()}\n\n";
        }
      } else {
        formattedResponse = "⚠️ Is topic ('$rawQuery') par exact match nahi mila.\n\n"
            "💡 **Tip:** Specific topic naam type karein (jaise: *Mitochondria, ATP, Lysosome, Ribosome*).";
      }

      setState(() {
        _messages.add({
          "role": "assistant",
          "text": formattedResponse.trim(),
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
                          "Poochhein: Mitochondria, Cell Wall, ATP, etc.",
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
                              if (msg.containsKey('db_time') && msg['db_time'] != '0ms') ...[
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
                      hintText: "Offline topic (e.g. Mitochondria)...",
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
