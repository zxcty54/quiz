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

  double? _contextId;
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
      throw Exception("GGUF model file nahi mili:\n$targetPath");
    }

    _isInitializing = true;

    try {
      if (_contextId != null) {
        await unloadModel();
      }

      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('initContext', <String, dynamic>{
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
        throw Exception("Native engine ne initContext par null return kiya.");
      }

      final dynamic rawId = result['contextId'] ?? result['id'];
      if (rawId == null) {
        throw Exception("ContextId null mila. Native response: $result");
      }

      _contextId = (rawId as num).toDouble();
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
      await _channel.invokeMethod('releaseContext', <String, dynamic>{
        'contextId': id,
      });
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (Zero-NPE Parameter Map)
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
      throw Exception("Model load nahi hai. Pehle loadModelManually() call karein.");
    }

    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    // Sabhi expected native fields explicitly provided with concrete types to avoid getClass() NPE
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', <String, dynamic>{
      'contextId': currentId,
      'prompt': prompt,
      'temperature': 0.2,
      'nPredict': 300,
      'nThreads': 2,
      'penaltyRepeat': 1.1,
      'repeatPenalty': 1.1,
      'stop': <String>['<|im_end|>', '<|endoftext|>'],
    });

    if (result == null) {
      throw Exception("Native completion ne null response return kiya.");
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
${contextBlock}DAILY OBSERVATION / TOPIC:
$userInput
<|im_end|>
<|im_start|>assistant
''';
  }

  // ------------------------------------------------------------
  // NOTEBOOK STRUCTURE PROMPT
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
Explain strictly using this exact 1-screen conversational card format in clear Hinglish:
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

  // ------------------------------------------------------------
  // EXTRACT RESULT TEXT
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
      throw Exception("Native completion map me valid text nahi mila: $result");
    }

    return text.toString().trim();
  }
}
