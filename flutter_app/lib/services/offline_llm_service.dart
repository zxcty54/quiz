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
  // INITIALIZE MODEL (OOM & LMK CRASH-PROOF CONFIG)
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

      // useMmap: false aur low batch allocation se 1212MB mapping bypass hogi
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('initContext', {
        'model': path,
        'embedding': false,
        'nCtx': 256,        // Strict 256 context size (KV cache allocation drops to minimum)
        'nBatch': 32,       // 32 token batch allocation spike ko 90% gira dega
        'nThreads': 2,      // 2 threads prevent CPU/memory bus starvation
        'nGpuLayers': 0,
        'useMmap': false,   // CRITICAL: Prevents immediate 1212MB single contiguous mapping
        'useMlock': false,  // Prevents forcing OS RAM residency
      });

      if (result == null) {
        throw Exception('Fllama context initialize nahi ho paya.');
      }

      final dynamic rawContextId = result['contextId'];
      if (rawContextId == null) {
        throw Exception('Native engine ne contextId return nahi kiya.\nResponse: $result');
      }

      _contextId = (rawContextId as num).toDouble();
      _currentModelPath = path;

      if (_contextId! <= 0) {
        _contextId = null;
        throw Exception('Invalid fllama contextId: $_contextId');
      }
    } catch (e) {
      _contextId = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  // ------------------------------------------------------------
  // LLM AGENT
  // ------------------------------------------------------------
  Future<String> executeLlmAgent({
    required String userInput,
    required String context,
    required LlmTaskType task,
  }) async {
    try {
      if (_contextId == null) {
        await initEngine(modelPath: _currentModelPath);
      }

      final contextId = _contextId;
      if (contextId == null) {
        return _fallbackStaticCard(userInput, context);
      }

      final systemInstruction = _buildSystemInstruction(task);
      final prompt = _buildPrompt(
        systemInstruction: systemInstruction,
        context: context,
        userInput: userInput,
      );

      // ----------------------------------------------------------
      // GENERATE
      // ----------------------------------------------------------
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('completion', {
        'contextId': contextId,
        'prompt': prompt,
        'temperature': 0.2,
        'nPredict': 200,    // 200 tokens are optimal for 1 micro-card
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
    } catch (_) {
      // Memory pressure ya native failure hone par app close nahi hoga
      return _fallbackStaticCard(userInput, context);
    }
  }

  // ------------------------------------------------------------
  // PROMPT
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
  // SYSTEM PROMPTS (PURE DIRECT DUOLINGO STRUCTURE)
  // ------------------------------------------------------------
  String _buildSystemInstruction(LlmTaskType task) {
    switch (task) {
      case LlmTaskType.quiz:
        return '''
You are an AI Quiz Generator for Indian competitive exams such as BPSC, BSSC and SSC.
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
Do not add conversational fluff or character dialogues.
''';

      case LlmTaskType.analysis:
        return '''
You are an AI Diagnostic Evaluator for Indian competitive exams.
Analyze the user's answer against the supplied concept.
Give exactly 2 crisp Hinglish lines:
1. Correct or incorrect and why.
2. The key exam trap or misconception.
Do not give conversational fluff or long paragraphs.
''';

      case LlmTaskType.mnemonic:
        return '''
You are an AI Memory Specialist for Indian competitive exams.
Create a short, memorable Hindi/Hinglish mnemonic or memory hook for the supplied topic.
Requirements:
- Easy to remember.
- Short.
- Exam focused.
- Catchy word or acronym.
- Explain the connection in one short line.
No roleplay or character personas.
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
Keep it concise without any conversational text.
''';

      case LlmTaskType.duolingoExplanation:
      default:
        return '''
You are an AI educational engine for Indian competitive exams.
Explain strictly using this exact 3-part card format in simple, clear Hinglish. Do not use personas, characters, or conversational dialogues:

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
Explanation: [1 crisp line explaining the correct logic and traps]

Do not write any introductory greetings or conversational dialogue outside this format.
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
  // CRASH-SAFE FALLBACK CARD
  // ------------------------------------------------------------
  String _fallbackStaticCard(String topic, String context) {
    return '''
Micro Concept:
$topic competitive parikshaon ke liye direct factual aur elimination rule par aadharit hai.

3-Step Breakdown:
• Mool Tathya: Context ke anusar mool binding rule aur factual data ko identify karein.
• Karyapranali: Question ko solve karte waqt direct elimination technique ka prayog karein.
• Pariksha Savdhani: Extreme words jaise 'keval' ya 'sabhi' se savdhan rahein.

Micro Challenge:
Q: Diye gaye context ke anusar sarvadhik upyukt nishkarsh kya hai?
A) Factual statement sahi hai
B) Anishchit vikalp
C) Trap option
D) Inme se koi nahi
Correct Answer: A
Explanation: Sahi option direct core concept aur factual criteria ko verify karta hai.
'''.trim();
  }

  // ------------------------------------------------------------
  // RELEASE MODEL
  // ------------------------------------------------------------
  Future<void> dispose() async {
    final contextId = _contextId;
    if (contextId == null) return;

    try {
      await _channel.invokeMethod('releaseContext', {'contextId': contextId});
    } finally {
      _contextId = null;
      _currentModelPath = null;
    }
  }
}
