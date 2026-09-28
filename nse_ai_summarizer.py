import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION & MULTI-MODEL FALLBACK REGISTRY
# ============================================================

INPUT_FILE = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

# Production Multi-Model Fallback Chain
MODEL_REGISTRY = [
    "gemini-2.5-flash",        # Primary High-Speed
    "gemini-2.0-flash",        # Fallback 1
    "gemini-1.5-flash",        # Fallback 2
    "gemini-2.5-pro",          # Fallback 3 (Deep reasoning fallback)
]

BATCH_SIZE = 4
BATCH_PAUSE_SECONDS = 20

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

current_model_idx = 0

# ============================================================
# AI FACT EXTRACTION & WORTHINESS SYSTEM PROMPT
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
# ROBUST JSON PARSER & CLEANER
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
# ADAPTIVE MULTI-MODEL CALLER (WITH 429 AUTO-FAILOVER)
# ============================================================

def call_gemini_with_fallback(batch_prompt):
    global current_model_idx

    if not client:
        print("❌ Gemini Client is not initialized! Please export GEMINI_API_KEY.")
        return None

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        model_name = MODEL_REGISTRY[current_model_idx]

        for attempt in range(2):
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
                if parsed is not None:
                    return parsed if isinstance(parsed, list) else [parsed]

                print(f"⚠️ [{model_name}] JSON parse retry (Attempt {attempt + 1})...")
                time.sleep(3)

            except Exception as e:
                err_str = str(e)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    print(f"⚠️ [{model_name}] Rate limit / Quota hit (429). Switching to fallback model...")
                    current_model_idx += 1
                    break

                print(f"⚠️ [{model_name}] Error on attempt {attempt + 1}: {e}")
                time.sleep(4)

        if current_model_idx < total_models and MODEL_REGISTRY[current_model_idx] != model_name:
            continue
        else:
            current_model_idx += 1

    print("⚠️ All models in registry exhausted. Pausing 60s for quota bucket reset...")
    time.sleep(60)
    current_model_idx = 0
    return None

# ============================================================
# BATCH ORCHESTRATOR
# ============================================================

def process_corporate_actions_feed():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Input master file '{INPUT_FILE}' not found! Scraper run karein pehle.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    announcements = master_data.get("corporate_announcements", [])
    print(f"🚀 Loaded {len(announcements)} corporate announcements from '{INPUT_FILE}'")

    # Load existing content feed to prevent duplicate AI calls
    feed_archive = {
        "generated_at": "",
        "worthy_count": 0,
        "skipped_count": 0,
        "content_feed": [],
        "skipped_archive": []
    }

    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    feed_archive = loaded
        except Exception:
            pass

    processed_hashes = {item["hash"] for item in feed_archive.get("content_feed", []) if "hash" in item}
    processed_hashes.update({item["hash"] for item in feed_archive.get("skipped_archive", []) if "hash" in item})

    # Only process announcements that have PDF extracted text and are not already analyzed
    pending_items = [
        a for a in announcements 
        if a.get("hash") not in processed_hashes and a.get("pdf_extracted_text")
    ]

    print(f"🎯 Fresh announcements requiring AI Fact Extraction: {len(pending_items)}")

    if not pending_items:
        print("✅ All items already processed. Everything is up to date!")
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
        batch_result = call_gemini_with_fallback(prompt_str)

        if not batch_result:
            print(f"🔄 Retrying Batch {batch_counter} to guarantee coverage...")
            time.sleep(10)
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

        # Checkpoint save after every batch
        feed_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        feed_archive["worthy_count"] = len(feed_archive["content_feed"])
        feed_archive["skipped_count"] = len(feed_archive["skipped_archive"])

        # Cap storage
        feed_archive["content_feed"] = feed_archive["content_feed"][:500]
        feed_archive["skipped_archive"] = feed_archive["skipped_archive"][:500]

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(pending_items):
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s to avoid token rate-limits...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print("✅ AI FACT EXTRACTION & FILTERING COMPLETED!")
    print(f"📊 Content-Worthy Cards : {feed_archive['worthy_count']}")
    print(f"📊 Filtered/Skipped Cards: {feed_archive['skipped_count']}")
    print(f"💾 Feed Written to      : '{OUTPUT_FILE}'")
    print("=" * 80)


if __name__ == "__main__":
    process_corporate_actions_feed()
