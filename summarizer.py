import os
import json
import time
from datetime import datetime, timezone, timedelta
from groq import Groq

# ============================================================
# CONFIGURATION
# ============================================================

INPUT_FILE = "rawnews.json"
OUTPUT_FILE = "finalnews.json"

GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

# High Capacity Model for Zero Rate Limit Errors (20,000 TPM Limit)
MODEL_NAME = "llama-3.1-8b-instant"

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

SYSTEM_PROMPT = """
You are an expert Current Affairs editor for civil services exams (BPSC, SSC CGL, UPSC).
Analyze the title and text, then filter, categorize, and summarize into valid JSON.

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

STRICT REJECTION RULES (CRITICAL):
- OTHER STATES NEWS BLOCK: If the news is specifically about OTHER Indian states (e.g., Uttar Pradesh, Madhya Pradesh, Rajasthan, Delhi, Maharashtra, Punjab, Haryana, Tamil Nadu, Karnataka, etc.) and is NOT a Central/National scheme or decision, set "is_relevant": false.
- Set "is_relevant": false if news is about stock market daily movements, Sensex/Nifty, Rupee fluctuations, local crime, accidents, viral videos, entertainment, gossip, or audio portal listings.
- Output MUST be valid JSON only with keys: "is_relevant", "title", "category", "bullets", "exam_tag".
"""


def trim_content_for_ai(text, max_words=90):
    if not text:
        return ""
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words])
    return text


def call_groq_api(user_prompt, max_retries=3):
    if not client:
        print("❌ Groq Client is not initialized! Check GROQ_API_KEY.")
        return None

    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=MODEL_NAME,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt}
                ],
                response_format={"type": "json_object"},
                temperature=0.2,
                max_tokens=450  # Compact tokens footprint
            )
            return json.loads(response.choices[0].message.content.strip())

        except Exception as e:
            err_msg = str(e).lower()
            if "429" in err_msg or "rate limit" in err_msg or "token" in err_msg:
                wait_time = (attempt + 1) * 8
                print(f"⚠️ Rate/Token limit hit. Pausing {wait_time}s (Attempt {attempt + 1}/{max_retries})...")
                time.sleep(wait_time)
            elif "400" in err_msg or "json_validate_failed" in err_msg:
                print(f"⚠️ JSON Format error on attempt {attempt + 1}. Retrying...")
                time.sleep(1)
            else:
                print(f"⚠️ Groq Error on attempt {attempt + 1}: {e}")
                time.sleep(2)
                
    return None


def summarize_article(item, is_bihar=False):
    title = item.get("title", "")
    content = item.get("content", "")

    # Skip portal indexes/audio archives before making API call
    if "audios:" in title.lower() or "news & current affairs" in title.lower():
        print(f"  ⏭️ SKIPPED (Audio Listing): {title[:45]}...")
        return None

    trimmed_content = trim_content_for_ai(content, max_words=90)

    news_type = "Bihar State News" if is_bihar else "National Current Affairs"
    user_prompt = (
        f"Domain: {news_type}\n"
        f"Title: {title}\n"
        f"Content: {trimmed_content}\n\n"
        "Return strictly valid JSON format."
    )

    parsed = call_groq_api(user_prompt)

    if not parsed:
        print(f"❌ Skipping [{title[:30]}...] due to persistent API limits/failure.")
        return None

    if not parsed.get("is_relevant", True):
        print(f"  ⏭️ SKIPPED (Other State / Irrelevant / Local): {title[:45]}...")
        return None

    assigned_category = parsed.get("category") or ("Bihar Special Affairs" if is_bihar else "National Polity, Judiciary & Governance")
    default_prefix = "🏛️ Bihar Special" if is_bihar else "🎯 National Special"
    exam_tag = parsed.get("exam_tag") or f"{default_prefix} / {assigned_category}"

    return {
        "title": parsed.get("title", title),
        "category": assigned_category,
        "bullets": parsed.get("bullets", [trimmed_content[:150] + "..."]),
        "exam_tag": exam_tag,
        "date": TODAY_DATE
    }


def process_all_news():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ {INPUT_FILE} not found!")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    national_raw = raw_data.get("national_raw_news", [])
    bihar_raw = raw_data.get("bihar_raw_news", [])

    print(f"🚀 Starting High-Throughput AI Summarization [{MODEL_NAME}]...")
    print(f"📦 Raw Inputs -> National: {len(national_raw)} | Bihar: {len(bihar_raw)}")

    national_cards = []
    bihar_cards = []

    # Process National News
    print("\n🇮🇳 Processing National News...")
    nat_idx = 1
    for item in national_raw:
        print(f"[National {nat_idx}/{len(national_raw)}] Summarizing: {item.get('title', '')[:45]}...")
        card_data = summarize_article(item, is_bihar=False)
        
        if card_data:
            formatted_card = {
                "id": f"nat_{nat_idx:02d}",
                "title": card_data["title"],
                "category": card_data["category"],
                "bullets": card_data["bullets"],
                "exam_tag": card_data["exam_tag"],
                "date": card_data["date"]
            }
            national_cards.append(formatted_card)
            nat_idx += 1
            
        time.sleep(1.5)  # Optimal delay for 8b instant model

    # Process Bihar News
    print("\n🏛️ Processing Bihar News...")
    bih_idx = 1
    for item in bihar_raw:
        print(f"[Bihar {bih_idx}/{len(bihar_raw)}] Summarizing: {item.get('title', '')[:45]}...")
        card_data = summarize_article(item, is_bihar=True)

        if card_data:
            formatted_card = {
                "id": f"bih_{bih_idx:02d}",
                "title": card_data["title"],
                "category": card_data["category"],
                "bullets": card_data["bullets"],
                "exam_tag": card_data["exam_tag"],
                "date": card_data["date"]
            }
            bihar_cards.append(formatted_card)
            bih_idx += 1
            
        time.sleep(1.5)

    output_data = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "national_count": len(national_cards),
        "bihar_count": len(bihar_cards),
        "total_count": len(national_cards) + len(bihar_cards),
        "national_news": national_cards,
        "bihar_news": bihar_cards
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Successfully generated '{OUTPUT_FILE}'!")
    print(f"📊 Accepted -> National: {len(national_cards)} | Bihar: {len(bihar_cards)}")
    print("=" * 80)


if __name__ == "__main__":
    process_all_news()
