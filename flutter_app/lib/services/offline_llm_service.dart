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

  // Aap jo bhi model use kar rahe hain (Llama 3.2 1B ya Qwen 0.5B) uska path
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
  // NATURAL AI CONVERSATION (Zero Script, Input-Driven)
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

    // Bilkul clean, open instruction: Na koi Raju, na koi forced format
    final prompt = '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a helpful, knowledgeable, and direct educational AI mentor for competitive exams.
Always understand the user's specific input carefully and respond naturally in clear spoken Hinglish.
Explain concepts simply, provide direct facts when asked, and answer conversational queries naturally.
Do not repeat templates, instructions, or fixed scripts. Give real, relevant answers based on what the user actually asked.<|eot_id|><|start_header_id|>user<|end_header_id|>

${context.trim().isNotEmpty ? "Context:\n$context\n\n" : ""}$cleanInput<|eot_id|><|start_header_id|>assistant<|end_header_id|>
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: prompt,
        temperature: 0.5, // Natural, thoughtful variation bina rigid repetition ke
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
          throw Exception("Inference timeout: Model ne samay par reply nahi kiya.");
        },
      );

      final cleanText = result
          .replaceAll('<|eot_id|>', '')
          .replaceAll('<|end_of_text|>', '')
          .trim();

      if (cleanText.isEmpty) {
        throw Exception("Model ne blank output diya.");
      }

      return cleanText;
    } finally {
      await subscription?.cancel();
    }
  }
}
