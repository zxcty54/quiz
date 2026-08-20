import os
import re
import json
import html
import hashlib
import warnings
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse, parse_qs

import feedparser
from bs4 import BeautifulSoup
from curl_cffi import requests as curl_requests
import requests as normal_requests
from dateutil import parser as date_parser

# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "alerts_news.json"
TIMEOUT = 20
MAX_PER_FEED = 20

MIN_CONTENT_WORDS = 80
MAX_CONTENT_WORDS = 500

IST = timezone(timedelta(hours=5, minutes=30))

GOOGLE_ALERT_FEEDS = [
    {
        "name": "India Firsts & Tech Alerts",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/752589673945921988"
    }
]

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

warnings.filterwarnings("ignore")

# ============================================================
# UTILITY FUNCTIONS & DEDUPLICATION HELPERS
# ============================================================

def now_ist():
    return datetime.now(IST)

def clean_text(text):
    if not text:
        return ""
    text = html.unescape(str(text))
    text = BeautifulSoup(text, "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ")
    return re.sub(r'\s+', ' ', text).strip()

def normalize_title(title):
    """Duplicates detect karne ke liye title ko clean & lowercase karta hai"""
    return re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', clean_text(title).lower())

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

def trim_words(text, max_words=500):
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

def decode_google_alert_url(alert_url):
    try:
        parsed = urlparse(alert_url)
        query_params = parse_qs(parsed.query)
        if "url" in query_params:
            return query_params["url"][0]
    except Exception:
        pass
    return alert_url

# ============================================================
# STRICT CURRENT DATE PARSER
# ============================================================

def get_entry_datetime(entry):
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        utc_dt = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    elif hasattr(entry, 'updated_parsed') and entry.updated_parsed:
        utc_dt = datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    
    published_str = getattr(entry, "published", "") or getattr(entry, "updated", "")
    if published_str:
        try:
            dt = date_parser.parse(published_str)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=IST)
            return dt.astimezone(IST)
        except Exception:
            pass
    return None

def is_strictly_today(entry_dt):
    if not entry_dt:
        return False
    return entry_dt.date() == now_ist().date()

# ============================================================
# FETCH & EXTRACTION
# ============================================================

def fetch_html(url):
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400 and len(r.text) > 200:
            return r.text
    except Exception:
        pass

    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
        if r.status_code < 400 and len(r.text) > 200:
            return r.text
    except Exception:
        pass

    return None

def extract_article_body(html_content):
    if not html_content:
        return ""

    soup = BeautifulSoup(html_content, "lxml")
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside", "header"]):
        tag.decompose()

    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", 
        ".story-content", ".entry-content", ".news-content", "main"
    ]

    for sel in selectors:
        elements = soup.select(sel)
        for el in elements:
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                return trim_words(txt, MAX_CONTENT_WORDS)

    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if len(p) > 25]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            return trim_words(joined, MAX_CONTENT_WORDS)

    return ""

# ============================================================
# MAIN SCRAPING LOGIC
# ============================================================

def process_alerts():
    today_str = now_ist().strftime("%d %b %Y")
    print(f"🚀 Starting Google Alerts Scraper Engine (Strict Date: {today_str})...\n")
    
    # 1. Load Existing File & Build Seen Sets
    existing_articles = []
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                old_data = json.load(f)
                for item in old_data.get("articles", []):
                    if today_str in item.get("date", ""):
                        existing_articles.append(item)
        except Exception:
            pass

    seen_urls = {item.get("url").strip() for item in existing_articles if item.get("url")}
    seen_titles = {normalize_title(item.get("title", "")) for item in existing_articles if item.get("title")}

    new_articles = []
    skipped_old_dates = 0
    skipped_duplicates = 0

    for feed_info in GOOGLE_ALERT_FEEDS:
        feed_name = feed_info["name"]
        feed_url = feed_info["url"]
        print(f"📡 Processing Alert Feed: [{feed_name}]")

        parsed_feed = feedparser.parse(feed_url)
        entries = parsed_feed.entries
        print(f"   Found {len(entries)} raw entries in feed.")

        for entry in entries[:MAX_PER_FEED]:
            raw_title = getattr(entry, "title", "")
            raw_link = getattr(entry, "link", "")
            raw_content = getattr(entry, "content", [{}])[0].get("value", "") or getattr(entry, "summary", "")

            clean_title_str = clean_text(raw_title)
            real_url = decode_google_alert_url(raw_link)
            norm_title = normalize_title(clean_title_str)

            if not real_url or len(clean_title_str) < 15:
                continue

            # 🛑 1. DEDUPLICATION CHECK (URL & TITLE)
            if real_url in seen_urls or norm_title in seen_titles:
                print(f"   🧹 Duplicate Skipped: {clean_title_str[:40]}...")
                skipped_duplicates += 1
                continue

            # 📅 2. STRICT CURRENT DATE FILTER
            entry_dt = get_entry_datetime(entry)
            if not is_strictly_today(entry_dt):
                pub_date_str = entry_dt.strftime("%d %b %Y") if entry_dt else "Unknown Date"
                print(f"   ⏭️ Skipped Old Date ({pub_date_str}): {clean_title_str[:40]}...")
                skipped_old_dates += 1
                continue

            # Fetch Deep Article Content
            html_raw = fetch_html(real_url)
            article_text = extract_article_body(html_raw)

            # Fallback to feed snippet if full scraping failed
            if word_count(article_text) < MIN_CONTENT_WORDS:
                snippet_text = clean_text(raw_content)
                if word_count(snippet_text) >= 100:
                    article_text = snippet_text
                else:
                    print(f"   ⚠️ Skipped (Low Content): {clean_title_str[:40]}...")
                    continue

            # Register in seen sets
            seen_urls.add(real_url)
            seen_titles.add(norm_title)

            formatted_date = entry_dt.strftime("%a, %d %b %Y %H:%M:%S IST")

            item = {
                "feed_name": feed_name,
                "title": clean_title_str,
                "url": real_url,
                "date": formatted_date,
                "content": article_text,
                "content_words": word_count(article_text)
            }

            new_articles.append(item)
            print(f"   ✅ Saved Today's News: {clean_title_str[:45]}... ({word_count(article_text)} words)")

    # 3. Merge Today's Runs
    all_today_articles = new_articles + existing_articles

    output_payload = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(all_today_articles),
        "articles": all_today_articles
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"💾 Output saved to '{OUTPUT_FILE}'!")
    print(f"   ✅ Added Today       : {len(new_articles)}")
    print(f"   🧹 Duplicates Dropped: {skipped_duplicates}")
    print(f"   ⏭️ Skipped Old Date  : {skipped_old_dates}")
    print(f"   📊 Total for Today   : {len(all_today_articles)}")
    print("=" * 70)

if __name__ == "__main__":
    process_alerts()
