import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from groq import Groq, APIConnectionError, RateLimitError, APIStatusError

# ============================================================
# EXCLUSIVE "FIRST IN INDIA" SUMMARIZER CONFIGURATION
# ============================================================

INPUT_FILE = "alerts_news.json"
MASTER_FILE = "final_alerts_news.json"  # Full Year Master Archive (Website)
APP_FILE = "app_alerts_news.json"        # Rolling 3-Day Archive (Mobile App)

GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

# Production Models Hierarchy
MODELS_PRIORITY = [
    "openai/gpt-oss-20b",    # Primary: 1000 T/s, 1000 RPM, 250k TPM
    "openai/gpt-oss-120b"    # Fallback: 500 T/s, 1000 RPM, 250k TPM
]

BATCH_SIZE = 3           # Exactly 3 news per batch
BATCH_PAUSE_SECONDS = 30 # 30-second safe cooldown between batches

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

# ============================================================
# STRICT "FIRST IN INDIA" STATIC GK PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are an expert Static GK & National Milestones Analyst for UPSC, BPSC, and Competitive Exams.
Your ONLY objective is to evaluate articles and extract genuine "First in India" (भारत में प्रथम) milestones that create permanent Static GK questions.

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

MANDATORY ACCEPTANCE CRITERIA (Set "is_relevant": true ONLY IF the news is a genuine "FIRST IN INDIA"):
1. India's First infrastructure/tech projects/payment technology (e.g., India's first geothermal plant, first paperless court, first vertical lift bridge, first AI university, first solar-powered village).
2. India's First scientific/space/defence achievements by Govt or Public Bodies (e.g., ISRO, DRDO, CSIR, Indian Navy, IITs).
3. India's First environmental or geographic designations (e.g., India's first dark sky reserve, first biodiversity heritage site).
4. Major public sector or national level "Firsts" that form permanent Static GK for competitive exams.

HARD REJECTION RULES (Set "is_relevant": false for ALL of these):
1. PRIVATE COMMERCIAL PRODUCTS: Private brand launches, private pharmaceutical company drugs (e.g., Zydus, Glenmark), commercial private gadgets, or company product releases.
2. CEREMONIAL & GREETINGS: ISS cosmonaut wishes, Independence Day greetings, speeches, or diplomatic goodwill gestures.
3. GENERAL GOVT REPORTS & INDICES: Routine NITI Aayog reports, rankings, annual budget releases, or regular policy circulars (unless it specifically marks a historic "First in India").
4. MARKET & COMMERCIAL NOISE: Stock market updates, private investments, corporate quarterly profits, or business deals.

FACTUAL BULLET EXTRACTION RULES:
- Focus ONLY on the Static Fact: What is the "First in India" achievement, where is it located, which ministry/agency built it, and what is its specific capacity/significance?
- Write 2 to 3 high-density factual bullet points in English.
- NO filler phrases.

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON array of objects:
[
  {
    "input_id": 1,
    "is_relevant": true,
    "title": "Clean Headline Highlighting the 'First in India' Milestone",
    "category": "EXACT CATEGORY NAME FROM ALLOWED LIST",
    "bullets": [
      "Core Static Fact: What is India's first achievement, location, and statutory/govt agency involved",
      "Specific Parameters: Capacity, target year, outlay, or technical mechanism"
    ],
    "exam_tag": "🏆 First in India / Static GK"
  }
]
"""

current_model_idx = 0

# ============================================================
# DEDUPLICATION & DATE UTILITIES
# ============================================================

def normalize_title(title):
    title = re.sub(r'[^a-zA-Z0-9\s]', '', str(title).lower())
    return set(w for w in title.split() if len(w) > 3)

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

def clean_json_response(raw_text):
    if not raw_text or not raw_text.strip():
        return None

    text = raw_text.strip()
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()

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

def parse_card_date(card):
    ts = card.get("timestamp", 0)
    if ts and isinstance(ts, (int, float)) and ts > 0:
        return datetime.fromtimestamp(ts, tz=IST)
    
    date_str = card.get("date", "")
    if date_str:
        try:
            parsed = datetime.strptime(date_str, "%d %b %Y")
            return parsed.replace(tzinfo=IST)
        except Exception:
            pass
            
    return datetime.now(IST)

# ============================================================
# GROQ API CALL WITH AUTOMATIC FAILOVER
# ============================================================

def call_groq_batch_api(batch_prompt):
    global current_model_idx

    if not client:
        print("❌ Groq Client is not initialized! Check GROQ_API_KEY.")
        return None

    total_models = len(MODELS_PRIORITY)

    while current_model_idx < total_models:
        model_name = MODELS_PRIORITY[current_model_idx]

        for attempt in range(2):
            try:
                response = client.chat.completions.create(
                    model=model_name,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT + "\nCRITICAL: Output ONLY a valid JSON array."},
                        {"role": "user", "content": batch_prompt}
                    ],
                    temperature=0.0,
                    max_tokens=2048
                )

                raw_text = response.choices[0].message.content
                parsed = clean_json_response(raw_text)
                if parsed is not None:
                    return parsed if isinstance(parsed, list) else [parsed]

                print(f"⚠️ [{model_name}] JSON parse retry (Attempt {attempt + 1})...")
                time.sleep(3)

            except RateLimitError:
                print(f"⚠️ [{model_name}] Rate limit 429 hit. Switching to fallback model...")
                current_model_idx += 1
                break
            except (APIConnectionError, APIStatusError) as e:
                print(f"⚠️ [{model_name}] Status error: {e}")
                time.sleep(4)
            except Exception as e:
                print(f"⚠️ [{model_name}] API error: {e}")
                time.sleep(3)

        if current_model_idx < total_models and MODELS_PRIORITY[current_model_idx] != model_name:
            continue
        else:
            current_model_idx += 1

    print("⚠️ All Groq models exhausted. Pausing 60s for quota reset...")
    time.sleep(60)
    current_model_idx = 0
    return None

# ============================================================
# BATCH PIPELINE PROCESSING
# ============================================================

def process_alerts_pipeline():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Input file '{INPUT_FILE}' not found! Run alerts_scraper.py first.")
        return

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

    if isinstance(raw_payload, list):
        articles = raw_payload
    elif isinstance(raw_payload, dict):
        articles = raw_payload.get("articles", raw_payload.get("alert_news", []))
    else:
        articles = []

    total_articles = len(articles)
    print(f"🚀 Starting 'First in India' AI Batch Summarizer [{MODELS_PRIORITY[0]}]")
    print(f"📦 Input Records: {total_articles} | Batch Size: {BATCH_SIZE} | Pause: {BATCH_PAUSE_SECONDS}s\n")

    new_approved_cards = []
    i = 0
    batch_counter = 1
    total_batches = (total_articles + BATCH_SIZE - 1) // BATCH_SIZE

    while i < total_articles:
        batch = articles[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            batch_payload.append({
                "input_id": idx,
                "feed_name": itm.get("feed_name", ""),
                "title": itm.get("title", ""),
                "content": str(itm.get("content", ""))[:2500],
                "url": itm.get("url", "")
            })

        prompt_str = f"Evaluate these {len(batch)} articles for 'First in India' milestones into JSON array:\n" + json.dumps(batch_payload, ensure_ascii=False)

        batch_result = call_groq_batch_api(prompt_str)

        if not batch_result:
            print(f"🔄 Retrying Batch {batch_counter}...")
            time.sleep(10)
            continue

        for res in batch_result:
            if not isinstance(res, dict):
                continue
            
            if not res.get("is_relevant", False):
                raw_t = str(res.get("title", ""))
                print(f"  ⏭️ REJECTED (Not First in India): {raw_t[:50]}...")
                continue

            c_title = res.get("title") or "First in India Milestone"
            if is_duplicate_story(c_title, seen_titles):
                print(f"  🧹 DROPPED DUPLICATE: {c_title[:45]}...")
                continue

            bullets = res.get("bullets", [])
            if not isinstance(bullets, list) or len(bullets) == 0:
                continue

            seen_titles.append(c_title)
            current_dt = datetime.now(IST)

            # Match URL from input batch
            matched_url = ""
            input_id = res.get("input_id", 1)
            if 1 <= input_id <= len(batch):
                matched_url = batch[input_id - 1].get("url", "")

            card_data = {
                "title": c_title,
                "category": res.get("category", "Space, Science & Technology"),
                "bullets": bullets,
                "exam_tag": res.get("exam_tag", "🏆 First in India / Static GK"),
                "date": TODAY_DATE,
                "timestamp": int(current_dt.timestamp()),
                "url": matched_url
            }

            new_approved_cards.append(card_data)
            print(f"  🏆 PASSED (First in India): {c_title[:50]}...")

        i += BATCH_SIZE
        batch_counter += 1

        if i < total_articles:
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s for safe rate pacing...")
            time.sleep(BATCH_PAUSE_SECONDS)

    # 1. Combine New Approved Cards + Existing Master Cards (Newest on top)
    combined_master = new_approved_cards + existing_master_cards

    for idx, card in enumerate(combined_master, 1):
        card["id"] = f"first_in_india_{idx:03d}"

    # 2. Save Master File for Website
    master_output_data = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(combined_master),
        "alert_news": combined_master
    }

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Master Website JSON '{MASTER_FILE}' updated ({len(combined_master)} total records)!")

    # 3. Robust 3-Day Filtering for App
    now_dt = datetime.now(IST)
    three_days_ago_dt = now_dt - timedelta(days=3)

    app_cards = []
    for card in combined_master:
        card_dt = parse_card_date(card)
        if card_dt >= three_days_ago_dt:
            app_cards.append(card)

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
