import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from groq import Groq

# ============================================================
# CONFIGURATION
# ============================================================

INPUT_FILE = "alerts_news.json"
OUTPUT_FILE = "final_alerts_news.json"

GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODEL_NAME = "llama-3.1-8b-instant"

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

# SMART & ADAPTIVE SYSTEM PROMPT
SYSTEM_PROMPT = """
You are an expert Current Affairs Analyst for competitive civil services exams (UPSC, BPSC, SSC CGL).
Your task is to analyze raw news articles and intelligently extract high-value exam facts into structured JSON.

NEWS EVALUATION & FILTERING:
- Set "is_relevant": true ONLY IF the article contains substantial administrative, technological, national, state, or policy significance.
- Set "is_relevant": false for daily stock market movements, routine local crimes, corporate quarterly profits, or pure marketing PR.

SMART BULLET EXTRACTION INSTRUCTIONS:
- Analyze the full content and identify all critical exam facts: entities, ministries, locations, target years, budgets, ISO/statutory certifications, technical mechanisms, and underlying significance.
- Dynamically extract these facts into concise, high-density bullet points in Hinglish/English.
- Adapt the number of bullets (typically 2 to 4) naturally based on content depth—never pad with fluff and never omit a crucial fact.
- Every bullet point must be purely fact-driven. Avoid generic opinions or filler lines like "Yeh ek accha kadam hai".

JSON OUTPUT STRUCTURE ONLY:
{
  "is_relevant": true or false,
  "title": "Crisp, Factual Headline in English",
  "category": "Science & Tech OR Infrastructure & Energy OR Govt Schemes & Policy OR Environment & Climate OR Awards & Milestones",
  "bullets": [
    "Fact-packed point covering core event, key agency/ministry, and location",
    "Fact-packed point covering specific figures, targets, or technical parameters",
    "Fact-packed point covering statutory background, implications, or policy scope"
  ],
  "exam_tag": "🎯 Special Affairs / National Milestones"
}
"""

# ============================================================
# DEDUPLICATION HELPERS
# ============================================================

def normalize_title(title):
    title = re.sub(r'[^a-zA-Z0-9\s]', '', title.lower())
    words = set(w for w in title.split() if len(w) > 3)
    return words

def is_duplicate_story(new_title, existing_titles, threshold=0.55):
    new_words = normalize_title(new_title)
    if not new_words:
        return False

    for exist_title in existing_titles:
        exist_words = normalize_title(exist_title)
        if not exist_words:
            continue
        
        intersection = new_words.intersection(exist_words)
        union = new_words.union(exist_words)
        similarity = len(intersection) / len(union) if union else 0

        if similarity >= threshold:
            return True

    return False

# ============================================================
# API CALL & PROCESSING
# ============================================================

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
                temperature=0.1,
                max_tokens=600
            )
            return json.loads(response.choices[0].message.content.strip())

        except Exception as e:
            err_msg = str(e).lower()
            if "429" in err_msg or "rate limit" in err_msg or "token" in err_msg:
                wait_time = (attempt + 1) * 8
                print(f"⚠️ Rate/Token limit hit. Pausing {wait_time}s (Attempt {attempt + 1}/{max_retries})...")
                time.sleep(wait_time)
            else:
                print(f"⚠️ Groq Error on attempt {attempt + 1}: {e}")
                time.sleep(2)
                
    return None

def summarize_alert_item(item):
    feed_name = item.get("feed_name", "")
    title = item.get("title", "")
    content = item.get("content", "")

    user_prompt = (
        f"Feed Context: {feed_name}\n"
        f"Article Title: {title}\n"
        f"Article Content: {content[:2500]}\n\n"
        "Extract all key exam-relevant details smartly into JSON."
    )

    parsed = call_groq_api(user_prompt)

    if not parsed:
        print(f"❌ Skipping [{title[:30]}...] due to API failure.")
        return None

    if not parsed.get("is_relevant", True):
        print(f"  ⏭️ SKIPPED (Irrelevant / Low Value): {title[:45]}...")
        return None

    bullets = parsed.get("bullets", [])
    if not isinstance(bullets, list) or len(bullets) == 0:
        print(f"  ⚠️ SKIPPED (No valid bullets extracted): {title[:45]}...")
        return None

    return {
        "title": parsed.get("title", title),
        "category": parsed.get("category", "Special Current Affairs"),
        "bullets": bullets,
        "exam_tag": parsed.get("exam_tag", "🎯 Special Affairs / National Milestones"),
        "date": TODAY_DATE,
        "url": item.get("url", "")
    }

def process_all_alerts():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ {INPUT_FILE} not found!")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_payload = json.load(f)

    articles = raw_payload.get("articles", [])
    print(f"🚀 Starting AI Summarization for Google Alerts [{MODEL_NAME}]...")
    print(f"📦 Total Input Articles: {len(articles)}")

    final_cards = []
    seen_titles = []

    for idx, item in enumerate(articles, 1):
        raw_title = item.get("title", "")
        print(f"[{idx}/{len(articles)}] Summarizing: {raw_title[:45]}...")

        card_data = summarize_alert_item(item)

        if card_data:
            c_title = card_data["title"]
            if not is_duplicate_story(c_title, seen_titles):
                seen_titles.append(c_title)
                formatted_card = {
                    "id": f"alert_{len(final_cards) + 1:02d}",
                    "title": card_data["title"],
                    "category": card_data["category"],
                    "bullets": card_data["bullets"],
                    "exam_tag": card_data["exam_tag"],
                    "date": card_data["date"],
                    "url": card_data["url"]
                }
                final_cards.append(formatted_card)
            else:
                print(f"  🧹 DROPPED DUPLICATE: {c_title[:45]}...")

        time.sleep(1.5)

    output_data = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(final_cards),
        "alert_news": final_cards
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Successfully generated '{OUTPUT_FILE}'!")
    print(f"📊 Accepted Summary Cards: {len(final_cards)}")
    print("=" * 80)

if __name__ == "__main__":
    process_all_alerts()
