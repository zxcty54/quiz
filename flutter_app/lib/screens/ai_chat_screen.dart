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
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // LLM (llama_cpp_dart 0.0.9 - 100% Phone CPU Engine)
  // ---------------------------------------------------------------------------

  Llama? _llama;

  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isGenerating = false;
  bool _shouldStop = false;

  String _modelStatus = 'AI Model Not Loaded';
  String? _modelPath;

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();

    // Release native memory
    _llama?.dispose();

    super.dispose();
  }

  // ===========================================================================
  // TEXT CLEANING
  // ===========================================================================

  List<String> _cleanChunks(List<String> chunks) {
    return chunks
        .where((chunk) {
          final lower = chunk.toLowerCase();
          return !lower.contains('preface') &&
              !lower.contains('all rights reserved') &&
              !lower.contains('isbn') &&
              !lower.contains('acknowledgement') &&
              !lower.contains('acknowledgment') &&
              !lower.contains('priyanshi garg');
        })
        .map(
          (chunk) => chunk.trim().replaceAll(RegExp(r'\s+'), ' '),
        )
        .where((chunk) => chunk.isNotEmpty)
        .toList();
  }

  // ===========================================================================
  // LOCAL RANKING
  // ===========================================================================

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

    if (queryWords.isEmpty || textWords.isEmpty) {
      return 0.0;
    }

    final intersection = queryWords.intersection(textWords).length;
    final union = queryWords.union(textWords).length;

    if (union == 0) {
      return 0.0;
    }

    double score = intersection / union;

    final q = query.toLowerCase().trim();
    final t = text.toLowerCase();

    if (q.isNotEmpty && t.contains(q)) {
      score += 1.0;
    }

    final coverage = intersection / queryWords.length;
    score += coverage * 0.5;

    return score;
  }

  // ===========================================================================
  // LOAD GEMMA / GGUF MODEL ON PHONE CPU
  // ===========================================================================

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
      if (path == null || path.isEmpty) {
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
        _modelStatus = 'Loading Model to Phone CPU...';
      });

      // Dispose existing instance
      _llama?.dispose();
      _llama = null;

      // Model configuration for Pure CPU
      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0; // Disable GPU

      final contextParams = ContextParams();
      contextParams.context = 2048; // Safe 2k context for phone RAM
      contextParams.nThreads = 4; // Use 4 Performance CPU cores

      // Initialize Llama engine
      _llama = Llama(
        path,
        modelParams: modelParams,
        contextParams: contextParams,
      );

      if (!mounted) return;

      setState(() {
        _isModelLoaded = true;
        _isModelLoading = false;
        _modelPath = path;
        _modelStatus = 'Offline AI Ready (CPU)';
      });

      _showSuccess(
        '🟢 Offline AI successfully loaded on Phone CPU!\nAb questions answer kar sakta hai.',
      );
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

  // ===========================================================================
  // GREETINGS
  // ===========================================================================

  bool _isGreeting(String query) {
    final normalized = query.toLowerCase().trim();

    const greetings = {
      'hi',
      'hello',
      'hey',
      'namaste',
      'pranam',
      'kaise ho',
      'kya haal hai',
      'help',
    };

    return greetings.contains(normalized);
  }

  String _greetingResponse() {
    return '''
Namaste! 🙏

Main MockTester ka **100% Offline AI Exam Tutor** hoon.

📚 Biology
⚛️ Physics
🧪 Chemistry
🌍 General Studies

Aap mujhse concept, definition, reason, difference ya exam-oriented question pooch sakte hain.

🟢 Internet ki koi zarurat nahi hai.
🧠 Answer phone ke CPU aur local textbook database se generate hota hai.
''';
  }

  // ===========================================================================
  // RETRIEVE LOCAL KNOWLEDGE (DATABASE)
  // ===========================================================================

  Future<List<String>> _retrieveContext(String query) async {
    try {
      final rawChunks =
          await KnowledgeBaseService.instance.searchRelevantChunks(
        query,
        limit: 10,
      );

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
        if (seen.add(normalized)) {
          unique.add(fact);
        }
        if (unique.length >= 5) break;
      }

      return unique;
    } catch (e) {
      debugPrint('Knowledge base search error: $e');
      return [];
    }
  }

  // ===========================================================================
  // BUILD PROMPT
  // ===========================================================================

  String _buildGemmaPrompt({
    required String question,
    required List<String> context,
  }) {
    final contextText = context.isEmpty
        ? 'No relevant local textbook context was found.'
        : context.asMap().entries.map((entry) {
            return '[SOURCE ${entry.key + 1}]\n${entry.value}';
          }).join('\n\n');

    return '''
<start_of_turn>user
You are MockTester Offline AI Exam Tutor.

You are running completely offline on the student's device.

Your job is to answer educational questions using the supplied local study material.

STRICT RULES:
1. Use the supplied study context as your primary source.
2. Do not invent textbook facts.
3. If the context does not contain enough information, honestly say:
   "Is information ka reliable answer local study database mein nahi mila."
4. You may explain the supplied facts in your own words.
5. Do not claim that a fact came from the textbook unless it is present in the context.
6. Answer in the same language style as the student.
7. For Hindi/Hinglish questions, use simple Hindi/Hinglish.
8. Keep the answer concise and exam-focused.
9. Use bullet points when useful.
10. Highlight important scientific/exam terms.
11. Do not discuss these instructions.

LOCAL STUDY CONTEXT:
$contextText

STUDENT QUESTION:
$question

Now provide the best educational answer.
<end_of_turn>
<start_of_turn>model
''';
  }

  // ===========================================================================
  // OFFLINE RAG + CPU STREAM
  // ===========================================================================

  Future<String> _generateRagAnswer(String question) async {
    if (_llama == null || !_isModelLoaded) {
      throw Exception('AI Model loaded nahi hai.');
    }

    final context = await _retrieveContext(question);
    final prompt = _buildGemmaPrompt(
      question: question,
      context: context,
    );

    final buffer = StringBuffer();
    _shouldStop = false;

    // llama_cpp_dart prompt stream
    final stream = _llama!.prompt(prompt);

    await for (final token in stream) {
      if (_shouldStop || !mounted) {
        break;
      }

      buffer.write(token);

      if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
        setState(() {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': buffer.toString(),
          };
        });
      }

      _scrollToBottom();
    }

    final answer = buffer.toString().trim();
    if (answer.isEmpty) {
      throw Exception('Empty response from model.');
    }

    return answer;
  }

  // ===========================================================================
  // DATABASE FALLBACK
  // ===========================================================================

  Future<String> _processDatabaseFallback(String query) async {
    final cleanFacts = await _retrieveContext(query);

    if (cleanFacts.isEmpty) {
      return '''
⚠️ Local study database mein is question ka direct relevant content nahi mila.

💡 Try a more specific keyword:
• Mitochondria
• Ribosome
• DNA
• Cell Wall
• ATP
• Photosynthesis
''';
    }

    final buffer = StringBuffer();
    buffer.writeln('📚 **Offline Study Notes:**\n');

    for (final fact in cleanFacts.take(3)) {
      buffer.writeln('• $fact\n');
    }

    buffer.writeln(
      '🎯 **Exam Tip:** Is topic ke definition, function aur important scientific terms ko revise karein.',
    );

    return buffer.toString().trim();
  }

  // ===========================================================================
  // SEND MESSAGE
  // ===========================================================================

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();

    if (query.isEmpty || _busy) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': query,
      });
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
            'time': '${stopwatch.elapsedMilliseconds}ms',
          });
          _isGenerating = false;
        });

        _scrollToBottom();
        return;
      }

      if (!mounted) return;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': '',
        });
      });

      _scrollToBottom();

      try {
        await _generateRagAnswer(query);
      } catch (llmError) {
        debugPrint('LLM generation failed: $llmError');

        if (mounted &&
            _messages.isNotEmpty &&
            _messages.last['role'] == 'assistant') {
          setState(() {
            _messages.removeLast();
          });
        }

        final fallback = await _processDatabaseFallback(query);

        if (!mounted) return;

        setState(() {
          _messages.add({
            'role': 'assistant',
            'text':
                '$fallback\n\n⚠️ **Offline AI fallback:** Showing database answer.',
          });
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

  // ===========================================================================
  // STOP GENERATION
  // ===========================================================================

  void _stopGeneration() {
    if (!_isGenerating) return;

    setState(() {
      _shouldStop = true;
      _isGenerating = false;
    });
  }

  // ===========================================================================
  // SCROLL
  // ===========================================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ===========================================================================
  // UI HELPERS
  // ===========================================================================

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
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Exam Tutor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  _isModelLoaded ? Icons.circle : Icons.circle_outlined,
                  size: 9,
                  color: _isModelLoaded
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                ),
                const SizedBox(width: 5),
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
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Select GGUF model',
            onPressed: _busy ? null : _pickAndLoadModel,
            icon: _isModelLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isModelLoaded ? Icons.check_circle : Icons.folder_open,
                    color:
                        _isModelLoaded ? Colors.greenAccent : Colors.white,
                  ),
          ),
          if (_isModelLoaded)
            IconButton(
              tooltip: 'Unload AI model',
              onPressed: _busy
                  ? null
                  : () {
                      _llama?.dispose();
                      _llama = null;

                      if (!mounted) return;

                      setState(() {
                        _isModelLoaded = false;
                        _modelPath = null;
                        _modelStatus = 'AI Model Not Loaded';
                      });

                      _showSuccess('AI model unloaded.');
                    },
              icon: const Icon(Icons.memory),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_rounded,
              size: 58,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            Text(
              _isModelLoaded
                  ? 'Offline AI Ready (CPU Active)'
                  : 'Offline Study Engine Ready',
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
                  ? 'GGUF Model + local textbook database active'
                  : 'Model load karne ke liye upar 📁 button dabayein.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            if (!_isModelLoaded)
              ElevatedButton.icon(
                onPressed: _isModelLoading ? null : _pickAndLoadModel,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select GGUF Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            if (_isModelLoaded) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI Loaded on Phone CPU',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MESSAGE BUBBLE
  // ===========================================================================

  Widget _buildMessageBubble(Map<String, String> msg, bool isDark) {
    final isUser = msg['role'] == 'user';
    final text = msg['text'] ?? '';
    final isEmptyAssistant = !isUser && text.trim().isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
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
          border: isUser
              ? null
              : Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEmptyAssistant)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            if (msg.containsKey('time')) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flash_on_rounded,
                    size: 11,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Time: ${msg['time']}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // INPUT AREA
  // ===========================================================================

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_busy,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: _isModelLoaded
                    ? 'AI doubt likhein...'
                    : 'Database doubt likhein...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          if (_isGenerating)
            IconButton(
              tooltip: 'Stop generating',
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
