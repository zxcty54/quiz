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

  // 1️⃣ CUSTOM DOUBT SOLVER (Pure Human Teacher Conversational Tone)
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
You are a warm, highly experienced, and friendly BPSC/BSSC Exam Teacher from Patna who explains concepts in natural conversational Hinglish (Roman Hindi written in English alphabets), just like a real human tutor.

A student came to you with a specific doubt on a question.

CONTEXT:
Question: $question
Options: ${options.join(', ')}
Correct Answer: $correctAnswer
Standard Solution: $explanation

STUDENT'S EXACT DOUBT: "$userDoubt"

STRICT TEACHING RULES:
1. Speak DIRECTLY to the student in friendly Hinglish (e.g., "Dekho...", "Bilkul simple example se samjho...", "Aisa isliye hota hai kyunki...").
2. DO NOT use ANY robotic template headers like 'Direct Answer:', 'Core Concept:', 'Section 1:', etc.
3. ALWAYS use a practical, relatable daily-life comparison or analogy (e.g., water pipe, heater, traffic, daily objects) to clear the doubt.
4. Explain clearly why the student's doubt point is wrong or right.
5. End naturally with 1 short line mentioning a related PYQ fact or exam trap.
6. Strictly NO Devanagari script (pure Hindi text banned). Use natural Hinglish only.
""";

      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile", // ⚡ Upgraded High-End 70B Model
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 800,
          "temperature": 0.7, // Natural and warm conversational tone
        }),
      ).timeout(const Duration(seconds: 15));

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
You are a master AI Study Mentor for BPSC, BSSC, and Railway exams.
Below is the list of recent wrong questions attempted by the student:

${qSummaries.join('\n')}

Analyze these mistakes and provide a warm, encouraging Performance Audit Report in simple Hinglish (English alphabets me Hindi).

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
          "model": "llama-3.3-70b-versatile",
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

  // 3️⃣ COMPATIBILITY METHOD FOR OLD CBT WIDGETS
  static Future<String> getExplanation({
    required String question,
    required List<String> options,
    required String correctAnswer,
  }) async {
    return askCustomDoubt(
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: '',
      userDoubt: "Mujhe is question ka conceptual logic aasan daily life example ke sath samjhayein.",
    );
  }
}
