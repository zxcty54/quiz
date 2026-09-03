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
  // DIRECT EXPLANATION PIPELINE (Zero Counter-Questions)
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

    // Direct, factual, no counter-questions prompt
    final prompt = '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are an expert educational AI assistant.
Answer the user's question directly, clearly, and factually in simple Hinglish.

Strict Rules:
1. NEVER ask a counter-question back to the user (do not say "kya aapko pata hai?", "aap kya janna chahte hain?").
2. Give the direct explanation immediately based on the user's input.
3. If the user asks about an exam or organization (like BPSC, UPSC), state its full form, role, and main purpose clearly.
4. Keep the answer crisp, helpful, and natural without placeholders or robotic text.<|eot_id|><|start_header_id|>user<|end_header_id|>

${context.trim().isNotEmpty ? "Context:\n$context\n\n" : ""}$cleanInput<|eot_id|><|start_header_id|>assistant<|end_header_id|>
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: prompt,
        temperature: 0.1, // Zero randomness -> Direct factual answers
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
          throw Exception("Inference timeout.");
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
