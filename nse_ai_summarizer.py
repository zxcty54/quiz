import os
import json
import time
import re
from datetime import datetime, timezone, timedelta

# Provider SDKs
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
# CONFIGURATION & HYBRID MODEL REGISTRY
# ============================================================

INPUT_FILE = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"

BATCH_SIZE = 4
BATCH_PAUSE_SECONDS = 20

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

# Exact requested hybrid model chain
MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-20b", "provider": "groq"},       # Primary
    {"name": "gemini-3.5-flash-lite", "provider": "google"},   # Fallback 1
    {"name": "openai/gpt-oss-120b", "provider": "groq"},      # Fallback 2
    {"name": "gemini-3.1-flash-lite", "provider": "google"}    # Fallback 3
]

# Collect Groq Keys
GROQ_KEYS = []
for k in ["GROQ_API_KEY", "GROQ_API_KEY2"]:
    v = os.environ.get(k)
    if v and v.strip() and v.strip() not in GROQ_KEYS:
        GROQ_KEYS.append(v.strip())

# Collect Google Keys
GOOGLE_KEYS = []
for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"]:
    v = os.environ.get(k)
    if v and v.strip() and v.strip() not in GOOGLE_KEYS:
        GOOGLE_KEYS.append(v.strip())

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("\n" + "=" * 80)
    print("❌ FATAL ERROR: Neither GROQ nor GOOGLE API Keys found in environment!")
    print("   Please check GitHub Secrets for GROQ_API_KEY / GOOGLE_API_KEY.")
    print("=" * 80 + "\n")
    exit(1)

groq_key_idx = 0
google_key_idx = 0
current_model_idx = 0

# ============================================================
# AI PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are a senior institutional equity research analyst and financial journalist.
You will receive a batch of Indian corporate filings from the National Stock Exchange (NSE) including regulatory announcements and detailed extracted PDF text.

YOUR TASK:
Perform hard fact extraction and make a strict CONTENT-WORTHINESS DECISION for each item.

Step 1: FACT EXTRACTION
- what_happened: 1-sentence crisp summary of the event (Order Win, Capex, Acquisition, JV, etc.).
- who: Specific entities involved (Buyer, seller, client, partner, promoters).
- what_business: Specific business segment, technology, or industry affected.
- how_much: Exact financial numbers (deal size in ₹ Cr / USD, capacity metric, valuation).
- when: Timelines, execution period, commissioning date.
- where: Geography, plant location, state/country.
- what_changes: Concrete change in ownership %, capacity metric, or revenue run-rate.
- what_is_disclosed: Key commercial terms explicitly stated.
- what_is_not_disclosed: Critical metrics kept opaque (e.g. client name confidential, margins not given, deal valuation hidden).

Step 2: CONTENT-WORTHINESS DECISION (content_worthy: true/false)
- Set "content_worthy": true ONLY IF the event has material commercial impact:
  * Commercial contract / order win with substantial value or marquee client.
  * Significant third-party acquisition, JV, or new business launch.
  * Meaningful capex / commercial production rollout.
  * Material quarterly financial result with explicit growth / profit numbers.
- Set "content_worthy": false for:
  * Routine administrative compliance, clarifications, minor non-material orders.
  * Incomplete filings where core numbers or terms are completely absent.

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

# ============================================================
# PARSER HELPER
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
        obj_match = re.search(r"\{[\s\S]*\}", text)
        if obj_match:
            try:
                data = json.loads(obj_match.group(0))
                return [data] if isinstance(data, dict) else data
            except Exception:
                pass
    return None

# ============================================================
# HYBRID CALLER DISPATCHER (GROQ & GOOGLE GENAI)
# ============================================================

def call_groq(model_name, payload):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None, "Groq SDK or keys missing"

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
            err = str(e)
            if "429" in err or "rate_limit" in err.lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                print(f"⚠️ Groq rate limit hit. Rotated to Key {groq_key_idx + 1}")
                time.sleep(2)
                continue
            return None, err
    return None, "All Groq keys exhausted"


def call_google(model_name, payload):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None, "Google GenAI SDK or keys missing"

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
            err = str(e)
            if "429" in err or "RESOURCE_EXHAUSTED" in err:
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                print(f"⚠️ Google rate limit hit. Rotated to Key {google_key_idx + 1}")
                time.sleep(2)
                continue
            return None, err
    return None, "All Google keys exhausted"


def call_hybrid_ai(batch_prompt):
    global current_model_idx

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        target = MODEL_REGISTRY[current_model_idx]
        m_name = target["name"]
        provider = target["provider"]

        print(f"   🤖 Trying [{provider.upper()}]: {m_name}...")

        if provider == "groq":
            res, err = call_groq(m_name, batch_prompt)
        else:
            res, err = call_google(m_name, batch_prompt)

        if res:
            return res if isinstance(res, list) else [res]

        print(f"   ⚠️ Failed on {m_name} ({err}). Switching to next fallback model...")
        current_model_idx += 1

    print("⚠️ All hybrid models in chain exhausted. Pausing 45s for reset...")
    time.sleep(45)
    current_model_idx = 0
    return None

# ============================================================
# BATCH ORCHESTRATOR
# ============================================================

def process_corporate_actions_feed():
    print("=" * 80)
    print("🚀 RUNNING HYBRID AI FACT EXTRACTION & WORTHINESS PIPELINE")
    print(f"📅 Timestamp: {datetime.now(IST).strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    feed_archive = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST"),
        "worthy_count": 0,
        "skipped_count": 0,
        "content_feed": [],
        "skipped_archive": []
    }

    # Guard: Create empty output file if not present
    if not os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)
        print(f"📁 Initialized target file: '{OUTPUT_FILE}'")
    else:
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    feed_archive = loaded
        except Exception:
            pass

    if not os.path.exists(INPUT_FILE):
        print(f"❌ '{INPUT_FILE}' not found! Run the scraper first.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    announcements = master_data.get("corporate_announcements", [])
    print(f"📦 Total raw announcements: {len(announcements)}")

    processed_hashes = {item["hash"] for item in feed_archive.get("content_feed", []) if "hash" in item}
    processed_hashes.update({item["hash"] for item in feed_archive.get("skipped_archive", []) if "hash" in item})

    pending_items = [
        a for a in announcements 
        if a.get("hash") not in processed_hashes and a.get("pdf_extracted_text")
    ]

    print(f"🎯 Announcements awaiting processing: {len(pending_items)}")

    if not pending_items:
        print("✅ No pending items. Everything is up to date!")
        return

    total_batches = (len(pending_items) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1

    while i < len(pending_items):
        batch = pending_items[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "symbol": itm.get("symbol", ""),
                "company_name": itm.get("company_name", ""),
                "category": itm.get("category", ""),
                "subject": itm.get("subject", ""),
                "summary": itm.get("summary", ""),
                "pdf_text": str(itm.get("pdf_extracted_text", ""))[:3500]
            })

        prompt_str = "Analyze and extract facts for these NSE filings:\n" + json.dumps(batch_payload, ensure_ascii=False)
        batch_result = call_hybrid_ai(prompt_str)

        if not batch_result:
            print(f"⚠️ Batch {batch_counter} skipped due to API exhaustion. Next hourly run will retry.")
            i += BATCH_SIZE
            batch_counter += 1
            continue

        result_map = {res.get("input_id"): res for res in batch_result if isinstance(res, dict)}

        for idx, itm in enumerate(batch, 1):
            res = result_map.get(idx)
            if not res:
                continue

            is_worthy = res.get("content_worthy", False)
            headline = res.get("headline") or itm.get("subject")

            record = {
                "hash": itm.get("hash"),
                "symbol": itm.get("symbol"),
                "company_name": itm.get("company_name"),
                "category": itm.get("category"),
                "broadcast_date": itm.get("broadcast_date"),
                "pdf_link": itm.get("pdf_link"),
                "headline": headline,
                "content_worthy": is_worthy,
                "worthiness_reason": res.get("worthiness_reason", ""),
                "facts": res.get("facts", {}),
                "social_post_hook": res.get("social_post_hook", ""),
                "analyzed_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
            }

            if is_worthy:
                print(f"  ⭐ [YES -> CONTENT] {itm.get('symbol')}: {headline[:50]}")
                feed_archive["content_feed"].insert(0, record)
            else:
                print(f"  ⏭️ [NO  -> SKIP]    {itm.get('symbol')}: {res.get('worthiness_reason', '')[:50]}")
                feed_archive["skipped_archive"].insert(0, record)

        feed_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])

        feed_archive["content_feed"] = feed_archive["content_feed"][:500]
        feed_archive["skipped_archive"] = feed_archive["skipped_archive"][:500]

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(pending_items):
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s between batches...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print("✅ HYBRID RUN COMPLETED:")
    print(f"   • Content-Worthy Events : {feed_archive['worthy_count']}")
    print(f"   • Skipped Records Stored: {feed_archive['skipped_count']}")
    print(f"💾 File Saved to           : '{OUTPUT_FILE}'")
    print("=" * 80)


if __name__ == "__main__":
    process_corporate_actions_feed()
