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

  // ------------------------------------------------------------
  // 1. SAFE MODEL LOADER (2048 Context Buffer)
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
  // 3. ADAPTIVE INFERENCE ENGINE (True AI Behavior)
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
      throw Exception("Model load nahi hai. Pehle file load karein.");
    }

    final cleanInput = userInput.trim();
    final lower = cleanInput.toLowerCase();

    // Natural conversation handling
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'kaise ho') {
      return "Aman Sir: Namaste! Main bilkul theek hoon. Aaj kaun sa topic samajhna hai—Science me Cell/Biology ya Polity ka koi Article?";
    }

    final systemInstruction = _buildSystemInstruction(task);
    
    final formattedPrompt = '''<|im_start|>system
$systemInstruction<|im_end|>
<|im_start|>user
${context.trim().isNotEmpty ? "STUDY CONTEXT:\n$context\n\n" : ""}TOPIC / QUERY:
$cleanInput<|im_end|>
<|im_start|>assistant
Micro Concept:
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: formattedPrompt,
        temperature: 0.2,
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
          if (buffer.isNotEmpty) {
            return buffer.toString();
          }
          throw Exception("Inference timeout: 45s tak output complete nahi hua.");
        },
      );

      String cleanText = result
          .replaceAll('<|im_end|>', '')
          .replaceAll('<|endoftext|>', '')
          .trim();

      if (cleanText.isEmpty) {
        throw Exception("Engine ne blank output diya.");
      }

      if (!cleanText.startsWith("Micro Concept:")) {
        cleanText = "Micro Concept:\n$cleanText";
      }

      return cleanText;
    } finally {
      await subscription?.cancel();
    }
  }

  // ------------------------------------------------------------
  // 4. NOTEBOOK DUOLINGO CARD FORMAT (Zero Placeholders)
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    return '''
You are Aman Sir, an expert pedagogical tutor for Indian competitive exams (BPSC/BSSC).
Explain the concept using real facts in clear spoken Hinglish:
- Explain WHY before WHAT.
- Raju shares a natural daily-life doubt.
- Aman Sir clears it directly with no textbook formality.

Structure your response strictly as follows:

Micro Concept:
State the core rule or definition in 1 crisp line explaining why it matters before what it is.

Raju vs Aman Sir:
Raju: State a practical, daily-life doubt regarding this topic.
Aman Sir: Give direct, spoken-logic reasoning resolving Raju's confusion.

3-Step Breakdown:
• Mool Tathya: State the foundational factual or scientific rule.
• Karyapranali: Explain how it functions or applies in practice.
• Pariksha Savdhani: Highlight the common exam trap or point of confusion to avoid.

Micro Challenge:
Q: One direct exam-style question on this topic
A) Option 1
B) Option 2
C) Option 3
D) Option 4
Correct Answer: Option letter
Explanation: One concise line explaining why other options fail.

Important Rules:
1. Never output square brackets or placeholder texts.
2. Fill every section with concrete, accurate facts based on the user's specific query.
''';
  }
}
