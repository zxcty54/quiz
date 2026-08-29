import 'package:flutter/material.dart';
import '../services/knowledge_base_service.dart';
import '../services/offline_llm_service.dart';

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
  bool _engineReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrapOfflineEngine();
  }

  Future<void> _bootstrapOfflineEngine() async {
    final ready = await OfflineLlmService.instance.initializeEngine();
    if (mounted) {
      setState(() {
        _engineReady = ready;
      });
    }
  }

  List<String> _cleanChunks(List<String> chunks) {
    return chunks.where((chunk) {
      final lower = chunk.toLowerCase();
      return !lower.contains("preface") &&
             !lower.contains("all rights reserved") &&
             !lower.contains("isbn") &&
             !lower.contains("acknowledgement");
    }).toList();
  }

  Future<void> _sendMessage() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": rawText});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    // 1. Fetch Local DB Context Chunks
    final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(rawText, limit: 2);
    final cleanFacts = _cleanChunks(rawChunks);
    final contextString = cleanFacts.isNotEmpty ? cleanFacts.join("\n") : "General concepts";

    // 2. Run Local LLM Inference
    String aiReply = "";
    if (_engineReady) {
      aiReply = await OfflineLlmService.instance.generateResponse(
        userPrompt: rawText,
        contextFacts: contextString,
      );
    } else {
      // Fallback if GGUF is missing
      aiReply = cleanFacts.isNotEmpty
          ? "📚 **Local DB Summary:**\n\n" + cleanFacts.map((e) => "• $e").join("\n\n")
          : "Gemma model file storage me nahi mili. Direct match nahi mila.";
    }

    stopwatch.stop();

    setState(() {
      _messages.add({
        "role": "assistant",
        "text": aiReply,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Exam Tutor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _engineReady ? const Color(0xFF16A34A) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _engineReady ? "100% Offline (Gemma 2B Engine Active)" : "Model Loading / DB Engine",
                  style: TextStyle(
                    fontSize: 10,
                    color: _engineReady ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.offline_bolt_rounded, size: 52, color: Color(0xFF2563EB)),
                        const SizedBox(height: 10),
                        Text(
                          "Local On-Device Engine",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Direct CPU execution via Llama.cpp & Gemma-2B",
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
                            border: isUser ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
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
                                    const Icon(Icons.speed_rounded, size: 11, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Inference: ${msg['time']}",
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
                      hintText: "Offline doubt likhein...",
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
