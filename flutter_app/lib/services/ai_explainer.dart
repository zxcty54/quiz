import 'dart:convert';
import 'package:http/http.dart' as http;

class AiExplainerService {
  // 🛡️ API Key Assembly
  static String _getKey1() {
    const String p1 = "gsk_LoIYC9hBn";
    const String p2 = "66OK3T1NFjUWGdyb3F";
    const String p3 = "YoSIE1A9ngox2B6TYJgrIhZgU";
    return "$p1$p2$p3";
  }

  static String _getKey2() => "";
  static String _getKey3() => "";

  static int _currentKeyIndex = 0;

  static String get _activeApiKey {
    List<String> validKeys = [
      _getKey1(),
      _getKey2(),
      _getKey3(),
    ].where((k) => k.trim().isNotEmpty).toList();

    if (validKeys.isEmpty) return "";

    String selectedKey = validKeys[_currentKeyIndex % validKeys.length];
    _currentKeyIndex++;

    return selectedKey;
  }

  static Future<String> getExplanation({
    required String question,
    required List<String> options,
    required String correctAnswer,
  }) async {
    final String apiKey = _activeApiKey;
    if (apiKey.isEmpty) {
      return "⚠️ AI Service configure nahi hai.";
    }

    try {
      final String prompt = """
Aap BPSC, BSSC aur SSC exams ke expert mentor hain.
Kripya niche diye gaye question ka clear, short aur easy Hindi language me explanation dein:

❓ Question: $question
📌 Options: ${options.join(', ')}
✅ Correct Answer: $correctAnswer

Instructions:
1. Short bullet points me explanation dein.
2. Important facts ya short trick batayein.
""";

      // 🚀 Groq Endpoint Call with Timeout
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant", // ⚡ Updated Latest Fast Groq Model
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 500,
          "temperature": 0.5,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Explanation load nahi ho paya.";
      } else {
        return "⚠️ Groq Error (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      return "⚠️ Error: $e";
    }
  }
}
