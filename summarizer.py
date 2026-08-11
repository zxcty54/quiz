import os
import json
import time
import re
from datetime import datetime, timezone, timedelta
from groq import Groq

# ============================================================
# CONFIGURATION
# ============================================================

INPUT_FILE = "rawnews.json"
OUTPUT_FILE = "finalnews.json"
ARCHIVE_FILE = "all_current_affairs.json"

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
- BANNED TOPICS BLOCK (STRICT DROP): Set "is_relevant": false for ALL news related to:
  1. Corporate fraud, bribery, court lawsuits involving business personalities (e.g., Adani bribery/fraud cases, corporate scam court trials).
  2. Foreign immigration rules, visa policy changes for other countries, US/UK/Canada immigration updates (unless directly related to Indian bilateral treaties).
  3. Local protests, lathi-charge incidents, student strikes, hunger strikes, political party Bandhs, and political clashes.
- GARBAGE & NAVIGATION TITLES BLOCK: Set "is_relevant": false if the title/content contains website navigation phrases like "Skip to Main Content", "Accessibility Options", "Home", "Contact Us", etc.
- OTHER STATES NEWS BLOCK: If the news is specifically about OTHER Indian states (e.g., Uttar Pradesh, Madhya Pradesh, Rajasthan, Delhi, Maharashtra, Punjab, Haryana, Tamil Nadu, Karnataka, etc.) and is NOT a Central/National scheme or decision, set "is_relevant": false.
- Set "is_relevant": false if news is about stock market daily movements, Sensex/Nifty, Rupee fluctuations, local crime, accidents, viral videos, entertainment, gossip, or audio portal listings.

OUTPUT FORMAT REQUIREMENTS:
Output MUST be strictly valid JSON format with keys:
- "is_relevant": true or false
- "title": A crisp, factual headline in English
- "category": Exact name matched from ALLOWED CATEGORIES
- "bullets": Array of EXACTLY 2 to 3 exam-relevant factual points. NEVER leave this empty.
- "exam_tag": Exam tag name
"""

# ============================================================
# DEDUPLICATION HELPERS
# ============================================================

def normalize_title(title):
    """Extract key words for similarity comparison"""
    title = re.sub(r'[^a-zA-Z0-9\s]', '', title.lower())
    words = set(w for w in title.split() if len(w) > 3)
    return words


def is_duplicate_story(new_title, existing_titles, threshold=0.55):
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

        if similarity >= threshold:
            return True

    return False


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

    # Skip navigation/boilerplate titles before making API call
    junk_phrases = ["skip to main content", "accessibility options", "screen reader access", "home", "search"]
    if any(phrase in title.lower() for phrase in junk_phrases):
        print(f"  ⏭️ SKIPPED (Navigation Garbage): {title[:45]}...")
        return None

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
        "Return strictly valid JSON format with keys: is_relevant, title, category, bullets (array of 2-3 points), exam_tag."
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

    # GUARANTEED NON-EMPTY BULLETS FALLBACK
    bullets = parsed.get("bullets", [])
    if not isinstance(bullets, list) or len(bullets) == 0:
        clean_text_snippet = trimmed_content if len(trimmed_content) > 30 else title
        bullets = [
            f"Key update regarding {title[:60]}.",
            f"Overview: {clean_text_snippet[:120]}..."
        ]

    return {
        "title": parsed.get("title", title),
        "category": assigned_category,
        "bullets": bullets,
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
    seen_national_titles = []

    bihar_cards = []
    seen_bihar_titles = []

    # Process National News
    print("\n🇮🇳 Processing National News...")
    nat_idx = 1
    for item in national_raw:
        print(f"[National {nat_idx}/{len(national_raw)}] Summarizing: {item.get('title', '')[:45]}...")
        card_data = summarize_article(item, is_bihar=False)
        
        if card_data:
            c_title = card_data["title"]
            if not is_duplicate_story(c_title, seen_national_titles):
                seen_national_titles.append(c_title)
                formatted_card = {
                    "id": f"nat_{len(national_cards) + 1:02d}",
                    "title": card_data["title"],
                    "category": card_data["category"],
                    "bullets": card_data["bullets"],
                    "exam_tag": card_data["exam_tag"],
                    "date": card_data["date"]
                }
                national_cards.append(formatted_card)
            else:
                print(f"  🧹 DROPPED DUPLICATE: {c_title[:45]}...")

            nat_idx += 1
            
        time.sleep(1.5)  # Optimal delay for 8b instant model

    # Process Bihar News
    print("\n🏛️ Processing Bihar News...")
    bih_idx = 1
    for item in bihar_raw:
        print(f"[Bihar {bih_idx}/{len(bihar_raw)}] Summarizing: {item.get('title', '')[:45]}...")
        card_data = summarize_article(item, is_bihar=True)

        if card_data:
            c_title = card_data["title"]
            if not is_duplicate_story(c_title, seen_bihar_titles):
                seen_bihar_titles.append(c_title)
                formatted_card = {
                    "id": f"bih_{len(bihar_cards) + 1:02d}",
                    "title": card_data["title"],
                    "category": card_data["category"],
                    "bullets": card_data["bullets"],
                    "exam_tag": card_data["exam_tag"],
                    "date": card_data["date"]
                }
                bihar_cards.append(formatted_card)
            else:
                print(f"  🧹 DROPPED DUPLICATE: {c_title[:45]}...")

            bih_idx += 1
            
        time.sleep(1.5)

    # ------------------------------------------------------------
    # 1. SAVE DAILY OVERWRITTEN FILE (finalnews.json)
    # ------------------------------------------------------------
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

    # ------------------------------------------------------------
    # 2. SAVE & APPEND TO MASTER ARCHIVE FILE (all_current_affairs.json)
    # ------------------------------------------------------------
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
        except Exception as e:
            print(f"⚠️ Could not load master archive, creating new one: {e}")

    existing_nat = master_archive.get("national_news", [])
    existing_bih = master_archive.get("bihar_news", [])

    existing_nat_titles = {item.get("title", "").strip().lower() for item in existing_nat}
    existing_bih_titles = {item.get("title", "").strip().lower() for item in existing_bih}

    # Append new national news (Newest on top)
    for item in national_cards:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_nat_titles:
            existing_nat.insert(0, item)
            existing_nat_titles.add(t_clean)

    # Append new bihar news (Newest on top)
    for item in bihar_cards:
        t_clean = item.get("title", "").strip().lower()
        if t_clean and t_clean not in existing_bih_titles:
            existing_bih.insert(0, item)
            existing_bih_titles.add(t_clean)

    # Re-assign clean IDs for master archive
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

    print("\n" + "=" * 80)
    print(f"💾 Master Archive successfully updated in '{ARCHIVE_FILE}'!")
    print(f"📊 Total Archived -> National: {len(existing_nat)} | Bihar: {len(existing_bih)}")
    print("=" * 80)


if __name__ == "__main__":
    process_all_news()
