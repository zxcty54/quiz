import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
  bool _isModelLoaded = false;
  String _modelStatus = "Initializing On-Device AI Engine...";

  @override
  void initState() {
    super.initState();
    _initLocalGemmaModel();
  }

  // 🔍 1. Load Local GGUF Model from Phone Storage into RAM/NPU
  Future<void> _initLocalGemmaModel() async {
    try {
      final devModel = File('/storage/emulated/0/Download/gemma-2-2b-it-Q4_K_M.gguf');
      final appDocDir = await getApplicationDocumentsDirectory();
      final localModel = File('${appDocDir.path}/gemma-2-2b-it-Q4_K_M.gguf');

      String? activePath;
      if (await devModel.exists()) {
        activePath = devModel.path;
      } else if (await localModel.exists()) {
        activePath = localModel.path;
      }

      if (activePath != null) {
        await FlutterGemmaPlugin.instance.init(
          maxTokens: 512,
          temperature: 0.3,
          randomSeed: 1,
          topK: 1,
        );
        await FlutterGemmaPlugin.instance.loadModel(modelPath: activePath);

        if (mounted) {
          setState(() {
            _isModelLoaded = true;
            _modelStatus = "Gemma-2B On-Device Active (100% Offline)";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _modelStatus = "Model file not found in Downloads. SQLite Fallback Active.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelStatus = "Local Engine Ready (Direct Retrieval Mode)";
        });
      }
    }
  }

  // 🧹 Clean publishers boilerplate
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

  // 🧠 2. Pure On-Device Offline AI Inference Execution
  Future<String> _generateOfflineAiResponse(String rawQuery) async {
    // A. Fetch Context from Local SQLite
    final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(rawQuery, limit: 2);
    final cleanFacts = _cleanChunks(rawChunks);
    final contextText = cleanFacts.isNotEmpty ? cleanFacts.join("\n") : "General concepts";

    // B. If Local Gemma is loaded, run full On-Device Reasoning
    if (_isModelLoaded) {
      final prompt = """
<start_of_turn>system
Aap ek highly intelligent offline BPSC/SSC Science tutor ho.
Niche diye gaye Authentic Reference aur student ke sawaal ko analyze karo.
Agar casual baat ho toh friendly Hinglish me reply do.
Agar academic doubt ho toh concept ko easy points me step-by-step explain karo.

[AUTHENTIC REFERENCE]:
$contextText
<end_of_turn>
<start_of_turn>user
$rawQuery
<end_of_turn>
<start_of_turn>model
""";

      try {
        final response = await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
        if (response != null && response.trim().isNotEmpty) {
          return response.trim();
        }
      } catch (_) {}
    }

    // C. Graceful Fallback if model binary is loading
    if (cleanFacts.isNotEmpty) {
      return "📚 **Authentic Notes Summary (Offline Engine):**\n\n" +
          cleanFacts.map((c) => "• ${c.trim()}").join("\n\n");
    }

    return "⚠️ Is topic par local textbook me direct record nahi mila. Specific scientific term (jaise *Ribosome, Mitochondria, ATP*) likhkar dekhein.";
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
    final reply = await _generateOfflineAiResponse(query);
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
                    color: _isModelLoaded ? const Color(0xFF16A34A) : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _modelStatus,
                  style: TextStyle(
                    fontSize: 10,
                    color: _isModelLoaded ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
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
                        const Icon(Icons.offline_bolt_rounded, size: 52, color: Color(0xFF2563EB)),
                        const SizedBox(height: 10),
                        Text(
                          "100% Offline AI Agent Active",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "No internet required. Powered by On-Device Gemma 2B.",
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
                      hintText: "Offline doubt (e.g. Ribosomes, ATP)...",
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
