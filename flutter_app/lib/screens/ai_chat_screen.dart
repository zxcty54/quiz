import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Apne project path ke mutabiq service import karein
import 'offline_llm_service.dart';

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
  String _statusMessage = "Checking offline Qwen model...";

  @override
  void initState() {
    super.initState();
    _checkAndAutoLoadModel();
  }

  Future<void> _checkAndAutoLoadModel() async {
    // 1. Check Download folder default path
    const defaultDownloadPath = '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';
    if (await File(defaultDownloadPath).exists()) {
      await _initQwenModel(defaultDownloadPath);
      return;
    }

    // 2. Check internal documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final internalFile = File('${appDir.path}/qwen3-5-2B-Q4_K_M.gguf');
    if (await internalFile.exists()) {
      await _initQwenModel(internalFile.path);
      return;
    }

    // 3. Check SharedPreferences saved path
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('saved_qwen_path');
    if (savedPath != null && File(savedPath).existsSync()) {
      await _initQwenModel(savedPath);
    } else {
      setState(() {
        _statusMessage = "Select Qwen .gguf model";
      });
    }
  }

  Future<void> _pickModelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf', 'bin'],
    );

    if (result != null && result.files.single.path != null) {
      final pickedPath = result.files.single.path!;
      await _initQwenModel(pickedPath);
    }
  }

  Future<void> _initQwenModel(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Loading Qwen GGUF into RAM...";
    });

    try {
      await OfflineLlmAgentService.instance.initEngine(modelPath: path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_qwen_path', path);

      setState(() {
        _isModelLoaded = true;
        _isLoading = false;
        _statusMessage = "Qwen 2B GGUF Active (Offline)";
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
        context: "BPSC / BSSC Exam Preparation Study Guide",
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
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200;
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
                color: _isModelLoaded ? Colors.greenAccent : Colors.white70,
              ),
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
                    child: Text(
                      _isModelLoaded
                          ? "Qwen 2B Ready! Ask any question..."
                          : "Tap folder icon to select .gguf model",
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isUser ? Colors.blueAccent : cardBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isUser ? Colors.white : textColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
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
                  Text("Qwen is formulating analysis...", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
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
                      hintText: "Type any question...",
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
