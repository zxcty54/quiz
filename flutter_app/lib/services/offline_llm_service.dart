import 'package:flutter_gemma/flutter_gemma.dart';

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

  final _gemma = FlutterGemmaPlugin.instance;
  bool _isInitialized = false;

  bool get isReady => _isInitialized;

  Future<void> initEngine() async {
    if (_isInitialized) return;
    await _gemma.init(
      maxTokens: 512,
      temperature: 0.2,
      randomSeed: 1,
      topK: 1,
    );
    _isInitialized = true;
  }

  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    String systemPrompt;

    switch (task) {
      case LlmTaskType.quiz:
        systemPrompt = '''
You are an autonomous AI Quiz Generator for competitive exams (BPSC, BSSC, SSC).
Generate 2 MCQs for the user's topic based on the study context.
Format:
Q1. [Question]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct: [Option Letter]
Explanation: [1-line reason]
''';
        break;

      case LlmTaskType.analysis:
        systemPrompt = '''
You are an AI Diagnostic Evaluator.
Analyze the user's input/answer against the verified exam rule and explain the conceptual trap.
''';
        break;

      case LlmTaskType.mnemonic:
        systemPrompt = '''
You are an AI Memory Specialist.
Create a high-impact Hindi/Hinglish mnemonic code or acronym to remember this topic easily.
''';
        break;

      case LlmTaskType.summary:
        systemPrompt = '''
You are a Rapid-Revision AI Agent.
Summarize the topic into:
• 💡 Core Law / Definition
• ⚡ 3 Most Frequent Exam Points
• 🎯 Elimination Strategy
''';
        break;

      case LlmTaskType.duolingoExplanation:
      default:
        systemPrompt = '''
You are a Duolingo-style structured learning AI tutor for competitive exams.
Explain the topic in crisp points:
1. 💡 Micro Concept (1-line definition)
2. ⚡ 3-Step Breakdown (3 short bullet points)
3. 🎯 1 Micro Challenge MCQ with answer.

STUDY CONTEXT:
$context

TOPIC:
$userInput
''';
        break;
    }

    final fullPrompt = '''
<start_of_turn>user
$systemPrompt
<end_of_turn>
<start_of_turn>model
''';

    return await _gemma.getResponse(fullPrompt);
  }
}
