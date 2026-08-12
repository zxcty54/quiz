import os
import json
import html
import requests
import feedparser
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs, unquote
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION
# ============================================================
FEED_URL = os.environ.get(
    "PIB_ALERT_FEED_URL",
    "https://www.google.com/alerts/feeds/18398184577640792063/4294037665781559395"
)

OUTPUT_FILE = "pib_alerts_raw.json"
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


def extract_real_url(google_url):
    """Google Alert Redirect URL se Real Target Link Extract karta hai"""
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
    except Exception as e:
        print(f"⚠️ URL Extraction error: {e}")
    return google_url


def clean_text(text):
    """Extra spaces aur newlines ko clean karta hai"""
    if not text:
        return ""
    return html.unescape(" ".join(text.split())).strip()


def scrape_full_url_content(target_url):
    """URL Par Visit Karke Page ka Entire/Full Article Text Scrape Karta Hai"""
    try:
        resp = requests.get(target_url, headers=HEADERS, timeout=12)
        if resp.status_code == 200:
            soup = BeautifulSoup(resp.content, "html.parser")

            # Remove unwanted elements (scripts, styles, header, footer)
            for tag in soup(["script", "style", "nav", "footer", "header"]):
                tag.decompose()

            # PIB specific main content div check
            pib_div = soup.find("div", class_="ReleaseContentDiv") or soup.find("form", id="form1")
            
            if pib_div:
                full_text = pib_div.get_text(separator=" ")
            else:
                full_text = soup.get_text(separator=" ")

            cleaned = clean_text(full_text)
            # Max 800 words limit so AI prompt handles it easily
            words = cleaned.split()
            if len(words) > 800:
                return " ".join(words[:800])
            return cleaned

    except Exception as e:
        print(f"  ⚠️ Could not fetch full webpage content for {target_url[:40]}: {e}")

    return ""


def parse_feed_date(entry):
    """Published date format '12 Aug 2026'"""
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        dt = datetime(*entry.published_parsed[:6])
        return dt.strftime("%d %b %Y")
    return datetime.now(IST).strftime("%d %b %Y")


def scrape_pib_alerts():
    print(f"📡 Fetching Feed: {FEED_URL[:60]}...")
    feed = feedparser.parse(FEED_URL)

    entries = feed.entries
    print(f"📦 Total Feed Entries Found: {len(entries)}")

    scraped_news = []

    for idx, entry in enumerate(entries, 1):
        raw_title = entry.get("title", "")
        raw_link = entry.get("link", "")
        feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

        clean_title_text = clean_text(BeautifulSoup(raw_title, "html.parser").get_text())
        real_target_url = extract_real_url(raw_link)
        formatted_date = parse_feed_date(entry)

        if not clean_title_text or not real_target_url:
            continue

        print(f"🌐 [{idx}/{len(entries)}] Scraping Full Page Content: {clean_title_text[:45]}...")
        
        # 🔍 Step: Open URL and Scrape Full Webpage Content
        full_article_content = scrape_full_url_content(real_target_url)

        # Fallback to RSS snippet if URL scraping fails
        if not full_article_content:
            full_article_content = clean_text(BeautifulSoup(feed_snippet, "html.parser").get_text())

        item = {
            "id": f"pib_alert_{idx:03d}",
            "title": clean_title_text,
            "url": real_target_url,
            "content": full_article_content,
            "date": formatted_date
        }

        scraped_news.append(item)

    output_data = {
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_count": len(scraped_news),
        "raw_news": scraped_news
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"💾 Successfully scraped full content and saved to '{OUTPUT_FILE}'!")
    print("=" * 70)


if __name__ == "__main__":
    scrape_pib_alerts()
