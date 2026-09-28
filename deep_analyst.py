import os
import json
import time
from datetime import datetime, timezone, timedelta

# Fallback web search for non-Google models
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

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

# Active Google Models with Search Grounding + Groq Fallback
MODEL_REGISTRY = [
    {"name": "gemini-2.5-flash", "provider": "google"},
    {"name": "gemini-2.5-flash-lite", "provider": "google"},
    {"name": "gemini-2.5-pro", "provider": "google"},
    {"name": "gemini-3.1-flash-lite", "provider": "google"},
    {"name": "openai/gpt-oss-120b", "provider": "groq"}
]

GROQ_KEYS = [os.environ.get(k).strip() for k in ["GROQ_API_KEY", "GROQ_API_KEY2"] if os.environ.get(k)]
GOOGLE_KEYS = [os.environ.get(k).strip() for k in ["GOOGLE_API_KEY", "GOOGLE_API_KEY2", "GEMINI_API_KEY"] if os.environ.get(k)]

if not GROQ_KEYS and not GOOGLE_KEYS:
    print("❌ FATAL: No API keys found! Exiting.")
    exit(1)

groq_key_idx = 0
google_key_idx = 0
current_model_idx = 0

def get_web_search_context(query, max_results=3):
    """Fallback search function for Groq using DuckDuckGo"""
    if not DDGS:
        return ""
    try:
        results = DDGS().text(query, max_results=max_results)
        snippets = [f"• {r.get('title')}: {r.get('body')}" for r in results]
        return "\n".join(snippets)
    except Exception:
        return ""

# ============================================================
# CALL ENGINES WITH SEARCH GROUNDING & FALLBACK
# ============================================================

def call_google_analyst(model_name, card, system_instruction, prompt_content):
    global google_key_idx
    if not genai or not GOOGLE_KEYS:
        return None, "Google GenAI missing"

    for _ in range(len(GOOGLE_KEYS)):
        try:
            client = genai.Client(api_key=GOOGLE_KEYS[google_key_idx])
            response = client.models.generate_content(
                model=model_name,
                contents=f"{system_instruction}\n\n{prompt_content}",
                config=types.GenerateContentConfig(
                    tools=[{"google_search": {}}],
                    temperature=0.1
                )
            )
            if response.text and response.text.strip():
                return response.text.strip(), None
        except Exception as e:
            err = str(e)
            if "429" in err or "RESOURCE_EXHAUSTED" in err:
                google_key_idx = (google_key_idx + 1) % len(GOOGLE_KEYS)
                time.sleep(2)
                continue
            return None, err
    return None, "Google keys exhausted"

def call_groq_analyst(model_name, card, system_instruction, prompt_content):
    global groq_key_idx
    if not Groq or not GROQ_KEYS:
        return None, "Groq missing"

    # Fetch real web context for Groq
    symbol = card.get("symbol", "")
    reqs = card.get("research_requirements", [])
    search_queries = f"{symbol} share {reqs[0]}" if reqs else f"{symbol} latest revenue and capacity"
    web_snippets = get_web_search_context(search_queries)

    enhanced_prompt = f"{prompt_content}\n\nVERIFIED WEB SEARCH RESULTS (GROUND TRUTH):\n{web_snippets}"

    for _ in range(len(GROQ_KEYS)):
        try:
            client = Groq(api_key=GROQ_KEYS[groq_key_idx])
            completion = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_instruction},
                    {"role": "user", "content": enhanced_prompt}
                ],
                temperature=0.1
            )
            content = completion.choices[0].message.content
            if content and content.strip():
                return content.strip(), None
        except Exception as e:
            err = str(e)
            if "429" in err or "rate_limit" in err.lower():
                groq_key_idx = (groq_key_idx + 1) % len(GROQ_KEYS)
                time.sleep(2)
                continue
            return None, err
    return None, "Groq keys exhausted"

def call_hybrid_analyst(card, system_instruction, prompt_content):
    global current_model_idx
    total = len(MODEL_REGISTRY)

    while current_model_idx < total:
        target = MODEL_REGISTRY[current_model_idx]
        m_name = target["name"]
        provider = target["provider"]

        if provider == "google":
            res, err = call_google_analyst(m_name, card, system_instruction, prompt_content)
        else:
            res, err = call_groq_analyst(m_name, card, system_instruction, prompt_content)

        if res:
            return res

        print(f"   ⚠️ Fail on {m_name} ({provider}). Switching to fallback model...")
        current_model_idx += 1

    time.sleep(20)
    current_model_idx = 0
    return None

# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def process_deep_feed():
    print("=" * 80)
    print("🧠 STAGE 2: MULTI-MODEL DEEP CONTEXT ANALYST (GOOGLE SEARCH)")
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

    system_instruction = """
You are a senior institutional equity research editor.
Your job is to analyze corporate announcements by contextualizing them against the company's existing business scale.
Do not invent figures. If baseline capacity or financials cannot be confirmed via search, state clearly: 'Baseline numbers not disclosed or verified.'
Output strictly Telegram-compatible HTML tags: <b>, <i>, <a>, <code>. Do not use Markdown asterisks (*).
"""

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
    for card in pending_cards:
        c_hash = card.get("hash")
        symbol = card.get("symbol", "")
        company = card.get("company_name", sym)
        event_type = card.get("event_type", "CORPORATE_UPDATE")
        headline = card.get("headline", "")
        summary_text = card.get("summary", "")
        reqs = card.get("research_requirements", [])
        pdf_link = card.get("pdf_link", "")

        clean_cat_tag = event_type.upper().replace(" ", "_")
        cat_icon = category_icons.get(clean_cat_tag, "⚡")
        reqs_list = "\n".join([f"- {r}" for r in reqs]) if reqs else "- Latest annual revenue, segment scale, and debt profile"

        prompt_content = f"""
COMPANY: {company} (NSE: {symbol})
EVENT TYPE: {event_type}
HEADLINE: {headline}

VERIFIED FILING SUMMARY:
{summary_text}

TARGET SEARCH REQUIREMENTS:
{reqs_list}

TASK:
1. Search/ground the target requirements to verify {company}'s baseline scale.
2. Produce an institutional research post adhering to this exact format:

{cat_icon} <b>#{clean_cat_tag} | INSTITUTIONAL NOTE</b>
🏢 <b>{company} (NSE: {sym})</b>
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

        print(f"\n🔍 Synthesizing deep analysis for: {sym} ({event_type})...")
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

        final_card = dict(card)
        final_card["telegram_post"] = final_post
        final_card["deep_analyzed_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")

        final_feed["content_feed"].insert(0, final_card)
        existing_hashes.add(c_hash)
        dispatched += 1

        time.sleep(4)

    final_feed["total_posts"] = len(final_feed["content_feed"])
    final_feed["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(final_feed, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"✅ STAGE 2 COMPLETE: {dispatched} posts analyzed and saved to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    process_deep_feed()
