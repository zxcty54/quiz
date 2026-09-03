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

  // fllama context ID
  double? _contextId;
  String? _currentModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;

  // Default Qwen GGUF model
  static const String defaultModelPath = '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';

  /// Initialize the native llama.cpp context.
  Future<void> initEngine({String? modelPath}) async {
    // Already initialized
    if (_contextId != null) {
      return;
    }

    // Prevent duplicate initialization
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    final path = modelPath ?? defaultModelPath;

    try {
      // Check model file
      final modelFile = File(path);
      if (!await modelFile.exists()) {
        throw Exception('GGUF model file nahi mili:\n$path');
      }

      final fllama = FllamaPlatform.instance;

      // Initialize llama.cpp context
      final result = await fllama.initContext(
        path,
        nCtx: 768,
        nBatch: 768,
        nThreads: 4,
        useMmap: true,
        useMlock: false,
      );

      if (result == null) {
        throw Exception('Fllama context initialize nahi ho paya.');
      }

      final dynamic contextValue = result['contextId'];
      if (contextValue == null) {
        throw Exception('Native engine ne contextId return nahi kiya.');
      }

      _contextId = (contextValue as num).toDouble();
      _currentModelPath = path;
    } catch (e) {
      _contextId = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Execute an offline LLM task.
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    // Initialize model if required.
    if (_contextId == null) {
      await initEngine(modelPath: _currentModelPath);
    }

    final contextId = _contextId;
    if (contextId == null) {
      throw Exception('Fllama native context initialize nahi ho paya.');
    }

    final systemInstruction = _buildSystemInstruction(task);
    final userContent = '''
STUDY CONTEXT:
$context

TOPIC / INPUT:
$userInput
''';

    final fllama = FllamaPlatform.instance;

    // Build chat messages.
    final messages = <RoleContent>[
      RoleContent(
        role: 'system',
        content: systemInstruction,
      ),
      RoleContent(
        role: 'user',
        content: userContent,
      ),
    ];

    // Let fllama/llama.cpp format the chat according to the model.
    String formattedPrompt;
    try {
      final formatted = await fllama.getFormattedChat(
        contextId,
        messages: messages,
      );
      formattedPrompt = formatted ?? _fallbackPrompt(systemInstruction, userContent);
    } catch (_) {
      // Fallback if chat template is unavailable.
      formattedPrompt = _fallbackPrompt(systemInstruction, userContent);
    }

    // Generate completion.
    final result = await fllama.completion(
      contextId,
      prompt: formattedPrompt,
      temperature: 0.2,
      nPredict: 512,
      nThreads: 4,
      stop: const [
        '<|im_end|>',
        '<|endoftext|>',
      ],
    );

    if (result == null) {
      return 'No response generated from offline engine.';
    }

    return _extractCompletionText(result);
  }

  /// Creates the system prompt for each task.
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
You are an AI Quiz Generator for Indian competitive exams such as BPSC, BSSC and SSC.
Generate exactly 2 standard MCQs based ONLY on the supplied study context.
Format:
Q1. [Question]
A) [Option 1] | B) [Option 2] | C) [Option 3] | D) [Option 4]
Correct: [Letter]
Explanation: [One short line]
Q2. [Question]
A) [Option 1] | B) [Option 2] | C) [Option 3] | D) [Option 4]
Correct: [Letter]
Explanation: [One short line]
Do not add unnecessary text.
''';

      case LlmTaskType.analysis:
        return '''
You are an AI Diagnostic Evaluator for Indian competitive exam preparation.
Analyze the user's answer against the provided concept.
Give the result in exactly 2 crisp Hinglish lines:
1. Whether the answer/reasoning is correct or incorrect.
2. The key trap or misconception the student should remember.
Do not give a long explanation.
''';

      case LlmTaskType.mnemonic:
        return '''
You are an AI Memory Specialist for Indian competitive exam students.
Create a high-impact Hindi/Hinglish mnemonic or memory hook for the given topic.
Requirements:
- Easy to remember.
- Short.
- Exam focused.
- Prefer a catchy word, phrase or story.
- Explain the connection in one short line.
''';

      case LlmTaskType.summary:
        return '''
You are a Rapid Revision AI Agent for Indian competitive exams.
Summarize the supplied study context using exactly this format:
💡 Core Concept: [One crisp explanation]
⚡ 3 High-Yield Exam Points:
• Point 1
• Point 2
• Point 3
🎯 Elimination Tip: [One practical MCQ elimination tip]
Keep it concise.
''';

      case LlmTaskType.duolingoExplanation:
      default:
        return '''
You are a Duolingo-style micro-learning AI tutor for Indian competitive exams.
Explain the topic strictly using this format in simple Hinglish:

Micro Concept:
[1 crisp line definition]

3-Step Breakdown:
• [Step 1: Core rule or fact]
• [Step 2: Key application or formula]
• [Step 3: Common exam trap to avoid]

Micro Challenge:
Q: [One line question based on the concept]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line]

Do not add anything outside this format.
''';
    }
  }

  /// Fallback prompt if the model/package cannot provide its native chat template.
  String _fallbackPrompt(
    String systemInstruction,
    String userContent,
  ) {
    return '''
<|im_start|>system
$systemInstruction
<|im_end|>
<|im_start|>user
$userContent
<|im_end|>
<|im_start|>assistant
''';
  }

  /// Extract generated text safely from fllama result.
  String _extractCompletionText(Map<Object?, dynamic> result) {
    dynamic text;
    text = result['text'];
    if (text == null) {
      text = result['completion'];
    }
    if (text == null) {
      text = result['content'];
    }
    if (text == null && result.isNotEmpty) {
      text = result.values.first;
    }
    if (text == null) {
      return 'No response generated from offline engine.';
    }
    return text.toString().trim();
  }

  /// Release native context.
  Future<void> dispose() async {
    final contextId = _contextId;
    if (contextId == null) {
      return;
    }
    try {
      await FllamaPlatform.instance.releaseContext(contextId);
    } finally {
      _contextId = null;
      _currentModelPath = null;
    }
  }
}
