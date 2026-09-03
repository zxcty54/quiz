import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'web_search_service.dart';

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

  LlamaController? _controller;
  String? _loadedModelPath;
  bool _isInitializing = false;

  bool get isReady => _controller != null;
  String? get activeModelName => _loadedModelPath?.split('/').last;

  static const String defaultModelPath =
      '/storage/emulated/0/Download/Llama-3.2-1B-Instruct-Q4_K_M.gguf';

  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? defaultModelPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception("Model file nahi mili:\n$targetPath");
    }

    _isInitializing = true;

    try {
      if (_controller != null) {
        await unloadModel();
      }

      final controller = LlamaController();
      await controller.loadModel(
        modelPath: targetPath,
        threads: 2,
        contextSize: 2048,
      );

      _controller = controller;
      _loadedModelPath = targetPath;
    } catch (e) {
      _controller = null;
      _loadedModelPath = null;
      throw Exception("Model load fail: $e");
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> initEngine({String? modelPath}) async {
    await loadModelManually(modelPath: modelPath);
  }

  Future<void> unloadModel() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _loadedModelPath = null;
  }

  bool _needsLiveSearch(String input) {
    final lower = input.toLowerCase();
    final triggers = [
      'latest',
      'current affairs',
      'current affair',
      'aaj ka',
      'recent',
      'new update',
      'breaking',
      'news',
      'taaza',
      '2026',
    ];
    return triggers.any((word) => lower.contains(word));
  }

  // ------------------------------------------------------------
  // CLEAN DIRECT INFERENCE PIPELINE
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (_controller == null) {
      await loadModelManually(modelPath: _loadedModelPath);
    }

    final activeController = _controller;
    if (activeController == null) {
      throw Exception("Model load nahi hai. Pehle model file load karein.");
    }

    final cleanInput = userInput.trim();
    if (cleanInput.isEmpty) {
      return "Kripya apna sawal likhein.";
    }

    // Dynamic Search: Only trigger when explicitly asking for live news/current affairs
    String retrievedKnowledge = context.trim();
    if (retrievedKnowledge.isEmpty && _needsLiveSearch(cleanInput)) {
      try {
        final webResult = await WebSearchService.instance
            .searchWebContext(cleanInput)
            .timeout(const Duration(seconds: 4));
        if (webResult.isNotEmpty) {
          retrievedKnowledge = "Relevant retrieved knowledge:\n$webResult";
        }
      } catch (_) {
        retrievedKnowledge = "";
      }
    }

    // Exact Prompt Architecture as requested
    final prompt = '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a helpful AI assistant.

Answer the user's actual question directly in simple, clear Hinglish or English as appropriate.

Rules:
- Stay focused on the user's question.
- Do not introduce unrelated topics.
- Do not invent facts when you are uncertain.
- Use the conversation context when relevant.
- If the question is ambiguous, ask a clarification question.
- If you don't know the answer, say so instead of guessing.
- Keep the answer proportional to the question.
- Before producing the final answer, check whether it actually answers the user's question.
- Never output meta thoughts, JSON, brackets, or card templates. Output clean plain text only.<|eot_id|><|start_header_id|>user<|end_header_id|>

${retrievedKnowledge.isNotEmpty ? "$retrievedKnowledge\n\n" : ""}$cleanInput<|eot_id|><|start_header_id|>assistant<|end_header_id|>
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: prompt,
        temperature: 0.2, // Balanced factual adherence
        maxTokens: 300,
      );

      subscription = stream.listen(
        (token) {
          buffer.write(token);
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(Exception("Inference Error: $err"));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
        cancelOnError: true,
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          subscription?.cancel();
          if (buffer.isNotEmpty) return buffer.toString();
          throw Exception("Inference timeout: 40s.");
        },
      );

      final cleanText = result
          .replaceAll('<|eot_id|>', '')
          .replaceAll('<|end_of_text|>', '')
          .trim();

      if (cleanText.isEmpty) {
        throw Exception("Model ne blank response diya.");
      }

      return cleanText;
    } finally {
      await subscription?.cancel();
    }
  }
}
