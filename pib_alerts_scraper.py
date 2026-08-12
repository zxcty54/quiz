import os
import re
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

RAW_NEWS_FILE = "rawnews.json"
IST = timezone(timedelta(hours=5, minutes=30))

MIN_CONTENT_WORDS = 100  # Minimum 100 words required
MAX_CONTENT_WORDS = 500  # Maximum 500 words strictly enforced

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


# ============================================================
# BANNED TOPICS & EXAM IRRELEVANCE REGEX FILTER
# ============================================================

BANNED_TOPICS_REGEX = r'\b(' + '|'.join([
    # Routine Defense Yards & Vessels (Non-Policy Routine Launches)
    r'patrol vessel', r'offshore patrol', r'ngopv', r'yard \d+', r'launch of next generation',
    # Speculative Finance & Private Commercial Market Rankings
    r'upi transaction', r'upi transactions', r'upi charges', r'top 5 indian states', r'ev registrations', r'ev adoption',
    # Fact Checks, Gossip & Viral Items
    r'fact check', r'fact-check', r'viral video', r'fake news',
    # Corporate Lawsuits, Scams & Stock Fluctuations
    r'corporate fraud', r'bribery', r'court lawsuit', r'adani', r'stock market', r'sensex', r'nifty', r'share price',
    # Foreign Visa & Local Protests/Clashes
    r'visa policy', r'immigration rule', r'lathi-charge', r'lathi charge', r'protest', r'student strike', r'bandh'
]) + r')\b'


def is_topic_banned(title, content):
    """Returns True if news contains exam-irrelevant or banned topic keywords."""
    combined_text = f"{title} {content}".lower()
    if re.search(BANNED_TOPICS_REGEX, combined_text, flags=re.IGNORECASE):
        return True
    return False


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


def word_count(text):
    """Calculates exact word count in text"""
    if not text:
        return 0
    return len(re.findall(r'\S+', text))


def process_content_limits(text, min_words=100, max_words=500):
    """
    Enforces minimum and maximum word limits:
    - Trims text to max_words if longer than max_words.
    - Discards text if shorter than min_words.
    """
    text = clean_text(text)
    total_words = word_count(text)

    if total_words < min_words:
        return "", 0  # Rejects content shorter than 100 words

    words = text.split()
    if len(words) > max_words:
        text = " ".join(words[:max_words]) + "..."
        total_words = max_words

    return text, total_words


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

            return clean_text(full_text)

    except Exception as e:
        print(f"  ⚠️ Could not fetch full webpage content for {target_url[:40]}: {e}")

    return ""


def parse_feed_date(entry):
    """Published date format matching rawnews.json standard"""
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        dt = datetime(*entry.published_parsed[:6])
        return dt.strftime("%a, %d %b %Y %H:%M:%S IST")
    return datetime.now(IST).strftime("%a, %d %b %Y %H:%M:%S IST")


def load_existing_raw_news():
    """`rawnews.json` load karta hai, agar file na mile toh default structure banata hai"""
    if os.path.exists(RAW_NEWS_FILE):
        try:
            with open(RAW_NEWS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"⚠️ Could not read {RAW_NEWS_FILE}, creating fresh structure. Error: {e}")

    return {
        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": 0,
        "national_raw_count": 0,
        "total_raw_count": 0,
        "bihar_raw_news": [],
        "national_raw_news": [],
        "source_breakdown": {}
    }


def scrape_pib_alerts():
    print(f"📡 Fetching Feed: {FEED_URL[:60]}...")
    feed = feedparser.parse(FEED_URL)

    entries = feed.entries
    print(f"📦 Total Feed Entries Found: {len(entries)}")

    # Load existing rawnews.json structure
    raw_data = load_existing_raw_news()
    existing_national = raw_data.get("national_raw_news", [])

    # Duplicate check using existing URLs
    seen_urls = {item.get("url") for item in existing_national if item.get("url")}
    added_count = 0
    rejected_count = 0

    for idx, entry in enumerate(entries, 1):
        raw_title = entry.get("title", "")
        raw_link = entry.get("link", "")
        feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

        clean_title_text = clean_text(BeautifulSoup(raw_title, "html.parser").get_text())
        real_target_url = extract_real_url(raw_link)
        formatted_date = parse_feed_date(entry)

        if not clean_title_text or not real_target_url:
            continue

        # Skip duplicate items
        if real_target_url in seen_urls:
            print(f"⏭️ Skipping duplicate: {clean_title_text[:40]}...")
            continue

        print(f"🌐 [{idx}/{len(entries)}] Scraping Full Page Content: {clean_title_text[:45]}...")
        
        # Open URL and Scrape Full Webpage Content
        raw_article_content = scrape_full_url_content(real_target_url)

        # Fallback to RSS snippet if URL scraping fails or is empty
        if not raw_article_content:
            raw_article_content = clean_text(BeautifulSoup(feed_snippet, "html.parser").get_text())

        # 🚫 BANNED TOPICS CHECK
        if is_topic_banned(clean_title_text, raw_article_content):
            print(f"🚫 Discarded (Banned Topic): {clean_title_text[:40]}...")
            rejected_count += 1
            continue

        # Enforce Minimum 100 Words and Maximum 500 Words Limits
        final_content, words_total = process_content_limits(
            raw_article_content, 
            min_words=MIN_CONTENT_WORDS, 
            max_words=MAX_CONTENT_WORDS
        )

        # Reject content if less than 100 words
        if not final_content or words_total < MIN_CONTENT_WORDS:
            print(f"🚫 Discarded (Too short: {words_total} words < {MIN_CONTENT_WORDS}): {clean_title_text[:40]}...")
            rejected_count += 1
            continue

        content_chars = len(final_content)

        # Target structure item
        item = {
            "source": "PIB India",
            "title": clean_title_text,
            "url": real_target_url,
            "date": formatted_date,
            "content": final_content,
            "content_chars": content_chars,
            "content_words": words_total,
            "type": "Press Release"
        }

        existing_national.append(item)
        seen_urls.add(real_target_url)
        added_count += 1

    # Update metadata
    raw_data["national_raw_news"] = existing_national
    raw_data["national_raw_count"] = len(existing_national)
    raw_data["bihar_raw_count"] = len(raw_data.get("bihar_raw_news", []))
    raw_data["total_raw_count"] = raw_data["national_raw_count"] + raw_data["bihar_raw_count"]
    raw_data["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")

    # Update source breakdown count
    source_breakdown = raw_data.get("source_breakdown", {})
    source_breakdown["PIB India"] = sum(1 for x in existing_national if x.get("source") == "PIB India")
    raw_data["source_breakdown"] = source_breakdown

    # Save output directly to rawnews.json
    with open(RAW_NEWS_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 70)
    print(f"💾 Appended {added_count} items to '{RAW_NEWS_FILE}' (Rejected/Skipped {rejected_count} items).")
    print(f"📊 Total National: {raw_data['national_raw_count']} | Grand Total: {raw_data['total_raw_count']}")
    print("=" * 70)


if __name__ == "__main__":
    scrape_pib_alerts()
