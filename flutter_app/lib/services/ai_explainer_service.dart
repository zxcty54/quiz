import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiExplainerService {
  // 🔐 Environment Variables Se Keys Fetch Ho Rahi Hain (4 Keys Pool)
  static const String _gKey1 = String.fromEnvironment('GOOGLE_API_KEY');
  static const String _gKey2 = String.fromEnvironment('GOOGLE_API_KEY2');
  static const String _groqKey1 = String.fromEnvironment('GROQ_API_KEY');
  static const String _groqKey2 = String.fromEnvironment('GROQ_API_KEY2');

  static int _gIndex = 0;
  static int _groqIndex = 0;

  // 🔄 Google Keys Auto-Rotator
  static String _getGoogleApiKey() {
    final validKeys = [_gKey1, _gKey2].where((k) => k.trim().isNotEmpty).toList();
    if (validKeys.isEmpty) return "";
    final key = validKeys[_gIndex % validKeys.length];
    _gIndex++;
    return key;
  }

  // 🔄 Groq Keys Auto-Rotator
  static String _getGroqApiKey() {
    final validKeys = [_groqKey1, _groqKey2].where((k) => k.trim().isNotEmpty).toList();
    if (validKeys.isEmpty) return "";
    final key = validKeys[_groqIndex % validKeys.length];
    _groqIndex++;
    return key;
  }

  // 🌐 Dynamic Fallback Models (Cloud app_config.json se sync honge)
  static List<String> activeModelHierarchy = [
    "gemma-4-26b-a4b-it",
    "llama-3.3-70b-versatile",
    "gemini-2.0-flash",
    "llama-3.1-8b-instant"
  ];
  static bool isAiActive = true;

  // 🔄 Dynamic Config Sync from GitHub app_config.json
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

  // 🔄 KEYWORD-BASED HYBRID ROUTING ENGINE (Google AI Studio + Groq API)
  static Future<String> _generateWithHybridRouting(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 600,
    double temperature = 0.5,
  }) async {
    if (!isAiActive) {
      return "⚠️ AI Doubt service is temporarily paused for maintenance.";
    }

    final String fullPrompt = "$systemPrompt\n\n$userPrompt";

    for (int i = 0; i < activeModelHierarchy.length; i++) {
      final String model = activeModelHierarchy[i];
      final String mLower = model.toLowerCase();

      try {
        debugPrint("⚡ AI Routing [${i + 1}/${activeModelHierarchy.length}] attempting: $model");

        // 🟢 1. GOOGLE AI STUDIO (Keywords: gemini, gemma)
        if (mLower.contains('gemini') || mLower.contains('gemma')) {
          final googleKey = _getGoogleApiKey();
          if (googleKey.isEmpty) {
            debugPrint("⚠️ Google API Key missing, skipping $model");
            continue;
          }

          final url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$googleKey";
          final response = await http.post(
            Uri.parse(url),
            headers: {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": fullPrompt}
                  ]
                }
              ],
              "generationConfig": {
                "temperature": temperature,
                "maxOutputTokens": maxTokens,
              }
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                return parts[0]['text'].toString().trim();
              }
            }
          } else {
            debugPrint("Google AI Studio Status ${response.statusCode} on $model, trying next model...");
          }
        }
        // 🔵 2. GROQ API (Keywords: llama, mixtral, gpt-oss, qwen, etc.)
        else {
          final groqKey = _getGroqApiKey();
          if (groqKey.isEmpty) {
            debugPrint("⚠️ Groq API Key missing, skipping $model");
            continue;
          }

          final response = await http.post(
            Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
            headers: {
              "Authorization": "Bearer $groqKey",
              "Content-Type": "application/json; charset=utf-8",
            },
            body: jsonEncode({
              "model": model,
              "messages": [
                {"role": "system", "content": systemPrompt},
                {"role": "user", "content": userPrompt}
              ],
              "max_tokens": maxTokens,
              "temperature": temperature,
            }),
          ).timeout(const Duration(seconds: 12));

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final content = data['choices']?[0]?['message']?['content'];
            if (content != null && content.toString().trim().isNotEmpty) {
              return content.toString().trim();
            }
          } else {
            debugPrint("Groq API Status ${response.statusCode} on $model, trying next model...");
          }
        }
      } catch (e) {
        debugPrint("AI Connection Error on $model: $e");
      }
    }

    return "⚠️ AI Service busy hai. Kripya thodi der baad dobara try karein.";
  }

  // 1️⃣ CUSTOM DOUBT SOLVER
  static Future<String> askCustomDoubt({
    required String question,
    required List<String> options,
    required String correctAnswer,
    required String userDoubt,
  }) async {
    const String systemPrompt = """
You are a respectful, highly experienced, and friendly BPSC/BSSC Exam Professor from Patna explaining concepts in simple, everyday conversational Hinglish (the way students talk in daily life or chat).

STRICT RULES:
1. Speak DIRECTLY to the student in simple, clear, daily-life Hinglish.
2. DO NOT use complex Sanskritized Shuddh Hindi words written in Roman script. Use normal English words wherever natural (e.g. use 'difficult', 'concept', 'reason', 'mistake', 'option', 'process' instead of tough Hindi vocabulary).
3. STRICTLY BANNED WORDS: Do NOT use casual slangs like "Aare", "Dost", "Arey", "Bhai", "Bhaiya". Use professional, respectful words like "Dekhiye", "Is question me...", "Aapne yahan...".
4. DO NOT use robotic template headers like 'Direct Answer:', 'Core Concept:', 'Section 1:'.
5. ALWAYS use a practical, relatable daily-life comparison or analogy.
6. Explain clearly why the student's doubt point is wrong or right and why the correct answer is accurate.
7. Strictly NO Devanagari script. Use simple Roman Hinglish only.
""";

    final String userPrompt = """
CONTEXT:
Question: $question
Options: ${options.join(', ')}
Correct Answer: $correctAnswer

STUDENT'S EXACT DOUBT: "$userDoubt"
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 600, temperature: 0.7);
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
      return "- [Chapter: $chapter | User Tag: $tag] Q: $qText";
    }).toList();

    const String systemPrompt = """
You are an expert AI Study Doctor for BPSC & BSSC Exam Aspirants.
Analyze the student's wrong questions vault like a medical diagnostic checkup.

STRICT RESPONSE FORMAT (Simple Roman Hinglish only, NO Devanagari Hindi text, BANNED: 'Aare', 'Dost'):

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

    final String userPrompt = """
Tagged Metrics:
- 🟡 50-50 Option Confusion Traps: $trap5050Count
- 🔴 Knowledge/Concept Gaps: $conceptGapCount

Questions Context:
${qSummaries.join('\n')}
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 600, temperature: 0.3);
  }

  // 3️⃣ LIVE DYNAMIC "WHY WRONG?" EXPLAINER (SIMPLE HINGLISH, 180-280 WORDS MAX)
  static Future<String> explainWhyWrong({
    required String question,
    required List<String> options,
    required String userChoice,
    required String correctAnswer,
    required String userTag, // '50-50' or 'concept'
  }) async {
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

    final String systemPrompt = """
You are a senior, highly experienced BPSC/BSSC Exam Professor. Provide a concise, clear, and non-bookish breakdown for a student who got this question wrong.

$tagInstruction

STRICT RULES:
1. LANGUAGE: Use simple, everyday natural Hinglish (how students normally talk in daily life). Strictly DO NOT write tough or Sanskritized Shuddh Hindi words in Roman text. Use common English terms (like 'mistake', 'reason', 'difference', 'trap', 'concept') where natural.
2. STRICTLY BANNED WORDS: 'Aare', 'Dost', 'Arey', 'Bhai', 'Bhaiya'. Use polite terms like "Dekhiye", "Is option me...", "Aapne yahan...".
3. ABSOLUTELY NO NCERT or bookish copy-paste language.
4. MUST include a relatable real-life analogy or daily object comparison.
5. PROACTIVELY resolve common sub-doubts related to this topic so students don't need to ask again.
6. TARGET LENGTH: Keep the complete response short, crisp, and to the point (Strictly between 180 to 280 words maximum).

FORMAT YOUR RESPONSE IN THIS EXACT STRUCTURE:

🎯 AAPKI GALTI AUR EXAMINER KA TRAP:
(Explain clearly why Option "$userChoice" was chosen by the student and the exact subtle word/logic trap in it)

⚡ SAHI ANSWER KA CONCEPT & REAL-LIFE ANALOGY:
(Explain why "$correctAnswer" is accurate using a simple, practical daily life example)

🔍 IS TOPIC KE COMMON DOUBTS & CONFUSIONS:
(Proactively clear 1-2 common sub-doubts related to this topic)
""";

    final String userPrompt = """
QUESTION: $question
ALL OPTIONS: ${options.join(', ')}
STUDENT CHOSE: "$userChoice"
CORRECT ANSWER: "$correctAnswer"
""";

    return await _generateWithHybridRouting(systemPrompt, userPrompt, maxTokens: 700, temperature: 0.5);
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
