import 'dart:async';
import 'dart:io';
import 'package:fllama/fllama.dart';

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

  double? _contextId;
  String? _loadedModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;
  String? get activeModelName => _loadedModelPath?.split('/').last;

  static const String verified05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  // ------------------------------------------------------------
  // 1. MANUAL MODEL LOADER (Using Fllama.initContext)
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
      if (_contextId != null) {
        await unloadModel();
      }

      final completer = Completer<void>();
      String? initError;

      // Official Fllama class methods
      Fllama.initContext(
        OpenAI(
          modelUrl: targetPath,
          contextSize: 512,
          batchSize: 64,
          threads: 2,
          gpuLayers: 0,
        ),
        (double? contextId, String? err) {
          if (err != null && err.isNotEmpty) {
            initError = err;
          }
          if (contextId != null && contextId > 0) {
            _contextId = contextId;
            _loadedModelPath = targetPath;
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          throw Exception("Model init timeout: 25s me engine initialize nahi hua.");
        },
      );

      if (initError != null && initError!.isNotEmpty) {
        throw Exception("fllama native initialization error: $initError");
      }

      if (_contextId == null) {
        throw Exception("Invalid contextId pointer received from native engine.");
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// Backward compatibility for UI
  Future<void> initEngine({String? modelPath}) async {
    await loadModelManually(modelPath: modelPath);
  }

  // ------------------------------------------------------------
  // 2. UNLOAD MODEL
  // ------------------------------------------------------------
  Future<void> unloadModel() async {
    final id = _contextId;
    if (id == null) return;

    try {
      Fllama.dispose(contextId: id);
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (Using Fllama.inference)
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (_contextId == null) {
      await loadModelManually(modelPath: _loadedModelPath);
    }

    final currentId = _contextId;
    if (currentId == null) {
      throw Exception("Model load nahi hai. Pehle file load karein.");
    }

    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    final StringBuffer buffer = StringBuffer();
    final completer = Completer<String>();
    String? inferenceError;

    // Official Fllama.inference method
    Fllama.inference(
      Inference(
        contextId: currentId,
        prompt: prompt,
        temperature: 0.2,
        predictLength: 350,
        threads: 2,
        penaltyRepeat: 1.1,
        stop: ['<|im_end|>', '<|endoftext|>'],
      ),
      (String? result, String? err) {
        if (err != null && err.isNotEmpty) {
          inferenceError = err;
        }
        if (result != null) {
          buffer.write(result);
        }
      },
    );

    // Stream/Callback completion wait (with safe fallback timer)
    await Future.delayed(const Duration(milliseconds: 300));
    int elapsed = 0;
    while (elapsed < 30000) {
      await Future.delayed(const Duration(milliseconds: 200));
      elapsed += 200;
      final currentText = buffer.toString();
      if (currentText.contains('<|im_end|>') || 
          currentText.contains('Explanation:') || 
          (currentText.isNotEmpty && elapsed > 4000 && !currentText.endsWith(' '))) {
        break;
      }
    }

    if (inferenceError != null && inferenceError!.isNotEmpty) {
      throw Exception("Inference Error: $inferenceError");
    }

    final output = buffer.toString().replaceAll('<|im_end|>', '').replaceAll('<|endoftext|>', '').trim();
    if (output.isEmpty) {
      throw Exception("Engine ne empty text return kiya.");
    }

    return output;
  }

  // ------------------------------------------------------------
  // PROMPT BUILDER
  // ------------------------------------------------------------
  String _buildPrompt({
    required String systemInstruction,
    required String context,
    required String userInput,
  }) {
    final contextBlock = context.trim().isNotEmpty ? "STUDY CONTEXT:\n$context\n\n" : "";
    return '''
<|im_start|>system
$systemInstruction
<|im_end|>
<|im_start|>user
${contextBlock}DAILY OBSERVATION / QUERY:
$userInput
<|im_end|>
<|im_start|>assistant
''';
  }

  // ------------------------------------------------------------
  // PEDAGOGICAL STRUCTURE (Notebook Standard Format)
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
Generate 2 standard MCQs based strictly on the context.
Format:
Q1. [Question]
A) [Option 1] | B) [Option 2] | C) [Option 3] | D) [Option 4]
Correct: [Letter]
Explanation: [One short line]
''';

      case LlmTaskType.duolingoExplanation:
      default:
        return '''
You are an AI pedagogical engine for Indian competitive exams (BPSC/BSSC/SSC).
Explain strictly using this exact 1-screen conversational card format in clear Hinglish:
- Explain WHY before WHAT.
- Raju shares a natural daily-life doubt or curiosity.
- Aman Sir clears it directly with no textbook formality.

Micro Concept:
[1 crisp line definition of core rule]

Raju vs Aman Sir:
Raju: [Real-life observation or doubt]
Aman Sir: [Direct logic clearing the confusion]

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

Do not write introductory greetings or extra text outside this format.
''';
    }
  }
}
