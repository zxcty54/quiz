import 'package:flutter/material.dart';

import '../services/ai_data_disclosure_service.dart';
import '../services/ai_explainer_service.dart';
import '../widgets/report_ai_response_button.dart';

class AiChatScreen extends StatefulWidget {
  final bool isDarkMode;

  const AiChatScreen({super.key, this.isDarkMode = false});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isGenerating = false;
  bool _isConsentPending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isGenerating || _isConsentPending) return;

    setState(() => _isConsentPending = true);
    final consented = await AiDataDisclosureService.requireConsent(context);
    if (!mounted) return;
    setState(() => _isConsentPending = false);
    if (!consented) return;

    final recentMessages = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : _messages;
    final chatHistory = recentMessages
        .map((message) => '${message.isUser ? 'Student' : 'Tutor'}: ${message.text.trim()}')
        .join('\n');

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final response = await AiExplainerService.answerWithContext(
        question: text,
        context: chatHistory,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: 'Inference Error: $error', isUser: false),
        );
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Assistant', style: TextStyle(fontSize: 16)),
            Text(
              'Cloud AI · your prompt and recent chat context are sent to the AI service',
              style: TextStyle(fontSize: 10, color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Ask a study question. You will be asked to review how AI features use your data before the first request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isReportable = !message.isUser &&
                          !message.text.startsWith('Inference Error:') &&
                          !message.text.startsWith('⚠️ AI Service busy');

                      return Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: message.isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.82,
                              ),
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? Colors.blueAccent
                                    : (isDark
                                        ? const Color(0xFF242424)
                                        : const Color(0xFFF1F1F4)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SelectableText(
                                message.text.trim(),
                                style: TextStyle(
                                  color: message.isUser
                                      ? Colors.white
                                      : (isDark ? Colors.white : Colors.black87),
                                  fontSize: 14.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (isReportable)
                              ReportAiResponseButton(
                                response: message.text,
                                source: 'ai_chat_assistant',
                                isDarkMode: isDark,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isGenerating || _isConsentPending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConsentPending ? 'Waiting for your choice…' : 'AI is thinking…',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_isGenerating && !_isConsentPending,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Type your question…',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: (!_isGenerating && !_isConsentPending)
                      ? _sendMessage
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
