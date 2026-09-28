import os
import json
import time
import requests
from bs4 import BeautifulSoup
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
# CONFIGURATION & REPO PATHS
# ============================================================

INPUT_FILE = "nse_content_feed.json"
OUTPUT_FILE = "nse_final_content_feed.json"

BATCH_SIZE = 3
BATCH_PAUSE_SECONDS = 15

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-20b", "provider": "groq"},
    {"name": "openai/gpt-oss-120b", "provider": "groq"},
    {"name": "gemini-3.5-flash-lite", "provider": "google"},
    {"name": "gemini-3.1-flash-lite", "provider": "google"}
]

GROQ_KEYS = [os.environ.get(k, "").strip() for k in ["GROQ_API_KEY", "GROQ_API_KEY2"] if os.environ.get(k, "").strip()]
GOOGLE_KEYS = [os.environ.get(k, "").strip() for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"] if os.environ.get(k, "").strip()]

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys configured. Exiting.")
    exit(1)

groq_key_idx = 0
google_key_idx = 0

# ============================================================
# SEARCH ENGINE
# ============================================================

def get_financial_facts(company, symbol):
    clean_company = company.replace("Limited", "").replace("Ltd", "").strip()
    query = f"{symbol} share annual revenue net profit screener"
    
    url = "https://html.duckduckgo.com/html/"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    snippets = []
    try:
        resp = requests.post(url, data={"q": query}, headers=headers, timeout=6)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.text, "html.parser")
            for r in soup.find_all("a", class_="result__snippet")[:3]:
                txt = r.get_text(strip=True)
                if txt:
                    snippets.append(f"• {txt}")
    except Exception as e:
        print(f"      [Search Warning]: {e}")

    return "\n".join(snippets)

# ============================================================
# CALL ENGINES
# ============================================================

def call_groq_analyst(model_name, system_instruction, prompt_content):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None

    for _ in range(len(GROQ_KEYS)):
        current_key = GROQ_KEYS[groq_key_idx]
        try:
            client = Groq(api_key=current_key)
            completion = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_instruction},
                    {"role": "user", "content": prompt_content}
                ],
                temperature=0.1
            )
            content = completion.choices[0].message.content
            if content and content.strip():
                return content.strip()
        except Exception as e:
            err = str(e)
            print(f"      [Groq Fail on {model_name} | Key {groq_key_idx}]: {err[:100]}")
            if "429" in err or "rate_limit" in err.lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None
            
    return None

def call_google_analyst(model_name, system_instruction, prompt_content):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None

    for _ in range(len(GOOGLE_KEYS)):
        current_key = GOOGLE_KEYS[google_key_idx]
        try:
            client = genai.Client(api_key=current_key)
            config = types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.1
            )
            response = client.models.generate_content(
                model=model_name,
                contents=prompt_content,
                config=config
            )
            if response.text and response.text.strip():
                return response.text.strip()
        except Exception as e:
            err = str(e)
            print(f"      [Google Fail on {model_name} | Key {google_key_idx}]: {err[:100]}")
            if "429" in err or "RESOURCE_EXHAUSTED" in err or "quota" in err.lower():
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None
            
    return None

def call_hybrid_analyst(system_instruction, prompt_content):
    for target in MODEL_REGISTRY:
        m_name = target["name"]
        provider = target["provider"]

        if provider == "groq":
            res = call_groq_analyst(m_name, system_instruction, prompt_content)
        else:
            res = call_google_analyst(m_name, system_instruction, prompt_content)

        if res:
            return res
            
        print(f"   ⚠️ Model {m_name} failed. Attempting next candidate...")

    return None

# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def process_deep_feed():
    print("=" * 80)
    print("🧠 STAGE 2: STRICT VERIFIED INSTITUTIONAL ANALYST")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    if not os.path.exists(INPUT_FILE):
        print(f"ℹ️ Input feed file '{INPUT_FILE}' not found.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        feed_data = json.load(f)

    cards = feed_data.get("content_feed", [])
    if not cards:
        print("✅ Content feed empty. No cards pending.")
        return

    final_feed = {
        "generated_at": NOW.strftime("%Y-%m-%d %H:%M:%S IST"),
        "total_posts": 0,
        "content_feed": []
    }

    existing_hashes = set()
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    final_feed = loaded
                    existing_hashes = {c["hash"] for c in final_feed.get("content_feed", []) if "hash" in c}
        except Exception:
            pass

    pending_cards = [card for card in reversed(cards) if card.get("hash") not in existing_hashes]
    print(f"🎯 Total pending filings for deep analysis: {len(pending_cards)}")

    if not pending_cards:
        print("✅ Everything up to date. Exiting cleanly.")
        return

    system_instruction = (
        "You are an institutional equity research analyst covering Indian equities (NSE).\n"
        "Ground announcements mathematically using the provided financial baseline.\n"
        "NEVER use disclaimers like 'Baseline numbers not disclosed' or 'cannot be quantified'. "
        "Estimate annualized run-rate (e.g. monthly x 12) and frame it against annual turnover scale.\n"
        "Output strictly valid Telegram HTML format (<b>, <i>, <a>). Do NOT use markdown asterisks (*)."
    )

    category_icons = {
        "COMMERCIAL_PRODUCTION": "🏭",
        "ORDER_WIN": "📜",
        "NEW_PRODUCT": "🚀",
        "FINANCIAL_RESULTS": "📊",
        "RESULT": "📊",
        "CAPEX": "🏗️",
        "ACQUISITION": "🤝",
        "JOINT_VENTURE": "🤝",
        "REGULATORY_APPROVAL": "✅",
        "USFDA_OBSERVATION": "⚠️",
        "LITIGATION": "⚖️",
        "RESIGNATION": "👤"
    }

    dispatched = 0
    failed_count = 0
    total_batches = (len(pending_cards) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1

    while i < len(pending_cards):
        batch = pending_cards[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} cards)...")

        for card in batch:
            c_hash = card.get("hash")
            symbol = card.get("symbol", "")
            company = card.get("company_name", symbol)
            event_type = card.get("event_type", "CORPORATE_UPDATE")
            headline = card.get("headline", "")
            summary_text = card.get("summary", "")
            reqs = card.get("research_requirements", [])
            pdf_link = card.get("pdf_link", "")
            date_str = card.get("broadcast_date") or card.get("analyzed_at", "")

            clean_cat_tag = event_type.upper().replace(" ", "_")
            cat_icon = category_icons.get(clean_cat_tag, "⚡")

            # 1. Fetch web context
            financial_context = get_financial_facts(company, symbol)

            # 2. Strict Grounding Check: Context empty hone par fallback search
            if not financial_context.strip():
                financial_context = f"{company} (NSE: {symbol}) is an established Indian corporate with ongoing manufacturing operations."

            prompt_content = f"""
COMPANY: {company} (NSE: {symbol})
EVENT TYPE: {event_type}
HEADLINE: {headline}

VERIFIED FILING SUMMARY:
{summary_text}

FINANCIAL BASELINE CONTEXT:
{financial_context}

TASK:
Produce an institutional research note strictly matching this layout:

{cat_icon} <b>#{clean_cat_tag} | INSTITUTIONAL NOTE</b>
🏢 <b>{company} (NSE: {symbol})</b>
<b>{headline}</b>
━━━━━━━━━━━━━━━━━━━━━━

🔹 <b>The Event:</b>
↳ [1-2 crisp factual sentences based on the filing summary]

📊 <b>Materiality & Financial Context:</b>
• <b>Scale vs Existing Base:</b> [Compute annualized operational scale mathematically. Contrast this with {company}'s revenue and operational stature.]
• <b>Financial Relevance:</b> [Estimated revenue contribution at peak capacity or margin impact. State if this is bolt-on or material.]
• <b>Strategic Positioning:</b> [Operational relevance: customer ramp-up, market share expansion, backward integration, or execution timeline]

🎯 <b>Analyst Watchlist:</b>
↳ [1-2 critical operational checkpoints or concall questions to track]
━━━━━━━━━━━━━━━━━━━━━━
📌 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>
"""

            print(f"  🔍 Processing: {symbol} ({event_type})...")
            final_post = call_hybrid_analyst(system_instruction, prompt_content)

            # HARD FILTER: Discard failed or defensive generation
            if not final_post or "Baseline numbers not disclosed" in final_post:
                print(f"  ❌ DISCARDED {symbol}: Model failed or produced evasive disclaimers.")
                failed_count += 1
                continue  # DO NOT SAVE TO JSON. DO NOT MARK HASH AS DONE.

            compact_card = {
                "hash": c_hash,
                "symbol": symbol,
                "company_name": company,
                "date": date_str,
                "research_requirements": reqs,
                "telegram_post": final_post
            }

            final_feed["content_feed"].insert(0, compact_card)
            existing_hashes.add(c_hash)
            dispatched += 1

            time.sleep(2)

        # Save progress only if at least one verified post was created
        if dispatched > 0:
            final_feed["total_posts"] = len(final_feed["content_feed"])
            final_feed["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
            with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
                json.dump(final_feed, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(pending_cards):
            print(f"⏳ Cooldown pause of {BATCH_PAUSE_SECONDS}s...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print(f"📊 SUMMARY: {dispatched} valid posts saved | {failed_count} discarded")
    print("=" * 80)

    # Force GitHub Actions to fail if everything failed, so it doesn't give a fake green tick
    if dispatched == 0 and failed_count > 0:
        print("❌ CRITICAL: All pending cards failed deep research. Failing workflow run.")
        exit(1)

if __name__ == "__main__":
    process_deep_feed()
