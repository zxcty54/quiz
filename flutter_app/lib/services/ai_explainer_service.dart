import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_rate_limiter_service.dart'; // Aapki alag file ka import

class AiExplainerService {
  // 🌐 Dynamic Fallback Models
  static List<String> activeModelHierarchy = [
    "gemini-2.0-flash",
    "gemini-1.5-flash",
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant"
  ];
  static bool isAiActive = true;

  // 🔄 Dynamic Config Sync from GitHub root app_config.json
  static void updateModelFromConfig(Map<String, dynamic> config) {
    if (config.containsKey('ai_config')) {
      final dynamic aiCfg = config['ai_config'];
      if (aiCfg is Map) {
        List<String> loadedList = [];
        if (aiCfg['primary_model'] != null && aiCfg['primary_model'].toString().isNotEmpty) {
          loadedList.add(aiCfg['primary_model'].toString().trim());
        }
        if (aiCfg['fallback_model_1'] != null && aiCfg['fallback_model_1'].toString().isNotEmpty) {
          loadedList.add(aiCfg['fallback_model_1'].toString().trim());
        }
        if (aiCfg['fallback_model_2'] != null && aiCfg['fallback_model_2'].toString().isNotEmpty) {
          loadedList.add(aiCfg['fallback_model_2'].toString().trim());
        }
        if (aiCfg['fallback_model_3'] != null && aiCfg['fallback_model_3'].toString().isNotEmpty) {
          loadedList.add(aiCfg['fallback_model_3'].toString().trim());
        }

        if (loadedList.isNotEmpty) {
          activeModelHierarchy = loadedList;
        }
        if (aiCfg['is_ai_active'] != null) {
          isAiActive = aiCfg['is_ai_active'] == true;
        }
        debugPrint("🤖 Updated AI Routing Chain: ${activeModelHierarchy.join(' ➔ ')}");
      }
    }
  }

  // 🔄 CLOUDFLARE PROXY ROUTING ENGINE
  static Future<String> _generateWithHybridRouting(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 1200,
    double temperature = 0.4,
  }) async {
    if (!isAiActive) {
      return "⚠️ AI Doubt service is temporarily paused for maintenance.";
    }

    const String proxyUrl = "https://ai-proxy.nitesh-skyhigh.workers.dev";

    try {
      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: jsonEncode({
          "systemPrompt": systemPrompt,
          "userPrompt": userPrompt,
          "activeModelHierarchy": activeModelHierarchy,
          "maxTokens": maxTokens,
          "temperature": temperature,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final text = data['text']?.toString().trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } else {
        debugPrint("Proxy Worker Status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Proxy Connection Error: $e");
    }

    return "⚠️ AI Service busy hai. Kripya thodi der baad dobara try karein.";
  }

  // 1️⃣ SMART CUSTOM DOUBT SOLVER
  static Future<String> askCustomDoubt({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String userDoubt,
  }) async {
    const String systemPrompt = """
You are a senior, highly experienced BPSC/BSSC Exam Professor explaining concepts directly to an aspirant in clear, conversational Roman Hinglish (normal everyday Hindi-English blend).

STRICT RULES:
1. Talk directly and respectfully to the student (Use "Dekhiye", "Is question me...", "Aapka doubt...").
2. STRICTLY BANNED SLANGS: Never use words like 'Aare', 'Dost', 'Arey', 'Bhai', 'Bhaiya'.
3. NO tough or Sanskritized Hindi words in Roman script. Use normal English words (like 'concept', 'mistake', 'reason', 'change', 'frequency', 'tilt').
4. ALWAYS explain the exact scientific / logical reason behind the correct answer vs the doubt.
5. COMPLETION GUARANTEE: Never leave sentences unfinished. Complete all points with a crisp summary at the end.
6. Strictly NO Devanagari Hindi text. Only clean Roman Hinglish.
""";

    final String userPrompt = """
CONTEXT:
Question: $question
Options: ${options.join(', ')}
Correct Answer: $correctAnswer

STUDENT'S DOUBT: "$userDoubt"
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 1000, temperature: 0.5);
  }

  // 2️⃣ DOCTOR DIAGNOSIS & PRESCRIPTION HEALTH AUDIT
  static Future<String> analyzeWrongQuestions(List<Map<String, dynamic>> wrongQuestions) async {
    if (wrongQuestions.isEmpty) return "🎉 100% Healthy! Vault Zero achieved, koi wrong question nahi hai.";

    int trap5050Count = 0;
    int conceptGapCount = 0;

    List<String> qSummaries = wrongQuestions.take(15).map((q) {
      String qText = q['qe'] ?? q['qh'] ?? q['question'] ?? 'Question';
      String tag = q['errorTag'] ?? 'unmarked';
      if (tag == '50-50') trap5050Count++;
      if (tag == 'concept') conceptGapCount++;

      String chapter = q['chapterName'] ?? q['chapter'] ?? 'Sectional Mock';
      return "- [Chapter: $chapter | Tag: $tag] Q:$qText";
    }).toList();

    const String systemPrompt = """
You are an expert AI Study Doctor for BPSC & BSSC Exam Aspirants.
Analyze the student's wrong questions vault like a medical diagnostic checkup in clean Roman Hinglish.

STRICT RESPONSE FORMAT (Roman Hinglish only, BANNED: 'Aare', 'Dost'):

🩺 CONCEPT HEALTH DIAGNOSIS
- History: 🟥 Critical Weak (or 🟨 Average / 🟩 Healthy)
- Science: 🟨 Average / Stable
- Polity: 🟩 Healthy

🤔 DIAGNOSIS SUMMARY
- (1-2 short lines on option confusion vs knowledge gap ratio)

💊 TODAY'S PRESCRIPTION (Rx)
1. 15 Mins: [Specific Weak Sub-topic 1 extracted from questions]
2. 10 Mins: [Specific Weak Sub-topic 2 extracted from questions]

⏱️ TOTAL REHAB TIME: Done in 25 Minutes
""";

    final String userPrompt = """
Tagged Metrics:
- 🟡 50-50 Traps: $trap5050Count
- 🔴 Knowledge Gaps: $conceptGapCount

Questions Summary:
${qSummaries.join('\n')}
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 800, temperature: 0.3);
  }

  // 3️⃣ SMART "WHY WRONG?" EXPLAINER
  static Future<String> explainWhyWrong({
    required String question,
    required List<String> options,
    required String userChoice,
    required String correctAnswer,
    required String userTag,
  }) async {
    bool hasSpecificChoice = userChoice.trim().isNotEmpty && 
                             userChoice != "Attempted Option" && 
                             userChoice != "Incorrect Option" &&
                             userChoice != "No Option Selected";

    String userChoiceContext = hasSpecificChoice
        ? 'Student selected option: "$userChoice".'
        : 'Student was confused among the incorrect options / distractor traps.';

    String tagContext = (userTag == '50-50')
        ? 'TAG: 🟡 50-50 Trap (Student narrowed down to 2 options but chose the distractor trap).'
        : 'TAG: 🔴 Concept Gap (Student lacked the foundational concept).';

    final String systemPrompt = """
You are a senior, highly experienced BPSC/BSSC Exam Professor. Provide a crisp, highly logical breakdown for a student who got this question wrong.

CRITICAL INSTRUCTIONS:
1. NEVER mention placeholder phrases like "Attempted Option" or treat generic words as exam options. Analyze the REAL given options: ${options.join(' | ')}.
2. LANGUAGE: Use natural, conversational Roman Hinglish (e.g. "Dekhiye", "Is question me..."). STRICTLY BANNED: 'Aare', 'Dost', 'Arey', 'Bhai', 'Bhaiya'.
3. NO bookish rote language. Use simple daily-life logic, analogies, or formulas.
4. COMPLETENESS: Never cut your sentences in the middle. Complete all bullet points properly.

FORMAT YOUR RESPONSE IN THIS EXACT STRUCTURE:

🎯 AAPKI GALTI AUR EXAMINER KA TRAP:
(Explain the exact trap in the options and why a student easily gets confused between similar-looking facts or numbers)

⚡ SAHI ANSWER KA CONCEPT & REAL-LIFE ANALOGY:
(Explain why "$correctAnswer" is the accurate answer with a clear, practical fact or analogy)

🔍 IS TOPIC KE COMMON DOUBTS & CONFUSIONS:
(Proactively clear 1 common confusion related to this topic so the student never makes this mistake again)
""";

    final String userPrompt = """
QUESTION: $question
OPTIONS: ${options.join(', ')}
CORRECT ANSWER: $correctAnswer
$userChoiceContext$tagContext
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 1100, temperature: 0.4);
  }

  // 4️⃣ COMPATIBILITY METHOD
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

  // 5️⃣ 🚀 BULK QUESTIONS PARSER (Called by creator_mock_builder_screen.dart)
  static Future<List<Map<String, dynamic>>> parseBulkQuestionsWithAi(String rawText) async {
    if (rawText.trim().isEmpty) return [];

    // Rate Limiter Check (Eligibility)
    final eligibility = await AiRateLimiterService.checkEligibility();
    if (eligibility['allowed'] == false) {
      debugPrint("Rate limit hit: ${eligibility['message']}");
      return [];
    }

    if (rawText.length > AiRateLimiterService.maxInputChars) {
      debugPrint("Character limit exceeded");
      return [];
    }

    const String systemPrompt = r'''
You are an expert exam data extractor for Indian competitive exams (BPSC, SSC, UPSC, Railway).
Parse the raw unstructured questions or notes text into a strict JSON Array format.

Output ONLY a pure JSON array matching this exact schema:
[
  {
    "question": "Question text in Hindi or English (use $...$ for LaTeX math)",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0,
    "explanation": "Short 1-line solution explanation"
  }
]

RULES:
1. Always return a valid JSON array. Do not include markdown wraps or conversational chatter.
2. Ensure options list always contains exactly 4 options.
3. If the answer is missing in raw text, deduce the logically correct answer index (0 to 3).
''';

    final String responseText = await _generateWithHybridRouting(
      systemPrompt,
      "Raw Questions Text:\n\"\"\"\n$rawText\n\"\"\"",
      maxTokens: 2400,
      temperature: 0.1,
    );

    final result = _sanitizeAndParseJson(responseText);
    if (result.isNotEmpty) {
      await AiRateLimiterService.recordSuccess();
    }
    return result;
  }

  // 🧹 Helper: Clean & Parse JSON Array
  static List<Map<String, dynamic>> _sanitizeAndParseJson(String responseText) {
    try {
      String cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final int startIdx = cleanJson.indexOf('[');
      final int endIdx = cleanJson.lastIndexOf(']');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        cleanJson = cleanJson.substring(startIdx, endIdx + 1);
      }

      final dynamic parsed = jsonDecode(cleanJson);
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(parsed);
      }
    } catch (e) {
      debugPrint("AI JSON Parse Helper Error: $e\nRaw: $responseText");
    }
    return [];
  }
}
