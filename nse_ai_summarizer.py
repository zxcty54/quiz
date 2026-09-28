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
# CONFIGURATION & RETENTION
# ============================================================

INPUT_FILE = "nse_corporate_master.json"
OUTPUT_FILE = "nse_content_feed.json"

BATCH_SIZE = 4
BATCH_PAUSE_SECONDS = 20

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

# 24 Hours retention calculated strictly from the time of insertion into content_feed
CUTOFF_24H_ANALYZED = NOW - timedelta(hours=24)

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

def is_within_24h_of_analysis(item):
    """Purges card strictly 24 hours after it was generated/analyzed in content_feed."""
    analyzed_str = item.get("analyzed_at", "").replace(" IST", "").strip()
    if not analyzed_str:
        return True
    try:
        dt = datetime.strptime(analyzed_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=IST)
        return dt >= CUTOFF_24H_ANALYZED
    except Exception:
        return True

# ============================================================
# SYSTEM PROMPT (ROOT JSON OBJECT FOR GROQ & GEMINI ENGINE)
# ============================================================

SYSTEM_PROMPT = """
You are a senior institutional equity research editor and financial journalist.
You will receive Indian corporate announcements and quarterly financial results from the National Stock Exchange (NSE).

YOUR ROLE:
1. Make a strict CONTENT-WORTHINESS DECISION (content_worthy: true/false).
   - "true" ONLY for genuine business inflection points: Material order wins/contracts, M&A/slump sales, commercial production starts, new capacity, joint ventures, or significant financial turnarounds/accelerations.
   - "false" for routine administrative notices, minor orders, generic compliance, or filings lacking numbers.

2. If content_worthy is TRUE, WRITE A COMPLETE, CURATED, EDITORIAL TELEGRAM POST.

STRICT WRITING & EDITORIAL RULES:
- Facts only: Use strictly the information disclosed in the filing. Never invent numbers or details.
- Numbers accuracy: Preserve exact figures, currencies (₹ Cr, USD), capacities, dates, and percentages.
- Tone: Strictly objective and neutral. NEVER use evaluative hype words like "positive", "negative", "strong", "huge", "aggressive", "boosts earnings" unless quoting management directly.
- No investment advice: No buy/sell recommendations, no target prices, no future stock-price speculations.
- What changes: Focus strictly on concrete commercial/operational changes (e.g., product portfolio addition, manufacturing capacity expansion, new client base), NOT market-cap or stock-price impact.
- Not disclosed section: Include ONLY if genuinely critical information is missing (e.g., undisclosed deal value, hidden acquisition multiples, confidential client name, missing profit margins). If nothing vital is absent, OMIT the "Not disclosed" section completely.
- Source Link: Use standard HTML hyperlink format: <a href="PDF_LINK">NSE Corporate Filing</a>

EXACT TELEGRAM POST LAYOUT STRUCTURE:
🏷️ {CATEGORY}
<b>{COMPANY NAME} — {HEADLINE}</b>

<b>What happened?</b>
{1–2 sentence crisp factual summary of the event.}

<b>Key details</b>
• <b>What:</b> {Specific event or asset}
• <b>Who:</b> {Company and counterparty/client/partner}
• <b>Business:</b> {Affected business line/segment/product}
• <b>Value / Size:</b> {Financial value, capacity, or volume — only if stated}
• <b>When:</b> {Execution dates, milestones, commissioning timeline}
• <b>Where:</b> {Geography/location, if stated}

<b>What changes</b>
{1–2 sentences explaining the real-world operational/commercial change for the company.}

<b>Not disclosed</b>
{Material undisclosed metrics. OMIT this block if no material gaps exist.}

📌 <b>Source:</b> <a href="{PDF_LINK}">NSE Corporate Filing</a>

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON object with an "items" array:
{
  "items": [
    {
      "input_id": 1,
      "content_worthy": true,
      "worthiness_reason": "Crisp 1-line reason for inclusion or exclusion",
      "headline": "Factual and attention-worthy headline",
      "telegram_post": "Complete Telegram post matching the structure with HTML tags",
      "facts": {
        "what_happened": "...",
        "how_much": "...",
        "what_changes": "...",
        "what_is_not_disclosed": "..."
      }
    }
  ]
}
"""

def clean_json_response(raw_text):
    if not raw_text or not raw_text.strip():
        return None
    text = raw_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data.get("items", [])
        elif isinstance(data, list):
            return data
    except Exception:
        arr_match = re.search(r"\[[\s\S]*\]", text)
        if arr_match:
            try:
                return json.loads(arr_match.group(0))
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
    total = len(MODEL_REGISTRY)

    while current_model_idx < total:
        target = MODEL_REGISTRY[current_model_idx]
        m_name = target["name"]
        provider = target["provider"]

        if provider == "groq":
            res, err = call_groq(m_name, batch_prompt)
        else:
            res, err = call_google(m_name, batch_prompt)

        if res:
            return res

        print(f"   ⚠️ Fail on {m_name}. Switching to next fallback...")
        current_model_idx += 1

    time.sleep(45)
    current_model_idx = 0
    return None

# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def process_corporate_actions_feed():
    print("=" * 80)
    print("🚀 AI EDITORIAL SUMMARIZER (24-HOUR FEED RETENTION)")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    feed_archive = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
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
                    # Purge posts older than 24 hours based on analyzed_at
                    feed_archive["content_feed"] = [
                        item for item in feed_archive.get("content_feed", [])
                        if is_within_24h_of_analysis(item)
                    ]
                    feed_archive["skipped_archive"] = [
                        item for item in feed_archive.get("skipped_archive", [])
                        if is_within_24h_of_analysis(item)
                    ]
        except Exception:
            pass
    else:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(feed_archive, f, ensure_ascii=False, indent=2)

    if not os.path.exists(INPUT_FILE):
        print(f"❌ '{INPUT_FILE}' not found! Run scraper first.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        master_data = json.load(f)

    processed_hashes = {item["hash"] for item in feed_archive.get("content_feed", []) if "hash" in item}
    processed_hashes.update({item["hash"] for item in feed_archive.get("skipped_archive", []) if "hash" in item})

    candidates = []

    # 1. Actionable Announcements from 3-day Master Archive
    for a in master_data.get("corporate_announcements", []):
        if a.get("hash") not in processed_hashes and a.get("pdf_extracted_text"):
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

    # 2. Financial Results from Master Archive
    for r in master_data.get("financial_results", []):
        if r.get("hash") not in processed_hashes:
            summary_str = (
                f"Revenue: ₹{r.get('revenue')} Cr (YoY: {r.get('yoy_revenue_growth')}%), "
                f"PAT: ₹{r.get('pat')} Cr (YoY: {r.get('yoy_pat_growth')}%), "
                f"Signal: {r.get('signal_tag')}, Exceptional: ₹{r.get('exceptional_items')} Cr"
            )
            candidates.append({
                "type": "FINANCIAL_RESULT",
                "hash": r.get("hash"),
                "symbol": r.get("symbol"),
                "company_name": r.get("company_name"),
                "category": "RESULT",
                "subject": f"Quarterly Result - Revenue ₹{r.get('revenue')} Cr | PAT ₹{r.get('pat')} Cr",
                "summary": summary_str,
                "payload_text": json.dumps(r, indent=2),
                "broadcast_date": r.get("result_date"),
                "pdf_link": r.get("pdf_link")
            })

    print(f"🎯 Total pending filings for AI processing: {len(candidates)}")

    if not candidates:
        print("✅ No pending items. Content feed is fully synchronized!")
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
                "pdf_link": itm["pdf_link"],
                "details": itm["payload_text"]
            })

        prompt_str = "Write publication-ready Telegram posts for these corporate events:\n" + json.dumps(batch_payload, ensure_ascii=False)
        batch_result = call_hybrid_ai(prompt_str)

        if not batch_result:
            print(f"⚠️ Batch {batch_counter} skipped.")
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
            telegram_post = res.get("telegram_post", "")

            # Ensure PDF source hyperlink exists
            if itm["pdf_link"] and "Source:" not in telegram_post:
                telegram_post += f'\n\n📌 <b>Source:</b> <a href="{itm["pdf_link"]}">NSE Corporate Filing</a>'

            record = {
                "hash": itm["hash"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "broadcast_date": itm["broadcast_date"],
                "pdf_link": itm["pdf_link"],
                "headline": headline,
                "content_worthy": is_worthy,
                "worthiness_reason": res.get("worthiness_reason", ""),
                "telegram_post": telegram_post,
                "facts": res.get("facts", {}),
                "analyzed_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")  # 24-hr clock begins now
            }

            if is_worthy and telegram_post:
                print(f"  ⭐ [APPROVED & WRITTEN] {itm['symbol']}: {headline[:50]}")
                feed_archive["content_feed"].insert(0, record)
            else:
                print(f"  ⏭️ [SKIPPED]            {itm['symbol']}: {res.get('worthiness_reason', '')[:50]}")
                feed_archive["skipped_archive"].insert(0, record)

        # Enforce rolling 24-hr window based on analyzed_at
        feed_archive["content_feed"] = [item for item in feed_archive["content_feed"] if is_within_24h_of_analysis(item)]
        feed_archive["skipped_archive"] = [item for item in feed_archive["skipped_archive"] if is_within_24h_of_analysis(item)]

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
    print("✅ AI EDITORIAL WORKFLOW COMPLETE:")
    print(f"   • Active Posts in Feed (Last 24h) : {feed_archive['worthy_count']}")
    print(f"   • Filtered Records Archive        : {feed_archive['skipped_count']}")
    print(f"💾 File Saved to                     : '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    process_corporate_actions_feed()
