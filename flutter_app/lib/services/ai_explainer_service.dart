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
You are a respectful, highly experienced, and friendly BPSC/BSSC Exam Professor from Patna explaining concepts in conversational Hinglish (Roman Hindi written in English alphabets).

CONTEXT:
Question: $question
Options: ${options.join(', ')}
Correct Answer: $correctAnswer
Standard Solution: $explanation

STUDENT'S EXACT DOUBT: "$userDoubt"

STRICT RULES:
1. Speak DIRECTLY to the student in respectful, clear Hinglish.
2. STRICTLY BANNED WORDS: Do NOT use casual slangs like "Aare", "Dost", "Arey", "Bhai", "Bhaiya". Use professional terms like "Dekhiye", "Is question me...", "Aapne yahan...".
3. DO NOT use robotic template headers like 'Direct Answer:', 'Core Concept:', 'Section 1:'.
4. ALWAYS use a practical, relatable daily-life comparison or analogy.
5. Explain clearly why the student's doubt point is wrong or right.
6. Strictly NO Devanagari script (pure Hindi text banned). Use Roman Hinglish only.
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

  // 2️⃣ DOCTOR DIAGNOSIS & PRESCRIPTION HEALTH AUDIT
  static Future<String> analyzeWrongQuestions(List<Map<String, dynamic>> wrongQuestions) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "⚠️ AI Doctor unavailable.";
    if (wrongQuestions.isEmpty) return "🎉 100% Healthy! Vault Zero achieved, koi wrong question nahi hai.";

    try {
      int trap5050Count = 0;
      int conceptGapCount = 0;

      List<String> qSummaries = wrongQuestions.take(15).map((q) {
        String qText = q['qe'] ?? q['qh'] ?? q['question'] ?? 'Question';
        String exp = q['explanation'] ?? q['e'] ?? '';
        String tag = q['errorTag'] ?? 'unmarked';
        if (tag == '50-50') trap5050Count++;
        if (tag == 'concept') conceptGapCount++;

        String chapter = q['chapterName'] ?? q['chapter'] ?? 'Sectional Mock';
        return "- [Chapter: $chapter | User Tag: $tag] Q: $qText | Exp: $exp";
      }).toList();

      final String prompt = """
You are an expert AI Study Doctor for BPSC & BSSC Exam Aspirants.
Analyze the student's wrong questions vault like a medical diagnostic checkup.

Tagged Metrics:
- 🟡 50-50 Option Confusion Traps: $trap5050Count
- 🔴 Knowledge/Concept Gaps: $conceptGapCount

Questions Context:
${qSummaries.join('\n')}

STRICT RESPONSE FORMAT (Roman Hinglish only, NO Devanagari Hindi text, BANNED: 'Aare', 'Dost'):

🩺 CONCEPT HEALTH DIAGNOSIS
- History: 🟥 Critical Weak (or 🟨 Average / 🟩 Healthy based on errors)
- Science: 🟨 Average / Stable
- Polity: 🟩 Healthy

🤔 DIAGNOSIS SUMMARY
- (1-2 short lines on option confusion vs knowledge gap ratio)

💊 TODAY'S PRESCRIPTION (Rx)
1. 15 Mins: [Specific Weak Sub-topic 1 extracted from questions]
2. 10 Mins: [Specific Weak Sub-topic 2 extracted from questions]

⏱️ TOTAL REHAB TIME: Done in 25 Minutes
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
          "temperature": 0.3,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Health report generate nahi ho paya.";
      }
      return "⚠️ Service busy hai. Dubara try karein.";
    } catch (e) {
      return "⚠️ Error analyzing health: $e";
    }
  }

  // 3️⃣ LIVE DYNAMIC "WHY WRONG?" EXPLAINER (TAG-AWARE PROFESSOR TRAP & CONCEPT BUILDER)
  static Future<String> explainWhyWrong({
    required String question,
    required String userChoice,
    required String correctAnswer,
    required String explanation,
    required String userTag, // '50-50' or 'concept'
  }) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "AI Service current moment par active nahi hai.";

    try {
      String tagInstruction = "";
      if (userTag == '50-50') {
        tagInstruction = """
STUDENT TAG: '50-50 TRAP'
- Student double options ke beech confuse hokar examiner/bureaucrat ke trap me aagaye.
- Explain clearly how option "$userChoice" was set up as a subtle distractor trap.
- Compare option "$userChoice" vs "$correctAnswer" side by side and show the exact word or rule difference.
""";
      } else {
        tagInstruction = """
STUDENT TAG: 'DIDN'T KNOW / CONCEPT GAP'
- Student lacks basic theory or knowledge on this concept.
- Teach the core principle behind this question from zero using a simple daily life example.
- Explain clearly why "$correctAnswer" is the accurate fact.
""";
      }

      final String prompt = """
You are a senior BPSC/BSSC Exam Professor.
Analyze why this specific option was wrong for the student.

QUESTION: $question
STUDENT'S CHOICE: "${userChoice.isNotEmpty ? userChoice : 'Incorrect Option'}"
CORRECT ANSWER: "$correctAnswer"
SOLUTION CONTEXT: $explanation

$tagInstruction

STRICT RULES:
1. Speak in clean, respectful Roman Hinglish.
2. STRICTLY BANNED WORDS: Do NOT use "Aare", "Dost", "Arey", "Bhai", "Bhaiya". Use polite words like "Dekhiye", "Is option me...".
3. Strictly NO Devanagari text.
4. Keep explanation precise, educational and punchy.

FORMAT YOUR RESPONSE IN BULLET POINTS:

🧐 TRAP & CONCEPT BREAKDOWN:
• [Point 1: Direct analysis of option "$userChoice"]
• [Point 2: Core technical difference vs "$correctAnswer"]
• [Point 3: Key exam tip to avoid this trap in future]
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
          "max_tokens": 400,
          "temperature": 0.3,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Reasoning generate nahi ho paaya.";
      }
      return "Service busy hai. Dubara 'Analyze Trap ⚡' par tap karein.";
    } catch (e) {
      return "Network connection slow hai. Dubara try karein.";
    }
  }

  // 4️⃣ COMPATIBILITY METHOD FOR OLD WIDGETS
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
