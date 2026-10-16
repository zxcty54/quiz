export default {
  // 🌐 1. Dynamic Proxy (Doubt Solver, Why Wrong, etc.)
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 🧪 Direct Manual Mastery Trigger (Testing ke liye active)
    if (url.pathname === "/sync-mastery" || url.pathname === "/debug-sync") {
      // 🔐 Optional protection: agar SYNC_KEY secret set hai to sahi key lazmi hai.
      // Secret set nahi hai to pehle ki tarah hi khulega (kuch break nahi hoga).
      if (env.SYNC_KEY && url.searchParams.get("key") !== env.SYNC_KEY) {
        return new Response(JSON.stringify({
          success: false,
          error: "Unauthorized: URL me sahi key dalo (?key=...)"
        }), {
          status: 401,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        });
      }
      try {
        console.log("🚀 Manual Mastery Sync triggered via URL:", url.pathname);
        const clientModels = url.searchParams.get("models")
          ? url.searchParams.get("models").split(",")
          : null;

        const result = await handleAutoMasterySync(env, clientModels);
        return new Response(JSON.stringify({
          success: true,
          message: "Mastery Sync executed successfully!",
          details: result
        }), {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        });
      } catch (err) {
        console.error("❌ Sync Error:", err.message, err.stack);
        return new Response(JSON.stringify({
          success: false,
          error: err.message
        }), {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        });
      }
    }

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    try {
      const { systemPrompt, userPrompt, activeModelHierarchy, maxTokens, temperature } = await request.json();

      const googleKeys = [env.GOOGLE_API_KEY, env.GOOGLE_API_KEY2].filter(k => k && k.trim().length > 0);
      const groqKeys = [env.GROQ_API_KEY, env.GROQ_API_KEY2].filter(k => k && k.trim().length > 0);

      const models = activeModelHierarchy || [
        "gemini-2.0-flash",
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
      ];

      const fullPrompt = `${systemPrompt}\n\n${userPrompt}`;

      for (const model of models) {
        const mLower = model.toLowerCase();

        try {
          if (mLower.includes("gemini") || mLower.includes("gemma")) {
            if (googleKeys.length === 0) continue;
            const key = googleKeys[Math.floor(Math.random() * googleKeys.length)];

            const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
            const res = await fetch(url, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                contents: [{ parts: [{ text: fullPrompt }] }],
                generationConfig: {
                  temperature: temperature ?? 0.4,
                  maxOutputTokens: maxTokens ?? 1200,
                },
              }),
            });

            if (res.ok) {
              const data = await res.json();
              const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
              if (text) {
                return new Response(JSON.stringify({ text }), {
                  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
                });
              }
            }
          } else {
            if (groqKeys.length === 0) continue;
            const key = groqKeys[Math.floor(Math.random() * groqKeys.length)];

            const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${key}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: model,
                messages: [
                  { role: "system", content: systemPrompt },
                  { role: "user", content: userPrompt },
                ],
                max_tokens: maxTokens ?? 1200,
                temperature: temperature ?? 0.4,
              }),
            });

            if (res.ok) {
              const data = await res.json();
              const text = data?.choices?.[0]?.message?.content;
              if (text) {
                return new Response(JSON.stringify({ text }), {
                  headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
                });
              }
            }
          }
        } catch (err) {
          console.error(`Model ${model} network error: ${err.message}`);
        }
      }

      return new Response(JSON.stringify({ error: "All AI providers failed" }), {
        status: 503,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    } catch (e) {
      return new Response(JSON.stringify({ error: e.message }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
      });
    }
  },

  // ⚡ 2. AUTOMATIC CRON TRIGGER
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      (async () => {
        try {
          console.log("⏰ Cron execution started for Mastery Sync...");
          await handleAutoMasterySync(env);
        } catch (err) {
          console.error("❌ Mastery Cron Error:", err.message);
        }
      })()
    );
  }
};

// ⏱️ Helpers
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function chunkArray(array, size) {
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
}

// 🔤 String Normalizer for safe deduplication
const normalize = (s) => (s ? s.toString().toLowerCase().trim().replace(/\s+/g, " ") : "");

// 🧠 Helper: Remote Config fetch
async function fetchModelsFromRemoteConfig(env) {
  try {
    const configUrl = env.REMOTE_CONFIG_URL;
    if (!configUrl) {
      console.warn("⚠️ [CONFIG] env.REMOTE_CONFIG_URL set nahi hai!");
      return [];
    }

    console.log(`🌐 [CONFIG] Fetching remote models from: ${configUrl}`);
    const res = await fetch(configUrl);
    if (!res.ok) {
      console.error(`❌ [CONFIG] Remote config URL responded with status: ${res.status}`);
      return [];
    }

    const data = await res.json();
    const aiCfg = data?.ai_config;
    if (aiCfg) {
      const list = [];
      if (aiCfg.primary_model) list.push(aiCfg.primary_model.trim());
      if (aiCfg.fallback_model_1) list.push(aiCfg.fallback_model_1.trim());
      if (aiCfg.fallback_model_2) list.push(aiCfg.fallback_model_2.trim());
      if (aiCfg.fallback_model_3) list.push(aiCfg.fallback_model_3.trim());

      if (list.length > 0) {
        console.log("✅ [CONFIG] Models successfully loaded from Remote Config:", JSON.stringify(list));
        return list;
      }
    }
  } catch (err) {
    console.error("❌ [CONFIG] Error fetching remote config:", err.message);
  }
  return [];
}

// 🧠 Core Engine
async function handleAutoMasterySync(env, overrideModels = null) {
  const supabaseUrl = env.SUPABASE_URL;
  const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;
  const googleKeys = [env.GOOGLE_API_KEY, env.GOOGLE_API_KEY2].filter(k => k && k.trim().length > 0);
  const groqKeys = [env.GROQ_API_KEY, env.GROQ_API_KEY2].filter(k => k && k.trim().length > 0);

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Credentials missing: SUPABASE_URL ya SUPABASE_SERVICE_ROLE_KEY set nahi hai.");
  }

  const headers = {
    'apikey': supabaseKey,
    'Authorization': `Bearer ${supabaseKey}`,
    'Content-Type': 'application/json'
  };

  // 1️⃣ Fresh un-analyzed attempts uthayenge
  const attemptsRes = await fetch(
    `${supabaseUrl}/rest/v1/user_question_attempts?is_analyzed=eq.false&select=id,user_id,user_name,question_text,is_correct,time_taken_seconds,attempted_at&order=attempted_at.asc&limit=150`,
    { headers }
  );

  if (!attemptsRes.ok) {
    const errText = await attemptsRes.text();
    throw new Error(`Supabase fetch failed (${attemptsRes.status}): ${errText}`);
  }

  const attempts = await attemptsRes.json();
  if (!attempts || !Array.isArray(attempts) || attempts.length === 0) {
    console.log("ℹ️ [MASTERY] No fresh un-analyzed questions found in Supabase.");
    return { status: "No fresh un-analyzed questions found." };
  }

  console.log(`📊 [MASTERY] Found ${attempts.length} un-analyzed attempts to process.`);

  let models = overrideModels;
  if (!models || models.length === 0) {
    models = await fetchModelsFromRemoteConfig(env);
  }
  if (!models || models.length === 0) {
    models = ["openai/gpt-oss-20b", "gemini-3.5-flash-lite", "openai/gpt-oss-120b", "gemini-3.1-flash-lite"];
  }

  // User grouping
  const userGroups = {};
  for (const row of attempts) {
    if (!userGroups[row.user_id]) {
      userGroups[row.user_id] = {
        userName: row.user_name || 'Aspirant',
        items: []
      };
    }
    userGroups[row.user_id].items.push(row);
  }

  let totalBatchesProcessed = 0;

  for (const userId of Object.keys(userGroups)) {
    const group = userGroups[userId];

    // 2️⃣ User ka EXISTING CUMULATIVE REPORT uthayein
    const currentInsightRes = await fetch(
      `${supabaseUrl}/rest/v1/user_ai_insights?user_id=eq.${userId}&select=summary_report`,
      { headers }
    );

    let currentReport = null;
    if (currentInsightRes.ok) {
      const existingData = await currentInsightRes.json();
      if (existingData && existingData.length > 0 && existingData[0].summary_report) {
        currentReport = existingData[0].summary_report;
      }
    }

    const batches = chunkArray(group.items, 15);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];

      const compactBatchData = batch.map(a => ({
        q: a.question_text ? (a.question_text.length > 400 ? a.question_text.substring(0, 400).trim() : a.question_text.trim()) : '',
        correct: a.is_correct,
        sec: a.time_taken_seconds || 0
      }));

      const previousAttemptsCount = currentReport?.evidence_meta?.total_attempts_analyzed || 0;
      const newTotalCount = previousAttemptsCount + compactBatchData.length;

      const systemPrompt = `
You are a senior cognitive learning diagnostician for competitive exam aspirants.
Analyze this NEW BATCH of ${compactBatchData.length} attempted questions by candidate ${group.userName}.

LIFETIME LEARNING & COGNITIVE RULES:
1. STRICT SUBJECT INDEPENDENCE: Never merge subjects into combined strings (e.g., do NOT output "History & Polity"). Keep "History", "Polity", "Physics", "Chemistry", "Biology", "Economics", "Quantitative Aptitude" strictly separate.
1B. SUBJECT CLASSIFICATION FROM QUESTION TEXT (no topic/subject tags are provided — YOU must infer the subject from the question itself):
   - The subject you infer MUST be one of ONLY these: "Physics", "Chemistry", "Biology", "Polity", "History", "Geography", "Economics", "Quantitative Aptitude", "Reasoning", "English", "Bihar Special", "Static GK", "Current Affairs".
   - BIHAR SPECIAL RULE (VERY IMPORTANT): Any question about the state of Bihar — its history (Magadha, Maurya & Pataliputra, Pala dynasty, Sher Shah, 1857 and the freedom movement in Bihar), geography (rivers, districts, soil, climate of Bihar), polity and governance of Bihar, Bihar economy, art and culture (Madhubani painting, folk songs, festivals of Bihar), society (castes, tribes, languages of Bihar), or famous personalities of Bihar — MUST be classified as subject "Bihar Special". NEVER put a Bihar question into History, Geography or Polity, even if it looks like general history or geography.
   - If a question mentions Bihar, Patna, or any Bihar district, place or person, prefer "Bihar Special" over the generic subject.
   - Keep topic names SHORT and CONSISTENT (2-4 words, e.g. "Bihar Art Culture", "Magadha Empire", "Ray Optics"), so the same topic is recognised again in future batches. For Bihar questions in critical_traps_detailed, always use subject "Bihar Special" with such short topic names.
   - Add a subject to subject_analysis only if it has at least 2 attempts in this batch OR it already exists in the lifetime report.
   - In every subject_analysis entry, always include "attempts": the number of questions of that subject in THIS batch.
2. TIME TELEMETRY & BEHAVIOR:
   Analyze "sec" for attempts:
   - Wrong attempt < 20s: "Impulsive Guesswork / Rushed Trap"
   - Wrong attempt > 90s: "Concept Paralysis / Overthinking Trap"
   - Correct attempt > 100s: "Slow Accuracy (Needs Speed Drill)"
3. PERSISTENT WEAK TRAPS:
   - Must have at least 2 attempts AND at least 2 repeated errors.
   - Include "subject", "topic", and "subtopic".
   - If candidate achieved >= 75% accuracy on a topic, omit it (mastered).
4. AI HEADLINE & VERDICT:
   - "ai_headline": 6-10 words punchy summary of learning state.
   - "summary_verdict": 1 crisp conversational Roman Hinglish sentence under 18 words addressing behavioral habits.

OUTPUT STRICT VALID JSON ONLY:
{
  "ai_headline": "Physics accuracy improving but Optics numericals remain trap-prone",
  "subject_analysis": [
    { "subject": "Physics", "accuracy_pct": 68, "attempts": 12 },
    { "subject": "Chemistry", "accuracy_pct": 75, "attempts": 8 },
    { "subject": "Bihar Special", "accuracy_pct": 45, "attempts": 9 }
  ],
  "behavioral_pattern": "Impulsive Guesswork",
  "summary_verdict": "Candidate basic facts me confident hai lekin Optics me rushed decisions se trap me phasta hai.",
  "critical_traps_detailed": [
    {
      "subject": "Physics",
      "topic": "Optics",
      "subtopic": "Ray Optics",
      "accuracy_pct": 30,
      "attempts": 6,
      "repeated_errors": 4
    },
    {
      "subject": "Bihar Special",
      "topic": "Bihar Art Culture",
      "subtopic": "Madhubani Painting",
      "accuracy_pct": 25,
      "attempts": 4,
      "repeated_errors": 3
    }
  ],
  "progress_delta": [
    { "subject": "Physics", "from_pct": 60, "to_pct": 68, "diff": 8 }
  ],
  "tactical_prescription": [
    "Optics formulas me sign conventions revise karein",
    "Options mark karne se pehle at least 2 distractors eliminate karein"
  ]
}`;

      const userPrompt = `
CANDIDATE'S LIFETIME SAVED PROGRESS (DO NOT ERASE):
${currentReport ? JSON.stringify(currentReport) : "No previous record found. Initial baseline batch."}

NEW BATCH ATTEMPTS (Contains text, correctness & time in seconds):
${JSON.stringify(compactBatchData)}
`;

      const fullPrompt = `${systemPrompt}\n\n${userPrompt}`;

      let parsedReport = null;
      let failureDetails = [];

      // 🔄 Dynamic Multi-Model Fallback Engine with Safe Parsing & Schema Guardrail
      for (const model of models) {
        if (!model) continue;
        const mLower = model.toLowerCase();
        let rawText = null;

        try {
          if (mLower.includes("gemini") || mLower.includes("gemma")) {
            if (googleKeys.length === 0) continue;
            const key = googleKeys[Math.floor(Math.random() * googleKeys.length)];
            const cleanGemini = model.replace(/^google\//i, '').trim();

            const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${cleanGemini}:generateContent?key=${key}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                contents: [{ parts: [{ text: fullPrompt }] }],
                generationConfig: {
                  response_mime_type: "application/json",
                  temperature: 0.2,
                  maxOutputTokens: 1800
                }
              })
            });

            if (res.ok) {
              const data = await res.json();
              rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
            } else {
              failureDetails.push(`Google [${model}] ${res.status}`);
            }
          } else {
            if (groqKeys.length === 0) continue;
            const key = groqKeys[Math.floor(Math.random() * groqKeys.length)];

            const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${key}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                model: model.trim(),
                messages: [
                  { role: "system", content: systemPrompt },
                  { role: "user", content: userPrompt },
                ],
                max_tokens: 1800,
                temperature: 0.2,
                response_format: { type: "json_object" }
              }),
            });

            if (res.ok) {
              const data = await res.json();
              rawText = data?.choices?.[0]?.message?.content;
            } else {
              failureDetails.push(`Groq [${model}] ${res.status}`);
            }
          }

          if (rawText) {
            // 🛡️ Point 3: Safe Parsing (Crash Protection)
            const cleanJson = rawText.replace(/```json/gi, '').replace(/```/g, '').trim();
            let tempJson;
            try {
              tempJson = JSON.parse(cleanJson);
            } catch (jsonErr) {
              console.warn(`⚠️ [JSON PARSE FAILED] Model ${model} returned invalid JSON syntax. Trying next fallback...`);
              continue;
            }

            // 🛡️ Point 1: Complete Schema Validation Guardrail (Including headline & verdict)
            const requiredKeys = [
              "ai_headline",
              "subject_analysis",
              "critical_traps_detailed",
              "progress_delta",
              "behavioral_pattern",
              "summary_verdict"
            ];
            const isSchemaValid = requiredKeys.every(k => tempJson[k] !== undefined && tempJson[k] !== null);

            if (!isSchemaValid) {
              console.warn(`⚠️ [SCHEMA INVALID] Model ${model} missing mandatory keys. Trying next fallback...`);
              continue;
            }

            parsedReport = tempJson;
            console.log(`✅ Success response & verified schema from model: ${model}`);
            break;
          }
        } catch (err) {
          failureDetails.push(`${model} Error: ${err.message}`);
        }
      }

      if (!parsedReport) {
        throw new Error(`Mastery AI failed for all models: ${failureDetails.join(" | ")}`);
      }

      const updatedReport = parsedReport;

      // 🛡️ Deterministic Code-Level Confidence Calculation
      const distinctSubjectsCount = new Set((updatedReport.subject_analysis || []).map(s => s.subject)).size;
      let calculatedConfidence = "Low";
      let calculatedBadge = "Developing";

      if (newTotalCount >= 45 && distinctSubjectsCount >= 3) {
        calculatedConfidence = "High";
        calculatedBadge = "Mastery Tracker";
      } else if (newTotalCount >= 20) {
        calculatedConfidence = "Medium";
        calculatedBadge = "Progressing";
      }

      updatedReport.evidence_meta = {
        total_attempts_analyzed: newTotalCount,
        confidence_level: calculatedConfidence,
        confidence_reason: `Based on ${newTotalCount} cumulative analyzed attempts across mocks`,
        badge: calculatedBadge
      };

      // 🛡️ Code-Level Deep Merging (Zero Data Loss Architecture)
      if (currentReport) {
        // A. Subject Analysis: Retention & Mathematical Weighted Accuracy
        if (Array.isArray(currentReport.subject_analysis)) {
          const newSubjectMap = new Map();
          (updatedReport.subject_analysis || []).forEach(s => newSubjectMap.set(normalize(s.subject), s));

          for (const oldSub of currentReport.subject_analysis) {
            const normKey = normalize(oldSub.subject);
            if (!newSubjectMap.has(normKey)) {
              // Subject naye batch me nahi tha, retain karein
              updatedReport.subject_analysis.push(oldSub);
            } else {
              // Subject naye batch me bhi hai: Weighted accuracy merge formula
              const newSub = newSubjectMap.get(normKey);
              const oldAttempts = oldSub.total_attempts || 10;
              const newAttempts = newSub.attempts || newSub.total_attempts || compactBatchData.length;
              const oldAcc = oldSub.accuracy_pct ?? 0;
              const newAcc = newSub.accuracy_pct ?? oldAcc;

              const weightedAcc = Math.round(
                ((oldAttempts * oldAcc) + (newAttempts * newAcc)) / (oldAttempts + newAttempts)
              );

              newSub.accuracy_pct = weightedAcc;
              newSub.total_attempts = oldAttempts + newAttempts;
            }
          }
        }

        // B. Critical Traps: Normalized Deduplication & Persistence until Mastered (>= 75%)
        if (Array.isArray(currentReport.critical_traps_detailed)) {
          const newTrapKeys = new Set(
            (updatedReport.critical_traps_detailed || []).map(
              t => `${normalize(t.subject)}_${normalize(t.topic)}_${normalize(t.subtopic)}`
            )
          );

          for (const oldTrap of currentReport.critical_traps_detailed) {
            const trapKey = `${normalize(oldTrap.subject)}_${normalize(oldTrap.topic)}_${normalize(oldTrap.subtopic)}`;
            const trapAcc = oldTrap.accuracy_pct ?? 0;

            // Agar naye report me missing hai aur master nahi hua (<75%), safely retain karein
            if (!newTrapKeys.has(trapKey) && trapAcc < 75) {
              updatedReport.critical_traps_detailed.push(oldTrap);
            }
          }
        }

        // C. Progress Delta: Preserve Lifetime Baseline for all historical subjects
        if (Array.isArray(currentReport.progress_delta)) {
          const newDeltaSubjects = new Set((updatedReport.progress_delta || []).map(d => normalize(d.subject)));
          for (const oldDelta of currentReport.progress_delta) {
            if (!newDeltaSubjects.has(normalize(oldDelta.subject))) {
              updatedReport.progress_delta.push({
                subject: oldDelta.subject,
                from_pct: oldDelta.from_pct ?? oldDelta.to_pct ?? 0,
                to_pct: oldDelta.to_pct ?? 0,
                diff: 0
              });
            }
          }
        }
      }

      // Upsert into Supabase
      const upsertRes = await fetch(`${supabaseUrl}/rest/v1/user_ai_insights?on_conflict=user_id`, {
        method: 'POST',
        headers: { ...headers, 'Prefer': 'resolution=merge-duplicates' },
        body: JSON.stringify({
          user_id: userId,
          summary_report: updatedReport,
          analyzed_at: new Date().toISOString()
        })
      });

      if (!upsertRes.ok) {
        const upErr = await upsertRes.text();
        throw new Error(`Supabase Upsert Failed: ${upErr}`);
      }

      // 🛡️ Point 4: Supabase PATCH with Strict Error Check (Infinite Loop Prevention)
      const batchIds = batch.map(item => item.id);
      const patchRes = await fetch(`${supabaseUrl}/rest/v1/user_question_attempts?id=in.(${batchIds.join(',')})`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ is_analyzed: true })
      });

      if (!patchRes.ok) {
        const patchErr = await patchRes.text();
        console.error(`❌ [PATCH FAILED] Supabase failed to mark attempts as analyzed (${patchRes.status}): ${patchErr}`);
        throw new Error(`Supabase PATCH failed: ${patchErr}`);
      }

      console.log(`✔️ Successfully patched ${batchIds.length} attempts to is_analyzed=true`);

      currentReport = updatedReport;
      totalBatchesProcessed++;

      if (i < batches.length - 1) {
        console.log(`⏳ Batch ${i + 1}/${batches.length} done. Waiting 20 seconds before next batch...`);
        await sleep(20000);
      }
    }
  }

  console.log(`🎉 Mastery Sync complete. Total batches processed: ${totalBatchesProcessed}`);
  return {
    status: "Completed",
    usersProcessed: Object.keys(userGroups).length,
    batches: totalBatchesProcessed
  };
}
