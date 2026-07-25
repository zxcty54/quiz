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

  // 1️⃣ CUSTOM DOUBT SOLVER (For Revision Hub, Sectional Mocks, and Vault Questions)
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
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 800,
          "temperature": 0.7,
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

  // 2️⃣ TAG-AWARE DATA ANALYTICS PROMPT (Reads User Tags + Question Context)
  static Future<String> analyzeWrongQuestions(List<Map<String, dynamic>> wrongQuestions) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "⚠️ AI Mentor unavailable.";
    if (wrongQuestions.isEmpty) return "Sabaash! Vault Zero achieved, koi wrong question nahi hai.";

    try {
      int sillyCount = 0;
      int conceptCount = 0;

      List<String> qSummaries = wrongQuestions.take(15).map((q) {
        String qText = q['qe'] ?? q['qh'] ?? q['question'] ?? 'Question';
        String exp = q['explanation'] ?? q['e'] ?? '';
        String tag = q['errorTag'] ?? 'unmarked';
        if (tag == 'silly') sillyCount++;
        if (tag == 'concept') conceptCount++;

        String chapter = q['chapterName'] ?? q['chapter'] ?? 'Sectional Mock';
        return "- [Chapter: $chapter | User Tag: $tag] Question: $qText | Exp: $exp";
      }).toList();

      final String prompt = """
You are an expert AI Exam Analyst for BPSC, BSSC & State Exams.
Analyze the following list of wrong questions saved in the student's vault:

User Tagged Metrics:
- Total Silly Mistakes: $sillyCount
- Total Knowledge/Concept Gaps: $conceptCount

Questions:
${qSummaries.join('\n')}

ANALYTICAL INSTRUCTIONS:
1. Include the user's Silly ($sillyCount) vs Concept ($conceptCount) tag ratio in MISTAKE REASON section to tell them if they are rushing or lacking revision.
2. For Revision Hub questions, group errors by Chapter and extract exact Sub-Topics.
3. For Sectional Mocks, auto-detect Subject & Sub-topic from text.
4. Output MUST BE strictly structured, concise Roman Hinglish. Strictly NO Devanagari Hindi text.

STRICT OUTPUT FORMAT:

📊 PATTERN FOUND
- (Pinpoint exact error trend)

🤔 MISTAKE REASON
- (Analyze root cause including Silly vs Concept tag feedback)

⚡ CONFIDENCE ESTIMATE
Biology:  ████████ 80%
History:  ███ 35%

📌 PRIORITY REVISION TOPICS
1. [Sub-topic 1]
2. [Sub-topic 2]
3. [Sub-topic 3]

🎯 NEXT ACTION
- (1 short practical line)
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
          "temperature": 0.4,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Analysis generate nahi ho paya.";
      }
      return "⚠️ Service busy hai. Dubara try karein.";
    } catch (e) {
      return "⚠️ Error analyzing vault: $e";
    }
  }

  // 3️⃣ COMPATIBILITY METHOD FOR OLD WIDGETS
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
