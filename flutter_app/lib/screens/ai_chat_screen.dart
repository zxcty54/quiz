import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({Key? key}) : super(key: key);

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const platform = MethodChannel('com.mocktester.ai/offline_llm');
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _isModelLoaded = false;
  bool _isLoading = false;
  bool _isGenerating = false;
  String _statusMessage = "Select offline model (.bin)";

  @override
  void initState() {
    super.initState();
    _checkAndAutoLoadModel();
  }

  // Auto-loads model on startup if previously picked
  Future<void> _checkAndAutoLoadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('saved_offline_model_path');

    if (savedPath != null && File(savedPath).existsSync()) {
      _initModel(savedPath);
    }
  }

  Future<void> _pickModelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      _initModel(path);
    }
  }

  Future<void> _initModel(String path) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Loading offline model into RAM...";
    });

    try {
      final bool result = await platform.invokeMethod('initModel', {'modelPath': path});
      if (result) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_offline_model_path', path);

        setState(() {
          _isModelLoaded = true;
          _isLoading = false;
          _statusMessage = "Offline AI Active (On-Device)";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isModelLoaded = false;
        _statusMessage = "Failed to load model: $e";
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
      // Direct user prompt passed without hardcoded quiz wraps
      final String response = await platform.invokeMethod('generate', {'prompt': text});
      
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Error generating response: $e", isUser: false));
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
    return Scaffold(
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
            tooltip: "Select Model (.bin)",
            onPressed: _isLoading ? null : _pickModelFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      _isModelLoaded
                          ? "Type anything to ask offline AI"
                          : "Please select your .bin model from top-right icon",
                      style: const TextStyle(color: Colors.grey),
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
                            color: msg.isUser ? Colors.blueAccent : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isUser ? Colors.white : Colors.black87,
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
                children: const [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text("AI is thinking...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isModelLoaded && !_isGenerating,
                    decoration: const InputDecoration(
                      hintText: "Type your query...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
