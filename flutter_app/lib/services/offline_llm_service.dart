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

  static const String default05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  // ------------------------------------------------------------
  // 1. MANUAL MODEL LOADER
  // ------------------------------------------------------------
  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) return;

    final targetPath = modelPath ?? default05BPath;
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
        'path': targetPath,
        'modelUrl': targetPath,
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

      final dynamic rawId = result['contextId'] ?? result['id'] ?? result['context'];
      if (rawId == null) {
        throw Exception("ContextId null mila. Result: $result");
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
        'id': id,
      });
    } catch (_) {}

    _contextId = null;
    _loadedModelPath = null;
  }

  // ------------------------------------------------------------
  // 3. EXECUTE INFERENCE (NPE Crash-Proof Payload)
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
    final formattedPrompt = '''
<|im_start|>system
$systemInstruction
<|im_end|>
<|im_start|>user
${context.trim().isNotEmpty ? "STUDY CONTEXT:\n$context\n\n" : ""}OBSERVATION / QUERY:
$userInput
<|im_end|>
<|im_start|>assistant
''';

    // FLlama.java Line 46 crash prevention:
    // 'input' aur 'prompt' dono provide kiye gaye hain taaki koi bhi key null na mile
    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', <String, dynamic>{
      'contextId': currentId,
      'id': currentId,
      'prompt': formattedPrompt,
      'input': <Map<String, String>>[
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': userInput},
      ],
      'messages': <Map<String, String>>[
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': userInput},
      ],
      'temperature': 0.2,
      'topP': 0.95,
      'nPredict': 350,
      'max_tokens': 350,
      'nThreads': 2,
      'threads': 2,
      'penaltyRepeat': 1.1,
      'repeatPenalty': 1.1,
      'stop': <String>['<|im_end|>', '<|endoftext|>'],
    });

    if (result == null) {
      throw Exception("Native completion returned null.");
    }

    return _extractText(result);
  }

  // ------------------------------------------------------------
  // PEDAGOGY PROMPT (1 Screen WhatsApp Style Raju vs Aman Sir)
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    return '''
You are an AI pedagogical engine for competitive exams (BPSC, BSSC, SSC).
Strictly follow this 1-screen WhatsApp chat micro-card format in simple, natural Hinglish.
Rules:
- Explain WHY before WHAT.
- Raju shares a real-life observation or doubt from daily surroundings.
- Aman Sir clears it directly with no textbook formality.

Micro Concept:
[1 crisp line definition of core rule]

Raju vs Aman Sir:
Raju: [Real-life curiosity or doubt]
Aman Sir: [Direct logic clearing Raju's doubt]

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

Do not write any introductory greetings or conversational dialogue outside this format.
''';
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
      throw Exception("Native completion map me text nahi mila: $result");
    }

    return text.toString().trim();
  }
}
