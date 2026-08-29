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

    // Check potential GGUF file locations in phone storage
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
      final response = _llama!.prompt(formattedPrompt);
      final output = response.trim();
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
