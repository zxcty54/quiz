import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
from groq import Groq

# ============================================================
# EXCLUSIVE "FIRST IN INDIA" SUMMARIZER CONFIGURATION
# ============================================================

INPUT_FILE = "alerts_news.json"
MASTER_FILE = "final_alerts_news.json"  # Full Year Master Archive (Website)
APP_FILE = "app_alerts_news.json"        # Rolling 3-Day Archive (Mobile App)

GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODEL_NAME = "llama-3.1-8b-instant"
MAX_WORKERS = 2  # Exactly 2 parallel threads for Groq RPM safety

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

# ============================================================
# STRICT "FIRST IN INDIA" STATIC GK PROMPT WITH EXACT CATEGORIES
# ============================================================

SYSTEM_PROMPT = """
You are an expert Static GK & National Milestones Analyst for UPSC, BPSC, and Competitive Exams.
Your ONLY objective is to extract genuine "First in India" (भारत में प्रथम) milestones that create permanent Static GK questions.

STRICT ALLOWED CATEGORIES (Choose EXACTLY ONE from this list for "category"):
1. Space, Science & Technology
2. Environment, Climate & Sustainability
3. Governance, Judiciary & Public Administration
4. Internal Security & Emergency Services
5. Aviation & Transport
6. Banking, Finance & FinTech
7. Maritime, Shipping & Defence Manufacturing
8. Education & Research
9. Health & Medical Sciences
10. Agriculture, Fisheries & Biodiversity
11. Sports & Gaming

✅ MANDATORY ACCEPTANCE CRITERIA (Set "is_relevant": true ONLY IF the news is a genuine "FIRST IN INDIA"):
1. India's First infrastructure/tech projects (e.g., India's first geothermal plant, first paperless court, first vertical lift bridge, first AI university, first solar-powered village).
2. India's First scientific/space/defence achievements by Govt or Public Bodies (e.g., ISRO, DRDO, CSIR, Indian Navy, IITs).
3. India's First environmental or geographic designations (e.g., India's first dark sky reserve, first biodiversity heritage site).
4. Major public sector or national level "Firsts" that form permanent Static GK for competitive exams.

❌ HARD REJECTION RULES (Set "is_relevant": false for ALL of these):
1. PRIVATE COMMERCIAL PRODUCTS: Private brand launches, private pharmaceutical company drugs (e.g., Zydus, Glenmark), commercial private gadgets, or company product releases.
2. CEREMONIAL & GREETINGS: ISS cosmonaut wishes, Independence Day greetings, speeches, or diplomatic goodwill gestures.
3. GENERAL GOVT REPORTS & INDICES: Routine NITI Aayog reports, rankings, annual budget releases, or regular policy circulars (unless it specifically marks a historic "First in India").
4. MARKET & COMMERCIAL NOISE: Stock market updates, private investments, corporate quarterly profits, or business deals.

FACTUAL BULLET EXTRACTION RULES:
- Focus ONLY on the Static Fact: What is the "First in India" achievement, where is it located, which ministry/agency built it, and what is its specific capacity/significance?
- Write 2 to 3 high-density factual bullet points in Hinglish/English.
- NO filler phrases (e.g., DO NOT write "Yeh ek mahatvapurna uplabdhi hai").

JSON OUTPUT FORMAT ONLY:
{
  "is_relevant": true or false,
  "title": "Clean Headline Highlighting the 'First in India' Milestone",
  "category": "EXACT CATEGORY NAME FROM ALLOWED LIST",
  "bullets": [
    "Core Static Fact: What is India's first achievement, location, and statutory/govt agency involved",
    "Specific Parameters: Capacity, target year, outlay, or technical mechanism"
  ],
  "exam_tag": "🏆 First in India / Static GK"
}
"""

# ============================================================
# DEDUPLICATION & THREAD SAFETY
# ============================================================

lock = Lock()

def normalize_title(title):
    title = re.sub(r'[^a-zA-Z0-9\s]', '', title.lower())
    words = set(w for w in title.split() if len(w) > 3)
    return words

def is_duplicate_story(new_title, existing_titles, threshold=0.50):
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
# GROQ API INTEGRATION
# ============================================================

def call_groq_api(user_prompt, max_retries=3):
    if not client:
        print("❌ Groq Client is not initialized! Set GROQ_API_KEY environment variable.")
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
                temperature=0.0,  # Zero randomness for strict filtering
                max_tokens=600
            )
            return json.loads(response.choices[0].message.content.strip())

        except Exception as e:
            err_msg = str(e).lower()
            if "429" in err_msg or "rate limit" in err_msg or "token" in err_msg:
                wait_time = (attempt + 1) * 6
                print(f"⚠️ Rate limit encountered. Pausing {wait_time}s (Attempt {attempt + 1}/{max_retries})...")
                time.sleep(wait_time)
            else:
                print(f"⚠️ Groq API Error: {e}")
                time.sleep(2)
                
    return None

def summarize_alert_item(item):
    feed_name = item.get("feed_name", "")
    title = item.get("title", "")
    content = item.get("content", "")

    user_prompt = (
        f"Alert Feed: {feed_name}\n"
        f"Article Title: {title}\n"
        f"Article Content: {content[:2500]}\n\n"
        "Evaluate if this is a genuine 'First in India' Static GK milestone. If yes, extract static facts into JSON."
    )

    parsed = call_groq_api(user_prompt)

    if not parsed:
        return None

    if not parsed.get("is_relevant", False):
        print(f"  ⏭️ REJECTED (Not a genuine First in India Milestone): {title[:50]}...")
        return None

    bullets = parsed.get("bullets", [])
    if not isinstance(bullets, list) or len(bullets) == 0:
        return None

    current_dt = datetime.now(IST)

    return {
        "title": parsed.get("title", title),
        "category": parsed.get("category", "Space, Science & Technology"),
        "bullets": bullets,
        "exam_tag": parsed.get("exam_tag", "🏆 First in India / Static GK"),
        "date": TODAY_DATE,
        "timestamp": int(current_dt.timestamp()),  # Exact IST Timestamp
        "url": item.get("url", "")
    }

# Safe date parser for older master cards
def parse_card_date(card):
    # 1. Try direct timestamp if exists and valid
    ts = card.get("timestamp", 0)
    if ts and isinstance(ts, (int, float)) and ts > 0:
        return datetime.fromtimestamp(ts, tz=IST)
    
    # 2. Try parsing string date format e.g., "11 Aug 2026"
    date_str = card.get("date", "")
    if date_str:
        try:
            parsed = datetime.strptime(date_str, "%d %b %Y")
            return parsed.replace(tzinfo=IST)
        except Exception:
            pass
            
    # Fallback to current time if unparseable
    return datetime.now(IST)

# ============================================================
# PARALLEL PIPELINE EXECUTOR
# ============================================================

def process_alerts_pipeline():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Input file '{INPUT_FILE}' not found! Run alerts_scraper.py first.")
        return

    # 1. Load Master Existing Data (for Append & Deduplication)
    existing_master_cards = []
    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                existing_master_cards = json.load(f).get("alert_news", [])
        except Exception:
            existing_master_cards = []

    seen_titles = [c.get("title", "") for c in existing_master_cards]

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_payload = json.load(f)

    articles = raw_payload.get("articles", [])
    print(f"🚀 Starting 'First in India' AI Summarizer [{MODEL_NAME}]")
    print(f"📦 Input Records: {len(articles)} | Worker Threads: {MAX_WORKERS}\n")

    new_approved_cards = []

    def worker(item):
        raw_title = item.get("title", "")
        print(f"⚡ Evaluating: {raw_title[:50]}...")
        card_data = summarize_alert_item(item)

        if card_data:
            c_title = card_data["title"]
            
            with lock:
                if not is_duplicate_story(c_title, seen_titles):
                    seen_titles.append(c_title)
                    new_approved_cards.append(card_data)
                    print(f"  🏆 PASSED (First in India): {c_title[:50]}...")
                else:
                    print(f"  🧹 DROPPED DUPLICATE: {c_title[:45]}...")

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(worker, item) for item in articles]
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"⚠️ Thread Execution Error: {e}")

    # 2. Combine New Approved Cards + Existing Master Cards (Newest on top)
    combined_master = new_approved_cards + existing_master_cards

    # Re-assign clean IDs
    for idx, card in enumerate(combined_master, 1):
        card["id"] = f"first_in_india_{idx:03d}"

    # 3. Save Master File for Website
    master_output_data = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(combined_master),
        "alert_news": combined_master
    }

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Master Website JSON '{MASTER_FILE}' updated ({len(combined_master)} total records)!")

    # 4. Robust 3-Day Filtering for App
    now_dt = datetime.now(IST)
    three_days_ago_dt = now_dt - timedelta(days=3)

    app_cards = []
    for card in combined_master:
        card_dt = parse_card_date(card)
        if card_dt >= three_days_ago_dt:
            app_cards.append(card)

    # Save Rolling 3-Day File for App
    app_output_data = {
        "generated_at": now_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(app_cards),
        "alert_news": app_cards
    }

    with open(APP_FILE, "w", encoding="utf-8") as f:
        json.dump(app_output_data, f, ensure_ascii=False, indent=2)

    print(f"📱 App JSON '{APP_FILE}' updated with rolling 3-day window ({len(app_cards)} active records)!")
    print("=" * 80)

if __name__ == "__main__":
    process_alerts_pipeline()
