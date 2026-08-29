import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../services/knowledge_base_service.dart';

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

  String _modelStatus = 'AI Model Not Loaded';
  String? _modelPath;

  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _llama?.dispose();
    super.dispose();
  }

  List<String> _cleanChunks(List<String> chunks) {
    return chunks
        .where((chunk) {
          final lower = chunk.toLowerCase();
          return !lower.contains('preface') &&
              !lower.contains('all rights reserved') &&
              !lower.contains('isbn') &&
              !lower.contains('acknowledgement') &&
              !lower.contains('acknowledgment');
        })
        .map((chunk) => chunk.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((chunk) => chunk.isNotEmpty)
        .toList();
  }

  double _calculateMatchScore(String query, String text) {
    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toSet();

    final textWords = text
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2)
        .toSet();

    if (queryWords.isEmpty || textWords.isEmpty) return 0.0;

    final intersection = queryWords.intersection(textWords).length;
    final union = queryWords.union(textWords).length;
    if (union == 0) return 0.0;

    double score = intersection / union;
    final q = query.toLowerCase().trim();
    final t = text.toLowerCase();

    if (q.isNotEmpty && t.contains(q)) score += 1.0;
    score += (intersection / queryWords.length) * 0.5;

    return score;
  }

  Future<void> _pickAndLoadModel() async {
    if (_busy) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
        allowMultiple: false,
      );

      if (result == null) return;

      final path = result.files.single.path;
      if (path == null || path.isEmpty || !File(path).existsSync()) {
        _showError('GGUF model ka valid file path nahi mila.');
        return;
      }

      final fileName = result.files.single.name.toLowerCase();
      if (!fileName.endsWith('.gguf')) {
        _showError('Please sirf .gguf model file select karein.');
        return;
      }

      setState(() {
        _isModelLoading = true;
        _modelStatus = 'Loading Model to Phone RAM...';
      });

      // Give UI a chance to render spinner
      await Future.delayed(const Duration(milliseconds: 100));

      _llama?.dispose();
      _llama = null;

      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0; // Pure CPU on Android

      final contextParams = ContextParams();
      contextParams.nCtx = 1536; // Optimized context length for 4GB phone RAM
      contextParams.nThreads = 4; // Use 4 Performance CPU cores

      _llama = Llama(path, modelParams, contextParams);

      if (!mounted) return;

      setState(() {
        _isModelLoaded = true;
        _isModelLoading = false;
        _modelPath = path;
        _modelStatus = 'Offline AI Ready (Gemma 2 CPU)';
      });

      _showSuccess('🟢 Offline AI Loaded! Zero-internet active.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isModelLoaded = false;
        _isModelLoading = false;
        _modelStatus = 'Model Error';
      });

      _showError('Model loading error:\n$e');
    }
  }

  bool _isGreeting(String query) {
    final normalized = query.toLowerCase().trim();
    const greetings = {'hi', 'hello', 'hey', 'namaste', 'pranam', 'help'};
    return greetings.contains(normalized);
  }

  String _greetingResponse() {
    return '''
Namaste! 🙏

Main MockTester ka **100% Offline Duolingo-Style AI Exam Tutor** hoon.
📚 General Science (Physics, Chemistry, Bio) | ⚖️ Indian Polity | 🌍 Bihar GK

Aap koi bhi concept ya sawal poochein, main use 3 आसान स्टेप्स में समझाऊंगा।
🟢 Internet: OFF | CPU Mode: ACTIVE
''';
  }

  Future<List<String>> _retrieveContext(String query) async {
    try {
      final rawChunks = await KnowledgeBaseService.instance
          .searchRelevantChunks(query, limit: 8);
      final cleanFacts = _cleanChunks(rawChunks);
      if (cleanFacts.isEmpty) return [];

      cleanFacts.sort((a, b) {
        final scoreB = _calculateMatchScore(query, b);
        final scoreA = _calculateMatchScore(query, a);
        return scoreB.compareTo(scoreA);
      });

      final unique = <String>[];
      final seen = <String>{};

      for (final fact in cleanFacts) {
        final normalized = fact.toLowerCase().trim();
        if (seen.add(normalized)) unique.add(fact);
        if (unique.length >= 3) break;
      }

      return unique;
    } catch (e) {
      debugPrint('Knowledge base search error: $e');
      return [];
    }
  }

  String _buildGemmaPrompt({
    required String question,
    required List<String> context,
  }) {
    final contextText = context.isEmpty
        ? 'General Study Concept'
        : context.join('\n');

    return '''
<start_of_turn>user
You are a Duolingo-style structured learning AI tutor for competitive exams (BPSC, BSSC, SSC CGL).
Explain the topic in crisp, bite-sized points:
1. 💡 Micro Concept (1 line definition + KaTeX formula)
2. ⚡ 3-Step Breakdown
3. 🎯 1 Micro Challenge MCQ with answer.

STUDY CONTEXT:
$contextText

QUESTION / TOPIC:
$question
<end_of_turn>
<start_of_turn>model
''';
  }

  Future<String> _generateRagAnswer(String question) async {
    if (_llama == null || !_isModelLoaded) {
      throw Exception('AI Model loaded nahi hai.');
    }

    final context = await _retrieveContext(question);
    final prompt = _buildGemmaPrompt(question: question, context: context);

    final buffer = StringBuffer();
    _shouldStop = false;

    _llama!.setPrompt(prompt);

    int tokenCount = 0;
    while (!_shouldStop && mounted) {
      final tokenResult = _llama!.getNext();
      final tokenText = tokenResult.$1;
      final isDone = tokenResult.$2;

      if (isDone || tokenText.isEmpty || tokenText == '<end_of_turn>' || tokenText == '</s>') {
        break;
      }

      buffer.write(tokenText);
      tokenCount++;

      // Update UI every 2 tokens for smooth 60fps rendering
      if (tokenCount % 2 == 0 && _messages.isNotEmpty && _messages.last['role'] == 'assistant') {
        setState(() {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': buffer.toString(),
          };
        });
        _scrollToBottom();
      }

      // Crucial: Prevents UI Thread lockup on low-end phones
      await Future.delayed(const Duration(milliseconds: 1));
    }

    final answer = buffer.toString().trim();
    if (answer.isEmpty) throw Exception('Empty response from model.');

    return answer;
  }

  Future<String> _processDatabaseFallback(String query) async {
    final cleanFacts = await _retrieveContext(query);
    if (cleanFacts.isEmpty) {
      return '⚠️ Local study database mein direct topic nahi mila.\n\n💡 Try: Gravitation, Article 32, Gaganyaan, Ohm\'s Law, Mitochondria.';
    }

    final buffer = StringBuffer();
    buffer.writeln('📚 **Offline Notes:**\n');
    for (final fact in cleanFacts.take(3)) {
      buffer.writeln('• $fact\n');
    }
    return buffer.toString().trim();
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty || _busy) return;

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isGenerating = true;
    });

    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    try {
      if (_isGreeting(query)) {
        final reply = _greetingResponse();
        stopwatch.stop();
        if (!mounted) return;

        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'time': '${stopwatch.elapsedMilliseconds}ms',
          });
          _isGenerating = false;
        });
        _scrollToBottom();
        return;
      }

      if (!_isModelLoaded || _llama == null) {
        final reply = await _processDatabaseFallback(query);
        stopwatch.stop();
        if (!mounted) return;

        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'time': '${stopwatch.elapsedMilliseconds}ms (DB Mode)',
          });
          _isGenerating = false;
        });
        _scrollToBottom();
        return;
      }

      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'text': 'Thinking...'});
      });
      _scrollToBottom();

      try {
        await _generateRagAnswer(query);
      } catch (llmError) {
        debugPrint('LLM generation failed: $llmError');
        final fallback = await _processDatabaseFallback(query);
        if (!mounted) return;
        setState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
            _messages[_messages.length - 1] = {
              'role': 'assistant',
              'text': '$fallback\n\n*(Note: Showing local DB fallback)*',
            };
          }
        });
      }

      stopwatch.stop();
      if (!mounted) return;

      if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
        final currentText = _messages.last['text'] ?? '';
        setState(() {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': currentText,
            'time': '${stopwatch.elapsedMilliseconds}ms',
          };
          _isGenerating = false;
        });
      } else {
        setState(() {
          _isGenerating = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': '❌ Offline AI error:\n$e',
          'time': '${stopwatch.elapsedMilliseconds}ms',
        });
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
      ),
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
              'Offline Duolingo AI Tutor',
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
            tooltip: 'Load Gemma 2 GGUF Model',
            onPressed: _busy ? null : _pickAndLoadModel,
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
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index], isDark);
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
              _isModelLoaded ? 'Gemma 2 2B Ready (Zero Lag)' : 'Offline Learning Agent Ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isModelLoaded
                  ? 'Ask any exam topic for 3-step breakdown & instant challenge!'
                  : 'Gemma 2 2B GGUF file load karne ke liye upar 📁 button dabayein.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (!_isModelLoaded)
              ElevatedButton.icon(
                onPressed: _isModelLoading ? null : _pickAndLoadModel,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Load Gemma 2 (.gguf)'),
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

  Widget _buildMessageBubble(Map<String, String> msg, bool isDark) {
    final isUser = msg['role'] == 'user';
    final text = msg['text'] ?? '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2563EB)
              : isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isUser ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
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
                  Text(
                    'Time: ${msg['time']}',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ],
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
                hintText: _isModelLoaded ? 'Ask any concept (e.g. Gravitation, Writs)...' : 'Type topic name...',
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