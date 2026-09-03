import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';

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

  // ------------------------------------------------------------
  // THINKING & REASONING INFERENCE PIPELINE (Up to 200 words)
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
      return "Kripya apna sawal ya topic likhein.";
    }

    // Two-Phase Brain Prompt:
    // 1. Model pehle query analyze karega (Intent determine karega)
    // 2. Fir seedhe 150-200 words me crystal-clear Hinglish explanation dega
    final prompt = '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are an expert AI mentor for competitive exams.
Before answering, silently analyze the user's input:
- What is the exact intent? (Greeting, core science concept, polity article, or exam details?)
- How to make it immediately clear to a student in everyday terms?

Response Guidelines:
1. Natural Spoken Hinglish: Explain like a real mentor sitting in front of the student.
2. Conceptual Depth: Start with real-life intuition (WHY before WHAT), explain the core factual mechanism, and point out what trap examiners set.
3. Length: Provide a complete, thoughtful explanation within 150 to 200 words.
4. Directness: Never ask counter-questions. Do not output meta-tags, thought processes, or template brackets. Speak directly to the student.<|eot_id|><|start_header_id|>user<|end_header_id|>

${context.trim().isNotEmpty ? "Context:\n$context\n\n" : ""}$cleanInput<|eot_id|><|start_header_id|>assistant<|end_header_id|>
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      // 200 words = lagbhag 260-320 tokens. maxTokens 350 rakha hai taaki answer beech me na kate.
      final stream = activeController.generate(
        prompt: prompt,
        temperature: 0.3, // Accurate reasoning bina bhatke
        maxTokens: 350,
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
        const Duration(seconds: 45),
        onTimeout: () {
          subscription?.cancel();
          if (buffer.isNotEmpty) return buffer.toString();
          throw Exception("Inference timeout: 45s.");
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
