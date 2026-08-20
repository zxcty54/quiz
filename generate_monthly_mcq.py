import os
import json
import time
import re
import hashlib
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# Groq Official SDK
try:
    from groq import Groq
except ImportError:
    Groq = None

# ============================================================
# CONFIGURATION & DYNAMIC DATE SETUP
# ============================================================

MASTER_FILE = "all_current_affairs.json"
ALERTS_FILE = "final_alerts_news.json"
OUTPUT_DIR = "current_affair"
IST = timezone(timedelta(hours=5, minutes=30))

# Dynamic Month & Year Calculation (IST)
CURRENT_DT = datetime.now(IST)
CURRENT_MONTH_STR = CURRENT_DT.strftime("%b")           # e.g., "Aug"
CURRENT_FULL_MONTH = CURRENT_DT.strftime("%B").lower()  # e.g., "august"
CURRENT_YEAR_STR = CURRENT_DT.strftime("%Y")            # e.g., "2026"
TARGET_MONTH_KEY = f"{CURRENT_MONTH_STR} {CURRENT_YEAR_STR}" # "Aug 2026"

# Output File: current_affair/august_2026.json
OUTPUT_QUIZ_FILE = os.path.join(OUTPUT_DIR, f"{CURRENT_FULL_MONTH}_{CURRENT_YEAR_STR}.json")

# Gemini Client
GEMINI_API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
gemini_client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None

# Groq Client
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
groq_client = Groq(api_key=GROQ_API_KEY) if (Groq and GROQ_API_KEY) else None

# 🎯 MODEL PRIORITY REGISTRY
MODEL_REGISTRY = [
    {"provider": "gemini", "model": "gemini-3.6-flash"},       # 1st Priority (Gemini Flash)
    {"provider": "groq",   "model": "openai/gpt-oss-120b"},     # 2nd Priority (Groq Engine)
    {"provider": "gemini", "model": "gemini-3.5-flash-lite"},   # 3rd Priority (Fallback)
    {"provider": "gemini", "model": "gemini-3.1-flash-lite"}    # 4th Priority (Emergency Backup)
]

BATCH_SIZE = 12            # 12 items batch for smart selection
PAUSE_BETWEEN_BATCHES = 18 # 18s cooldown

# ============================================================
# STRICT SINGLE-QUESTION HIGH-INTELLIGENCE PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are an Elite Paper Setter for Civil Services and State Public Service Commissions (BPSC, SSC CGL, State PCS).
You will review a batch of raw current affairs items and curate ONLY the most essential, high-value MCQs.

================================================================================
CRITICAL SELECTION & FRAMING DIRECTIVES:
================================================================================
1. AGGRESSIVE QUALITY FILTER:
   - Out of 12 items in a batch, typically only 2 to 4 articles are genuinely worthy of an exam question.
   - Set "has_high_yield_mcq": false for ANY article that is routine, localized, political commentary, private commercial trade, or retrospective audit.
   - Accept ONLY items with concrete national/state significance: statutory cabinet policies, constitutional appointments, target years, international treaties, major space/defense tests, or key Bihar milestones.

2. STRICTLY NO STATEMENT-BASED QUESTIONS:
   - FORBIDDEN: Do NOT write multi-statement formats ("Consider the following statements: 1, 2, 3...", "Which of the above are correct?", "1 and 2 only").
   - MANDATORY: Write a clean, direct, single-sentence formal question in English ("qe") and Hindi ("qh").

3. QUESTION vs EXPLANATION DIVISION:
   - Question ("qe" / "qh"): Crisp, direct, formal line asking for the specific statutory body, nodal ministry, project target, location, or objective.
   - Explanation ("e"): Put the comprehensive news details, background context, numbers, and definitions inside the explanation for each option.

4. BALANCED CORRECT ANSWER INDEX:
   - Distribute the correct answer index "a" evenly across 0 (A), 1 (B), 2 (C), and 3 (D).

================================================================================
OUTPUT SCHEMA (Strict JSON Array):
================================================================================
Return strictly valid JSON with exact field structure:
[
  {
    "input_id": 1,
    "has_high_yield_mcq": true,
    "qe": "Single direct formal question sentence in English?",
    "qh": "शुद्ध, स्पष्ट एवं मानक एकल वाक्य में प्रश्न हिंदी में?",
    "oe": [
      "Option A text in English",
      "Option B text in English",
      "Option C text in English",
      "Option D text in English"
    ],
    "oh": [
      "विकल्प A हिंदी में",
      "विकल्प B हिंदी में",
      "विकल्प C हिंदी में",
      "विकल्प D हिंदी में"
    ],
    "a": 1,
    "e": "• Option B is Correct because [core factual news context, nodal agency, and targets].\\n• Option A is Incorrect because [factual context].\\n• Option C is Incorrect because [factual context].\\n• Option D is Incorrect because [factual context].",
    "category": "Exact matched category",
    "exam_tag": "BPSC / SSC CGL / State PCS"
  },
  {
    "input_id": 2,
    "has_high_yield_mcq": false
  }
]
* Note for "a": 0 for Option A, 1 for Option B, 2 for Option C, 3 for Option D.
"""

current_model_idx = 0

# ============================================================
# DETERMINISTIC RETROSPECTIVE & OLD AUDIT FILTER
# ============================================================

OLD_AUDIT_REGEX = re.compile(
    r'(\b(2021|2022|2023|2024|2025)\b.*?\b(audit|cag|findings|unspent|retrospective|old report|audit report)\b)|'
    r'(\b(audit|cag|findings|unspent|retrospective)\b.*?\b(2021|2022|2023|2024|2025)\b)',
    re.IGNORECASE
)

def is_old_retrospective_story(title, bullets):
    combined_text = f"{title} {' '.join(bullets)}"
    if OLD_AUDIT_REGEX.search(combined_text):
        return True
    return False

# ============================================================
# UTILITY HELPERS
# ============================================================

def generate_article_hash(title):
    clean = re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', str(title).lower().strip())
    return hashlib.md5(clean.encode('utf-8')).hexdigest()[:8]


def clean_json_response(raw_text):
    if not raw_text or not raw_text.strip():
        return None
    text = raw_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        array_match = re.search(r"\[[\s\S]*\]", text)
        if array_match:
            try:
                return json.loads(array_match.group(0))
            except Exception:
                pass
    return None

# ============================================================
# MULTI-PROVIDER LLM CALL DISPATCHER
# ============================================================

def call_llm_mcq_api(batch_prompt):
    global current_model_idx
    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        entry = MODEL_REGISTRY[current_model_idx]
        provider = entry["provider"]
        model_name = entry["model"]

        try:
            # 1. GEMINI CALL
            if provider == "gemini":
                if not gemini_client:
                    print(f"⚠️ Gemini Client not initialized. Skipping [{model_name}]...")
                    current_model_idx += 1
                    continue

                response = gemini_client.models.generate_content(
                    model=model_name,
                    contents=batch_prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_PROMPT,
                        temperature=0.1,
                        response_mime_type="application/json"
                    )
                )
                parsed = clean_json_response(response.text)
                if parsed:
                    return parsed if isinstance(parsed, list) else [parsed]

            # 2. GROQ CALL
            elif provider == "groq":
                if not groq_client:
                    print(f"⚠️ Groq Client not initialized (missing GROQ_API_KEY). Skipping [{model_name}]...")
                    current_model_idx += 1
                    continue

                response = groq_client.chat.completions.create(
                    model=model_name,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": batch_prompt}
                    ],
                    temperature=0.1,
                    response_format={"type": "json_object"}
                )
                raw_content = response.choices[0].message.content
                parsed = clean_json_response(raw_content)
                if parsed:
                    if isinstance(parsed, dict):
                        for k, v in parsed.items():
                            if isinstance(v, list):
                                return v
                    return parsed if isinstance(parsed, list) else [parsed]

        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str or "Rate limit" in err_str:
                print(f"⚠️ [{provider.upper()} - {model_name}] Quota hit (429). Switching to next priority...")
                current_model_idx += 1
                continue
            print(f"⚠️ [{provider.upper()} - {model_name}] Error: {e}")
            time.sleep(20)

        current_model_idx += 1

    print("⚠️ All models exhausted. Pausing 60s...")
    time.sleep(60)
    current_model_idx = 0
    return None


# ============================================================
# MAIN AUTOMATED ENGINE
# ============================================================

def generate_monthly_mcqs_auto():
    print("=" * 80)
    print(f"🚀 RUNNING SELECTIVE BILINGUAL MCQ GENERATOR [{TARGET_MONTH_KEY}]")
    print(f"📁 Target Output File: {OUTPUT_QUIZ_FILE}")
    print("=" * 80)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Load Existing MCQs
    existing_quiz_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": 0,
        "national_total": 0,
        "bihar_total": 0,
        "source_breakdown": {
            "all_current_affairs": {"total_scanned": 0, "mcqs_created": 0, "dropped": 0},
            "final_alerts_news": {"total_scanned": 0, "mcqs_created": 0, "dropped": 0}
        },
        "national_questions": [],
        "bihar_questions": []
    }
    
    if os.path.exists(OUTPUT_QUIZ_FILE):
        try:
            with open(OUTPUT_QUIZ_FILE, "r", encoding="utf-8") as f:
                existing_quiz_payload = json.load(f)
        except Exception:
            pass

    existing_national = existing_quiz_payload.get("national_questions", [])
    existing_bihar = existing_quiz_payload.get("bihar_questions", [])
    all_existing = existing_national + existing_bihar

    processed_hashes = {q.get("source_hash") for q in all_existing if q.get("source_hash")}
    seen_q_texts = {
        re.sub(r'[^a-zA-Z0-9]+', '', q.get("qe", "").lower())
        for q in all_existing if q.get("qe")
    }

    # Tracking metrics per source
    metrics = {
        "all_current_affairs": {
            "total_scanned": 0,
            "retrospective_dropped": 0,
            "already_processed": 0,
            "ai_evaluated": 0,
            "ai_rejected": 0,
            "mcqs_created": sum(1 for q in all_existing if q.get("source_file") == "all_current_affairs")
        },
        "final_alerts_news": {
            "total_scanned": 0,
            "retrospective_dropped": 0,
            "already_processed": 0,
            "ai_evaluated": 0,
            "ai_rejected": 0,
            "mcqs_created": sum(1 for q in all_existing if q.get("source_file") == "final_alerts_news")
        }
    }

    scanned_articles = []
    seen_titles = set()

    # 2. EXTRACT SOURCE 1: all_current_affairs.json
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)

            # Bihar News
            for item in master_data.get("bihar_news", []):
                t = item.get("title", "")
                t_hash = generate_article_hash(t)
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_hash not in seen_titles:
                    metrics["all_current_affairs"]["total_scanned"] += 1
                    if is_old_retrospective_story(t, bullets):
                        metrics["all_current_affairs"]["retrospective_dropped"] += 1
                        continue
                    item["domain"] = "Bihar"
                    item["source_hash"] = t_hash
                    item["source_file"] = "all_current_affairs"
                    scanned_articles.append(item)
                    seen_titles.add(t_hash)

            # National News
            for item in master_data.get("national_news", []):
                t = item.get("title", "")
                t_hash = generate_article_hash(t)
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_hash not in seen_titles:
                    metrics["all_current_affairs"]["total_scanned"] += 1
                    if is_old_retrospective_story(t, bullets):
                        metrics["all_current_affairs"]["retrospective_dropped"] += 1
                        continue
                    item["domain"] = "National"
                    item["source_hash"] = t_hash
                    item["source_file"] = "all_current_affairs"
                    scanned_articles.append(item)
                    seen_titles.add(t_hash)

            print(f"📦 Loaded from {MASTER_FILE} | Month Matched: {metrics['all_current_affairs']['total_scanned']}")
        except Exception as e:
            print(f"⚠️ Error reading {MASTER_FILE}: {e}")
    else:
        print(f"⚠️ {MASTER_FILE} not found!")

    # 3. EXTRACT SOURCE 2: final_alerts_news.json
    if os.path.exists(ALERTS_FILE):
        try:
            with open(ALERTS_FILE, "r", encoding="utf-8") as f:
                alerts_data = json.load(f)

            alert_items = []
            if isinstance(alerts_data, dict):
                alert_items = alerts_data.get("alert_news", [])
            elif isinstance(alerts_data, list):
                alert_items = alerts_data

            for item in alert_items:
                if not isinstance(item, dict):
                    continue
                t = item.get("title", "").strip()
                date_str = str(item.get("date", ""))
                t_hash = generate_article_hash(t)

                if TARGET_MONTH_KEY in date_str and t_hash not in seen_titles:
                    metrics["final_alerts_news"]["total_scanned"] += 1
                    bullets = item.get("bullets", [])
                    if not bullets and item.get("content"):
                        bullets = [item.get("content")[:400]]

                    if is_old_retrospective_story(t, bullets):
                        metrics["final_alerts_news"]["retrospective_dropped"] += 1
                        continue

                    scanned_articles.append({
                        "title": t,
                        "category": item.get("category", "Special Alerts & Tech"),
                        "domain": "National",
                        "bullets": bullets,
                        "date": date_str,
                        "source_hash": t_hash,
                        "source_file": "final_alerts_news"
                    })
                    seen_titles.add(t_hash)

            print(f"📦 Loaded from {ALERTS_FILE} | Month Matched: {metrics['final_alerts_news']['total_scanned']}")
        except Exception as e:
            print(f"⚠️ Error reading {ALERTS_FILE}: {e}")
    else:
        print(f"ℹ️ {ALERTS_FILE} not found (Skipped second source).")

    # 4. Separate Unprocessed Articles by Source
    fresh_articles_to_process = []
    for art in scanned_articles:
        src = art["source_file"]
        if art["source_hash"] in processed_hashes:
            metrics[src]["already_processed"] += 1
        else:
            metrics[src]["ai_evaluated"] += 1
            fresh_articles_to_process.append(art)

    print("\n" + "-" * 80)
    print("📊 PRE-EVALUATION SOURCE BREAKDOWN:")
    for src, m in metrics.items():
        print(f"   [{src}] -> Scanned: {m['total_scanned']} | Old Audits Dropped: {m['retrospective_dropped']} | Already Done: {m['already_processed']} | Fresh To AI: {m['ai_evaluated']}")
    print("-" * 80 + "\n")

    if not fresh_articles_to_process:
        print("✅ All monthly articles are already processed. No new API calls needed!")
        return

    newly_created_mcqs = []
    total_batches = (len(fresh_articles_to_process) + BATCH_SIZE - 1) // BATCH_SIZE

    # 5. Process in Batches of 12
    for b_idx in range(0, len(fresh_articles_to_process), BATCH_SIZE):
        batch = fresh_articles_to_process[b_idx : b_idx + BATCH_SIZE]
        batch_num = (b_idx // BATCH_SIZE) + 1
        print(f"⚡ Evaluating Batch {batch_num}/{total_batches} ({len(batch)} items in batch)...")

        batch_payload = []
        for idx, news in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "domain": news.get("domain", "National"),
                "title": news.get("title", ""),
                "category": news.get("category", news.get("domain", "")),
                "facts": news.get("bullets", [])
            })

        prompt_str = f"Filter and create high-yield single direct MCQs for this batch of {len(batch)} items:\n" + json.dumps(batch_payload, ensure_ascii=False)
        mcq_result = call_llm_mcq_api(prompt_str)

        if mcq_result:
            for item in mcq_result:
                if not isinstance(item, dict):
                    continue

                input_id = item.get("input_id", 1)
                matched_news = batch[input_id - 1] if 0 < input_id <= len(batch) else batch[0]
                item_src = matched_news.get("source_file", "all_current_affairs")

                if not item.get("has_high_yield_mcq", True):
                    metrics[item_src]["ai_rejected"] += 1
                    continue

                qe_text = str(item.get("qe", "")).strip()
                qh_text = str(item.get("qh", "")).strip()
                norm_q = re.sub(r'[^a-zA-Z0-9]+', '', qe_text.lower())

                if "consider the following" in qe_text.lower() or "which of the statements" in qe_text.lower():
                    print(f"   🛑 Skipped Statement Question: {qe_text[:40]}...")
                    metrics[item_src]["ai_rejected"] += 1
                    continue

                item_domain = matched_news.get("domain", "National")
                item_hash = matched_news.get("source_hash", "")

                oe_opts = item.get("oe", [])
                oh_opts = item.get("oh", [])
                if len(oe_opts) != 4 or len(oh_opts) != 4 or not qe_text or not qh_text:
                    metrics[item_src]["ai_rejected"] += 1
                    continue

                if norm_q and norm_q not in seen_q_texts:
                    seen_q_texts.add(norm_q)
                    
                    correct_idx = item.get("a", 0)
                    if not isinstance(correct_idx, int) or correct_idx not in [0, 1, 2, 3]:
                        correct_idx = 0

                    clean_mcq = {
                        "source_hash": item_hash,
                        "source_file": item_src,
                        "qe": qe_text,
                        "qh": qh_text,
                        "oe": oe_opts,
                        "oh": oh_opts,
                        "a": correct_idx,
                        "e": item.get("e", ""),
                        "category": item.get("category", "Current Affairs"),
                        "exam_tag": item.get("exam_tag", "🎯 BPSC / SSC CGL"),
                        "domain": item_domain
                    }
                    newly_created_mcqs.append(clean_mcq)
                    metrics[item_src]["mcqs_created"] += 1
                    print(f"   🏆 [{item_src.upper()} | {item_domain}]: {qe_text[:45]}...")
                else:
                    metrics[item_src]["ai_rejected"] += 1
                    print(f"   🧹 Duplicate Question Dropped.")
        
        if b_idx + BATCH_SIZE < len(fresh_articles_to_process):
            print(f"⏳ Sleeping {PAUSE_BETWEEN_BATCHES}s to respect API limits...")
            time.sleep(PAUSE_BETWEEN_BATCHES)

    # 6. Segregate and Merge into National & Bihar Arrays
    all_combined_mcqs = all_existing + newly_created_mcqs

    final_national = []
    final_bihar = []

    for q in all_combined_mcqs:
        domain_tag = str(q.get("domain", "")).lower()
        cat_tag = str(q.get("category", "")).lower()
        
        if "bihar" in domain_tag or "bihar" in cat_tag:
            q_copy = dict(q)
            q_copy["id"] = f"bih_q_{len(final_bihar) + 1:03d}"
            final_bihar.append(q_copy)
        else:
            q_copy = dict(q)
            q_copy["id"] = f"nat_q_{len(final_national) + 1:03d}"
            final_national.append(q_copy)

    # Compute final source breakdown counts
    source_summary = {
        "all_current_affairs": {
            "total_scanned": metrics["all_current_affairs"]["total_scanned"],
            "mcqs_created": sum(1 for q in all_combined_mcqs if q.get("source_file") == "all_current_affairs"),
            "total_dropped": metrics["all_current_affairs"]["retrospective_dropped"] + metrics["all_current_affairs"]["ai_rejected"]
        },
        "final_alerts_news": {
            "total_scanned": metrics["final_alerts_news"]["total_scanned"],
            "mcqs_created": sum(1 for q in all_combined_mcqs if q.get("source_file") == "final_alerts_news"),
            "total_dropped": metrics["final_alerts_news"]["retrospective_dropped"] + metrics["final_alerts_news"]["ai_rejected"]
        }
    }

    final_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": len(final_national) + len(final_bihar),
        "national_total": len(final_national),
        "bihar_total": len(final_bihar),
        "source_breakdown": source_summary,
        "national_questions": final_national,
        "bihar_questions": final_bihar
    }

    with open(OUTPUT_QUIZ_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Selective Monthly Quiz Saved to: '{OUTPUT_QUIZ_FILE}'")
    print(f"   📊 Grand Total Active MCQs : {len(final_national) + len(final_bihar)}")
    print(f"      • National : {len(final_national)}")
    print(f"      • Bihar    : {len(final_bihar)}")
    print("-" * 80)
    print("📈 SOURCE BREAKDOWN SUMMARY:")
    print(f"   1. all_current_affairs.json -> MCQs Created: {source_summary['all_current_affairs']['mcqs_created']} | Dropped: {source_summary['all_current_affairs']['total_dropped']}")
    print(f"   2. final_alerts_news.json   -> MCQs Created: {source_summary['final_alerts_news']['mcqs_created']} | Dropped: {source_summary['final_alerts_news']['total_dropped']}")
    print("=" * 80)


if __name__ == "__main__":
    generate_monthly_mcqs_auto()
