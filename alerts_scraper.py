import os
import re
import json
import html
import hashlib
import warnings
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse, parse_qs, urljoin

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
MAX_PER_FEED = 15

MIN_CONTENT_WORDS = 80
MAX_CONTENT_WORDS = 500

IST = timezone(timedelta(hours=5, minutes=30))

# Apne Google Alert RSS Feeds ki URLs yahan add karein
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
# UTILITY FUNCTIONS
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

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

def trim_words(text, max_words=500):
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

def decode_google_alert_url(alert_url):
    """Google Alerts ke redirect link se real publisher URL nikalta hai"""
    try:
        parsed = urlparse(alert_url)
        query_params = parse_qs(parsed.query)
        if "url" in query_params:
            return query_params["url"][0]
    except Exception:
        pass
    return alert_url

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

    # Priority article selectors
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

    # Paragraph fallback
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
    print("🚀 Starting Google Alerts Scraper Engine...\n")
    all_articles = []
    seen_urls = set()

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
            published_str = getattr(entry, "published", "") or getattr(entry, "updated", "")

            clean_title_str = clean_text(raw_title)
            real_url = decode_google_alert_url(raw_link)

            if not real_url or real_url in seen_urls or len(clean_title_str) < 15:
                continue

            # Fetch Deep Article Content
            html_raw = fetch_html(real_url)
            article_text = extract_article_body(html_raw)

            # Fallback to feed content if webpage scraping failed
            if word_count(article_text) < MIN_CONTENT_WORDS:
                snippet_text = clean_text(raw_content)
                if word_count(snippet_text) >= 20:
                    article_text = snippet_text
                else:
                    print(f"   ⚠️ Skipped (Low Content): {clean_title_str[:40]}...")
                    continue

            # Parse Date
            pub_date = now_ist()
            if published_str:
                try:
                    dt = date_parser.parse(published_str)
                    pub_date = dt.astimezone(IST)
                except Exception:
                    pass

            seen_urls.add(real_url)
            all_articles.append({
                "feed_name": feed_name,
                "title": clean_title_str,
                "url": real_url,
                "date": pub_date.strftime("%a, %d %b %Y %H:%M:%S IST"),
                "content": article_text,
                "content_words": word_count(article_text)
            })

            print(f"   ✅ Saved: {clean_title_str[:50]}... ({word_count(article_text)} words)")

    output_payload = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(all_articles),
        "articles": all_articles
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print(f"\n💾 Output successfully saved to '{OUTPUT_FILE}' with {len(all_articles)} items!")

if __name__ == "__main__":
    process_alerts()
