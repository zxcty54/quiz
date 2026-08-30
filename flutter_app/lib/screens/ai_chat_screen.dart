import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../services/knowledge_base_service.dart';

// --- ENUMS & AGENT SERVICE ---
enum LlmTaskType {
  duolingoExplanation,
  quiz,
  analysis,
  mnemonic,
  summary,
}

class OfflineLlmAgentService {
  static final OfflineLlmAgentService instance = OfflineLlmAgentService._internal();
  OfflineLlmAgentService._internal();

  final _gemma = FlutterGemmaPlugin.instance;
  bool _isInitialized = false;

  bool get isReady => _isInitialized;

  Future<void> initEngine() async {
    if (_isInitialized) return;
    await _gemma.init(
      maxTokens: 512,
      temperature: 0.2,
      randomSeed: 1,
      topK: 1,
    );
    _isInitialized = true;
  }

  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    String systemPrompt;

    switch (task) {
      case LlmTaskType.quiz:
        systemPrompt = '''
You are an autonomous AI Quiz Generator for competitive exams (BPSC, BSSC, SSC).
Generate 2 MCQs for the user's topic based on the study context.
Format:
Q1. [Question]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct: [Option Letter]
Explanation: [1-line reason]
''';
        break;

      case LlmTaskType.analysis:
        systemPrompt = '''
You are an AI Diagnostic Evaluator.
Analyze the user's input/answer against the verified exam rule and explain the conceptual trap.
''';
        break;

      case LlmTaskType.mnemonic:
        systemPrompt = '''
You are an AI Memory Specialist.
Create a high-impact Hindi/Hinglish mnemonic code or acronym to remember this topic easily.
''';
        break;

      case LlmTaskType.summary:
        systemPrompt = '''
You are a Rapid-Revision AI Agent.
Summarize the topic into:
• 💡 Core Law / Definition
• ⚡ 3 Most Frequent Exam Points
• 🎯 Elimination Strategy
''';
        break;

      case LlmTaskType.duolingoExplanation:
      default:
        systemPrompt = '''
You are a Duolingo-style structured learning AI tutor for competitive exams.
Explain the topic in crisp points:
1. 💡 Micro Concept (1-line definition)
2. ⚡ 3-Step Breakdown (3 short bullet points)
3. 🎯 1 Micro Challenge MCQ with answer.

STUDY CONTEXT:
$context

TOPIC:
$userInput
''';
        break;
    }

    final fullPrompt = '''
<start_of_turn>user
$systemPrompt
<end_of_turn>
<start_of_turn>model
''';

    return await _gemma.getResponse(fullPrompt);
  }
}

// --- SCREEN UI ---
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

  bool _isModelLoading = false;
  bool _isGenerating = false;
  String _modelStatus = 'Initializing On-Device LLM...';
  LlmTaskType _currentTask = LlmTaskType.duolingoExplanation;

  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  @override
  void initState() {
    super.initState();
    _loadLlmEngine();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLlmEngine() async {
    setState(() {
      _isModelLoading = true;
      _modelStatus = 'Loading MediaPipe Gemma LLM into GPU...';
    });

    try {
      await OfflineLlmAgentService.instance.initEngine();
      if (!mounted) return;
      setState(() {
        _isModelLoading = false;
        _modelStatus = 'Offline Gemma LLM Active (GPU/NPU)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelLoading = false;
        _modelStatus = 'LLM Init Error';
      });
      debugPrint('LLM Load Error: $e');
    }
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
          .searchRelevantChunks(query, limit: 6);
      final cleanFacts = _cleanChunks(rawChunks);
      if (cleanFacts.isEmpty) return '';
      return cleanFacts.take(3).join('\n---\n');
    } catch (e) {
      return '';
    }
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

    setState(() {
      _messages.add({'role': 'assistant', 'text': 'LLM neural network generating response...'});
    });
    _scrollToBottom();

    try {
      final context = await _retrieveContext(query);
      final response = await OfflineLlmAgentService.instance.executeLlmAgent(
        userInput: query,
        context: context,
        task: _currentTask,
      );

      stopwatch.stop();
      if (!mounted) return;

      setState(() {
        if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': response.trim(),
            'time': '${stopwatch.elapsedMilliseconds}ms (Real LLM)',
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
            'text': '❌ LLM Inference Error:\n$e',
            'time': '${stopwatch.elapsedMilliseconds}ms',
          };
        }
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Offline LLM Exam Agent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  OfflineLlmAgentService.instance.isReady ? Icons.circle : Icons.circle_outlined,
                  size: 8,
                  color: OfflineLlmAgentService.instance.isReady ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(_modelStatus, style: const TextStyle(fontSize: 10, color: Colors.white70)),
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
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildModeChip('💡 Concept', LlmTaskType.duolingoExplanation, isDark),
                _buildModeChip('🎯 Quiz Generator', LlmTaskType.quiz, isDark),
                _buildModeChip('🧠 Mnemonic', LlmTaskType.mnemonic, isDark),
                _buildModeChip('📋 Summary', LlmTaskType.summary, isDark),
                _buildModeChip('🔍 Answer Analyzer', LlmTaskType.analysis, isDark),
              ],
            ),
          ),
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
            const LinearProgressIndicator(minHeight: 2, color: Color(0xFF2563EB)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_busy,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter topic for on-device LLM...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _sendMessage,
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, LlmTaskType task, bool isDark) {
    final isSelected = _currentTask == task;
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
              _currentTask = task;
            });
          }
        },
      ),
    );
  }
}
