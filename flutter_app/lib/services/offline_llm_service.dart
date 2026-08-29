import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

class OfflineLlmService {
  static final OfflineLlmService instance = OfflineLlmService._internal();
  OfflineLlmService._internal();

  Llama? _llama;
  bool _isLoaded = false;
  bool get isModelReady => _isLoaded;

  Future<bool> initializeEngine() async {
    if (_isLoaded) return true;

    // 1. Check local model file locations
    final devPath = File('/storage/emulated/0/Download/gemma-2-2b-it-Q4_K_M.gguf');
    final appDocDir = await getApplicationDocumentsDirectory();
    final internalPath = File('${appDocDir.path}/gemma-2-2b-it-Q4_K_M.gguf');

    String? targetModelPath;
    if (await devPath.exists()) {
      targetModelPath = devPath.path;
    } else if (await internalPath.exists()) {
      targetModelPath = internalPath.path;
    }

    if (targetModelPath == null) return false;

    try {
      final modelParams = ModelParams();
      final contextParams = ContextParams()
        ..contextSize = 1024
        ..nThreads = Platform.numberOfProcessors > 2 ? Platform.numberOfProcessors - 1 : 2;

      _llama = Llama(
        targetModelPath,
        modelParams,
        contextParams,
      );

      _isLoaded = true;
      return true;
    } catch (_) {
      _isLoaded = false;
      return false;
    }
  }

  Future<String> generateResponse({
    required String userPrompt,
    required String contextFacts,
  }) async {
    if (!_isLoaded || _llama == null) {
      return "⚠️ Offline Model load nahi hua. Model file check karein.";
    }

    final formattedPrompt = """
<start_of_turn>system
Aap ek smart BPSC/SSC Science tutor ho.
Rule:
- Agar student casual baat kare toh polite Hinglish me reply do.
- Agar study doubt ho toh diye gaye context ki madad se concise points me explain karo.

[TEXTBOOK CONTEXT]:
$contextFacts
<end_of_turn>
<start_of_turn>user
$userPrompt
<end_of_turn>
<start_of_turn>model
""";

    try {
      final buffer = StringBuffer();
      
      // llama_cpp_dart 0.0.9 uses prompt Stream generator
      final stream = _llama!.prompt(formattedPrompt);
      await for (final token in stream) {
        buffer.write(token);
      }

      final output = buffer.toString().trim();
      return output.isNotEmpty ? output : "Response generate nahi ho saka.";
    } catch (e) {
      return "⚠️ Local Inference Error: $e";
    }
  }

  void dispose() {
    _llama?.dispose();
    _isLoaded = false;
  }
}
