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
IST = timezone(timedelta(hours=5, minutes=30))

# 🎯 DYNAMIC CURRENT MONTH & YEAR
CURRENT_DT = datetime.now(IST)
CURRENT_MONTH_STR = CURRENT_DT.strftime("%b")      # e.g., "Aug"
CURRENT_YEAR_STR = CURRENT_DT.strftime("%Y")       # e.g., "2026"
TARGET_MONTH_KEY = f"{CURRENT_MONTH_STR} {CURRENT_YEAR_STR}" # "Aug 2026"

OUTPUT_QUIZ_FILE = f"monthly_quiz_{CURRENT_MONTH_STR.lower()}_{CURRENT_YEAR_STR}.json"

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

MODEL_REGISTRY = [
    "gemini-3.5-flash-lite",  # 500 RPD / 15 RPM (Primary)
    "gemini-3.1-flash-lite",  # 500 RPD / 15 RPM (Fallback 1)
    "gemini-3.6-flash"        # Fallback 2
]

BATCH_SIZE = 4            # 4 news items per API call
PAUSE_BETWEEN_BATCHES = 6 # 6s safe cooldown

# ============================================================
# STRICT HIGH-YIELD EXAM MCQ PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are a Chief Paper Setter and Examiner for Civil Services & State PCS (BPSC, UPSC, SSC CGL).
You will receive a list of summarized Current Affairs news items.

STRICT FILTERING & QUESTION CREATION RULE:
1. NOT all news items deserve an MCQ. Generate an MCQ ONLY IF the news contains concrete, testable facts:
   - Specific statutory ministry / department / committee chairman
   - Financial outlay, target year, or quantifiable statistical target
   - Global rank / index score / GI tag location / national park / space mission component
   - Major Bihar-specific policy / infrastructure milestone
2. REJECT news (set "has_high_yield_mcq": false) if it is:
   - Routine administrative reshuffle, standard inaugurations without policy changes, generic bilateral goodwill statements.
3. Frame rigorous, unambiguous questions with 4 plausible options (A, B, C, D) and a concise 2-line explanation.

OUTPUT FORMAT (STRICT JSON ARRAY ONLY):
[
  {
    "input_id": 1,
    "has_high_yield_mcq": true,
    "question": "Clear, direct factual question in English",
    "options": {
      "A": "Option text",
      "B": "Option text",
      "C": "Option text",
      "D": "Option text"
    },
    "correct_option": "A",
    "explanation": "Fact-based concise explanation covering the core facts.",
    "category": "Exact Category",
    "exam_tag": "Relevant Board/Exam Tag"
  },
  {
    "input_id": 2,
    "has_high_yield_mcq": false
  }
]
"""

current_model_idx = 0

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
        print("❌ Gemini Client not initialized! Check GOOGLE_API_KEY.")
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
                print(f"⚠️ [{model_name}] Quota limit hit (429). Switching to fallback model...")
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
    print(f"🚀 RUNNING AUTO MONTHLY MCQ GENERATOR [{TARGET_MONTH_KEY}]")
    print(f"📁 Target Output File: {OUTPUT_QUIZ_FILE}")
    print("=" * 80)

    # 1. Load Existing MCQs for this Month (to prevent duplicate generation & token burn)
    existing_quiz_payload = {
        "month": TARGET_MONTH_KEY,
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_questions": 0,
        "questions": []
    }
    
    if os.path.exists(OUTPUT_QUIZ_FILE):
        try:
            with open(OUTPUT_QUIZ_FILE, "r", encoding="utf-8") as f:
                existing_quiz_payload = json.load(f)
        except Exception:
            pass

    existing_questions = existing_quiz_payload.get("questions", [])
    seen_q_texts = {re.sub(r'[^a-zA-Z0-9]+', '', q.get("question", "").lower()) for q in existing_questions}
    seen_article_titles = set()

    target_articles = []

    # 2. EXTRACT SOURCE 1: all_current_affairs.json
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)

            # Bihar News
            for item in master_data.get("bihar_news", []):
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', item.get("title", "").lower())
                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    item["domain"] = "Bihar Special Affairs"
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            # National News
            for item in master_data.get("national_news", []):
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', item.get("title", "").lower())
                if TARGET_MONTH_KEY in item.get("date", "") and t_norm not in seen_article_titles:
                    item["domain"] = item.get("category", "National Current Affairs")
                    target_articles.append(item)
                    seen_article_titles.add(t_norm)

            print(f"📦 Loaded from {MASTER_FILE} | Total matched: {len(target_articles)}")
        except Exception as e:
            print(f"⚠️ Could not read {MASTER_FILE}: {e}")
    else:
        print(f"⚠️ {MASTER_FILE} not found!")

    # 3. EXTRACT SOURCE 2: final_alerts_news.json
    alerts_added = 0
    if os.path.exists(ALERTS_FILE):
        try:
            with open(ALERTS_FILE, "r", encoding="utf-8") as f:
                alerts_data = json.load(f)

            # Support list format or dict with "articles"/"news" keys
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
                date_str = item.get("date", "")
                t_norm = re.sub(r'[^a-zA-Z0-9]+', '', item.get("title", "").lower())

                if TARGET_MONTH_KEY in date_str and t_norm and t_norm not in seen_article_titles:
                    bullets = item.get("bullets", [])
                    if not bullets and item.get("content"):
                        bullets = [item.get("content")[:400]]

                    target_articles.append({
                        "title": item.get("title", ""),
                        "category": item.get("category") or item.get("feed_name") or "Special Alerts & Tech",
                        "domain": "Alerts Special",
                        "bullets": bullets,
                        "date": date_str
                    })
                    seen_article_titles.add(t_norm)
                    alerts_added += 1

            print(f"📦 Loaded from {ALERTS_FILE} | Newly added: {alerts_added}")
        except Exception as e:
            print(f"⚠️ Could not read {ALERTS_FILE}: {e}")
    else:
        print(f"ℹ️ {ALERTS_FILE} not found (Skipped second source).")

    total_news = len(target_articles)
    print(f"\n📊 Total Combined Articles for {TARGET_MONTH_KEY}: {total_news}")
    print(f"📑 Existing MCQs in Quiz File: {len(existing_questions)}\n")

    if total_news == 0:
        print(f"⚠️ No articles found for '{TARGET_MONTH_KEY}'. Skipping execution.")
        return

    newly_created_mcqs = []
    skipped_low_value = 0
    total_batches = (total_news + BATCH_SIZE - 1) // BATCH_SIZE

    # 4. Process in Micro-Batches
    for b_idx in range(0, total_news, BATCH_SIZE):
        batch = target_articles[b_idx : b_idx + BATCH_SIZE]
        batch_num = (b_idx // BATCH_SIZE) + 1
        print(f"⚡ Evaluating Batch {batch_num}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, news in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "title": news.get("title", ""),
                "category": news.get("category", news.get("domain", "")),
                "facts": news.get("bullets", [])
            })

        prompt_str = f"Evaluate and create high-yield MCQs for these {len(batch)} items into JSON array:\n" + json.dumps(batch_payload, ensure_ascii=False)
        mcq_result = call_gemini_mcq_api(prompt_str)

        if mcq_result:
            for item in mcq_result:
                if not isinstance(item, dict):
                    continue
                
                # Check AI's quality flag
                if not item.get("has_high_yield_mcq", True):
                    skipped_low_value += 1
                    continue

                q_text = item.get("question", "").strip()
                norm_q = re.sub(r'[^a-zA-Z0-9]+', '', q_text.lower())

                # Prevent duplicate questions
                if norm_q and norm_q not in seen_q_texts:
                    seen_q_texts.add(norm_q)
                    clean_mcq = {
                        "question": q_text,
                        "options": item.get("options", {}),
                        "correct_option": item.get("correct_option", "A"),
                        "explanation": item.get("explanation", ""),
                        "category": item.get("category", "Current Affairs"),
                        "exam_tag": item.get("exam_tag", "🎯 BPSC/UPSC Special")
                    }
                    newly_created_mcqs.append(clean_mcq)
                    print(f"   🏆 [High-Yield MCQ]: {q_text[:50]}...")
                else:
                    print(f"   🧹 Duplicate Question Dropped.")
        
        if b_idx + BATCH_SIZE < total_news:
            time.sleep(PAUSE_BETWEEN_BATCHES)

    # 5. Merge New MCQs with Existing Monthly File
    all_final_mcqs = existing_questions + newly_created_mcqs

    for idx, q in enumerate(all_final_mcqs, 1):
        q["id"] = f"q_{idx:03d}"

    existing_quiz_payload["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")
    existing_quiz_payload["month"] = TARGET_MONTH_KEY
    existing_quiz_payload["total_questions"] = len(all_final_mcqs)
    existing_quiz_payload["questions"] = all_final_mcqs

    with open(OUTPUT_QUIZ_FILE, "w", encoding="utf-8") as f:
        json.dump(existing_quiz_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Monthly Quiz Updated Successfully: '{OUTPUT_QUIZ_FILE}'")
    print(f"   ✅ Newly Added MCQs       : {len(newly_created_mcqs)}")
    print(f"   ⏭️ Rejected Low-Yield News : {skipped_low_value}")
    print(f"   📊 Total Active MCQs In Quiz: {len(all_final_mcqs)}")
    print("=" * 80)


if __name__ == "__main__":
    generate_monthly_mcqs_auto()
