import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';

enum LlmTaskType {
  duolingoExplanation,
  quiz,
  analysis,
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

  // ------------------------------------------------------------
  // 1. SAFE MODEL LOADER (Pre-compiled Android C++ Engine)
  // ------------------------------------------------------------
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
        contextSize: 512,
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

  // ------------------------------------------------------------
  // 2. UNLOAD MODEL
  // ------------------------------------------------------------
  Future<void> unloadModel() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (Zero NullPointer Type-Safe Bridge)
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
      throw Exception("Model load nahi hai. Pehle file select karein.");
    }

    final systemInstruction = _buildSystemInstruction(task);
    final userContent = context.trim().isNotEmpty
        ? "STUDY CONTEXT:\n$context\n\nOBSERVATION / QUERY:\n$userInput"
        : "OBSERVATION / QUERY:\n$userInput";

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      // Type-safe pigeon call specifically built for Android GGUF inference
      final stream = activeController.generateChat(
        messages: [
          ChatMessage(role: 'system', content: systemInstruction),
          ChatMessage(role: 'user', content: userContent),
        ],
        template: 'chatml',
        temperature: 0.1,
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
        const Duration(seconds: 40),
        onTimeout: () {
          subscription?.cancel();
          if (buffer.isNotEmpty) {
            return buffer.toString();
          }
          throw Exception("Inference timeout: 40s tak output complete nahi hua.");
        },
      );

      final cleanText = result
          .replaceAll('<|im_end|>', '')
          .replaceAll('<|endoftext|>', '')
          .trim();

      if (cleanText.isEmpty) {
        throw Exception("Engine returned blank output.");
      }

      return cleanText;
    } finally {
      await subscription?.cancel();
    }
  }

  // ------------------------------------------------------------
  // PEDAGOGICAL STRUCTURE (Notebook Standard Format)
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    return '''
You are Aman Sir, an expert pedagogical tutor for Indian competitive exams (BPSC/BSSC).
Strictly output in this 1-screen WhatsApp conversational card format in clear spoken Hinglish:
- Explain WHY before WHAT.
- Raju shares a natural daily-life doubt or curiosity.
- Aman Sir clears it directly with no textbook formality.

Micro Concept:
[1 crisp line definition of core rule]

Raju vs Aman Sir:
Raju: [Real-life observation or doubt]
Aman Sir: [Direct spoken logic resolving Raju's doubt]

3-Step Breakdown:
• Mool Tathya: [Core factual rule]
• Karyapranali: [Direct application]
• Pariksha Savdhani: [Elimination trap to avoid]

Micro Challenge:
Q: [One line question based on the concept]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line trap reason]

Do not write any introductory greetings or conversational filler outside this format.
''';
  }
}
