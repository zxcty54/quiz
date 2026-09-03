import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'offline_db_service.dart';

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

  // Llama 3.2 1B Instruct GGUF path
  static const String defaultLlamaPath =
      '/storage/emulated/0/Download/Llama-3.2-1B-Instruct-Q4_K_M.gguf';

  // ------------------------------------------------------------
  // 1. SAFE MODEL LOADER (2048 Context Length for Llama 3.2)
  // ------------------------------------------------------------
  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? defaultLlamaPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception("Llama 3.2 GGUF file nahi mili:\n$targetPath");
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
      throw Exception("Llama 3.2 load fail: $e");
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> initEngine({String? modelPath}) async {
    await loadModelManually(modelPath: modelPath);
  }

  // ------------------------------------------------------------
  // 2. UNLOAD / DISPOSE ENGINE
  // ------------------------------------------------------------
  Future<void> unloadModel() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. ADAPTIVE INFERENCE PIPELINE
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
      throw Exception("Model load nahi hai. Folder icon se file load karein.");
    }

    final cleanInput = userInput.trim();
    final lower = cleanInput.toLowerCase();

    // Natural conversation filter
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'kaise ho') {
      return "Aman Sir: Namaste! Main bilkul theek hoon. Aaj kaun sa topic samajhna hai—Science me Cell/Biology, ya Polity ka koi Article?";
    }

    // Optional background SQLite lookup (Secondary fact check)
    String optionalDbNotes = context.trim();
    if (optionalDbNotes.isEmpty) {
      try {
        final dbResult = await OfflineDbService.instance
            .searchRelevantContext(cleanInput)
            .timeout(const Duration(milliseconds: 300));
        if (dbResult.isNotEmpty) {
          optionalDbNotes = dbResult;
        }
      } catch (_) {
        optionalDbNotes = "";
      }
    }

    // Official Llama 3.2 Native Header Template with Duolingo Card Structure
    final prompt = '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

Cutting Knowledge Date: December 2023
Today Date: 26 Jul 2024

Aap Aman Sir hain, BPSC aur competitive exams ke intuitive teacher.
Student ke topic ko samajh kar is 1-screen conversational card format me Hinglish me samjhaiye:

Micro Concept:
[Real-life analogy se WHY before WHAT 1 line me]

Raju vs Aman Sir:
Raju: [Natural daily-life doubt ya curiosity]
Aman Sir: [Spoken Hinglish practical logic]

3-Step Breakdown:
• Mool Tathya: [Core factual ya scientific rule]
• Karyapranali: [Real life application ya formula]
• Pariksha Savdhani: [Elimination trap to avoid]

Micro Challenge:
Q: [One line direct exam question]
A) Option A
B) Option B
C) Option C
D) Option D
Correct Answer: [Option letter]
Explanation: [Crisp 1-line reason]

Important: Square brackets mat print karna. Real facts aur natural Hinglish likhna.<|eot_id|><|start_header_id|>user<|end_header_id|>

${optionalDbNotes.isNotEmpty ? "OPTIONAL REFERENCE NOTES:\n$optionalDbNotes\n\n" : ""}TOPIC: $cleanInput<|eot_id|><|start_header_id|>assistant<|end_header_id|>
Micro Concept:
''';

    final completer = Completer<String>();
    final StringBuffer buffer = StringBuffer();
    StreamSubscription<String>? subscription;

    try {
      final stream = activeController.generate(
        prompt: prompt,
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
          if (buffer.isNotEmpty) return buffer.toString();
          throw Exception("Inference timeout: 45s.");
        },
      );

      String cleanText = result
          .replaceAll('<|eot_id|>', '')
          .replaceAll('<|end_of_text|>', '')
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
}
