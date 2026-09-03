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
  // 1. MANUAL MODEL LOADER (Strict Type-Safe Official Binding)
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

      String? initError;
      double? assignedContextId;

      // fllama typed initialization method to prevent Java reflection NPE
      fllama.initContext(
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
          assignedContextId = contextId;
        },
      );

      if (initError != null && initError!.isNotEmpty) {
        throw Exception("fllama native initialization error: $initError");
      }

      if (assignedContextId == null || assignedContextId! <= 0) {
        throw Exception("Invalid contextId received from native engine: $assignedContextId");
      }

      _contextId = assignedContextId;
      _loadedModelPath = targetPath;
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
      fllama.dispose(contextId: id);
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (Zero Crash Typed Wrapper)
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
      throw Exception("Model load nahi hai. Pehle loadModelManually() trigger karein.");
    }

    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    final StringBuffer buffer = StringBuffer();
    String? inferenceError;

    // Type-safe inference call: guarantees all required keys to FLlama.java
    await fllama.inference(
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

    if (inferenceError != null && inferenceError!.isNotEmpty) {
      throw Exception("Inference Error: $inferenceError");
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw Exception("Engine ne koi response generate nahi kiya.");
    }

    return text;
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
${contextBlock}DAILY OBSERVATION / TOPIC:
$userInput
<|im_end|>
<|im_start|>assistant
''';
  }

  // ------------------------------------------------------------
  // NOTEBOOK STRUCTURE PEDAGOGY PROMPT
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
Q2. [Question]
A) [Option 1] | B) [Option 2] | C) [Option 3] | D) [Option 4]
Correct: [Letter]
Explanation: [One short line]
No conversational fluff.
''';

      case LlmTaskType.duolingoExplanation:
      default:
        return '''
You are an AI pedagogical engine for Indian competitive exams (BPSC/BSSC/SSC).
Explain strictly using this exact 1-screen conversational micro-learning format in simple Hinglish:
- Explain WHY before WHAT.
- Raju shares a natural daily-life observation or doubt.
- Aman Sir clears it directly with no textbook formality.

Micro Concept:
[1 crisp line definition of core rule]

Raju vs Aman Sir:
Raju: [Real-life observation or doubt]
Aman Sir: [Direct logic resolving the doubt]

3-Step Breakdown:
• Mool Tathya: [Core factual rule]
• Karyapranali: [Direct application / formula]
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
