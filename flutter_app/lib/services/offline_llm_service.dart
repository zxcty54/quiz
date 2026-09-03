import 'dart:io';
import 'package:flutter/services.dart';

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

  static const MethodChannel _channel = MethodChannel('fllama');

  num? _contextId;
  String? _loadedModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;
  String? get activeModelName => _loadedModelPath?.split('/').last;

  static const String verified05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  // ------------------------------------------------------------
  // 1. MANUAL MODEL LOADER
  // ------------------------------------------------------------
  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? verified05BPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception("GGUF file nahi mili: $targetPath");
    }

    _isInitializing = true;

    try {
      if (_contextId != null) {
        await unloadModel();
      }

      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('initContext', {
        'model': targetPath,
        'embedding': false,
        'nCtx': 512,
        'nBatch': 64,
        'nThreads': 2,
        'nGpuLayers': 0,
        'useMmap': true,
        'useMlock': false,
      });

      if (result == null) {
        throw Exception("Native engine init failed.");
      }

      final dynamic rawId = result['contextId'] ?? result['id'];
      if (rawId == null) {
        throw Exception("Invalid contextId: null returned from native layer.");
      }

      // Safe numeric assignment
      _contextId = rawId as num;
      _loadedModelPath = targetPath;
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
    final id = _contextId;
    if (id == null) return;

    try {
      // Force double to prevent casting crashes in releaseContext
      await _channel.invokeMethod('releaseContext', {
        'contextId': id.toDouble(),
      });
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (Casting Bug Fixed)
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
      throw Exception("Engine context is null. Please load model first.");
    }

    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    // CRITICAL FIX: Explicit `.toDouble()` ensures Java receives java.lang.Double
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', {
      'contextId': currentId.toDouble(),
      'prompt': prompt,
      'temperature': 0.2,
      'nPredict': 300,
      'nThreads': 2,
      'stop': const [
        '<|im_end|>',
        '<|endoftext|>',
      ],
    });

    if (result == null) {
      throw Exception("Native completion ne null response diya.");
    }

    return _extractText(result);
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
  // PEDAGOGICAL CARD INSTRUCTION
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
Explain strictly using this 1-screen WhatsApp conversational card format in clear Hinglish.
Rules:
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
''';
    }
  }

  String _extractText(Map<dynamic, dynamic> result) {
    dynamic text = result['text'] ??
        result['completion'] ??
        result['content'] ??
        result['result'];

    if (text == null && result.isNotEmpty) {
      final firstValue = result.values.first;
      if (firstValue is Map) {
        text = firstValue['text'] ?? firstValue['token'] ?? firstValue['content'];
      } else {
        text = firstValue;
      }
    }

    if (text == null) {
      throw Exception("Completion result me text nahi mila: $result");
    }

    return text.toString().trim();
  }
}
