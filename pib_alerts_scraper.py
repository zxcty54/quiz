import os
import json
import html
import feedparser
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs, unquote
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION
# ============================================================
# Aap feedback RSS link ko YML environment variable se bhi pass kar sakte hain
FEED_URL = os.environ.get(
    "PIB_ALERT_FEED_URL",
    "https://www.google.com/alerts/feeds/18398184577640792063/4294037665781559395"
)

OUTPUT_FILE = "pib_alerts_raw.json"
IST = timezone(timedelta(hours=5, minutes=30))


def extract_real_url(google_url):
    """Google Alert Redirect URL se Asli Website URL Extract Karta Hai"""
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
    except Exception as e:
        print(f"⚠️ URL Extraction error: {e}")
    return google_url


def clean_text(raw_html):
    """HTML Tags (<b>, &nbsp;, etc.) hatakar clean plain text banata hai"""
    if not raw_html:
        return ""
    soup = BeautifulSoup(raw_html, "html.parser")
    text = soup.get_text(separator=" ")
    return html.unescape(" ".join(text.split())).strip()


def parse_feed_date(entry):
    """Published date ko '12 Aug 2026' format mein convert karta hai"""
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        dt = datetime(*entry.published_parsed[:6])
        return dt.strftime("%d %b %Y")
    return datetime.now(IST).strftime("%d %b %Y")


def scrape_pib_alerts():
    print(f"📡 Fetching Feed: {FEED_URL[:60]}...")
    
    feed = feedparser.parse(FEED_URL)
    
    if feed.bozo:
        print("⚠️ Warning: Feed parser encountered formatting issues, continuing parsing...")

    entries = feed.entries
    print(f"📦 Total Feed Entries Found: {len(entries)}")

    scraped_news = []

    for idx, entry in enumerate(entries, 1):
        raw_title = entry.get("title", "")
        raw_link = entry.get("link", "")
        raw_content = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

        clean_title_text = clean_text(raw_title)
        real_target_url = extract_real_url(raw_link)
        clean_content_text = clean_text(raw_content)
        formatted_date = parse_feed_date(entry)

        if not clean_title_text or not real_target_url:
            continue

        item = {
            "id": f"pib_alert_{idx:03d}",
            "title": clean_title_text,
            "url": real_target_url,
            "content": clean_content_text,
            "date": formatted_date
        }

        scraped_news.append(item)
        print(f"  ✅ [{idx}/{len(entries)}] Scraped: {clean_title_text[:50]}...")

    output_data = {
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(scraped_news),
        "raw_news": scraped_news
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"💾 Successfully saved {len(scraped_news)} items to '{OUTPUT_FILE}'!")
    print("=" * 70)


if __name__ == "__main__":
    scrape_pib_alerts()
