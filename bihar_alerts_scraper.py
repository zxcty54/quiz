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

# Strict limits: Full article must have at least 150 words
MIN_WORDS_PER_ARTICLE = 150
MAX_WORDS_PER_ARTICLE = 500

# 3 Bihar Google Alerts Feeds
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
    if BANNED_TOPICS_REGEX.search(combined):
        return True
    return False


# ============================================================
# HELPER FUNCTIONS & DATE CHECKS
# ============================================================

def now_ist():
    return datetime.now(IST)


def extract_real_url(google_url):
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
    except Exception:
        pass
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
    """Extracts published/updated datetime converted to IST"""
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        utc_dt = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    elif hasattr(entry, 'updated_parsed') and entry.updated_parsed:
        utc_dt = datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    return None


def is_strictly_today(entry):
    """Checks if the Google Alert entry was published TODAY (IST)"""
    entry_dt = get_entry_datetime(entry)
    if not entry_dt:
        return False
    return entry_dt.date() == now_ist().date()


def scrape_full_webpage_content(target_url):
    """Fetches and extracts full article body; returns empty if invalid or short"""
    try:
        resp = requests.get(target_url, headers=HEADERS, timeout=TIMEOUT)
        if resp.status_code == 200:
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

            # Enforce minimum word requirement on raw extracted body
            if len(words) >= MIN_WORDS_PER_ARTICLE:
                return " ".join(words[:MAX_WORDS_PER_ARTICLE])
    except Exception:
        pass
    return ""


# ============================================================
# MAIN EXECUTION
# ============================================================

def process_and_append_bihar_alerts():
    today_str = now_ist().strftime("%d %b %Y")
    print("\n" + "=" * 75)
    print(f"🚀 STARTING STRICT BIHAR ALERTS SCRAPER [{today_str}]")
    print("=" * 75)

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
        except Exception as e:
            print(f"⚠️ Could not load {TARGET_FILE}: {e}")

    # Retain existing bihar items only if they belong to TODAY
    existing_bihar = raw_data.get("bihar_raw_news", [])
    valid_existing_bihar = [item for item in existing_bihar if today_str in item.get("date", "")]
    
    seen_urls = {item.get("url", "").strip() for item in valid_existing_bihar if item.get("url")}
    seen_titles = {re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', item.get("title", "").lower()) for item in valid_existing_bihar}

    new_bihar_items = []
    dropped_banned = 0
    skipped_old = 0
    failed_scrape = 0

    for feed_info in BIHAR_FEEDS:
        cat_name = feed_info["category"]
        feed_url = feed_info["url"]
        print(f"\n📡 Parsing Feed: {cat_name}...")

        try:
            feed = feedparser.parse(feed_url)
            entries = feed.entries
            print(f"   Found {len(entries)} items")
        except Exception as e:
            print(f"   ⚠️ Error fetching feed: {e}")
            continue

        for entry in entries:
            raw_title = entry.get("title", "")
            raw_link = entry.get("link", "")
            feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

            c_title = clean_title(raw_title)
            clean_snippet = clean_text(feed_snippet)
            real_url = extract_real_url(raw_link)

            if not c_title or not real_url or len(c_title) < 15:
                continue

            # 1. Date Check (Today Only)
            if not is_strictly_today(entry):
                skipped_old += 1
                continue

            # 2. Banned Topics Check on Title/Snippet
            if is_unwanted_news(c_title, clean_snippet):
                print(f"   ⏭️ REJECTED (Banned Topic): {c_title[:50]}...")
                dropped_banned += 1
                continue

            # 3. Duplicate Check
            norm_title = re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', c_title.lower())
            if real_url in seen_urls or norm_title in seen_titles:
                continue

            # 4. Strict Webpage Scraping (NO SNIPPET FALLBACK)
            print(f"   🌐 Scraping Target Webpage: {c_title[:45]}...")
            content = scrape_full_webpage_content(real_url)

            if not content:
                print(f"   🚫 REJECTED (Webpage scraping failed or < {MIN_WORDS_PER_ARTICLE} words): {c_title[:45]}...")
                failed_scrape += 1
                continue

            # 5. Final Body Quality & Topic Check
            if is_unwanted_news("", content[:250]):
                print(f"   ⏭️ REJECTED (Body Topic Filter): {c_title[:50]}...")
                dropped_banned += 1
                continue

            seen_urls.add(real_url)
            seen_titles.add(norm_title)

            words_total = len(content.split())
            entry_dt = get_entry_datetime(entry)
            formatted_date = entry_dt.strftime("%a, %d %b %Y %H:%M:%S IST")

            item = {
                "source": "Bihar Google Alert",
                "title": c_title,
                "url": real_url,
                "date": formatted_date,
                "content": content,
                "content_chars": len(content),
                "content_words": words_total,
                "type": "State News"
            }

            new_bihar_items.append(item)
            print(f"   ✅ Successfully Scraped ({words_total} words): {c_title[:40]}")

    print(f"\n📊 Filter Summary -> Added: {len(new_bihar_items)} | Scraping Failed: {failed_scrape} | Banned: {dropped_banned} | Old: {skipped_old}")

    # Merge fresh items with valid today's existing items
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

    print("\n" + "=" * 75)
    print(f"💾 Successfully updated '{TARGET_FILE}' with verified full-article news!")
    print(f"📊 Bihar Total: {len(updated_bihar_news)} | National Total: {national_count} | Grand Total: {raw_data['total_raw_count']}")
    print("=" * 75)


if __name__ == "__main__":
    process_and_append_bihar_alerts()
