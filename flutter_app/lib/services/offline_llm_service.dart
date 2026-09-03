import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

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

  Llama? _llama;
  bool _isInitialized = false;

  bool get isReady => _isInitialized;

  Future<void> initEngine({String? modelPath}) async {
    if (_isInitialized) return;

    final path = modelPath ?? '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';

    if (!await File(path).exists()) {
      throw Exception("GGUF Model file nahi mili: $path");
    }

    final contextParams = ContextParams()
      ..nCtx = 768
      ..nThreads = 4;

    final modelParams = ModelParams();

    _llama = Llama(
      path,
      modelParams: modelParams,
      contextParams: contextParams,
    );

    _isInitialized = true;
  }

  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (!_isInitialized || _llama == null) {
      await initEngine();
    }

    String systemInstruction;

    switch (task) {
      case LlmTaskType.quiz:
        systemInstruction = '''
You are an AI Quiz Generator for competitive exams (BPSC, BSSC, SSC).
Generate 2 MCQs based on the context.
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
Create a high-impact Hindi/Hinglish mnemonic code or trick to remember this topic easily.
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
You are a Duolingo-style structured learning AI tutor for Indian competitive exams.
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

    final fullChatmlPrompt = '''
<|im_start|>system
$systemInstruction
<|im_end|>
<|im_start|>user
STUDY CONTEXT:
$context

TOPIC / INPUT:
$userInput
<|im_end|>
<|im_start|>assistant
''';

    _llama!.setPrompt(fullChatmlPrompt);

    final buffer = StringBuffer();

    while (true) {
      final (tokenText, isDone) = _llama!.getNext();

      if (isDone || tokenText.isEmpty) {
        break;
      }

      if (tokenText == '<|im_end|>' ||
          tokenText == '<|endoftext|>' ||
          tokenText == '<|im_start|>') {
        break;
      }

      buffer.write(tokenText);
    }

    return buffer.toString().trim();
  }

  void dispose() {
    _llama?.dispose();
    _isInitialized = false;
  }
}
