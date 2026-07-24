import 'dart:convert';
import 'package:http/http.dart' as http;

class AiExplainerService {
  // 🛡️ API Key Assembly (Groq Key)
  static String _getKey1() {
    const String p1 = "gsk_LoIYC9hBn";
    const String p2 = "66OK3T1NFjUWGdyb3F";
    const String p3 = "YoSIE1A9ngox2B6TYJgrIhZgU";
    return "$p1$p2$p3";
  }

  static String get _activeApiKey => _getKey1();

  // 1️⃣ CUSTOM DOUBT SOLVER (User Input + Deep Conceptual Clarity)
  static Future<String> askCustomDoubt({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String explanation,
    required String userDoubt,
  }) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "⚠️ AI Service active nahi hai.";

    try {
      final String prompt = """
Aap BPSC/BSSC exams ke senior expert mentor hain.
Student ko is question me specific doubt aaya hai. Aapko student ka doubt thoroughly clear karna hai.

Context:
❓ Question: $question
📌 Options: ${options.join(', ')}
✅ Correct Answer: $correctAnswer
📖 Solution: $explanation

💬 Student Ka Specific Doubt: "$userDoubt"

🚨 STRICT RULES:
1. Do NOT limit to short sentences. Provide a deep, clear, and comprehensive explanation.
2. Do NOT repeat the question text or basic definition.
3. Strictly use simple Hinglish (English alphabets me Hindi). No Devanagari script.

Provide response in these sections:
🎯 DIRECT DOUBT RESOLUTION:
(Clear user's exact confusion with practical examples)

🔍 CORE & BACKGROUND CONCEPT:
(Explain the underlying theory/laws/history in detail)

💡 RELATED EXAM CONCEPTS:
(Share 2-3 connected facts/PYQ traps for upcoming exams)
""";

      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 700,
          "temperature": 0.6,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Doubt resolve nahi ho paya.";
      }
      return "⚠️ Service busy hai. Dubara try karein.";
    } catch (e) {
      return "⚠️ Connection Error: $e";
    }
  }

  // 2️⃣ AI WRONG VAULT ANALYZER (Weak Area & Smart Advice Generator)
  static Future<String> analyzeWrongQuestions(List<Map<String, dynamic>> wrongQuestions) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "⚠️ AI Mentor unavailable.";
    if (wrongQuestions.isEmpty) return "Sabaash! Aapka Vault khali hai, koi wrong question nahi hai.";

    try {
      List<String> qSummaries = wrongQuestions.take(15).map((q) {
        String qText = q['qe'] ?? q['qh'] ?? q['question'] ?? 'Question';
        String exp = q['explanation'] ?? q['e'] ?? '';
        return "- $qText (Topic/Exp: $exp)";
      }).toList();

      final String prompt = """
Aap BPSC, BSSC, aur Railway exams ke master AI Study Mentor hain.
Niche student ke haal me galat huye questions ki list di gayi hai:

${qSummaries.join('\n')}

Analyze these mistakes and provide a personalized Performance Audit Report in Hinglish (English alphabets me Hindi).

Format:
📊 WEAK SPOTS IDENTIFIED:
(Pinpoint exact sub-topics or subjects where the student is making maximum errors)

⚠️ COMMON ERROR PATTERN:
(Explain WHY they are failing - e.g. Formula confusion, Overthinking, Statement-based traps)

🎯 ACTIONABLE STUDY ADVICE:
(3 step-by-step practical suggestions to fix these mistakes in 7 days)
""";

      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 800,
          "temperature": 0.5,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Analysis generate nahi ho paya.";
      }
      return "⚠️ Analysis load nahi ho saka.";
    } catch (e) {
      return "⚠️ Error analyzing vault: $e";
    }
  }
}
