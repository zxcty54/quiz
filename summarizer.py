import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION
# ============================================================

INPUT_FILE = "rawnews.json"
OUTPUT_FILE = "finalnews.json"
ARCHIVE_FILE = "all_current_affairs.json"

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

# Updated active model
MODEL_NAME = "gemini-3.6-flash"
BATCH_SIZE = 5

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

SYSTEM_PROMPT = """
You are an expert Current Affairs editor for civil services exams (BPSC, SSC CGL, UPSC).
You will receive a JSON list of news articles. Filter, categorize, and summarize EACH valid article.

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

STRICT REJECTION RULES: Set "is_relevant": false for:
- Corporate fraud/bribery court trials (e.g., Adani court cases).
- Foreign immigration/visa rules (unless bilateral Indian treaty).
- Local protests, student strikes, political party Bandhs, fact-checks, routine patrol vessels, UPI volume stats.
- State-specific news of OTHER states (UP, MP, Delhi, Maharashtra, etc.) unless it is a Central policy.
- Stock market movements, Sensex/Nifty, routine local crime, entertainment gossip.

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON array of objects:
[
  {
    "input_id": 1,
    "is_relevant": true,
    "title": "Crisp headline in English",
    "category": "Exact matched category name",
    "bullets": ["Point 1 (Facts/Ministry/Date)", "Point 2", "Point 3"],
    "exam_tag": "Relevant Exam Tag"
  }
]
"""

# ============================================================
# DEDUPLICATION & UTILITY HELPERS
# ============================================================

def normalize_title(title):
    # Common words jo match count ko distract karte hain unhe filter karein
    stop_words = {"india", "indian", "union", "national", "state", "minister", "news", "under", "with", "from"}
    title = re.sub(r'[^a-zA-Z0-9\s]', '', str(title).lower())
    return set(w for w in title.split() if len(w) > 3 and w not in stop_words)

def is_duplicate_story(new_title, existing_titles, threshold=0.42):
    """Checks if the same news story has already been accepted"""
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

        # Agar 3+ core technical words same hain ya Jaccard similarity >= 0.42 hai
        if similarity >= threshold or len(intersection) >= 3:
            return True

    return False


def is_junk_article(title):
    t_lower = str(title).lower()
    junk_phrases = [
        "skip to main content", "accessibility options", "screen reader access",
        "home", "search", "audios: news", "translation disclaimer"
    ]
    return any(phrase in t_lower for phrase in junk_phrases)


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


def call_gemini_api(batch_prompt, max_retries=3):
    if not client:
        print("❌ Gemini Client is not initialized! Check GOOGLE_API_KEY.")
        return None

    for attempt in range(max_retries):
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
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

            print(f"⚠️ JSON Parse retry on attempt {attempt + 1}...")
            time.sleep(2)

        except Exception as e:
            print(f"⚠️ Gemini API Error on attempt {attempt + 1}: {e}")
            time.sleep(3)

    return None


def process_news_batches(news_list, is_bihar=False):
    valid_items = []
    for item in news_list:
        title = item.get("title", "")
        if not is_junk_article(title):
            valid_items.append(item)
        else:
            print(f"  ⏭️ SKIPPED (Junk/Navigation): {title[:40]}...")

    domain = "Bihar State News" if is_bihar else "National Current Affairs"
    total_valid = len(valid_items)
    cards = []
    seen_titles = []

    print(f"📦 Filtered {total_valid} valid articles into batches of {BATCH_SIZE}...")

    for i in range(0, total_valid, BATCH_SIZE):
        batch = valid_items[i : i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (total_valid + BATCH_SIZE - 1) // BATCH_SIZE

        print(f"\n⚡ Processing Batch {batch_num}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            content_words = str(itm.get("content", "")).split()
            trimmed = " ".join(content_words[:250]) if len(content_words) > 250 else itm.get("content", "")
            batch_payload.append({
                "input_id": idx,
                "domain": domain,
                "title": itm.get("title", ""),
                "content": trimmed
            })

        prompt_str = f"Process these {len(batch)} articles into JSON array:\n" + json.dumps(batch_payload, ensure_ascii=False)

        batch_result = call_gemini_api(prompt_str)

        if not batch_result:
            print(f"❌ Batch {batch_num} failed.")
            continue

        for res in batch_result:
            if not isinstance(res, dict):
                continue
            if not res.get("is_relevant", True):
                print(f"  ⏭️ SKIPPED (Irrelevant): {str(res.get('title', ''))[:40]}...")
                continue

            c_title = res.get("title") or "Current Affairs Update"
            if is_duplicate_story(c_title, seen_titles):
                print(f"  🧹 DROPPED DUPLICATE: {c_title[:40]}...")
                continue

            seen_titles.append(c_title)
            assigned_category = res.get("category") or ("Bihar Special Affairs" if is_bihar else "National Polity, Judiciary & Governance")
            default_prefix = "🏛️ Bihar Special" if is_bihar else "🎯 National Special"
            exam_tag = res.get("exam_tag") or f"{default_prefix} / {assigned_category}"

            bullets = res.get("bullets", [])
            if not isinstance(bullets, list) or len(bullets) == 0:
                bullets = [f"Key update regarding {c_title[:60]}."]

            prefix = "bih" if is_bihar else "nat"
            card = {
                "id": f"{prefix}_{len(cards) + 1:02d}",
                "title": c_title,
                "category": assigned_category,
                "bullets": bullets,
                "exam_tag": exam_tag,
                "date": TODAY_DATE
            }
            cards.append(card)
            print(f"  ✅ Added: {c_title[:40]} ({len(bullets)} bullets)")

        time.sleep(1.0)

    return cards


def process_all_news():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ {INPUT_FILE} not found!")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    national_raw = raw_data.get("national_raw_news", [])
    bihar_raw = raw_data.get("bihar_raw_news", [])

    start_time = time.time()
    print(f"🚀 Starting High-Capacity Gemini Batch Summarizer [{MODEL_NAME}]...")
    print(f"📦 Raw Inputs -> National: {len(national_raw)} | Bihar: {len(bihar_raw)}")

    # 1. Process National
    print("\n" + "=" * 50 + "\n🇮🇳 PROCESSING NATIONAL NEWS\n" + "=" * 50)
    national_cards = process_news_batches(national_raw, is_bihar=False)

    # 2. Process Bihar
    print("\n" + "=" * 50 + "\n🏛️ PROCESSING BIHAR NEWS\n" + "=" * 50)
    bihar_cards = process_news_batches(bihar_raw, is_bihar=True)

    # 3. Save finalnews.json
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

    print(f"\n💾 Daily summary successfully saved to '{OUTPUT_FILE}'!")

    # 4. Save master archive all_current_affairs.json
    master_archive = {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_national": 0,
        "total_bihar": 0,
        "total_count": 0,
        "national_news": [],
        "bihar_news": []
    }

    if os.path.exists(ARCHIVE_FILE):
        try:
            with open(ARCHIVE_FILE, "r", encoding="utf-8") as f:
                master_archive = json.load(f)
        except Exception:
            pass

    existing_nat = master_archive.get("national_news", [])
    existing_bih = master_archive.get("bihar_news", [])

    existing_nat_titles = {item.get("title", "").strip().lower() for item in existing_nat}
    existing_bih_titles = {item.get("title", "").strip().lower() for item in existing_bih}

    for item in national_cards:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_nat_titles:
            existing_nat.insert(0, item)
            existing_nat_titles.add(t_clean)

    for item in bihar_cards:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_bih_titles:
            existing_bih.insert(0, item)
            existing_bih_titles.add(t_clean)

    for idx, item in enumerate(existing_nat, 1):
        item["id"] = f"nat_{idx:03d}"

    for idx, item in enumerate(existing_bih, 1):
        item["id"] = f"bih_{idx:03d}"

    master_archive["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")
    master_archive["national_news"] = existing_nat
    master_archive["bihar_news"] = existing_bih
    master_archive["total_national"] = len(existing_nat)
    master_archive["total_bihar"] = len(existing_bih)
    master_archive["total_count"] = len(existing_nat) + len(existing_bih)

    with open(ARCHIVE_FILE, "w", encoding="utf-8") as f:
        json.dump(master_archive, f, ensure_ascii=False, indent=2)

    elapsed = round(time.time() - start_time, 1)
    print("\n" + "=" * 80)
    print(f"⚡ COMPLETED IN {elapsed}s (~{round(elapsed/60, 1)} min)!")
    print(f"📊 Saved Today -> National: {len(national_cards)} | Bihar: {len(bihar_cards)}")
    print("=" * 80)


if __name__ == "__main__":
    process_all_news()
