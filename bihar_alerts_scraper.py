import os
import re
import json
import html
import hashlib
import feedparser
import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs, unquote
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION
# ============================================================

TARGET_FILE = "rawnews.json"
IST = timezone(timedelta(hours=5, minutes=30))
TIMEOUT = 15

# Strict Limits: Scraping fail ya < 150 words par direct rejection
MIN_WORDS_PER_ARTICLE = 150
MAX_WORDS_PER_ARTICLE = 500

BIHAR_FEEDS = [
    {
        "category": "Schemes, Policy, Budget & Indexes",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/11872670836562053243"
    },
    {
        "category": "Appointments, Awards, Sports & Culture",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/12169416279183737117"
    },
    {
        "category": "Infrastructure, Energy, Agriculture & Environment",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/13882357121219546323"
    }
]

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
}

# ============================================================
# DEBUGGING & LOGGING HELPERS
# ============================================================

def now_ist():
    return datetime.now(IST)


def debug(msg):
    print(f"🔍 {msg}")


def warn(msg):
    print(f"⚠️ {msg}")


def success(msg):
    print(f"✅ {msg}")


# ============================================================
# COMPREHENSIVE REGEX FILTER
# ============================================================

BANNED_TOPICS_REGEX = re.compile(
    r'('
    # 1. Corporate Deals, Private Tenders & Business Contracts
    r'\bsecures?\s+order\b|\bbagged\s+order\b|\bsecures?\s+contract\b|\bwon\s+bid\b|'
    r'\bquarterly\s+results?\b|\bshares?\s+(jump|surge|tank|fall|rise)\b|\brooftop\s+solar\s+order\b|'
    r'\bmarket\s+cap\b|\bipo\b|\bq[1-4]\s+results?\b|\bpat\s+up\b|\bnet\s+profit\b|'
    r'ऑर्डर\s+मिला|टेंडर|शेयर\s+बाजार|मुनाफा|कारोबार|कंपनी\s+को\s+मिला|'

    # 2. Crime, Violence, Murder, Legal Scandals
    r'\bmurder\b|\bkilled\b|\bkilling\b|\brape\b|\bdead\b|\bdeath\b|\bdies\b|\bbody\s+found\b|'
    r'\barrested?\b|\bloot\b|\brobbery\b|\btheft\b|\bkidnap\b|\bextortion\b|\bbribe\b|\bbribery\b|'
    r'\bfraud\b|\bscam\b|\bshootout\b|\bfiring\b|\bencounter\b|\bsmuggling\b|\billicit\b|'
    r'\bliquor\b|\bspurious\b|\bcyber\s+crime\b|\bgangster\b|\bcriminal\b|\bsuicide\b|'
    r'हत्या|मर्डर|बलात्कार|मौत|शव|लाश|गिरफ्तार|हिरासत|गोलीबारी|गोली\s+मारी|लूट|चोरी|'
    r'डकैती|अपहरण|फिरौती|धोखाधड़ी|घूस|रिश्वत|मुठभेड़|तस्करी|शराब\s+बरामद|जब्त|'
    r'छापेमारी|दबोचा|बदमाश|अपराधी|आत्महत्या|'

    # 3. Accidents, Disasters & Stampedes
    r'\baccident\b|\bcrash\b|\bcollision\b|\bderail\b|\bderailment\b|\bdrowned\b|\bdrowning\b|'
    r'\bfire\s+broke\b|\bcylinder\s+blast\b|\bexplosion\b|\bblast\b|\bboat\s+capsize\b|\bstampede\b|'
    r'दुर्घटना|सड़क\s+हादसा|टक्कर|ट्रक|बस\s+हादसा|ट्रेन\s+हादसा|डूबने|डूबकर|'
    r'आग\s+लगी|सिलेंडर\s+ब्लास्ट|धमाका|विस्फोट|नाव\s+पलटी|भगदड़|'

    # 4. Local Politics, Protests, Strikes & March
    r'\blathi-?charge\b|\bprotest\b|\bprotesters\b|\bstrike\b|\bhunger\s+strike\b|'
    r'\bdharna\b|\bchakka\s+jam\b|\broad\s+block\b|\bclash\b|\bclashes\b|\bstone\s+pelting\b|\bviolence\b|'
    r'\braj\s+bhavan\s+march\b|\bcalls?\s+out\b|\bhits?\s+out\b|'
    r'लाठीचार्ज|प्रदर्शन|धरना|चक्का\s+जाम|सड़क\s+जाम|हड़ताल|भूख\s+हड़ताल|'
    r'बवाल|हंगामा|पथराव|हिंसा|झड़प|राजभवन\s+मार्च|घेराव|'

    # 5. Static Trivia, Horoscopes, Weather & Viral Content
    r'\bhoroscope\b|\brashifal\b|\blottery\b|\bviral\s+video\b|\breels?\b|'
    r'\bweather\s+today\b|\brain\s+batters\b|\bheavy\s+rain\b|'
    r'राशिफल|लॉटरी|वायरल\s+वीडियो|मौसम\s+का\s+हाल|भारी\s+बारिश'
    r')',
    re.IGNORECASE | re.UNICODE
)


def is_unwanted_news(title, text=""):
    combined = f"{title} {text}"
    match = BANNED_TOPICS_REGEX.search(combined)
    if match:
        return True, match.group(0)
    return False, ""


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def extract_real_url(google_url):
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
    except Exception as e:
        warn(f"URL extraction failed: {e}")
    return google_url


def clean_text(raw_text):
    if not raw_text:
        return ""
    soup = BeautifulSoup(str(raw_text), "html.parser")
    text = soup.get_text(separator=" ")
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return html.unescape(" ".join(text.split())).strip()


def clean_title(title):
    t = clean_text(title)
    t = re.sub(
        r'\s*[-|–—]\s*(Dainik Bhaskar|Amar Ujala|Prabhat Khabar|Live Hindustan|Jagran|NDTV|News18|PIB)\s*$',
        '',
        t,
        flags=re.I
    )
    return t.strip()


def get_entry_datetime(entry):
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        utc_dt = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    elif hasattr(entry, 'updated_parsed') and entry.updated_parsed:
        utc_dt = datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    return None


def is_strictly_today(entry):
    entry_dt = get_entry_datetime(entry)
    if not entry_dt:
        return False, "No Date Found"
    
    is_today = entry_dt.date() == now_ist().date()
    return is_today, entry_dt.strftime("%d %b %Y %H:%M IST")


# ============================================================
# WEBPAGE SCRAPER (NO FALLBACK, STRICT BODY EXTRACTION)
# ============================================================

def scrape_full_webpage_content(target_url):
    try:
        debug(f"FETCHING WEBPAGE: {target_url[:65]}...")
        resp = requests.get(target_url, headers=HEADERS, timeout=TIMEOUT)
        
        if resp.status_code != 200:
            warn(f"HTTP {resp.status_code} Error on {target_url[:50]}")
            return "", 0

        soup = BeautifulSoup(resp.content, "html.parser")

        for tag in soup(["script", "style", "nav", "footer", "header", "aside", "form", "svg"]):
            tag.decompose()

        target_elem = (
            soup.find("article") or
            soup.find(class_=re.compile(r'(story|article|news|detail|content)', re.I)) or
            soup.find("main")
        )

        if target_elem:
            text = target_elem.get_text(separator=" ")
        else:
            paragraphs = [p.get_text(strip=True) for p in soup.find_all("p") if len(p.get_text(strip=True)) > 25]
            text = " ".join(paragraphs) if paragraphs else soup.get_text(separator=" ")

        cleaned = clean_text(text)
        words = cleaned.split()
        total_words = len(words)

        if total_words >= MIN_WORDS_PER_ARTICLE:
            trimmed = " ".join(words[:MAX_WORDS_PER_ARTICLE])
            return trimmed, total_words
        else:
            return "", total_words

    except Exception as e:
        warn(f"Scrape Exception for {target_url[:40]}: {e}")
        return "", 0


# ============================================================
# MAIN EXECUTION
# ============================================================

def process_and_append_bihar_alerts():
    today_str = now_ist().strftime("%d %b %Y")
    print("\n" + "=" * 80)
    print(f"🚀 STARTING BIHAR ALERTS PIPELINE [{today_str}]")
    print("=" * 80)

    raw_data = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": 0,
        "national_raw_count": 0,
        "total_raw_count": 0,
        "bihar_raw_news": [],
        "national_raw_news": [],
        "source_breakdown": {}
    }

    if os.path.exists(TARGET_FILE):
        try:
            with open(TARGET_FILE, "r", encoding="utf-8") as f:
                raw_data = json.load(f)
            debug(f"Loaded existing {TARGET_FILE}")
        except Exception as e:
            warn(f"Could not load {TARGET_FILE}: {e}")

    # Keep only TODAY'S records from previous runs
    existing_bihar = raw_data.get("bihar_raw_news", [])
    valid_existing_bihar = [item for item in existing_bihar if today_str in item.get("date", "")]
    
    seen_urls = {item.get("url", "").strip() for item in valid_existing_bihar if item.get("url")}
    seen_titles = {re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', item.get("title", "").lower()) for item in valid_existing_bihar}

    new_bihar_items = []
    dropped_banned = 0
    skipped_old = 0
    failed_scrape = 0
    duplicate_count = 0

    for feed_info in BIHAR_FEEDS:
        cat_name = feed_info["category"]
        feed_url = feed_info["url"]
        print(f"\n📡 Reading Feed: {cat_name}")

        try:
            feed = feedparser.parse(feed_url)
            entries = feed.entries
            debug(f"Found {len(entries)} items in feed.")
        except Exception as e:
            warn(f"Error fetching feed: {e}")
            continue

        for entry in entries:
            raw_title = entry.get("title", "")
            raw_link = entry.get("link", "")
            feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

            c_title = clean_title(raw_title)
            clean_snippet = clean_text(feed_snippet)
            real_url = extract_real_url(raw_link)

            if not c_title or not real_url or len(c_title) < 15:
                debug(f"SKIPPED (Invalid/Empty Title or Link): {raw_title[:40]}")
                continue

            # 1. 📅 DATE CHECK
            is_today, pub_dt_str = is_strictly_today(entry)
            if not is_today:
                debug(f"REJECTED (Not Today | Pub: {pub_dt_str}): {c_title[:45]}...")
                skipped_old += 1
                continue

            # 2. 🛑 BANNED TOPIC (TITLE/SNIPPET)
            is_banned, matched_keyword = is_unwanted_news(c_title, clean_snippet)
            if is_banned:
                warn(f"REJECTED BANNED TOPIC [Matched: '{matched_keyword}']: {c_title[:50]}...")
                dropped_banned += 1
                continue

            # 3. 🧹 DUPLICATE CHECK
            norm_title = re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', c_title.lower())
            if real_url in seen_urls or norm_title in seen_titles:
                debug(f"DUPLICATE SKIPPED: {c_title[:45]}...")
                duplicate_count += 1
                continue

            # 4. 🌐 FULL WEBPAGE SCRAPE
            content, words_found = scrape_full_webpage_content(real_url)

            if not content or words_found < MIN_WORDS_PER_ARTICLE:
                warn(f"REJECTED TOO SHORT/SCRAPE FAILED ({words_found} words < {MIN_WORDS_PER_ARTICLE}): {c_title[:45]}...")
                failed_scrape += 1
                continue

            # 5. 🛑 BANNED TOPIC (FULL BODY)
            is_body_banned, body_keyword = is_unwanted_news("", content[:300])
            if is_body_banned:
                warn(f"REJECTED BANNED TOPIC IN BODY [Matched: '{body_keyword}']: {c_title[:50]}...")
                dropped_banned += 1
                continue

            seen_urls.add(real_url)
            seen_titles.add(norm_title)

            entry_dt = get_entry_datetime(entry)
            formatted_date = entry_dt.strftime("%a, %d %b %Y %H:%M:%S IST")

            item = {
                "source": "Bihar Google Alert",
                "title": c_title,
                "url": real_url,
                "date": formatted_date,
                "content": content,
                "content_chars": len(content),
                "content_words": len(content.split()),
                "type": "State News"
            }

            new_bihar_items.append(item)
            success(f"ADDED TO RAWNEWS ({len(content.split())} words): {c_title[:50]}")

    print("\n" + "=" * 80)
    print("📊 EXECUTION BREAKDOWN:")
    print(f"   ✅ Successfully Scraped & Added : {len(new_bihar_items)}")
    print(f"   📅 Skipped (Old Dates)          : {skipped_old}")
    print(f"   🚫 Rejected (Banned Keywords)   : {dropped_banned}")
    print(f"   ⚠️ Rejected (Scrape Failed/<150w): {failed_scrape}")
    print(f"   🧹 Skipped (Duplicates)         : {duplicate_count}")
    print("=" * 80)

    # Merge newly scraped items with valid today's existing items
    updated_bihar_news = new_bihar_items + valid_existing_bihar
    raw_data["bihar_raw_news"] = updated_bihar_news
    raw_data["bihar_raw_count"] = len(updated_bihar_news)

    national_count = len(raw_data.get("national_raw_news", []))
    raw_data["total_raw_count"] = national_count + len(updated_bihar_news)
    raw_data["generated_at"] = now_ist().strftime("%Y-%m-%d %H:%M:%S")

    source_breakdown = raw_data.get("source_breakdown", {})
    source_breakdown["Bihar Google Alert"] = len(updated_bihar_news)
    raw_data["source_breakdown"] = source_breakdown

    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_data, f, ensure_ascii=False, indent=2)

    success(f"Updated '{TARGET_FILE}'! Today's Bihar Total: {len(updated_bihar_news)} | Grand Total: {raw_data['total_raw_count']}")


if __name__ == "__main__":
    process_and_append_bihar_alerts()
