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
  String? _currentModelPath;
  bool _isInitializing = false;

  bool get isReady => _contextId != null;

  static const String defaultModelPath = '/sdcard/Download/qwen3-5-2B-Q4_K_M.gguf';

  // ------------------------------------------------------------
  // INITIALIZE MODEL (STRICT NULL & CRASH CHECK)
  // ------------------------------------------------------------
  Future<void> initEngine({String? modelPath}) async {
    if (_contextId != null) return;
    if (_isInitializing) return;

    _isInitializing = true;
    final path = modelPath ?? defaultModelPath;

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('GGUF model file nahi mili:\n$path');
      }

      // Memory-optimized parameters to prevent native initialization failure
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('initContext', {
        'model': path,
        'embedding': false,
        'nCtx': 512,
        'nBatch': 128,
        'nThreads': 2,
        'nGpuLayers': 0,
        'useMmap': true,    // true rakhein taaki file direct disk se stream ho
        'useMlock': false,   // false rakhein taaki physical RAM force lock na ho
      });

      if (result == null) {
        throw Exception('Fllama native init ne null return kiya.');
      }

      // Safe casting: contextId can be int or double
      final dynamic rawContextId = result['contextId'];
      if (rawContextId == null) {
        throw Exception('ContextId null mila native engine se. Engine response: $result');
      }

      final parsedId = (rawContextId as num).toDouble();
      if (parsedId <= 0) {
        throw Exception('Invalid contextId received: $parsedId');
      }

      _contextId = parsedId;
      _currentModelPath = path;
    } catch (e) {
      _contextId = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  // ------------------------------------------------------------
  // LLM AGENT EXECUTION
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    try {
      // Step 1: Ensure engine is initialized
      if (_contextId == null) {
        await initEngine(modelPath: _currentModelPath);
      }

      final contextId = _contextId;
      // Step 2: Strictly prevent calling completion if contextId is null
      if (contextId == null) {
        return _fallbackStaticCard(userInput, context);
      }

      final systemInstruction = _buildSystemInstruction(task);
      final prompt = _buildPrompt(
        systemInstruction: systemInstruction,
        context: context,
        userInput: userInput,
      );

      // Step 3: Native completion call with non-null contextId
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', {
        'contextId': contextId,
        'prompt': prompt,
        'temperature': 0.2,
        'nPredict': 256,
        'nThreads': 2,
        'stop': const [
          '<|im_end|>',
          '<|endoftext|>',
        ],
      });

      if (result == null) {
        return _fallbackStaticCard(userInput, context);
      }

      return _extractText(result);
    } catch (e) {
      // Native exception aane par UI crash nahi hoga, structured fallback card load hoga
      return _fallbackStaticCard(userInput, context);
    }
  }

  // ------------------------------------------------------------
  // PROMPT BUILDER
  // ------------------------------------------------------------
  String _buildPrompt({
    required String systemInstruction,
    required String context,
    required String userInput,
  }) {
    return '''
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
  }

  // ------------------------------------------------------------
  // DIRECT DUOLINGO CARD SYSTEM PROMPTS
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
You are an AI Quiz Generator for Indian competitive exams (BPSC, BSSC, SSC).
Generate exactly 2 standard MCQs based only on the supplied study context.
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
Create a short, memorable Hindi/Hinglish mnemonic or memory hook for the supplied topic.
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
Explain strictly using this exact 3-part card format in simple Hinglish:

Micro Concept:
[1 crisp line definition of the core rule]

3-Step Breakdown:
• Step 1: [Core rule or constitutional/scientific fact]
• Step 2: [Key application or formula]
• Step 3: [Common exam trap or elimination rule]

Micro Challenge:
Q: [One line question based on the concept]
A) [Option 1]
B) [Option 2]
C) [Option 3]
D) [Option 4]
Correct Answer: [Letter]
Explanation: [1 crisp line explaining why other options are traps]

Do not write any introductory greetings or conversational dialogue.
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
      return 'No response generated from offline engine.';
    }

    return text.toString().trim();
  }

  // ------------------------------------------------------------
  // SAFETY FALLBACK MICRO CARD
  // ------------------------------------------------------------
  String _fallbackStaticCard(String topic, String context) {
    return '''
Micro Concept:
$topic competitive parikshaon ke liye factual accuracy aur core elimination rule par aadharit hai.

3-Step Breakdown:
• Step 1: Context ke mool concept ko dhyan se padhein aur direct statement note karein.
• Step 2: Prashn me trap statements (jaise 'keval' ya 'sabhi') ko eliminate karein.
• Step 3: BPSC/SSC parikshaon me factual verification hamesha prioritize karein.

Micro Challenge:
Q: Diye gaye context ke anusar sahi vikalp chunein:
A) Concept statement satya hai
B) Anishchit vikalp
C) Trap option
D) Inme se koi nahi
Correct Answer: A
Explanation: Sahi option direct factual rule aur context ko verify karta hai.
'''.trim();
  }

  // ------------------------------------------------------------
  // CLEAN DISPOSE
  // ------------------------------------------------------------
  Future<void> dispose() async {
    final contextId = _contextId;
    if (contextId == null) return;

    try {
      await _channel.invokeMethod('releaseContext', {'contextId': contextId});
    } catch (_) {}
    _contextId = null;
    _currentModelPath = null;
  }
}
