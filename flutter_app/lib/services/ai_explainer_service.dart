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

STUDENT'S EXACT DOUBT: "$userDoubt"

STRICT RULES:
1. Speak DIRECTLY to the student in respectful, clear Hinglish.
2. STRICTLY BANNED WORDS: Do NOT use casual slangs like "Aare", "Dost", "Arey", "Bhai", "Bhaiya". Use professional terms like "Dekhiye", "Is question me...", "Aapne yahan...".
3. DO NOT use robotic template headers like 'Direct Answer:', 'Core Concept:', 'Section 1:'.
4. ALWAYS use a practical, relatable daily-life comparison or analogy.
5. Explain clearly why the student's doubt point is wrong or right and why the correct answer is accurate.
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
        String tag = q['errorTag'] ?? 'unmarked';
        if (tag == '50-50') trap5050Count++;
        if (tag == 'concept') conceptGapCount++;

        String chapter = q['chapterName'] ?? q['chapter'] ?? 'Sectional Mock';
        return "- [Chapter: $chapter | User Tag: $tag] Q: $qText";
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

  // 3️⃣ LIVE DYNAMIC "WHY WRONG?" EXPLAINER (SINGLE COMPREHENSIVE 200-500 WORDS RESPONSE)
  static Future<String> explainWhyWrong({
    required String question,
    required List<String> options,
    required String userChoice,
    required String correctAnswer,
    required String userTag, // '50-50' or 'concept'
  }) async {
    final apiKey = _activeApiKey;
    if (apiKey.isEmpty) return "AI Service current moment par active nahi hai.";

    try {
      String tagInstruction = "";
      if (userTag == '50-50') {
        tagInstruction = """
STUDENT TAG: '🟡 50-50 TRAP'
- Student ne do options ke beech confuse hokar Option "$userChoice" choose kiya.
- Detail me samjhayein ki Examiner ne Option "$userChoice" ko kaise 'distractor trap' ki tarah design kiya tha.
""";
      } else {
        tagInstruction = """
STUDENT TAG: '🔴 DIDN'T KNOW / CONCEPT GAP'
- Student ko is question ka core concept nahi pata tha.
- Concept ko zero-level se samjhayein simple daily-life example ke sath.
""";
      }

      final String prompt = """
You are a senior, highly experienced BPSC/BSSC Exam Professor. Provide a comprehensive, non-bookish breakdown for a student who got this question wrong.

QUESTION: $question
ALL OPTIONS: ${options.join(', ')}
STUDENT CHOSE: "$userChoice"
CORRECT ANSWER: "$correctAnswer"

$tagInstruction

STRICT RULES:
1. Speak directly to the student in clean, respectful Roman Hinglish. STRICTLY BANNED WORDS: 'Aare', 'Dost', 'Arey', 'Bhai', 'Bhaiya'. Use polite terms like "Dekhiye", "Is option me...", "Aapne yahan...".
2. ABSOLUTELY NO NCERT or bookish copy-paste language. Explain in practical, human teaching style.
3. NO filler text or repetitive introductions. Every single line must be 100% exam-relevant.
4. MUST include a relatable real-life analogy or daily object comparison to make the core logic crystal clear.
5. PROACTIVELY resolve common sub-doubts and confusions that students usually face in this specific topic so they never need to ask again.
6. TARGET WORD COUNT: Provide a detailed, deep-dive explanation strictly between 200 to 450 words.

FORMAT YOUR RESPONSE IN THIS EXACT STRUCTURE:

🎯 AAPKI GALTI AUR EXAMINER KA TRAP:
(Analyze clearly why Option "$userChoice" was chosen by the student and the exact subtle word/rule trap in it)

⚡ SAHI ANSWER KA CONCEPT & REAL-LIFE ANALOGY:
(Explain why "$correctAnswer" is accurate using a simple, practical daily life example)

🔍 IS TOPIC KE COMMON DOUBTS & CONFUSIONS:
(Proactively address and clear sub-doubts/confusions related to this topic)

📌 EXAM HALL PRO-TIP:
(One punchy rule/trick to avoid making this mistake again in BPSC/BSSC)
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
          "max_tokens": 1200,
          "temperature": 0.5,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] ?? "Analysis generate nahi ho paaya.";
      }
      return "Service busy hai. Dubara try karein.";
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
      userDoubt: "Mujhe is question ka conceptual logic aasan daily life example ke sath samjhayein.",
    );
  }
}
