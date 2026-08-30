import 'dart:async';
import 'package:flutter/material.dart';
import '../services/knowledge_base_service.dart';
import '../services/dynamic_ai_agent_service.dart';

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

  bool _isModelLoaded = false;
  bool _isModelLoading = false;
  bool _isGenerating = false;

  String _modelStatus = 'Offline AI Agent Initializing...';
  AgentTaskType? _selectedTaskOverride;
  final List<Map<String, String>> _messages = [];

  bool get _busy => _isModelLoading || _isGenerating;

  @override
  void initState() {
    super.initState();
    _initializeOfflineModel();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineModel() async {
    setState(() {
      _isModelLoading = true;
      _modelStatus = 'Loading Dynamic Agent Engine...';
    });

    try {
      await DynamicAiAgentService.instance.initModel();

      if (!mounted) return;
      setState(() {
        _isModelLoaded = true;
        _isModelLoading = false;
        _modelStatus = 'Dynamic AI Agent Ready (Multi-Task)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isModelLoaded = false;
        _isModelLoading = false;
        _modelStatus = 'Agent Init Error';
      });
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
      debugPrint('RAG search error: $e');
      return '';
    }
  }

  Future<void> _sendMessage({String? predefinedText, AgentTaskType? overrideTask}) async {
    final query = (predefinedText ?? _textController.text).trim();
    if (query.isEmpty || _busy) return;

    final taskToRun = overrideTask ?? _selectedTaskOverride;

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isGenerating = true;
      _selectedTaskOverride = null;
    });

    _textController.clear();
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();

    setState(() {
      _messages.add({'role': 'assistant', 'text': 'Agent thinking...'});
    });
    _scrollToBottom();

    try {
      final context = await _retrieveContext(query);
      final response = await DynamicAiAgentService.instance.executeAgent(
        userInput: query,
        context: context,
        forcedTask: taskToRun,
      );

      stopwatch.stop();
      if (!mounted) return;

      setState(() {
        if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
          _messages[_messages.length - 1] = {
            'role': 'assistant',
            'text': response.trim(),
            'time': '${stopwatch.elapsedMilliseconds}ms',
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
            'text': '❌ Agent execution error:\n$e',
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
            const Text('Multi-Agent AI Exam Tutor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
      ),
      body: Column(
        children: [
          // Dynamic Feature Action Bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildActionChip('⚡ Micro Concept', AgentTaskType.duolingoExplanation, isDark),
                _buildActionChip('🎯 Generate Quiz', AgentTaskType.quizGeneration, isDark),
                _buildActionChip('🧠 Mnemonic Trick', AgentTaskType.mnemonicTrick, isDark),
                _buildActionChip('📋 Rapid Summary', AgentTaskType.revisionSummary, isDark),
                _buildActionChip('🔍 Analyze Answer', AgentTaskType.answerAnalysis, isDark),
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

  Widget _buildActionChip(String label, AgentTaskType task, bool isDark) {
    final isSelected = _selectedTaskOverride == task;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : isDark ? Colors.white70 : Colors.black87)),
        selected: isSelected,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedColor: const Color(0xFF2563EB),
        checkmarkColor: Colors.white,
        onSelected: (selected) {
          setState(() {
            _selectedTaskOverride = selected ? task : null;
          });
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
              'Autonomous Multi-Agent AI Ready',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Select any mode above or ask any topic (e.g. "Gravitation", "Article 32", "Fundamental Rights trick").',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey.shade600),
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
                hintText: _selectedTaskOverride != null
                    ? 'Type topic for ${_selectedTaskOverride!.name}...'
                    : 'Ask any question, quiz, or topic...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            tooltip: 'Send',
            onPressed: _busy ? null : () => _sendMessage(),
            icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}
