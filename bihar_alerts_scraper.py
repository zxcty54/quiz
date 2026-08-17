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
MAX_WORDS_PER_ARTICLE = 500
MIN_WORDS_PER_ARTICLE = 100

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
# HELPER FUNCTIONS
# ============================================================

def now_ist():
    return datetime.now(IST)


def extract_real_url(google_url):
    """Google Alert redirect URL se original web link extract karta hai"""
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


def parse_feed_date(entry):
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        try:
            dt = datetime(*entry.published_parsed[:6])
            return dt.strftime("%a, %d %b %Y %H:%M:%S IST")
        except Exception:
            pass
    return now_ist().strftime("%a, %d %b %Y %H:%M:%S IST")


def scrape_full_webpage_content(target_url):
    """Target URL par visit karke full body text scrape karta hai"""
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

            if len(words) >= MIN_WORDS_PER_ARTICLE:
                return " ".join(words[:MAX_WORDS_PER_ARTICLE])
    except Exception:
        pass
    return ""


# ============================================================
# MAIN EXECUTION
# ============================================================

def process_and_append_bihar_alerts():
    print("\n" + "=" * 75)
    print(f"🚀 STARTING STANDALONE BIHAR ALERTS SCRAPER [{now_ist().strftime('%Y-%m-%d %H:%M:%S IST')}]")
    print("=" * 75)

    # 1. Load existing rawnews.json if available
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
            print(f"📦 Loaded existing {TARGET_FILE} (Current Bihar News: {len(raw_data.get('bihar_raw_news', []))})")
        except Exception as e:
            print(f"⚠️ Could not load {TARGET_FILE}, initializing fresh structure: {e}")

    existing_bihar = raw_data.get("bihar_raw_news", [])
    
    # Existing titles aur URLs track karna for zero duplicates
    seen_urls = {item.get("url", "").strip() for item in existing_bihar if item.get("url")}
    seen_titles = {re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', item.get("title", "").lower()) for item in existing_bihar}

    new_bihar_items = []

    # 2. Scrape 3 Feeds
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
            real_url = extract_real_url(raw_link)

            if not c_title or not real_url or len(c_title) < 15:
                continue

            # Duplicate Check
            norm_title = re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', c_title.lower())
            if real_url in seen_urls or norm_title in seen_titles:
                continue

            seen_urls.add(real_url)
            seen_titles.add(norm_title)

            print(f"   🌐 Scraping: {c_title[:45]}...")
            content = scrape_full_webpage_content(real_url)

            if not content:
                clean_snippet = clean_text(feed_snippet)
                if len(clean_snippet) > 40:
                    content = f"{c_title}. Details: {clean_snippet}"
                else:
                    content = f"{c_title}. Official update regarding Bihar state governance and development."

            words_total = len(content.split())

            item = {
                "source": "Bihar Google Alert",
                "title": c_title,
                "url": real_url,
                "date": parse_feed_date(entry),
                "content": content,
                "content_chars": len(content),
                "content_words": words_total,
                "type": "State News"
            }

            new_bihar_items.append(item)

    print(f"\n✅ Newly Scraped Bihar Articles: {len(new_bihar_items)}")

    # 3. Append to existing list (Newest first)
    updated_bihar_news = new_bihar_items + existing_bihar
    raw_data["bihar_raw_news"] = updated_bihar_news
    raw_data["bihar_raw_count"] = len(updated_bihar_news)

    national_count = len(raw_data.get("national_raw_news", []))
    raw_data["total_raw_count"] = national_count + len(updated_bihar_news)
    raw_data["generated_at"] = now_ist().strftime("%Y-%m-%d %H:%M:%S")

    # Update Source Breakdown
    source_breakdown = raw_data.get("source_breakdown", {})
    source_breakdown["Bihar Google Alert"] = source_breakdown.get("Bihar Google Alert", 0) + len(new_bihar_items)
    raw_data["source_breakdown"] = source_breakdown

    # 4. Save Back to rawnews.json
    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 75)
    print(f"💾 Successfully appended to '{TARGET_FILE}'!")
    print(f"📊 Bihar Total: {len(updated_bihar_news)} | National Total: {national_count} | All Total: {raw_data['total_raw_count']}")
    print("=" * 75)


if __name__ == "__main__":
    process_and_append_bihar_alerts()
