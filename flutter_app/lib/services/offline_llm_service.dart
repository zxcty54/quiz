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

  int? _contextId;
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
      // fllama 0.0.1 documented context initialization
      _contextId = await Fllama.initContext(
        path,
        contextSize: 768,
        nThreads: 4,
      );
      _currentModelPath = path;
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
      throw Exception("Failed to initialize fllama native context.");
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

    // 1. Format chat template using fllama's chat formatter
    final formattedPrompt = await Fllama.getFormattedChat(
      _contextId!,
      [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': userContent},
      ],
    );

    final StringBuffer buffer = StringBuffer();

    // 2. Token completion generation
    await Fllama.completion(
      _contextId!,
      formattedPrompt ?? userContent,
      temperature: 0.2,
      onToken: (token) {
        if (token.isNotEmpty) {
          buffer.write(token);
        }
      },
    );

    return buffer.toString().trim();
  }

  Future<void> dispose() async {
    if (_contextId != null) {
      await Fllama.releaseContext(_contextId!);
      _contextId = null;
    }
  }
}
