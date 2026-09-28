import os
import json
import time
import re
from datetime import datetime, timezone, timedelta

try:
    from groq import Groq
except ImportError:
    Groq = None

try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None

# ============================================================
# CONFIGURATION & 24-HOUR RETENTION PARAMETERS
# ============================================================

INPUT_FILE = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"

BATCH_SIZE = 4
BATCH_PAUSE_SECONDS = 20

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)
RETENTION_HOURS = 24
CUTOFF_24H = NOW - timedelta(hours=RETENTION_HOURS)

MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-20b", "provider": "groq"},
    {"name": "gemini-3.5-flash-lite", "provider": "google"},
    {"name": "openai/gpt-oss-120b", "provider": "groq"},
    {"name": "gemini-3.1-flash-lite", "provider": "google"}
]

GROQ_KEYS = [os.environ.get(k).strip() for k in ["GROQ_API_KEY", "GROQ_API_KEY2"] if os.environ.get(k)]
GOOGLE_KEYS = [os.environ.get(k).strip() for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"] if os.environ.get(k)]

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys found! Exiting.")
    exit(1)

groq_key_idx = 0
google_key_idx = 0
current_model_idx = 0

# ============================================================
# 24-HOUR RETENTION UTILITY
# ============================================================

def is_within_24_hours(item):
    """Returns True if the item broadcast/analyzed timestamp is within last 24 hours."""
    # 1. Try broadcast_date first ('28-Sep-2026 10:15:00' or '28-Sep-2026')
    dt_str = item.get("broadcast_date") or item.get("analyzed_at", "")
    if not dt_str:
        return False

    clean_str = dt_str.replace(" IST", "").strip()
    for fmt in ("%d-%b-%Y %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%d-%b-%Y", "%Y-%m-%d"):
        try:
            target = clean_str if (" " in fmt and " " in clean_str) else clean_str.split()[0]
            dt = datetime.strptime(target, fmt).replace(tzinfo=IST)
            return dt >= CUTOFF_24H
        except Exception:
            pass

    # 2. Fallback to analyzed_at
    analyzed_str = item.get("analyzed_at", "").replace(" IST", "").strip()
    if analyzed_str:
        try:
            dt = datetime.strptime(analyzed_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
            return dt >= CUTOFF_24H
        except Exception:
            pass

    return False

# ============================================================
# SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are a senior institutional equity research analyst and forensic accountant.
You will receive pre-filtered high-signal Indian corporate events (Orders, Acquisitions, JV, Capex) AND high-growth financial earnings results.

YOUR TASK:
Extract concrete facts, explain the underlying driver, evaluate disclosure transparency, and make a strict CONTENT-WORTHINESS DECISION.

Step 1: FACT EXTRACTION
- what_happened: 1-sentence crisp summary of the event (Turnaround, Order Win, Capex, Acquisition, JV).
- who: Specific entities involved (Buyer, seller, client, partner, promoters).
- what_business: Specific business segment, technology, or industry affected.
- how_much: Exact financial numbers (PAT, Revenue, YoY %, deal size, capacity).
- when: Timelines, execution period, commissioning date.
- where: Geography, plant location, state/country.
- what_changes: Concrete change in ownership %, capacity metric, or operational run-rate.
- what_is_disclosed: Key commercial/operational drivers explicitly stated.
- what_is_not_disclosed: Critical metrics kept opaque (e.g. margin breakdown missing, client name hidden, exceptional gain details undisclosed).

Step 2: FOR FINANCIAL RESULTS — FORENSIC "WHY" CHECK
- Check if the profit jump is organic (operating leverage, volume expansion, lower input costs) or an accounting distortion (one-off land sale, other income, tax reversal).
- If one-off driven, explicitly state this in headline and facts.

Step 3: CONTENT-WORTHINESS DECISION (content_worthy: true/false)
- Set "content_worthy": true ONLY IF the event or earnings result represents a material business inflection point.
- Set "content_worthy": false if the numbers lack substance or lack core operating growth.

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON array of objects:
[
  {
    "input_id": 1,
    "content_worthy": true,
    "worthiness_reason": "Crisp 1-line rationale for decision",
    "headline": "High-impact financial news headline",
    "facts": {
      "what_happened": "...",
      "who": "...",
      "what_business": "...",
      "how_much": "...",
      "when": "...",
      "where": "...",
      "what_changes": "...",
      "what_is_disclosed": "...",
      "what_is_not_disclosed": "..."
    },
    "social_post_hook": "Engaging 1-2 sentence market post hook with key numbers"
  }
]
"""

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
        obj_match = re.search(r"\{[\s\S]*\}", text)
        if obj_match:
            try:
                data = json.loads(obj_match.group(0))
                return [data] if isinstance(data, dict) else data
            except Exception:
                pass
    return None

def call_groq(model_name, payload):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None, "Groq missing"
    for _ in range(len(GROQ_KEYS)):
        try:
            client = Groq(api_key=GROQ_KEYS[groq_key_idx])
            completion = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": payload}
                ],
                temperature=0.1,
                response_format={"type": "json_object"}
            )
            parsed = clean_json_response(completion.choices[0].message.content)
            if parsed:
                return parsed, None
        except Exception as e:
            if "429" in str(e) or "rate_limit" in str(e).lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
    return None, "Groq keys exhausted"

def call_google(model_name, payload):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None, "Google GenAI missing"
    for _ in range(len(GOOGLE_KEYS)):
        try:
            client = genai.Client(api_key=GOOGLE_KEYS[google_key_idx])
            response = client.models.generate_content(
                model=model_name,
                contents=payload,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0.1,
                    response_mime_type="application/json"
                )
            )
            parsed = clean_json_response(response.text)
            if parsed:
                return parsed, None
        except Exception as e:
            if "429" in str(e) or "RESOURCE_EXHAUSTED" in str(e):
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None, str(e)
    return None, "Google keys exhausted"

def call_hybrid_ai(batch_prompt):
    global current_model_idx
    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        target = MODEL_REGISTRY[current_model_idx]
        m_name = target["name"]
        provider = target["provider"]

        if provider == "groq":
            res, err = call_groq(m_name, batch_prompt)
        else:
            res, err = call_google(m_name, batch_prompt)

        if res:
            return res if isinstance(res, list) else [res]

        print(f"   ⚠️ Model fail on {m_name}. Switching to next in registry...")
        current_model_idx += 1

    time.sleep(45)
    current_model_idx = 0
    return None

# ============================================================
# BATCH PROCESSOR WITH 24-HOUR ROLLING PURGE
# ============================================================

def process_corporate_actions_feed():
    print("=" * 80)
    print("🚀 RUNNING AI FORENSIC SUMMARIZER (24-HOUR ROLLING WINDOW)")
    print(f"📅 Active Window: After {CUTOFF_24H.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    feed_archive = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST"),
        "window": "Rolling 24 Hours",
        "worthy_count": 0,
        "skipped_count": 0,
        "content_feed": [],
        "skipped_archive": []
    }

    # 1. Load existing archive and purge anything > 24 hours immediately
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    feed_archive = loaded
                    # Strict 24-hour purge
                    feed_archive["content_feed"] = [
                        item for item in feed_archive.get("content_feed", [])
                        if is_within_24_hours(item)
                    ]
                    feed_archive["skipped_archive"] = [
                        item for item in feed_archive.get("skipped_archive", [])
                        if is_within_24_hours(item)
                    ]
        except Exception:
            pass
    else:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

    if not os.path.exists(INPUT_FILE):
        print(f"❌ Input master file '{INPUT_FILE}' not found! Scraper run karein pehle.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    processed_hashes = {item["hash"] for item in feed_archive.get("content_feed", []) if "hash" in item}
    processed_hashes.update({item["hash"] for item in feed_archive.get("skipped_archive", []) if "hash" in item})

    candidates = []

    # 1. Commercial Announcements (Within 24 Hours only)
    for a in master_data.get("corporate_announcements", []):
        if a.get("hash") not in processed_hashes and a.get("pdf_extracted_text"):
            if is_within_24_hours(a):
                candidates.append({
                    "type": "ANNOUNCEMENT",
                    "hash": a.get("hash"),
                    "symbol": a.get("symbol"),
                    "company_name": a.get("company_name"),
                    "category": a.get("category"),
                    "subject": a.get("subject"),
                    "summary": a.get("summary"),
                    "payload_text": a.get("pdf_extracted_text")[:3500],
                    "broadcast_date": a.get("broadcast_date"),
                    "pdf_link": a.get("pdf_link")
                })

    # 2. Financial Results (Within 24 Hours only)
    for r in master_data.get("financial_results", []):
        if r.get("hash") not in processed_hashes:
            if is_within_24_hours(r):
                summary_str = (
                    f"Revenue: ₹{r.get('revenue')} Cr (YoY: {r.get('yoy_revenue_growth')}%), "
                    f"PAT: ₹{r.get('pat')} Cr (YoY: {r.get('yoy_pat_growth')}%), "
                    f"Signal: {r.get('signal_tag')}, Exceptional Items: ₹{r.get('exceptional_items')} Cr"
                )
                candidates.append({
                    "type": "FINANCIAL_RESULT",
                    "hash": r.get("hash"),
                    "symbol": r.get("symbol"),
                    "company_name": r.get("company_name"),
                    "category": "RESULT",
                    "subject": f"Quarterly Outlier Result - {r.get('signal_tag')}",
                    "summary": summary_str,
                    "payload_text": json.dumps({
                        "financial_metrics": r,
                        "segments": r.get("segment_revenue", {}),
                        "one_off": r.get("is_one_off_driven")
                    }, indent=2),
                    "broadcast_date": r.get("result_date"),
                    "pdf_link": r.get("pdf_link")
                })

    print(f"🎯 High-conviction events in current 24h window: {len(candidates)}")

    if not candidates:
        print("✅ No pending items in the last 24 hours. Purging complete & up to date.")
        # Ensure pruned state is saved
        feed_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)
        return

    total_batches = (len(candidates) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1

    while i < len(candidates):
        batch = candidates[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "type": itm["type"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "subject": itm["subject"],
                "summary": itm["summary"],
                "details": itm["payload_text"]
            })

        prompt_str = "Perform forensic fact extraction on these corporate events:\n" + json.dumps(batch_payload, ensure_ascii=False)
        batch_result = call_hybrid_ai(prompt_str)

        if not batch_result:
            print(f"⚠️ Batch {batch_counter} skipped due to API exhaustion.")
            i += BATCH_SIZE
            batch_counter += 1
            continue

        result_map = {res.get("input_id"): res for res in batch_result if isinstance(res, dict)}

        for idx, itm in enumerate(batch, 1):
            res = result_map.get(idx)
            if not res:
                continue

            is_worthy = res.get("content_worthy", False)
            headline = res.get("headline") or itm["subject"]

            record = {
                "hash": itm["hash"],
                "type": itm["type"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "broadcast_date": itm["broadcast_date"],
                "pdf_link": itm["pdf_link"],
                "headline": headline,
                "content_worthy": is_worthy,
                "worthiness_reason": res.get("worthiness_reason", ""),
                "facts": res.get("facts", {}),
                "social_post_hook": res.get("social_post_hook", ""),
                "analyzed_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
            }

            if is_worthy:
                print(f"  ⭐ [WORTHY] {itm['symbol']}: {headline[:50]}")
                feed_archive["content_feed"].insert(0, record)
            else:
                print(f"  ⏭️ [SKIPPED] {itm['symbol']}: {res.get('worthiness_reason', '')[:50]}")
                feed_archive["skipped_archive"].insert(0, record)

        # Final 24-hour enforcement before writing
        feed_archive["content_feed"] = [item for item in feed_archive["content_feed"] if is_within_24_hours(item)]
        feed_archive["skipped_archive"] = [item for item in feed_archive["skipped_archive"] if is_within_24_hours(item)]

        feed_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(candidates):
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s to avoid rate limits...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print("✅ 24-HOUR CONTENT FEED SYNC COMPLETE:")
    print(f"   • Active Content-Worthy Cards (Last 24h): {feed_archive['worthy_count']}")
    print(f"   • Filtered/Skipped Cards (Last 24h)     : {feed_archive['skipped_count']}")
    print(f"💾 File Saved to                           : '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    process_corporate_actions_feed()
