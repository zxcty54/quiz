import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class OfflineLlmService {
  OfflineLlmService._();

  static final OfflineLlmService instance = OfflineLlmService._();

  Llama? _llama;
  String? _modelPath;

  bool get isModelLoaded => _llama != null;

  String? get modelPath => _modelPath;

  Future<bool> loadModel(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('GGUF model file not found:\n$path');
    }

    // Cleanup previous instance
    await unload();

    try {
      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0;

      final contextParams = ContextParams();
      contextParams.context = 2048;
      contextParams.nThreads = 4;

      _llama = Llama(
        path,
        modelParams: modelParams,
        contextParams: contextParams,
      );

      _modelPath = path;
      return true;
    } catch (e) {
      _llama = null;
      _modelPath = null;
      throw Exception('Failed to load GGUF model on Phone CPU: $e');
    }
  }

  Future<String> generate(String prompt) async {
    if (_llama == null) {
      throw Exception('AI model is not loaded.');
    }

    final buffer = StringBuffer();
    final stream = _llama!.prompt(prompt);

    await for (final token in stream) {
      buffer.write(token);
    }

    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw Exception('Model returned an empty response.');
    }

    return result;
  }

  Stream<String> generateStream(String prompt) {
    if (_llama == null) {
      throw Exception('AI model is not loaded.');
    }

    return _llama!.prompt(prompt);
  }

  Future<void> unload() async {
    if (_llama != null) {
      _llama!.dispose();
      _llama = null;
      _modelPath = null;
    }
  }
}
