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
    {"name": "gemini-2.5-flash", "provider": "google"},
    {"name": "openai/gpt-oss-120b", "provider": "groq"},
    {"name": "gemini-2.5-flash-lite", "provider": "google"}
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
# SYSTEM PROMPT (STAGE 1: GATEKEEPER, DENSE SUMMARY & DYNAMIC RESEARCH PLANNER)
# ============================================================

SYSTEM_PROMPT = """
You are a senior institutional equity research editor.
You will evaluate Indian corporate filings and financial results from the National Stock Exchange (NSE).

YOUR ROLE:
1. Make a strict CONTENT-WORTHINESS DECISION (content_worthy: true/false).
   - "true" ONLY for genuine business inflection points that alter the commercial, legal, managerial, operational, or financial reality of the company.
   - "false" for routine administrative notices, generic compliance, standard calendar dates, or minor immaterial filings.

CRITICAL FINANCIAL RESULT GUARDRAIL (MANDATORY REJECTION):
If the filing is a quarterly result, outcome of board meeting, or financial update, it MUST contain actual numerical figures for Revenue and Net Profit (PAT).
If actual numeric figures for Revenue and PAT are missing, undisclosed, or say "Not disclosed", you MUST SET "content_worthy": false.
Do NOT approve generic board approval notices or audit review letters without profit/revenue metrics.

2. If content_worthy is TRUE:
   - Identify the precise 'event_type' dynamically in uppercase snake-case (e.g. COMMERCIAL_PRODUCTION, ORDER_WIN, FINANCIAL_RESULTS, ACQUISITION, USFDA_OBSERVATION, LITIGATION, RESIGNATION, CAPEX, JOINT_VENTURE).
   - Generate a single dense, factual 'summary' paragraph synthesizing all facts, figures, timeline, operational changes, and critical undisclosed metrics.
   - DYNAMICALLY FORMULATE 'research_requirements':
     Evaluate the filing and determine: "What specific company scale baseline, historical segment data, or background context must be verified via web search to measure the true materiality of this development?"
     DO NOT use hardcoded or generic capex questions. Adapt strictly to the filing's nature:
     * Drug/Plant approval -> Facility revenue share, addressable therapy market size.
     * Litigation/Tax -> Demand amount as % of net worth or cash profit, dispute history.
     * Leadership changes -> Executive's past role, strategic tenure, succession clarity.
     * Capex/Plant commissioning -> Existing manufacturing capacity, current utilization, segment scale.
     * Order win -> Annual run-rate revenue, active order book, customer dependency.
     "For capacity addition/plant commissioning events, always include existing total capacity as one of the research requirements."

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON object with an "items" array:
{
  "items": [
    {
      "input_id": 1,
      "content_worthy": true,
      "worthiness_reason": "Crisp 1-line reason for inclusion or exclusion",
      "event_type": "DYNAMIC_EVENT_TYPE",
      "headline": "Factual and attention-worthy headline",
      "summary": "Dense single paragraph consolidating: what happened, exact numbers/capacity/deal values, counterparties, operational delta, and critical gaps not disclosed by management.",
      "facts": {
        "what_happened": "Exact factual statement",
        "how_much": "Financial value, capacity, or volume",
        "what_changes": "Operational/commercial change disclosed in filing",
        "what_is_not_disclosed": "Critical numbers missing from the filing"
      },
      "research_requirements": [
        "Dynamic search metric 1 strictly relevant to contextualizing this filing",
        "Dynamic search metric 2 for company baseline scale comparison",
        "Dynamic search metric 3 for segment or peer benchmark"
      ]
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
    print("🚀 AI EDITORIAL GATEKEEPER & RESEARCH PLANNER")
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

        prompt_str = "Evaluate corporate filings, produce dense summary and dynamic research requirements:\n" + json.dumps(batch_payload, ensure_ascii=False)
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
            summary_content = res.get("summary") or ""
            facts = res.get("facts", {})
            event_type = res.get("event_type") or itm["category"]

            # ------------------------------------------------------------
            # HARD GUARDRAIL: ZERO-NUMBER FINANCIAL RESULT CHECK
            # ------------------------------------------------------------
            if is_worthy and itm.get("category") == "RESULT":
                how_much = str(facts.get("how_much", "")).lower()
                summary_lower = summary_content.lower()

                has_no_value = (
                    "not disclosed" in how_much
                    or how_much in ["", "none", "nil", "n/a"]
                    or "revenue: not disclosed" in summary_lower
                )

                if has_no_value:
                    is_worthy = False
                    res["worthiness_reason"] = "Dropped: Zero financial metrics/numbers in results filing."

            record = {
                "hash": itm["hash"],
                "symbol": itm["symbol"],
                "company_name": itm["company_name"],
                "category": itm["category"],
                "event_type": event_type,
                "broadcast_date": itm["broadcast_date"],
                "pdf_link": itm["pdf_link"],
                "headline": headline,
                "content_worthy": is_worthy,
                "worthiness_reason": res.get("worthiness_reason", ""),
                "summary": summary_content if is_worthy else "",
                "facts": facts,
                "research_requirements": res.get("research_requirements", []) if is_worthy else [],
                "analyzed_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
            }

            if is_worthy and summary_content:
                req_count = len(record["research_requirements"])
                print(f"  ⭐ [APPROVED] {itm['symbol']} | {event_type} | {req_count} search targets mapped")
                feed_archive["content_feed"].insert(0, record)
            else:
                print(f"  ⏭️ [SKIPPED / REJECTED]  {itm['symbol']}: {res.get('worthiness_reason', '')[:50]}")
                feed_archive["skipped_archive"].insert(0, record)

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
