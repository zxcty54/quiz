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

  LlamaProcessor? _processor;
  bool _isInitialized = false;

  bool get isReady => _isInitialized;

  Future<void> initEngine({String? modelPath}) async {
    if (_isInitialized) return;

    // Default test path agar pass na kiya ho
    final path = modelPath ?? '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';

    if (!await File(path).exists()) {
      throw Exception("GGUF Model file nahi mili: $path");
    }

    // Context size ko 512-768 par limit rakha hai taaki RAM 1.2GB ke andar rahe
    final contextParams = ContextParams()
      ..nCtx = 768
      ..nThreads = 4;

    _processor = LlamaProcessor(
      modelPath: path,
      contextParams: contextParams,
    );

    _isInitialized = true;
  }

  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    if (!_isInitialized || _processor == null) {
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
Explain in crisp points using simple Hinglish:
1. 💡 Micro Concept (1-line definition)
2. ⚡ 3-Step Breakdown (3 short bullet points)
3. 🎯 1 Micro Challenge MCQ with answer.
''';
        break;
    }

    // Qwen 2.5/3 ChatML Template format
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

    // Model se inference call
    final response = await _processor!.process(
      fullChatmlPrompt,
      temperature: 0.2,
      topK: 30,
    );

    return response.trim();
  }

  void dispose() {
    _processor?.unloadModel();
    _isInitialized = false;
  }
}
