import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../services/knowledge_base_service.dart';

enum AgentTaskMode {
  explain,
  quiz,
  mnemonic,
  summary,
  analyze,
}

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;

  const AiChatScreen({
    super.key,
    this.isDarkMode = false,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Llama? _llama;

  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isGenerating = false;
  bool _shouldStop = false;

  String _modelStatus = 'Qwen 2.5 0.5B Not Loaded';
  AgentTaskMode _selectedMode = AgentTaskMode.explain;

  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _disposeModelSafely();
    super.dispose();
  }

  void _disposeModelSafely() {
    try {
      _llama?.dispose();
    } catch (e) {
      debugPrint('Model dispose warning: $e');
    }
    _llama = null;
  }

  List<String> _cleanChunks(List<String> chunks) {
    return chunks
        .where((chunk) {
          final lower = chunk.toLowerCase();
          return !lower.contains('preface') &&
              !lower.contains('all rights reserved') &&
              !lower.contains('isbn') &&
              !lower.contains('acknowledgement');
        })
        .map((chunk) => chunk.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((chunk) => chunk.isNotEmpty)
        .toList();
  }

  Future<String> _retrieveContext(String query) async {
    try {
      final rawChunks = await KnowledgeBaseService.instance
          .searchRelevantChunks(query, limit: 4);
      final cleanFacts = _cleanChunks(rawChunks);
      if (cleanFacts.isEmpty) return '';
      return cleanFacts.take(2).join('\n---\n');
    } catch (e) {
      debugPrint('Knowledge base search error: $e');
      return '';
    }
  }

  // --- 0.2.x MEMORY SAFE LOADER ---
  Future<void> _pickAndLoadQwenModel() async {
    if (_busy) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedPath = result.files.single.path;
      final fileName = result.files.single.name;

      if (pickedPath == null || !File(pickedPath).existsSync()) {
        _showError('GGUF file ka path invalid hai.');
        return;
      }

      if (!fileName.toLowerCase().endsWith('.gguf')) {
        _showError('Kripya sirf .gguf model file select karein.');
        return;
      }

      setState(() {
        _isModelLoading = true;
        _modelStatus = 'Loading Qwen 2.5 (0.2.x Core)...';
      });

      await Future.delayed(const Duration(milliseconds: 250));
      _disposeModelSafely();

      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0; // Pure CPU on Android

      final contextParams = ContextParams();
      contextParams.nCtx = 256;   // Safe context size
      contextParams.nThreads = 2; // Dual thread CPU

      final loadedInstance = Llama(pickedPath, modelParams, contextParams);

      if (!mounted) return;

      setState(() {
        _llama = loadedInstance;
        _isModelLoaded = true;
        _isModelLoading = false;
        _modelStatus = 'Qwen 2.5 Active (0.2.x Safe Core)';
      });

      _showSuccess('🟢 Model load ho gaya! Ab topic type karein.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelLoaded = false;
        _isModelLoading = false;
        _modelStatus = 'Loading Error';
      });
      _showError('Model loading error:\n$e');
    }
  }

  // --- DUOLINGO STRUCTURE PROMPT ---
  String _buildQwenPrompt({
    required String userInput,
    required String context,
    required AgentTaskMode mode,
  }) {
    String systemInstructions;
    switch (mode) {
      case AgentTaskMode.quiz:
        systemInstructions = '''
You are an expert exam quiz writer for BPSC, BSSC, and SSC.
Create 2 multiple-choice questions for the user topic based on study context.
Format:
Q1. [Question]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct: [Option Letter]
Explanation: [Crisp 1-line reason]
''';
        break;

      case AgentTaskMode.mnemonic:
        systemInstructions = '''
You are an AI Memory Specialist.
Create a high-impact Hindi/Hinglish mnemonic code or memory trick for the topic.
''';
        break;

      case AgentTaskMode.summary:
        systemInstructions = '''
You are a Rapid-Revision AI Tutor.
Provide a high-yield exam summary sheet:
• 💡 Core Definition/Law
• ⚡ 3 Most Frequent PYQ Points
• 🎯 Elimination Trap to avoid
''';
        break;

      case AgentTaskMode.analyze:
        systemInstructions = '''
You are an AI Diagnostic Evaluator.
Analyze the user's reasoning and point out traps.
''';
        break;

      case AgentTaskMode.explain:
      default:
        systemInstructions = '''
You are a Duolingo-style structured learning AI tutor for competitive exams.
Explain the topic strictly in 3 crisp points:
1. 💡 Micro Concept (1-line definition)
2. ⚡ 3-Step Breakdown (3 short bullet points)
3. 🎯 1 Micro Challenge MCQ with answer
''';
        break;
    }

    final contextPart = context.isNotEmpty ? '\n\nCONTEXT:\n$context' : '';

    return '''<|im_start|>system
$systemInstructions$contextPart<|im_end|>
<|im_start|>user
$userInput<|im_end|>
<|im_start|>assistant
''';
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _busy) return;

    if (!_isModelLoaded || _llama == null) {
      _showError('Pehle upar 📁 icon par click karke Qwen 0.5B GGUF load karein.');
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isGenerating = true;
    });

    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    setState(() {
      _messages.add({'role': 'assistant', 'text': ''});
    });
    _scrollToBottom();

    try {
      final context = await _retrieveContext(query);
      final prompt = _buildQwenPrompt(
        userInput: query,
        context: context,
        mode: _selectedMode,
      );

      final buffer = StringBuffer();
      _shouldStop = false;

      _llama!.setPrompt(prompt);

      int tokenCount = 0;
      while (!_shouldStop && mounted && tokenCount < 220) {
        final tokenResult = _llama!.getNext();
        final tokenText = tokenResult.$1;
        final isDone = tokenResult.$2;

        if (isDone ||
            tokenText.isEmpty ||
            tokenText == '<|im_end|>' ||
            tokenText == '<|endoftext|>') {
          break;
        }

        buffer.write(tokenText);
        tokenCount++;

        if (tokenCount % 2 == 0 &&
            _messages.isNotEmpty &&
            _messages.last['role'] == 'assistant') {
          setState(() {
            _messages[_messages.length - 1] = {
              'role': 'assistant',
              'text': buffer.toString(),
            };
          });
          _scrollToBottom();
        }

        await Future.delayed(const Duration(milliseconds: 2));
      }

      stopwatch.stop();
      if (!mounted) return;

      final finalAnswer = buffer.toString().trim();
      setState(() {
        if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': finalAnswer.isEmpty ? '⚠️ Output blank raha.' : finalAnswer,
            'time': '${stopwatch.elapsedMilliseconds}ms (0.2.x Engine)',
          };
        }
        _isGenerating = false;
      });
      _scrollToBottom();
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': '❌ Generation Error:\n$e',
            'time': '${stopwatch.elapsedMilliseconds}ms',
          };
        }
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  void _stopGeneration() {
    if (!_isGenerating) return;
    setState(() {
      _shouldStop = true;
      _isGenerating = false;
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
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
            const Text(
              'Qwen 2.5 AI Exam Agent',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  _isModelLoaded ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: _isModelLoaded ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _modelStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Load Qwen 0.5B GGUF',
            onPressed: _busy ? null : _pickAndLoadQwenModel,
            icon: _isModelLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _isModelLoaded ? Icons.check_circle : Icons.folder_open,
                    color: _isModelLoaded ? Colors.greenAccent : Colors.white,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildModeChip('💡 Concept', AgentTaskMode.explain, isDark),
                _buildModeChip('🎯 Quiz', AgentTaskMode.quiz, isDark),
                _buildModeChip('🧠 Mnemonic', AgentTaskMode.mnemonic, isDark),
                _buildModeChip('📋 Summary', AgentTaskMode.summary, isDark),
                _buildModeChip('🔍 Analyze', AgentTaskMode.analyze, isDark),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
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
                                style: TextStyle(
                                  color: isUser ? Colors.white : isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              if (msg.containsKey('time')) ...[
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 10, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text('Time: ${msg['time']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: const Color(0xFF2563EB),
                backgroundColor: Colors.grey.withOpacity(0.15),
              ),
            ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, AgentTaskMode mode, bool isDark) {
    final isSelected = _selectedMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : isDark ? Colors.white70 : Colors.black87)),
        selected: isSelected,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedColor: const Color(0xFF2563EB),
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedMode = mode;
            });
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_rounded, size: 54, color: Color(0xFF2563EB)),
            const SizedBox(height: 12),
            Text(
              _isModelLoaded ? 'Qwen 2.5 0.5B Ready' : 'Offline Qwen AI Agent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              _isModelLoaded
                  ? 'Upar se task select karein aur topic type karein!'
                  : 'Phone me downloaded Qwen 0.5B GGUF file load karne ke liye 📁 dabayein.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (!_isModelLoaded)
              ElevatedButton.icon(
                onPressed: _isModelLoading ? null : _pickAndLoadQwenModel,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Pick Downloaded Qwen GGUF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
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
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type topic for ${_selectedMode.name.toUpperCase()} mode...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_isGenerating)
            IconButton(
              tooltip: 'Stop',
              onPressed: _stopGeneration,
              icon: const Icon(Icons.stop_circle, color: Colors.red),
            )
          else
            IconButton(
              tooltip: 'Send',
              onPressed: _busy ? null : _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
            ),
        ],
      ),
    );
  }
}
