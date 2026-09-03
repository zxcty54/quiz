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

  static const String verified05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? verified05BPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception("GGUF model file nahi mili:\n$targetPath");
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
      throw Exception("Model engine load nahi hua.");
    }

    final cleanInput = userInput.trim();
    final lower = cleanInput.toLowerCase();

    // 1. Natural Greeting Filter (Instant human reply)
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'kaise ho') {
      return "Namaste! Main tayyar hoon. Aaj kaun sa topic samajhna hai—Science me Cell, ya Indian Constitution ka koi Article?";
    }

    // 2. Gemma-style Clean Structured Prompt (Exact UI match)
    final prompt = '''<|im_start|>system
You are a structured learning AI tutor for competitive exams (BPSC/BSSC).
Explain the user's topic in clear Hinglish following this format:

1. 💡 Micro Concept
(1 crisp line explaining why it matters in daily life before what it is)

2. ⚡ 3-Step Breakdown
• Mool Tathya: Core rule or fact.
• Karyapranali: How it works in real life.
• Pariksha Savdhani: Exam elimination trap.

3. 🎯 Micro Challenge
Q: One direct exam question.
A) Option A
B) Option B
C) Option C
D) Option D
Correct: Option letter
Explanation: 1-line reason.

Rule: Do not output brackets, instructions, or meta talk. Write real facts.<|im_end|>
<|im_start|>user
${context.trim().isNotEmpty ? "STUDY CONTEXT:\n$context\n\n" : ""}TOPIC: $cleanInput<|im_end|>
<|im_start|>assistant
1. 💡 Micro Concept
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: prompt,
        temperature: 0.15,
        maxTokens: 400,
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

      String cleanText = result
          .replaceAll('<|im_end|>', '')
          .replaceAll('<|endoftext|>', '')
          .trim();

      if (cleanText.isEmpty) {
        throw Exception("Model ne blank response diya.");
      }

      // UI Parser ko header ensure karke pass karein
      if (!cleanText.startsWith("1. 💡 Micro Concept")) {
        cleanText = "1. 💡 Micro Concept\n$cleanText";
      }

      return cleanText;
    } finally {
      await subscription?.cancel();
    }
  }
}
