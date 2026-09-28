import os
import json
import time
from datetime import datetime, timezone, timedelta

# Live web context fetcher for open models
try:
    from duckduckgo_search import DDGS
except ImportError:
    DDGS = None

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
# CONFIGURATION & MULTI-MODEL REGISTRY
# ============================================================

INPUT_FILE = "nse_content_feed.json"
OUTPUT_FILE = "nse_final_content_feed.json"

BATCH_SIZE = 3            # Har batch me 3 cards
BATCH_PAUSE_SECONDS = 15  # Har batch ke baad pause

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

# Groq models placed first because Google quota is temporarily exhausted
MODEL_REGISTRY = [
    {"name": "openai/gpt-oss-120b", "provider": "groq"},
    {"name": "openai/gpt-oss-20b", "provider": "groq"},
    {"name": "gemini-3.5-flash-lite", "provider": "google"},
    {"name": "gemini-3.1-flash-lite", "provider": "google"}
]

GROQ_KEYS = [os.environ.get(k, "").strip() for k in ["GROQ_API_KEY", "GROQ_API_KEY2"] if os.environ.get(k, "").strip()]
GOOGLE_KEYS = [os.environ.get(k, "").strip() for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"] if os.environ.get(k, "").strip()]

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys found! Exiting.")
    exit(1)

groq_key_idx = 0
google_key_idx = 0

def fetch_live_web_context(company, symbol, reqs):
    """Reliable live web search across all engines"""
    if not DDGS:
        return ""
    
    query = f"{company} {symbol} screener revenue capacity order book"
    if reqs and len(reqs) > 0:
        query = f"{company} {symbol} {reqs[0]}"

    try:
        results = DDGS().text(query, max_results=3)
        if not results:
            return ""
        snippets = [f"• {r.get('title')}: {r.get('body')}" for r in results]
        return "\n".join(snippets)
    except Exception:
        return ""

# ============================================================
# CALL ENGINES
# ============================================================

def call_groq_analyst(model_name, card, system_instruction, prompt_content):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None, "Groq SDK or Keys missing"

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
                return content.strip(), None
        except Exception as e:
            err = str(e)
            print(f"      [Groq API Error on {model_name} | Key {groq_key_idx}]: {err[:120]}")
            if "429" in err or "rate_limit" in err.lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None, err
            
    return None, "All Groq keys exhausted"

def call_google_analyst(model_name, card, system_instruction, prompt_content):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None, "Google GenAI SDK or Keys missing"

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
                return response.text.strip(), None
            else:
                return None, "Empty response from Gemini"
        except Exception as e:
            err = str(e)
            print(f"      [Google API Error on {model_name} | Key {google_key_idx}]: {err[:120]}")
            if "429" in err or "RESOURCE_EXHAUSTED" in err or "quota" in err.lower():
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None, err
            
    return None, "All Google keys exhausted"

def call_hybrid_analyst(card, system_instruction, prompt_content):
    total = len(MODEL_REGISTRY)
    idx = 0

    while idx < total:
        target = MODEL_REGISTRY[idx]
        m_name = target["name"]
        provider = target["provider"]

        if provider == "groq":
            res, err = call_groq_analyst(m_name, card, system_instruction, prompt_content)
        else:
            res, err = call_google_analyst(m_name, card, system_instruction, prompt_content)

        if res:
            return res

        print(f"   ⚠️ Fail on {m_name} ({provider}). Switching to fallback...")
        idx += 1

    return None

# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def process_deep_feed():
    print("=" * 80)
    print("🧠 STAGE 2: HIGH-AVAILABILITY DEEP CONTEXT ANALYST")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    if not os.path.exists(INPUT_FILE):
        print(f"❌ Input feed file '{INPUT_FILE}' not found.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        feed_data = json.load(f)

    cards = feed_data.get("content_feed", [])
    if not cards:
        print("✅ Content feed empty. No deep analysis pending.")
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
        "Use the provided VERIFIED WEB SEARCH DATA to mathematically contextualize the announcement.\n"
        "Never invent numbers. If baseline figures cannot be confirmed, state clearly: 'Baseline numbers not disclosed or verified.'\n"
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

    total_batches = (len(pending_cards) + BATCH_SIZE - 1) // BATCH_SIZE
    i = 0
    batch_counter = 1
    dispatched = 0

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

            # Live DuckDuckGo web search
            web_context = fetch_live_web_context(company, symbol, reqs)

            prompt_content = f"""
COMPANY: {company} (NSE: {symbol})
EVENT TYPE: {event_type}
HEADLINE: {headline}

VERIFIED FILING SUMMARY:
{summary_text}

VERIFIED WEB SEARCH RESULTS (BASELINE SCALE & FINANCIALS):
{web_context if web_context else "No external web baseline found."}

TASK:
Produce an institutional research note strictly matching this exact layout:

{cat_icon} <b>#{clean_cat_tag} | INSTITUTIONAL NOTE</b>
🏢 <b>{company} (NSE: {symbol})</b>
<b>{headline}</b>
━━━━━━━━━━━━━━━━━━━━━━

🔹 <b>The Event:</b>
↳ [1-2 crisp factual sentences based on the filing summary]

📊 <b>Materiality & Financial Context:</b>
• <b>Scale vs Existing Base:</b> [Explain mathematical scale - % capacity expansion or order size relative to annual turnover using retrieved numbers]
• <b>Financial Relevance:</b> [Estimated contribution to segment revenue, EBITDA margins, or balance sheet impact]
• <b>Strategic Positioning:</b> [Why this matters operationally: customer ramp-up, market share expansion, backward integration, or execution timeline]

🎯 <b>Analyst Watchlist:</b>
↳ [1-2 critical operational checkpoints or concall questions to track]
━━━━━━━━━━━━━━━━━━━━━━
📌 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>
"""

            print(f"  🔍 Researching: {symbol} ({event_type})...")
            final_post = call_hybrid_analyst(card, system_instruction, prompt_content)

            if not final_post:
                final_post = (
                    f"{cat_icon} <b>#{clean_cat_tag}</b>\n"
                    f"🏢 <b>{company}</b>\n<b>{headline}</b>\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
                    f"🔹 <b>Summary:</b>\n↳ {summary_text}\n\n"
                    f"━━━━━━━━━━━━━━━━━━━━━━\n"
                    f'📌 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>'
                )

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

        final_feed["total_posts"] = len(final_feed["content_feed"])
        final_feed["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(final_feed, f, ensure_ascii=False, indent=2)

        i += BATCH_SIZE
        batch_counter += 1

        if i < len(pending_cards):
            print(f"⏳ Cooldown pause of {BATCH_PAUSE_SECONDS}s before next batch...")
            time.sleep(BATCH_PAUSE_SECONDS)

    print("\n" + "=" * 80)
    print(f"✅ STAGE 2 COMPLETE: {dispatched} slim posts saved to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    process_deep_feed()
