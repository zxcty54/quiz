import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from google import genai
from google.genai import types

# ============================================================
# CONFIGURATION & CLEAN-SLATE PACING
# ============================================================

INPUT_FILE = "rawnews.json"
OUTPUT_FILE = "finalnews.json"          # Rolling 24-Hours / Daily News
ARCHIVE_FILE = "all_current_affairs.json" # Full Master Archive

API_KEY = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
client = genai.Client(api_key=API_KEY) if API_KEY else None

# Active Multi-Model Hierarchy (High RPD first)
MODEL_REGISTRY = [
    "gemini-3.6-flash",  # 500 RPD / 15 RPM (Primary)
    "gemini-3.5-flash-lite",  # 500 RPD / 15 RPM (Fallback 1)
    "gemini-3.1-flash-lite",       # 20 RPD / 5 RPM (Fallback 2)
    "gemini-3.7-flash",       # 20 RPD / 5 RPM (Fallback 3)
    "gemini-3-flash"          # Backup Flash
]

# 5 full news per batch
BATCH_SIZE = 4
BATCH_PAUSE_SECONDS = 30

IST = timezone(timedelta(hours=5, minutes=30))
TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")

SYSTEM_PROMPT = """
You are an expert Current Affairs editor for civil services exams (BPSC, SSC CGL, UPSC).
You will receive a JSON list of news articles with their FULL original text.
Extract key factual data (ministries, committees, dates, statistics, acts, targets) and summarize EACH valid article.

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
- IMD weather/cyclone routine forecasts and warnings.
-Traffic news,NTA,UGC,Indian Information Service (IIS), Indian Statistical Service (ISS),Employment growth.
-All India Radio,Startup,Prashant Kishor,Bihar School Examination Board,bsed,stet,ctet

OUTPUT FORMAT REQUIREMENTS:
Return strictly a valid JSON array of objects:
[
  {
    "input_id": 1,
    "is_relevant": true,
    "title": "Crisp headline in English",
    "category": "Exact matched category name",
    "bullets": [
      "Point 1 with exact facts, figures, dates or ministry",
      "Point 2 with core context and impact",
      "Point 3 with background or targets"
    ],
    "exam_tag": "Relevant Exam Tag"
  }
]
"""

current_model_idx = 0

# ============================================================
# DEDUPLICATION & UTILITY HELPERS
# ============================================================

def normalize_title(title):
    stop_words = {"india", "indian", "union", "national", "state", "minister", "news", "under", "with", "from", "launches", "begins"}
    title = re.sub(r'[^a-zA-Z0-9\s]', '', str(title).lower())
    return set(w for w in title.split() if len(w) > 3 and w not in stop_words)


def is_duplicate_story(new_title, existing_titles, threshold=0.42):
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


def parse_card_datetime(card):
    """Safely extracts datetime for 24-hour retention checking"""
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


def call_gemini_clean_slate_api(batch_prompt):
    global current_model_idx

    if not client:
        print("❌ Gemini Client is not initialized! Check GOOGLE_API_KEY.")
        return None

    total_models = len(MODEL_REGISTRY)

    while current_model_idx < total_models:
        model_name = MODEL_REGISTRY[current_model_idx]

        for attempt in range(2):
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=batch_prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_PROMPT,
                        temperature=0.1,
                        response_mime_type="application/json"
                    )
                )

                parsed = clean_json_response(response.text)
                if parsed is not None:
                    return (parsed if isinstance(parsed, list) else [parsed])

                print(f"⚠️ [{model_name}] JSON parse retry (Attempt {attempt + 1})...")
                time.sleep(3)

            except Exception as e:
                err_str = str(e)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    print(f"⚠️ [{model_name}] Daily limit hit (429). Switching to backup model...")
                    current_model_idx += 1
                    break
                
                print(f"⚠️ [{model_name}] Error on attempt {attempt + 1}: {e}")
                time.sleep(5)

        if current_model_idx < total_models and MODEL_REGISTRY[current_model_idx] != model_name:
            continue
        else:
            current_model_idx += 1

    print("⚠️ All models exhausted. Pausing 60s for quota bucket reset...")
    time.sleep(60)
    current_model_idx = 0
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

    print(f"📦 Filtered {total_valid} valid articles into safe batches of {BATCH_SIZE}...")

    i = 0
    batch_counter = 1
    total_batches = (total_valid + BATCH_SIZE - 1) // BATCH_SIZE

    while i < total_valid:
        batch = valid_items[i : i + BATCH_SIZE]
        print(f"\n⚡ Processing Batch {batch_counter}/{total_batches} ({len(batch)} items)...")

        batch_payload = []
        for idx, itm in enumerate(batch, 1):
            full_content = str(itm.get("content", "")).strip()
            batch_payload.append({
                "input_id": idx,
                "domain": domain,
                "title": itm.get("title", ""),
                "content": full_content
            })

        prompt_str = f"Process these {len(batch)} articles into JSON array:\n" + json.dumps(batch_payload, ensure_ascii=False)

        batch_result = call_gemini_clean_slate_api(prompt_str)

        if not batch_result:
            print(f"🔄 Retrying Batch {batch_counter} to guarantee 100% news coverage...")
            time.sleep(10)
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

            now_dt = datetime.now(IST)
            prefix = "bih" if is_bihar else "nat"
            card = {
                "id": f"{prefix}_{len(cards) + 1:02d}",
                "title": c_title,
                "category": assigned_category,
                "bullets": bullets,
                "exam_tag": exam_tag,
                "date": TODAY_DATE,
                "timestamp": int(now_dt.timestamp())
            }
            cards.append(card)
            print(f"  ✅ Added: {c_title[:40]} ({len(bullets)} bullets)")

        i += BATCH_SIZE
        batch_counter += 1

        if i < total_valid:
            print(f"⏳ Cooling down {BATCH_PAUSE_SECONDS}s for complete token & rate quota reset...")
            time.sleep(BATCH_PAUSE_SECONDS)

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
    print(f"🚀 Starting High-Precision Zero-Loss Summarizer...")
    print(f"📦 Raw Inputs -> National: {len(national_raw)} | Bihar: {len(bihar_raw)}")

    # 1. Process Fresh Scraped News
    print("\n" + "=" * 50 + "\n🇮🇳 PROCESSING NATIONAL NEWS\n" + "=" * 50)
    fresh_national = process_news_batches(national_raw, is_bihar=False)

    print("\n" + "=" * 50 + "\n🏛️ PROCESSING BIHAR NEWS\n" + "=" * 50)
    fresh_bihar = process_news_batches(bihar_raw, is_bihar=True)

    now_dt = datetime.now(IST)
    twenty_four_hours_ago = now_dt - timedelta(hours=24)

    # 2. UPDATE ROLLING 24-HOUR FILE (finalnews.json)
    existing_daily = {"national_news": [], "bihar_news": []}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                existing_daily = json.load(f)
        except Exception:
            pass

    # Merge & filter only items inside 24-hour window or today's date
    def merge_rolling_news(fresh_items, existing_items):
        merged = list(fresh_items)
        seen = {item.get("title", "").strip().lower() for item in fresh_items}

        for item in existing_items:
            t = item.get("title", "").strip().lower()
            item_dt = parse_card_datetime(item)
            # Retain if within 24 hours and not duplicated by fresh batch
            if item_dt >= twenty_four_hours_ago and t and t not in seen:
                merged.append(item)
                seen.add(t)
        return merged

    rolling_national = merge_rolling_news(fresh_national, existing_daily.get("national_news", []))
    rolling_bihar = merge_rolling_news(fresh_bihar, existing_daily.get("bihar_news", []))

    for idx, item in enumerate(rolling_national, 1):
        item["id"] = f"nat_{idx:02d}"

    for idx, item in enumerate(rolling_bihar, 1):
        item["id"] = f"bih_{idx:02d}"

    daily_output_data = {
        "generated_at": now_dt.strftime("%Y-%m-%d %H:%M:%S"),
        "window": "Rolling 24 Hours",
        "national_count": len(rolling_national),
        "bihar_count": len(rolling_bihar),
        "total_count": len(rolling_national) + len(rolling_bihar),
        "national_news": rolling_national,
        "bihar_news": rolling_bihar
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(daily_output_data, f, ensure_ascii=False, indent=2)

    print(f"\n💾 24-Hour Rolling Bulletin saved to '{OUTPUT_FILE}'! (Total: {len(rolling_national) + len(rolling_bihar)} items)")

    # 3. UPDATE MASTER ARCHIVE (all_current_affairs.json)
    master_archive = {
        "generated_at": now_dt.strftime("%Y-%m-%d %H:%M:%S"),
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

    for item in fresh_national:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_nat_titles:
            existing_nat.insert(0, item)
            existing_nat_titles.add(t_clean)

    for item in fresh_bihar:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_bih_titles:
            existing_bih.insert(0, item)
            existing_bih_titles.add(t_clean)

    for idx, item in enumerate(existing_nat, 1):
        item["id"] = f"nat_{idx:03d}"

    for idx, item in enumerate(existing_bih, 1):
        item["id"] = f"bih_{idx:03d}"

    master_archive["generated_at"] = now_dt.strftime("%Y-%m-%d %H:%M:%S")
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
    print(f"📊 24-Hour Rolling: {len(rolling_national) + len(rolling_bihar)} | Full Master: {len(existing_nat) + len(existing_bih)}")
    print("=" * 80)


if __name__ == "__main__":
    process_all_news()
