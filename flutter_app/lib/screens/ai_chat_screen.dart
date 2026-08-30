import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/knowledge_base_service.dart';

enum AgentTaskMode { explain, quiz, mnemonic, summary, analyze }

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;
  const AiChatScreen({super.key, this.isDarkMode = false});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const MethodChannel _llmChannel = MethodChannel('com.mocktester.ai/offline_llm');

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isGenerating = false;

  String _modelStatus = 'MediaPipe Model Not Loaded';
  AgentTaskMode _selectedMode = AgentTaskMode.explain;
  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadModel() async {
    if (_busy) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      if (pickedPath == null || !File(pickedPath).existsSync()) {
        _showError('Valid model path nahi mila.');
        return;
      }

      setState(() {
        _isModelLoading = true;
        _modelStatus = 'Loading MediaPipe Flatbuffer Engine...';
      });

      final bool success = await _llmChannel.invokeMethod('initModel', {'modelPath': pickedPath});

      if (!mounted) return;
      if (success) {
        setState(() {
          _isModelLoaded = true;
          _isModelLoading = false;
          _modelStatus = 'Qwen 2.5 Active (MediaPipe GPU/NPU)';
        });
        _showSuccess('🟢 On-device AI ready!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelLoaded = false;
        _isModelLoading = false;
        _modelStatus = 'Load Error';
      });
      _showError('Init Error: $e');
    }
  }

  String _buildPrompt(String userInput, String context) {
    return '''
You are a Duolingo-style structured learning AI tutor for competitive exams.
Explain the topic strictly following this 3-part format:
1. 💡 Micro Concept (1-line definition)
2. ⚡ 3-Step Breakdown (3 short bullet points)
3. 🎯 1 Micro Challenge MCQ with answer

Context: $context
User Topic: $userInput
''';
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _busy) return;

    if (!_isModelLoaded) {
      _showError('Pehle upar 📁 icon se .task/.bin model load karein.');
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isGenerating = true;
    });

    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    try {
      final rawChunks = await KnowledgeBaseService.instance.searchRelevantChunks(query, limit: 2);
      final context = rawChunks.join(' ');
      final prompt = _buildPrompt(query, context);

      final String response = await _llmChannel.invokeMethod('generate', {'prompt': prompt});

      stopwatch.stop();
      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': response.trim(),
          'time': '${stopwatch.elapsedMilliseconds}ms (MediaPipe INT4)',
        });
        _isGenerating = false;
      });
      _scrollToBottom();
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': '❌ Generation Error: $e',
          'time': '${stopwatch.elapsedMilliseconds}ms',
        });
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
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
            const Text('Autonomous AI Exam Agent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(_isModelLoaded ? Icons.circle : Icons.circle_outlined, size: 8, color: _isModelLoaded ? Colors.greenAccent : Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(_modelStatus, style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Load MediaPipe Task Model',
            onPressed: _busy ? null : _pickAndLoadModel,
            icon: Icon(_isModelLoaded ? Icons.check_circle : Icons.folder_open, color: _isModelLoaded ? Colors.greenAccent : Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2563EB) : isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: isUser ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg['text'] ?? '',
                          style: TextStyle(color: isUser ? Colors.white : isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, height: 1.45),
                        ),
                        if (msg.containsKey('time')) ...[
                          const SizedBox(height: 5),
                          Text('Latency: ${msg['time']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isGenerating) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF2563EB)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_busy,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    decoration: const InputDecoration(hintText: 'Enter topic for Duolingo breakdown...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(onPressed: _busy ? null : _sendMessage, icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
