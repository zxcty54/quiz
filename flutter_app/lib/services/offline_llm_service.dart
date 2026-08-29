import 'dart:io';

import 'package:flutter_llama/flutter_llama.dart';

class OfflineLlmService {
  OfflineLlmService._();

  static final OfflineLlmService instance = OfflineLlmService._();

  final FlutterLlama _llama = FlutterLlama.instance;

  bool get isModelLoaded => _llama.isModelLoaded;

  String? get modelPath => _llama.modelPath;

  Future<bool> loadModel(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('GGUF model file not found:\n$path');
    }

    final config = LlamaConfig(
      modelPath: path,

      // Start conservatively.
      nThreads: 4,

      // -1 = try all layers on GPU.
      // If device has problems, we will change this.
      nGpuLayers: -1,

      // 2048 is safer for mobile RAM.
      contextSize: 2048,

      batchSize: 256,

      useGpu: true,

      verbose: false,
    );

    return await _llama.loadModel(config);
  }

  Future<String> generate(String prompt) async {
    if (!_llama.isModelLoaded) {
      throw Exception('Gemma model is not loaded.');
    }

    final params = GenerationParams(
      prompt: prompt,
      temperature: 0.2,
      topP: 0.9,
      topK: 40,
      maxTokens: 384,
      repeatPenalty: 1.1,
    );

    final response = await _llama.generate(params);

    return response.text.trim();
  }

  Stream<String> generateStream(String prompt) {
    if (!_llama.isModelLoaded) {
      throw Exception('Gemma model is not loaded.');
    }

    final params = GenerationParams(
      prompt: prompt,
      temperature: 0.2,
      topP: 0.9,
      topK: 40,
      maxTokens: 384,
      repeatPenalty: 1.1,
    );

    return _llama.generateStream(params);
  }

  Future<Map<String, dynamic>?> getModelInfo() {
    return _llama.getModelInfo();
  }

  Future<void> unload() async {
    if (_llama.isModelLoaded) {
      await _llama.unloadModel();
    }
  }
}