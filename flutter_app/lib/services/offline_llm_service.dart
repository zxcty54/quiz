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
  String? get activeModelPath => _loadedModelPath;
  String? get activeModelName => _loadedModelPath?.split('/').last;

  // Phone me verified path
  static const String verified05BPath =
      '/storage/emulated/0/Download/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  // ------------------------------------------------------------
  // 1. STRICT MANUAL MODEL LOADER
  // ------------------------------------------------------------
  Future<void> loadModelManually({String? modelPath}) async {
    if (_isInitializing) {
      throw Exception("Pehle se ek model initialize ho raha hai, kripya intezar karein.");
    }

    final targetPath = modelPath ?? verified05BPath;
    final file = File(targetPath);

    if (!await file.exists()) {
      throw Exception(
        "GGUF model file nahi mili:\n$targetPath\nKripya phone ke Download folder me check karein.",
      );
    }

    _isInitializing = true;

    try {
      // Purana loaded context memory se free karein
      if (_contextId != null) {
        await unloadModel();
      }

      // Memory-optimized parameters to prevent LMK Allocating crash
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('initContext', {
        'model': targetPath,
        'embedding': false,
        'nCtx': 512,
        'nBatch': 64,       // Buffer allocation spike control
        'nThreads': 2,      // Smooth execution without heating
        'nGpuLayers': 0,
        'useMmap': true,
        'useMlock': false,
      });

      if (result == null) {
        throw Exception("Native engine ne initContext par null return kiya.");
      }

      final dynamic rawContextId = result['contextId'];
      if (rawContextId == null) {
        throw Exception("Native engine se contextId null mila. Result: $result");
      }

      final parsedId = (rawContextId as num).toDouble();
      if (parsedId <= 0) {
        throw Exception("Invalid contextId pointer: $parsedId");
      }

      _contextId = parsedId;
      _loadedModelPath = targetPath;
    } finally {
      _isInitializing = false;
    }
  }

  // ------------------------------------------------------------
  // 2. MANUAL UNLOAD / DISPOSE
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
  // 3. EXECUTE LLM (Pure Dynamic Generation - No Fake Fallbacks)
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    // Model manual load hona anivarya hai
    if (_contextId == null) {
      throw Exception(
        "Model load nahi hai! Pehle loadModelManually() call karke model initialize karein.",
      );
    }

    final currentId = _contextId!;
    final systemInstruction = _buildSystemInstruction(task);
    final prompt = _buildPrompt(
      systemInstruction: systemInstruction,
      context: context,
      userInput: userInput,
    );

    final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', {
      'contextId': currentId,
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
${contextBlock}TOPIC / INPUT:
$userInput
<|im_end|>
<|im_start|>assistant
''';
  }

  // ------------------------------------------------------------
  // NOTEBOOK STRUCTURE PROMPTS
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
You are an AI Quiz Generator for Indian competitive exams (BPSC, BSSC, SSC).
Generate exactly 2 standard MCQs based strictly on the supplied study context.
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

      case LlmTaskType.analysis:
        return '''
You are an AI Diagnostic Evaluator for Indian competitive exams.
Analyze the user's answer against the supplied concept.
Give exactly 2 crisp Hinglish lines:
1. Correct or incorrect and why.
2. The key exam trap or misconception.
No conversational greetings.
''';

      case LlmTaskType.mnemonic:
        return '''
You are an AI Memory Specialist for Indian competitive exams.
Create a short, memorable Hindi/Hinglish mnemonic code or hook for the supplied topic.
Requirements:
- Easy to remember.
- Short & exam focused.
- Catchy acronym or word.
- Explain the connection in one short line.
''';

      case LlmTaskType.summary:
        return '''
You are a Rapid Revision AI Agent for Indian competitive exams.
Summarize the supplied context using exactly this format:
💡 Core Concept: [One crisp explanation]
⚡ 3 High-Yield Exam Points:
• Point 1
• Point 2
• Point 3
🎯 Elimination Tip: [One practical MCQ elimination tip]
''';

      case LlmTaskType.duolingoExplanation:
      default:
        return '''
You are an AI educational engine for Indian competitive exams.
Explain strictly using this exact 3-part card format in simple, clear Hinglish:

Micro Concept:
[1 crisp line definition of the core rule]

3-Step Breakdown:
• Mool Tathya: [Core rule or constitutional/scientific fact]
• Karyapranali: [Direct application or formula]
• Pariksha Savdhani: [Common exam trap or elimination rule]

Micro Challenge:
Q: [One line question based on the concept]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line explaining why other options are traps]

Do not write introductory greetings or extra text outside this format.
''';
    }
  }

  // ------------------------------------------------------------
  // EXTRACT RESPONSE
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
      throw Exception("Native completion Map me valid text key nahi mili: $result");
    }

    return text.toString().trim();
  }
}
