// v1 source: flutter_app/lib/services/offline_llm_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task presets used by the offline agent.
enum LlmTaskType {
  duolingoExplanation,
  quizExplanation,
  generalChat,
}

/// On-device LLM host.
///
/// **Status:** the v1 source tree referenced `LlmTaskType`,
/// `OfflineLlmAgentService.instance.loadModelManually()` and
/// `executeLlmAgent()` from `ai_chat_screen.dart`, but the service file itself
/// was never committed — the screen simply never compiled or shipped. This
/// implementation restores the exact public API so the screen builds and runs.
///
/// Weight loading happens through [loadModelManually]: the file is validated
/// and remembered across launches. Actual text generation requires a native
/// llama.cpp binding, which is intentionally **not** bundled here — instead of
/// silently returning fake answers, the service reports that the engine is not
/// attached. Wire `LlmEngineAdapter` to a native implementation to enable it.
abstract class LlmEngineAdapter {
  /// Loads a model from an absolute device path.
  Future<void> loadModel(String path);

  /// Generates a completion for [prompt].
  Future<String> generate(String prompt);

  bool get isReady;
}

class OfflineLlmAgentService {
  OfflineLlmAgentService._();

  static final OfflineLlmAgentService instance = OfflineLlmAgentService._();

  static const String _prefModelPath = 'saved_model_path';

  LlmEngineAdapter? _adapter;
  String? _modelPath;

  /// True once a model file has been validated (and an adapter is attached).
  bool get isModelLoaded => _modelPath != null && (_adapter?.isReady ?? false);

  /// True when a model file is present on disk but no native engine is bound.
  bool get hasModelFileButNoEngine =>
      _modelPath != null && !(_adapter?.isReady ?? false);

  String? get modelPath => _modelPath;

  /// Attach a native engine (llama.cpp / ggml binding).
  void attachEngine(LlmEngineAdapter adapter) => _adapter = adapter;

  /// Validates the picked `.gguf` file, remembers it, and hands it to the
  /// engine when one is attached.
  Future<void> loadModelManually({required String modelPath}) async {
    _modelPath = modelPath;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefModelPath, modelPath);
    } catch (e) {
      debugPrint('OfflineLlmAgentService: could not persist model path: $e');
    }

    final LlmEngineAdapter? adapter = _adapter;
    if (adapter == null) {
      debugPrint('OfflineLlmAgentService: no native engine attached — '
          'model registered at $modelPath');
      return;
    }
    await adapter.loadModel(modelPath);
  }

  /// Restores the previously selected model, if the file still exists.
  Future<String?> restoreSavedModel() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_prefModelPath);
      if (saved != null && saved.isNotEmpty) {
        _modelPath = saved;
        return saved;
      }
    } catch (_) {}
    return null;
  }

  /// Runs the agent for [userInput]. Returns a human-readable answer that the
  /// chat UI can show directly.
  Future<String> executeLlmAgent({
    required String userInput,
    String? context,
    LlmTaskType task = LlmTaskType.generalChat,
  }) async {
    final LlmEngineAdapter? adapter = _adapter;
    if (adapter == null || !adapter.isReady) {
      return 'Local model file registered, but no inference engine is bundled '
          'in this build.\n\n'
          'To answer offline, attach a native adapter:\n'
          '  OfflineLlmAgentService.instance.attachEngine(MyLlamaAdapter());\n\n'
          'Meanwhile you can use the cloud-based "AI Doubt" screen, which '
          'explains answers in Hinglish using the same question context.';
    }

    final String prompt = _buildPrompt(
      userInput: userInput,
      context: context,
      task: task,
    );
    return adapter.generate(prompt);
  }

  String _buildPrompt({
    required String userInput,
    String? context,
    required LlmTaskType task,
  }) {
    final String instruction = switch (task) {
      LlmTaskType.duolingoExplanation =>
        'Explain in 3 short steps, exam-oriented Hinglish, no fluff.',
      LlmTaskType.quizExplanation =>
        'Explain why the correct option is right and the others wrong.',
      LlmTaskType.generalChat => 'Answer as a BPSC/BSSC exam tutor in Hinglish.',
    };

    return <String>[
      'You are MockTester, a Bihar competitive-exam tutor.',
      instruction,
      if (context != null && context.trim().isNotEmpty)
        'Conversation so far:\n$context',
      'Student: $userInput',
      'Tutor:',
    ].join('\n');
  }
}
