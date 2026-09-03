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
  String? _currentModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;

  Future<void> initEngine({String? modelPath}) async {
    if (_contextId != null) return;
    if (_isInitializing) return;

    _isInitializing = true;
    final path = modelPath ?? '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';

    if (!await File(path).exists()) {
      _isInitializing = false;
      throw Exception("GGUF Model file nahi mili: $path");
    }

    try {
      // FllamaPlatform initContext call: returns Map<Object?, dynamic>?
      final res = await FllamaPlatform.instance.initContext(
        path,
        nCtx: 768,
        nBatch: 768,
        nThreads: 4,
        useMmap: true,
        useMlock: false,
      );

      if (res != null && res.containsKey('contextId')) {
        _contextId = (res['contextId'] as num).toDouble();
        _currentModelPath = path;
      } else {
        throw Exception("Failed to retrieve valid contextId from native engine.");
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (_contextId == null) {
      await initEngine(modelPath: _currentModelPath);
    }

    if (_contextId == null) {
      throw Exception("fllama native context initialize nahi ho paya.");
    }

    String systemInstruction;

    switch (task) {
      case LlmTaskType.quiz:
        systemInstruction = '''
You are an AI Quiz Generator for Indian competitive exams (BPSC, BSSC, SSC).
Generate 2 standard MCQs based on the context.
Format:
Q1. [Question]
A) [Option 1] | B) [Option 2] | C) [Option 3] | D) [Option 4]
Correct: [Letter]
Explanation: [1 line]
''';
        break;

      case LlmTaskType.analysis:
        systemInstruction = '''
You are an AI Diagnostic Evaluator.
Analyze the user's answer against the concept and point out the trap in 2 crisp Hinglish lines.
''';
        break;

      case LlmTaskType.mnemonic:
        systemInstruction = '''
You are an AI Memory Specialist.
Create a high-impact Hindi/Hinglish mnemonic code or memory hook to remember this topic easily.
''';
        break;

      case LlmTaskType.summary:
        systemInstruction = '''
You are a Rapid-Revision AI Agent.
Summarize into:
• 💡 Core Concept
• ⚡ 3 High-Yield Exam Points
• 🎯 Elimination Tip
''';
        break;

      case LlmTaskType.duolingoExplanation:
      default:
        systemInstruction = '''
You are a Duolingo-style micro-learning AI tutor for Indian competitive exams.
Explain strictly using this exact 3-section format in simple Hinglish:

Micro Concept:
[1 crisp line definition]

3-Step Breakdown:
• [Step 1: Core rule or fact]
• [Step 2: Key application or formula]
• [Step 3: Common exam trap to avoid]

Micro Challenge:
Q: [One line question based on above concept]
A) [Option 1]  B) [Option 2]  C) [Option 3]  D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line]
''';
        break;
    }

    final userContent = '''
STUDY CONTEXT:
$context

TOPIC / INPUT:
$userInput
''';

    // RoleContent format matching FllamaPlatform
    final messages = [
      RoleContent(role: 'system', content: systemInstruction),
      RoleContent(role: 'user', content: userContent),
    ];

    final formattedPrompt = await FllamaPlatform.instance.getFormattedChat(
      _contextId!,
      messages: messages,
    );

    final finalPrompt = formattedPrompt ?? '''
<|im_start|>system
$systemInstruction
<|im_end|>
<|im_start|>user
$userContent
<|im_end|>
<|im_start|>assistant
''';

    // FllamaPlatform completion returns Future<Map<Object?, dynamic>?>
    final completionResult = await FllamaPlatform.instance.completion(
      _contextId!,
      prompt: finalPrompt,
      temperature: 0.2,
      nThreads: 4,
      nPredict: 512,
      stop: ['<|im_end|>', '<|endoftext|>'],
    );

    if (completionResult != null) {
      if (completionResult.containsKey('text')) {
        return (completionResult['text'] as String).trim();
      }
      if (completionResult.containsKey('completion')) {
        return (completionResult['completion'] as String).trim();
      }
      return completionResult.values.first.toString().trim();
    }

    return "No response generated from offline engine.";
  }

  Future<void> dispose() async {
    if (_contextId != null) {
      await FllamaPlatform.instance.releaseContext(_contextId!);
      _contextId = null;
    }
  }
}
