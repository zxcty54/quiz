import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktester/services/offline_llm_service.dart';
import 'package:mocktester/models/duolingo_payload.dart';
import 'package:mocktester/widgets/duolingo_card.dart';

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;

  const AiChatScreen({Key? key, this.isDarkMode = false}) : super(key: key);

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isModelLoaded = false;
  bool _isLoading = false;
  bool _isGenerating = false;
  String _statusMessage = "Tap folder icon to select .gguf model";
  String _currentModelName = "";

  @override
  void initState() {
    super.initState();
    _checkSavedModel();
  }

  Future<void> _checkSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('saved_qwen_path');
    if (savedPath != null && await File(savedPath).exists()) {
      _initQwenModel(savedPath);
    }
  }

  Future<void> _pickModelFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Opening file picker...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = _isModelLoaded ? "$_currentModelName Active" : "Selection cancelled";
        });
        return;
      }

      final pickedPath = result.files.single.path!;

      if (!pickedPath.toLowerCase().endsWith('.gguf')) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Galat format: sirf .gguf select karein";
        });
        return;
      }

      await _initQwenModel(pickedPath);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Picker error: $e";
      });
    }
  }

  Future<void> _initQwenModel(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Reading file directly from storage...";
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception("File path read nahi ho raha: $path");
      }

      final fileName = path.split('/').last;
      final sizeMB = (await file.length()) / (1024 * 1024);

      setState(() {
        _statusMessage = "Allocating ${sizeMB.toStringAsFixed(0)}MB to engine...";
      });

      await Future.delayed(const Duration(milliseconds: 150));

      // Manual model loading via official service
      await OfflineLlmAgentService.instance.loadModelManually(modelPath: path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_qwen_path', path);

      setState(() {
        _isModelLoaded = true;
        _isLoading = false;
        _currentModelName = fileName;
        _statusMessage = "$fileName Active (Offline)";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isModelLoaded = false;
        _statusMessage = "Load failed: $e";
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || !_isModelLoaded || _isGenerating) return;

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final String response = await OfflineLlmAgentService.instance.executeLlmAgent(
        userInput: text,
        context: "BPSC / BSSC Exam General Studies Concept Revision",
        task: LlmTaskType.duolingoExplanation,
      );

      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Inference Error: $e", isUser: false));
        _isGenerating = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Offline AI Assistant", style: TextStyle(fontSize: 16)),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 11,
                color: _isModelLoaded
                    ? Colors.greenAccent
                    : (_statusMessage.contains("failed") || _statusMessage.contains("error")
                        ? Colors.redAccent
                        : Colors.white70),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: "Select Model (.gguf)",
            onPressed: _isLoading ? null : _pickModelFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _isModelLoaded
                            ? "$_currentModelName Ready! Real-life observation ya concept enter karein..."
                            : _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];

                      if (msg.isUser) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      // Render structured pedagogical card
                      return DuolingoCard(
                        payload: DuolingoPayload.fromLlmText(msg.text),
                        isDarkMode: isDark,
                      );
                    },
                  ),
          ),
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(
                    "AI Agent is formulating card...",
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isModelLoaded && !_isGenerating,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: _isModelLoaded ? "Type concept or observation..." : "Select model first...",
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: (_isModelLoaded && !_isGenerating) ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
