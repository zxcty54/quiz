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

  dynamic _contextId;
  String? _loadedModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;
  String? get activeModelName => _loadedModelPath?.split('/').last;

  // Phone ka verified 0.5B path
  static const String default05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  // ------------------------------------------------------------
  // 1. MANUAL LOADER (Crash-Free Native Binding)
  // ------------------------------------------------------------
  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? default05BPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception('GGUF file nahi mili:\n$targetPath');
    }

    _isInitializing = true;

    try {
      if (_contextId != null) {
        await unloadModel();
      }

      // Memory parameters strictly sized for mobile stability
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
        throw Exception('Native init failed: null response returned.');
      }

      // Null check: Native reference preserve rakhein
      final dynamic rawId = result['contextId'] ?? result['id'] ?? result['context'];
      if (rawId == null) {
        throw Exception('Native engine contextId null mila. Result: $result');
      }

      _contextId = rawId;
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
  // 2. UNLOAD CONTEXT
  // ------------------------------------------------------------
  Future<void> unloadModel() async {
    final id = _contextId;
    if (id == null) return;

    try {
      await _channel.invokeMethod('releaseContext', {'contextId': id});
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. RUN INFERENCE (Strict Null-Safe Call)
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (_contextId == null) {
      await loadModelManually(modelPath: _loadedModelPath);
    }

    final validId = _contextId;
    if (validId == null) {
      throw Exception('ContextId is null! Model pehle load karein.');
    }

    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    // Native layer ko exact validId pass karein
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', {
      'contextId': validId,
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
      throw Exception('Native completion null return hua.');
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
${contextBlock}OBSERVATION / QUERY:
$userInput
<|im_end|>
<|im_start|>assistant
''';
  }

  // ------------------------------------------------------------
  // NOTEBOOK WHATSAPP CHAT PEDAGOGY PROMPT
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
Generate 2 MCQs based strictly on the context.
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
Rules:
- Explain WHY before WHAT.
- Raju observes real life or raises a doubt.
- Aman Sir resolves the doubt directly without textbook jargon.
- Strictly follow this 1-screen WhatsApp card format:

Micro Concept:
[1 crisp line definition of core rule]

Raju vs Aman Sir:
Raju: [Real-life observation or doubt]
Aman Sir: [Clear, direct explanation solving Raju's doubt]

3-Step Breakdown:
• Mool Tathya: [Core factual rule]
• Karyapranali: [Direct application / formula]
• Pariksha Savdhani: [Elimination trap to avoid]

Micro Challenge:
Q: [One line standard MCQ question]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line trap explanation]

Do not write any introductory greetings or conversational dialogue outside this format.
''';
    }
  }

  // ------------------------------------------------------------
  // TEXT EXTRACTOR
  // ------------------------------------------------------------
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
      throw Exception('Completion output me koi valid text nahi mila: $result');
    }

    return text.toString().trim();
  }
}
