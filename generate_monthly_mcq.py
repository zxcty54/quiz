import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION & DYNAMIC DATE SETUP
# ============================================================

MASTER_FILE = "all_current_affairs.json"
ALERTS_FILE = "final_alerts_news.json"
OUTPUT_DIR = "current_affair"
IST = timezone(timedelta(hours=5, minutes=30))

# Dynamic Month & Year Calculation
CURRENT_DT = datetime.now(IST)
CURRENT_MONTH_STR = CURRENT_DT.strftime("%b")           # e.g., "Aug"
CURRENT_FULL_MONTH = CURRENT_DT.strftime("%B").lower()  # e.g., "august"
CURRENT_YEAR_STR = CURRENT_DT.strftime("%Y")            # e.g., "2026"
TARGET_MONTH_KEY = f"{CURRENT_MONTH_STR} {CURRENT_YEAR_STR}" # "Aug 2026"

# Output File: current_affair/august_2026.json
OUTPUT_QUIZ_FILE = os.path.join(OUTPUT_DIR, f"{CURRENT_FULL_MONTH}_{CURRENT_YEAR_STR}.json")

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

MODEL_REGISTRY = [
    "gemini-3.5-flash-lite",  # 500 RPD / 15 RPM (Primary)
    "gemini-3.1-flash-lite",  # 500 RPD / 15 RPM (Fallback 1)
    "gemini-3.6-flash"        # Fallback 2
]

BATCH_SIZE = 5            # 3 bilingual questions per API call (optimized for token context)
PAUSE_BETWEEN_BATCHES = 17 # 6s safe cooldown

# ============================================================
# BILINGUAL HIGH-YIELD SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are the Chief Exam Moderator and Paper Setter for Civil Services Examinations (BPSC, UPSC, SSC CGL).
Analyze the incoming news articles strictly on their direct factual testability.

ALLOWED CATEGORIES:
1. National Polity, Judiciary & Governance
2. Govt Schemes, Policies & Social Welfare
3. National Economy, Union Budget & Banking
4. International Relations, Summits & Global Organizations
5. Science, Technology, Defense & Space
6. Agriculture, Environment, Climate & GI Tags
7. Infrastructure, Energy & Digital Projects
8. Awards, Appointments, Sports, Persons & Indexes
9. Bihar Special Affairs

STRICT FILTER CRITERIA:
1. Set "has_high_yield_mcq": true ONLY IF the news contains testable statutory facts (Ministry, Target Year, Budget Outlay, Index Rank, Location, Exercise, Bihar milestone).
2. Set "has_high_yield_mcq": false for routine political rallies, private corporate orders, editorials/opinions, and historical retrospective audits (CAG 2021-2025).

SCHEMA REQUIREMENTS (Strict JSON Array):
Return strictly valid JSON with exact field structure:
[
  {
    "input_id": 1,
    "has_high_yield_mcq": true,
    "qe": "Question text in clear English",
    "qh": "Question text in accurate formal Hindi (शुद्ध एवं स्पष्ट हिंदी)",
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
    "a": 0,
    "e": "• Option A is Correct because [reason].\\n• Option B is Incorrect because [reason].\\n• Option C is Incorrect because [reason].\\n• Option D is Incorrect because [reason].",
    "category": "Exact category from list",
    "exam_tag": "Relevant Exam Tag"
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


def call_gemini_mcq_api(batch_prompt):
    global current_model_idx
    if not client:
        print("❌ Gemini Client not initialized! Check GOOGLE_API_KEY / GEMINI_API_KEY.")
        return None

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        model_name = MODEL_REGISTRY[current_model_idx]
        try:
            response = client.models.generate_content(
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
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                print(f"⚠️ [{model_name}] Quota hit (429). Switching to fallback model...")
                current_model_idx += 1
                continue
            print(f"⚠️ [{model_name}] Error: {e}")
            time.sleep(3)

        current_model_idx += 1

    print("⚠️ All models exhausted. Pausing 30s...")
    time.sleep(30)
    current_model_idx = 0
    return None


# ============================================================
# MAIN AUTOMATED ENGINE
# ============================================================

def generate_monthly_mcqs_auto():
    print("=" * 80)
    print(f"🚀 RUNNING BILINGUAL MONTHLY MCQ GENERATOR [{TARGET_MONTH_KEY}]")
    print(f"📁 Target Output File: {OUTPUT_QUIZ_FILE}")
    print("=" * 80)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Load Existing MCQs for this Month (to prevent duplicates)
    existing_quiz_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": 0,
        "national_total": 0,
        "bihar_total": 0,
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
    
    seen_q_texts = {
        re.sub(r'[^a-zA-Z0-9]+', '', q.get("qe", "").lower())
        for q in (existing_national + existing_bihar) if q.get("qe")
    }
    seen_article_titles = set()

    target_articles = []
    dropped_retrospective = 0

    # 2. EXTRACT SOURCE 1: all_current_affairs.json
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)

            # Process Bihar News
            for item in master_data.get("bihar_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "Bihar"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            # Process National News
            for item in master_data.get("national_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "National"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            print(f"📦 Loaded from {MASTER_FILE} | Matched Current Month: {len(target_articles)}")
        except Exception as e:
            print(f"⚠️ Error reading {MASTER_FILE}: {e}")
    else:
        print(f"⚠️ {MASTER_FILE} not found!")

    # 3. EXTRACT SOURCE 2: final_alerts_news.json
    alerts_added = 0
    if os.path.exists(ALERTS_FILE):
        try:
            with open(ALERTS_FILE, "r", encoding="utf-8") as f:
                alerts_data = json.load(f)

            alert_items = []
            if isinstance(alerts_data, list):
                alert_items = alerts_data
            elif isinstance(alerts_data, dict):
                alert_items = (
                    alerts_data.get("articles") or
                    alerts_data.get("news") or
                    alerts_data.get("national_news", []) + alerts_data.get("bihar_news", [])
                )

            for item in alert_items:
                if not isinstance(item, dict):
                    continue
                t = item.get("title", "")
                date_str = item.get("date", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())

                if TARGET_MONTH_KEY in date_str and t_norm and t_norm not in seen_article_titles:
                    bullets = item.get("bullets", [])
                    if not bullets and item.get("content"):
                        bullets = [item.get("content")[:400]]

                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    target_articles.append({
                        "title": t,
                        "category": item.get("category") or item.get("feed_name") or "Special Alerts & Tech",
                        "domain": "National",
                        "bullets": bullets,
                        "date": date_str
                    })
                    seen_article_titles.add(t_norm)
                    alerts_added += 1

            print(f"📦 Loaded from {ALERTS_FILE} | Newly added: {alerts_added}")
        except Exception as e:
            print(f"⚠️ Error reading {ALERTS_FILE}: {e}")
    else:
        print(f"ℹ️ {ALERTS_FILE} not found (Skipped second source).")

    total_news = len(target_articles)
    print(f"\n📊 Total Combined Articles for {TARGET_MONTH_KEY}: {total_news}")
    print(f"🚫 Pre-filtered Retrospective/Audit Stories: {dropped_retrospective}")
    print(f"📑 Existing Questions: {len(existing_national) + len(existing_bihar)} (National: {len(existing_national)}, Bihar: {len(existing_bihar)})\n")

    if total_news == 0:
        print(f"⚠️ No articles found matching '{TARGET_MONTH_KEY}'. Execution finished.")
        return

    newly_created_mcqs = []
    skipped_low_value = 0
    total_batches = (total_news + BATCH_SIZE - 1) // BATCH_SIZE

    # 4. Batch-by-Batch MCQ Generation
    for b_idx in range(0, total_news, BATCH_SIZE):
        batch = target_articles[b_idx : b_idx + BATCH_SIZE]
        batch_num = (b_idx // BATCH_SIZE) + 1
        print(f"⚡ Evaluating Batch {batch_num}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, news in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "domain": news.get("domain", "National"),
                "title": news.get("title", ""),
                "category": news.get("category", news.get("domain", "")),
                "facts": news.get("bullets", [])
            })

        prompt_str = f"Create bilingual MCQs matching the requested JSON schema for these {len(batch)} items:\n" + json.dumps(batch_payload, ensure_ascii=False)
        mcq_result = call_gemini_mcq_api(prompt_str)

        if mcq_result:
            for item in mcq_result:
                if not isinstance(item, dict):
                    continue
                
                if not item.get("has_high_yield_mcq", True):
                    skipped_low_value += 1
                    continue

                qe_text = item.get("qe", "").strip()
                qh_text = item.get("qh", "").strip()
                norm_q = re.sub(r'[^a-zA-Z0-9]+', '', qe_text.lower())

                input_id = item.get("input_id", 1)
                matched_news = batch[input_id - 1] if 0 < input_id <= len(batch) else batch[0]
                item_domain = matched_news.get("domain", "National")

                # Validate options array length
                oe_opts = item.get("oe", [])
                oh_opts = item.get("oh", [])
                if len(oe_opts) != 4 or len(oh_opts) != 4 or not qe_text or not qh_text:
                    continue

                if norm_q and norm_q not in seen_q_texts:
                    seen_q_texts.add(norm_q)
                    
                    correct_idx = item.get("a", 0)
                    if not isinstance(correct_idx, int) or correct_idx not in [0, 1, 2, 3]:
                        correct_idx = 0

                    clean_mcq = {
                        "qe": qe_text,
                        "qh": qh_text,
                        "oe": oe_opts,
                        "oh": oh_opts,
                        "a": correct_idx,
                        "e": item.get("e", ""),
                        "category": item.get("category", "Current Affairs"),
                        "exam_tag": item.get("exam_tag", "🎯 Exam Special"),
                        "domain": item_domain
                    }
                    newly_created_mcqs.append(clean_mcq)
                    print(f"   🏆 [{item_domain} Bilingual MCQ]: {qe_text[:45]}...")
                else:
                    print(f"   🧹 Duplicate Question Dropped.")
        
        if b_idx + BATCH_SIZE < total_news:
            time.sleep(PAUSE_BETWEEN_BATCHES)

    # 5. Split and Merge into Separate National and Bihar Arrays
    all_combined_mcqs = existing_national + existing_bihar + newly_created_mcqs

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

    final_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": len(final_national) + len(final_bihar),
        "national_total": len(final_national),
        "bihar_total": len(final_bihar),
        "national_questions": final_national,
        "bihar_questions": final_bihar
    }

    with open(OUTPUT_QUIZ_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Segregated Monthly Quiz Saved to: '{OUTPUT_QUIZ_FILE}'")
    print(f"   🇮🇳 National Total : {len(final_national)}")
    print(f"   🏛️ Bihar Total    : {len(final_bihar)}")
    print(f"   📊 Grand Total    : {len(final_national) + len(final_bihar)}")
    print("=" * 80)


if __name__ == "__main__":
    generate_monthly_mcqs_auto()import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION & DYNAMIC DATE SETUP
# ============================================================

MASTER_FILE = "all_current_affairs.json"
ALERTS_FILE = "final_alerts_news.json"
OUTPUT_DIR = "current_affair"
IST = timezone(timedelta(hours=5, minutes=30))

# Dynamic Month & Year Calculation
CURRENT_DT = datetime.now(IST)
CURRENT_MONTH_STR = CURRENT_DT.strftime("%b")           # e.g., "Aug"
CURRENT_FULL_MONTH = CURRENT_DT.strftime("%B").lower()  # e.g., "august"
CURRENT_YEAR_STR = CURRENT_DT.strftime("%Y")            # e.g., "2026"
TARGET_MONTH_KEY = f"{CURRENT_MONTH_STR} {CURRENT_YEAR_STR}" # "Aug 2026"

# Output File: current_affair/august_2026.json
OUTPUT_QUIZ_FILE = os.path.join(OUTPUT_DIR, f"{CURRENT_FULL_MONTH}_{CURRENT_YEAR_STR}.json")

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

MODEL_REGISTRY = [
    "gemini-3.5-flash-lite",  # 500 RPD / 15 RPM (Primary)
    "gemini-3.1-flash-lite",  # 500 RPD / 15 RPM (Fallback 1)
    "gemini-3.6-flash"        # Fallback 2
]

BATCH_SIZE = 3            # 3 bilingual questions per API call (optimized for token context)
PAUSE_BETWEEN_BATCHES = 6 # 6s safe cooldown

# ============================================================
# BILINGUAL HIGH-YIELD SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are the Chief Exam Moderator and Paper Setter for Civil Services Examinations (BPSC, UPSC, SSC CGL).
Analyze the incoming news articles strictly on their direct factual testability.

ALLOWED CATEGORIES:
1. National Polity, Judiciary & Governance
2. Govt Schemes, Policies & Social Welfare
3. National Economy, Union Budget & Banking
4. International Relations, Summits & Global Organizations
5. Science, Technology, Defense & Space
6. Agriculture, Environment, Climate & GI Tags
7. Infrastructure, Energy & Digital Projects
8. Awards, Appointments, Sports, Persons & Indexes
9. Bihar Special Affairs

STRICT FILTER CRITERIA:
1. Set "has_high_yield_mcq": true ONLY IF the news contains testable statutory facts (Ministry, Target Year, Budget Outlay, Index Rank, Location, Exercise, Bihar milestone).
2. Set "has_high_yield_mcq": false for routine political rallies, private corporate orders, editorials/opinions, and historical retrospective audits (CAG 2021-2025).

SCHEMA REQUIREMENTS (Strict JSON Array):
Return strictly valid JSON with exact field structure:
[
  {
    "input_id": 1,
    "has_high_yield_mcq": true,
    "qe": "Question text in clear English",
    "qh": "Question text in accurate formal Hindi (शुद्ध एवं स्पष्ट हिंदी)",
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
    "a": 0,
    "e": "• Option A is Correct because [reason].\\n• Option B is Incorrect because [reason].\\n• Option C is Incorrect because [reason].\\n• Option D is Incorrect because [reason].",
    "category": "Exact category from list",
    "exam_tag": "Relevant Exam Tag"
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


def call_gemini_mcq_api(batch_prompt):
    global current_model_idx
    if not client:
        print("❌ Gemini Client not initialized! Check GOOGLE_API_KEY / GEMINI_API_KEY.")
        return None

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        model_name = MODEL_REGISTRY[current_model_idx]
        try:
            response = client.models.generate_content(
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
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                print(f"⚠️ [{model_name}] Quota hit (429). Switching to fallback model...")
                current_model_idx += 1
                continue
            print(f"⚠️ [{model_name}] Error: {e}")
            time.sleep(3)

        current_model_idx += 1

    print("⚠️ All models exhausted. Pausing 30s...")
    time.sleep(30)
    current_model_idx = 0
    return None


# ============================================================
# MAIN AUTOMATED ENGINE
# ============================================================

def generate_monthly_mcqs_auto():
    print("=" * 80)
    print(f"🚀 RUNNING BILINGUAL MONTHLY MCQ GENERATOR [{TARGET_MONTH_KEY}]")
    print(f"📁 Target Output File: {OUTPUT_QUIZ_FILE}")
    print("=" * 80)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Load Existing MCQs for this Month (to prevent duplicates)
    existing_quiz_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": 0,
        "national_total": 0,
        "bihar_total": 0,
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
    
    seen_q_texts = {
        re.sub(r'[^a-zA-Z0-9]+', '', q.get("qe", "").lower())
        for q in (existing_national + existing_bihar) if q.get("qe")
    }
    seen_article_titles = set()

    target_articles = []
    dropped_retrospective = 0

    # 2. EXTRACT SOURCE 1: all_current_affairs.json
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)

            # Process Bihar News
            for item in master_data.get("bihar_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "Bihar"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            # Process National News
            for item in master_data.get("national_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "National"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            print(f"📦 Loaded from {MASTER_FILE} | Matched Current Month: {len(target_articles)}")
        except Exception as e:
            print(f"⚠️ Error reading {MASTER_FILE}: {e}")
    else:
        print(f"⚠️ {MASTER_FILE} not found!")

    # 3. EXTRACT SOURCE 2: final_alerts_news.json
    alerts_added = 0
    if os.path.exists(ALERTS_FILE):
        try:
            with open(ALERTS_FILE, "r", encoding="utf-8") as f:
                alerts_data = json.load(f)

            alert_items = []
            if isinstance(alerts_data, list):
                alert_items = alerts_data
            elif isinstance(alerts_data, dict):
                alert_items = (
                    alerts_data.get("articles") or
                    alerts_data.get("news") or
                    alerts_data.get("national_news", []) + alerts_data.get("bihar_news", [])
                )

            for item in alert_items:
                if not isinstance(item, dict):
                    continue
                t = item.get("title", "")
                date_str = item.get("date", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())

                if TARGET_MONTH_KEY in date_str and t_norm and t_norm not in seen_article_titles:
                    bullets = item.get("bullets", [])
                    if not bullets and item.get("content"):
                        bullets = [item.get("content")[:400]]

                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    target_articles.append({
                        "title": t,
                        "category": item.get("category") or item.get("feed_name") or "Special Alerts & Tech",
                        "domain": "National",
                        "bullets": bullets,
                        "date": date_str
                    })
                    seen_article_titles.add(t_norm)
                    alerts_added += 1

            print(f"📦 Loaded from {ALERTS_FILE} | Newly added: {alerts_added}")
        except Exception as e:
            print(f"⚠️ Error reading {ALERTS_FILE}: {e}")
    else:
        print(f"ℹ️ {ALERTS_FILE} not found (Skipped second source).")

    total_news = len(target_articles)
    print(f"\n📊 Total Combined Articles for {TARGET_MONTH_KEY}: {total_news}")
    print(f"🚫 Pre-filtered Retrospective/Audit Stories: {dropped_retrospective}")
    print(f"📑 Existing Questions: {len(existing_national) + len(existing_bihar)} (National: {len(existing_national)}, Bihar: {len(existing_bihar)})\n")

    if total_news == 0:
        print(f"⚠️ No articles found matching '{TARGET_MONTH_KEY}'. Execution finished.")
        return

    newly_created_mcqs = []
    skipped_low_value = 0
    total_batches = (total_news + BATCH_SIZE - 1) // BATCH_SIZE

    # 4. Batch-by-Batch MCQ Generation
    for b_idx in range(0, total_news, BATCH_SIZE):
        batch = target_articles[b_idx : b_idx + BATCH_SIZE]
        batch_num = (b_idx // BATCH_SIZE) + 1
        print(f"⚡ Evaluating Batch {batch_num}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, news in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "domain": news.get("domain", "National"),
                "title": news.get("title", ""),
                "category": news.get("category", news.get("domain", "")),
                "facts": news.get("bullets", [])
            })

        prompt_str = f"Create bilingual MCQs matching the requested JSON schema for these {len(batch)} items:\n" + json.dumps(batch_payload, ensure_ascii=False)
        mcq_result = call_gemini_mcq_api(prompt_str)

        if mcq_result:
            for item in mcq_result:
                if not isinstance(item, dict):
                    continue
                
                if not item.get("has_high_yield_mcq", True):
                    skipped_low_value += 1
                    continue

                qe_text = item.get("qe", "").strip()
                qh_text = item.get("qh", "").strip()
                norm_q = re.sub(r'[^a-zA-Z0-9]+', '', qe_text.lower())

                input_id = item.get("input_id", 1)
                matched_news = batch[input_id - 1] if 0 < input_id <= len(batch) else batch[0]
                item_domain = matched_news.get("domain", "National")

                # Validate options array length
                oe_opts = item.get("oe", [])
                oh_opts = item.get("oh", [])
                if len(oe_opts) != 4 or len(oh_opts) != 4 or not qe_text or not qh_text:
                    continue

                if norm_q and norm_q not in seen_q_texts:
                    seen_q_texts.add(norm_q)
                    
                    correct_idx = item.get("a", 0)
                    if not isinstance(correct_idx, int) or correct_idx not in [0, 1, 2, 3]:
                        correct_idx = 0

                    clean_mcq = {
                        "qe": qe_text,
                        "qh": qh_text,
                        "oe": oe_opts,
                        "oh": oh_opts,
                        "a": correct_idx,
                        "e": item.get("e", ""),
                        "category": item.get("category", "Current Affairs"),
                        "exam_tag": item.get("exam_tag", "🎯 Exam Special"),
                        "domain": item_domain
                    }
                    newly_created_mcqs.append(clean_mcq)
                    print(f"   🏆 [{item_domain} Bilingual MCQ]: {qe_text[:45]}...")
                else:
                    print(f"   🧹 Duplicate Question Dropped.")
        
        if b_idx + BATCH_SIZE < total_news:
            time.sleep(PAUSE_BETWEEN_BATCHES)

    # 5. Split and Merge into Separate National and Bihar Arrays
    all_combined_mcqs = existing_national + existing_bihar + newly_created_mcqs

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

    final_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": len(final_national) + len(final_bihar),
        "national_total": len(final_national),
        "bihar_total": len(final_bihar),
        "national_questions": final_national,
        "bihar_questions": final_bihar
    }

    with open(OUTPUT_QUIZ_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Segregated Monthly Quiz Saved to: '{OUTPUT_QUIZ_FILE}'")
    print(f"   🇮🇳 National Total : {len(final_national)}")
    print(f"   🏛️ Bihar Total    : {len(final_bihar)}")
    print(f"   📊 Grand Total    : {len(final_national) + len(final_bihar)}")
    print("=" * 80)


if __name__ == "__main__":
    generate_monthly_mcqs_auto()import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION & DYNAMIC DATE SETUP
# ============================================================

MASTER_FILE = "all_current_affairs.json"
ALERTS_FILE = "final_alerts_news.json"
OUTPUT_DIR = "current_affair"
IST = timezone(timedelta(hours=5, minutes=30))

# Dynamic Month & Year Calculation
CURRENT_DT = datetime.now(IST)
CURRENT_MONTH_STR = CURRENT_DT.strftime("%b")           # e.g., "Aug"
CURRENT_FULL_MONTH = CURRENT_DT.strftime("%B").lower()  # e.g., "august"
CURRENT_YEAR_STR = CURRENT_DT.strftime("%Y")            # e.g., "2026"
TARGET_MONTH_KEY = f"{CURRENT_MONTH_STR} {CURRENT_YEAR_STR}" # "Aug 2026"

# Output File: current_affair/august_2026.json
OUTPUT_QUIZ_FILE = os.path.join(OUTPUT_DIR, f"{CURRENT_FULL_MONTH}_{CURRENT_YEAR_STR}.json")

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

MODEL_REGISTRY = [
    "gemini-3.5-flash-lite",  # 500 RPD / 15 RPM (Primary)
    "gemini-3.1-flash-lite",  # 500 RPD / 15 RPM (Fallback 1)
    "gemini-3.6-flash"        # Fallback 2
]

BATCH_SIZE = 3            # 3 bilingual questions per API call (optimized for token context)
PAUSE_BETWEEN_BATCHES = 6 # 6s safe cooldown

# ============================================================
# BILINGUAL HIGH-YIELD SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are the Chief Exam Moderator and Paper Setter for Civil Services Examinations (BPSC, UPSC, SSC CGL).
Analyze the incoming news articles strictly on their direct factual testability.

ALLOWED CATEGORIES:
1. National Polity, Judiciary & Governance
2. Govt Schemes, Policies & Social Welfare
3. National Economy, Union Budget & Banking
4. International Relations, Summits & Global Organizations
5. Science, Technology, Defense & Space
6. Agriculture, Environment, Climate & GI Tags
7. Infrastructure, Energy & Digital Projects
8. Awards, Appointments, Sports, Persons & Indexes
9. Bihar Special Affairs

STRICT FILTER CRITERIA:
1. Set "has_high_yield_mcq": true ONLY IF the news contains testable statutory facts (Ministry, Target Year, Budget Outlay, Index Rank, Location, Exercise, Bihar milestone).
2. Set "has_high_yield_mcq": false for routine political rallies, private corporate orders, editorials/opinions, and historical retrospective audits (CAG 2021-2025).

SCHEMA REQUIREMENTS (Strict JSON Array):
Return strictly valid JSON with exact field structure:
[
  {
    "input_id": 1,
    "has_high_yield_mcq": true,
    "qe": "Question text in clear English",
    "qh": "Question text in accurate formal Hindi (शुद्ध एवं स्पष्ट हिंदी)",
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
    "a": 0,
    "e": "• Option A is Correct because [reason].\\n• Option B is Incorrect because [reason].\\n• Option C is Incorrect because [reason].\\n• Option D is Incorrect because [reason].",
    "category": "Exact category from list",
    "exam_tag": "Relevant Exam Tag"
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


def call_gemini_mcq_api(batch_prompt):
    global current_model_idx
    if not client:
        print("❌ Gemini Client not initialized! Check GOOGLE_API_KEY / GEMINI_API_KEY.")
        return None

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        model_name = MODEL_REGISTRY[current_model_idx]
        try:
            response = client.models.generate_content(
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
        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                print(f"⚠️ [{model_name}] Quota hit (429). Switching to fallback model...")
                current_model_idx += 1
                continue
            print(f"⚠️ [{model_name}] Error: {e}")
            time.sleep(3)

        current_model_idx += 1

    print("⚠️ All models exhausted. Pausing 30s...")
    time.sleep(30)
    current_model_idx = 0
    return None


# ============================================================
# MAIN AUTOMATED ENGINE
# ============================================================

def generate_monthly_mcqs_auto():
    print("=" * 80)
    print(f"🚀 RUNNING BILINGUAL MONTHLY MCQ GENERATOR [{TARGET_MONTH_KEY}]")
    print(f"📁 Target Output File: {OUTPUT_QUIZ_FILE}")
    print("=" * 80)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # 1. Load Existing MCQs for this Month (to prevent duplicates)
    existing_quiz_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": 0,
        "national_total": 0,
        "bihar_total": 0,
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
    
    seen_q_texts = {
        re.sub(r'[^a-zA-Z0-9]+', '', q.get("qe", "").lower())
        for q in (existing_national + existing_bihar) if q.get("qe")
    }
    seen_article_titles = set()

    target_articles = []
    dropped_retrospective = 0

    # 2. EXTRACT SOURCE 1: all_current_affairs.json
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)

            # Process Bihar News
            for item in master_data.get("bihar_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "Bihar"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            # Process National News
            for item in master_data.get("national_news", []):
                t = item.get("title", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())
                bullets = item.get("bullets", [])

                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    item["domain"] = "National"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            print(f"📦 Loaded from {MASTER_FILE} | Matched Current Month: {len(target_articles)}")
        except Exception as e:
            print(f"⚠️ Error reading {MASTER_FILE}: {e}")
    else:
        print(f"⚠️ {MASTER_FILE} not found!")

    # 3. EXTRACT SOURCE 2: final_alerts_news.json
    alerts_added = 0
    if os.path.exists(ALERTS_FILE):
        try:
            with open(ALERTS_FILE, "r", encoding="utf-8") as f:
                alerts_data = json.load(f)

            alert_items = []
            if isinstance(alerts_data, list):
                alert_items = alerts_data
            elif isinstance(alerts_data, dict):
                alert_items = (
                    alerts_data.get("articles") or
                    alerts_data.get("news") or
                    alerts_data.get("national_news", []) + alerts_data.get("bihar_news", [])
                )

            for item in alert_items:
                if not isinstance(item, dict):
                    continue
                t = item.get("title", "")
                date_str = item.get("date", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', t.lower())

                if TARGET_MONTH_KEY in date_str and t_norm and t_norm not in seen_article_titles:
                    bullets = item.get("bullets", [])
                    if not bullets and item.get("content"):
                        bullets = [item.get("content")[:400]]

                    if is_old_retrospective_story(t, bullets):
                        dropped_retrospective += 1
                        continue

                    target_articles.append({
                        "title": t,
                        "category": item.get("category") or item.get("feed_name") or "Special Alerts & Tech",
                        "domain": "National",
                        "bullets": bullets,
                        "date": date_str
                    })
                    seen_article_titles.add(t_norm)
                    alerts_added += 1

            print(f"📦 Loaded from {ALERTS_FILE} | Newly added: {alerts_added}")
        except Exception as e:
            print(f"⚠️ Error reading {ALERTS_FILE}: {e}")
    else:
        print(f"ℹ️ {ALERTS_FILE} not found (Skipped second source).")

    total_news = len(target_articles)
    print(f"\n📊 Total Combined Articles for {TARGET_MONTH_KEY}: {total_news}")
    print(f"🚫 Pre-filtered Retrospective/Audit Stories: {dropped_retrospective}")
    print(f"📑 Existing Questions: {len(existing_national) + len(existing_bihar)} (National: {len(existing_national)}, Bihar: {len(existing_bihar)})\n")

    if total_news == 0:
        print(f"⚠️ No articles found matching '{TARGET_MONTH_KEY}'. Execution finished.")
        return

    newly_created_mcqs = []
    skipped_low_value = 0
    total_batches = (total_news + BATCH_SIZE - 1) // BATCH_SIZE

    # 4. Batch-by-Batch MCQ Generation
    for b_idx in range(0, total_news, BATCH_SIZE):
        batch = target_articles[b_idx : b_idx + BATCH_SIZE]
        batch_num = (b_idx // BATCH_SIZE) + 1
        print(f"⚡ Evaluating Batch {batch_num}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, news in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "domain": news.get("domain", "National"),
                "title": news.get("title", ""),
                "category": news.get("category", news.get("domain", "")),
                "facts": news.get("bullets", [])
            })

        prompt_str = f"Create bilingual MCQs matching the requested JSON schema for these {len(batch)} items:\n" + json.dumps(batch_payload, ensure_ascii=False)
        mcq_result = call_gemini_mcq_api(prompt_str)

        if mcq_result:
            for item in mcq_result:
                if not isinstance(item, dict):
                    continue
                
                if not item.get("has_high_yield_mcq", True):
                    skipped_low_value += 1
                    continue

                qe_text = item.get("qe", "").strip()
                qh_text = item.get("qh", "").strip()
                norm_q = re.sub(r'[^a-zA-Z0-9]+', '', qe_text.lower())

                input_id = item.get("input_id", 1)
                matched_news = batch[input_id - 1] if 0 < input_id <= len(batch) else batch[0]
                item_domain = matched_news.get("domain", "National")

                # Validate options array length
                oe_opts = item.get("oe", [])
                oh_opts = item.get("oh", [])
                if len(oe_opts) != 4 or len(oh_opts) != 4 or not qe_text or not qh_text:
                    continue

                if norm_q and norm_q not in seen_q_texts:
                    seen_q_texts.add(norm_q)
                    
                    correct_idx = item.get("a", 0)
                    if not isinstance(correct_idx, int) or correct_idx not in [0, 1, 2, 3]:
                        correct_idx = 0

                    clean_mcq = {
                        "qe": qe_text,
                        "qh": qh_text,
                        "oe": oe_opts,
                        "oh": oh_opts,
                        "a": correct_idx,
                        "e": item.get("e", ""),
                        "category": item.get("category", "Current Affairs"),
                        "exam_tag": item.get("exam_tag", "🎯 Exam Special"),
                        "domain": item_domain
                    }
                    newly_created_mcqs.append(clean_mcq)
                    print(f"   🏆 [{item_domain} Bilingual MCQ]: {qe_text[:45]}...")
                else:
                    print(f"   🧹 Duplicate Question Dropped.")
        
        if b_idx + BATCH_SIZE < total_news:
            time.sleep(PAUSE_BETWEEN_BATCHES)

    # 5. Split and Merge into Separate National and Bihar Arrays
    all_combined_mcqs = existing_national + existing_bihar + newly_created_mcqs

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

    final_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": len(final_national) + len(final_bihar),
        "national_total": len(final_national),
        "bihar_total": len(final_bihar),
        "national_questions": final_national,
        "bihar_questions": final_bihar
    }

    with open(OUTPUT_QUIZ_FILE, "w", encoding="utf-8") as f:
        json.dump(final_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Segregated Monthly Quiz Saved to: '{OUTPUT_QUIZ_FILE}'")
    print(f"   🇮🇳 National Total : {len(final_national)}")
    print(f"   🏛️ Bihar Total    : {len(final_bihar)}")
    print(f"   📊 Grand Total    : {len(final_national) + len(final_bihar)}")
    print("=" * 80)


if __name__ == "__main__":
    generate_monthly_mcqs_auto()
