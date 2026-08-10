import os
import json
import re
import time
import base64
import hashlib
import feedparser
import warnings
from collections import defaultdict
from urllib.parse import quote
from datetime import datetime, timedelta, timezone

from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# Safe import for googlenewsdecoder
decoding_func = None
try:
    from googlenewsdecoder import new_decodurl as decoding_func
except ImportError:
    try:
        from googlenewsdecoder.new_decodurl import new_decodurl as decoding_func
    except ImportError:
        decoding_func = None

# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "rawnews.json"
TIMEOUT = 20
MAX_PER_SOURCE = 10

MIN_CONTENT_WORDS = 60      # Strictly Minimum 60 words required
MAX_CONTENT_WORDS = 2000    # Maximum 2000 words limit

# STRICT 24-HOUR ROLLING WINDOW
DEFAULT_MAX_AGE_HOURS = 24

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Referer": "https://www.google.com/",
    "Upgrade-Insecure-Requests": "1"
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

# Source Performance Tracking
SOURCE_STATS = defaultdict(lambda: {"fetched": 0, "accepted": 0, "rejected": 0, "reasons": defaultdict(int)})

# ============================================================
# EXCLUDE KEYWORDS BLACKLIST (Crime & Non-Bihar Local States)
# ============================================================

EXCLUDE_KEYWORDS = [
    "murder", "police", "arrest", "theft", "accident", "rape", "crime", "fir", "killed", "dead", "gang",
    "bjp", "congress", "rjd", "jdu", "aap", "election campaign", "rally", "neta", "mp", "mla",
    "party", "opposition", "voter", "vote", "seat", "by-poll",
    "uttar pradesh news", "madhya pradesh news", "rajasthan news", "maharashtra news", "mumbai news",
    "delhi news", "punjab news", "haryana news", "karnataka news", "tamil nadu news", "kerala news"
]

def check_blacklist_reason(title, content=""):
    text = (title + " " + content).lower()
    for bad_word in EXCLUDE_KEYWORDS:
        if re.search(r'\b' + re.escape(bad_word) + r'\b', text):
            return bad_word
    return None

def now_ist(): return datetime.now(IST)
def debug(msg): print(f"🔍 {msg}")
def warn(msg): print(f"⚠️ {msg}")
def success(msg): print(f"✅ {msg}")

# ============================================================
# DATE PARSER & 24-HOUR FILTER ENGINE
# ============================================================

DATE_FORMATS = [
    "%a, %d %b %Y %H:%M:%S %z",
    "%a, %d %b %Y %H:%M:%S GMT",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S.%f%z",
    "%Y-%m-%d %H:%M:%S",
    "%d-%b-%Y", "%d-%B-%Y", "%d/%m/%Y", "%d-%m-%Y",
    "%Y-%m-%d", "%d %b %Y", "%d %B %Y"
]

def parse_date(value):
    if not value:
        return None

    value = clean_text(str(value))
    lower_val = value.lower()
    current_now = now_ist()

    if any(k in lower_val for k in ["ago", "today", "yesterday", "घंटे पहले", "दिन पहले", "आज", "कल"]):
        if "today" in lower_val or "आज" in lower_val:
            return current_now
        if "yesterday" in lower_val or "कल" in lower_val:
            return current_now - timedelta(days=1)

        match = re.search(r'(\d+)\s*(hour|hr|day|min|minute|घंटे|मिनट|दिन)s?\s*(ago|पहले)?', lower_val)
        if match:
            num = int(match.group(1))
            unit = match.group(2)
            if "day" in unit or "दिन" in unit:
                return current_now - timedelta(days=num)
            elif "hour" in unit or "hr" in unit or "घंटे" in unit:
                return current_now - timedelta(hours=num)
            elif "min" in unit or "मिनट" in unit:
                return current_now - timedelta(minutes=num)

    value2 = re.sub(r'\b(IST|GMT|UTC)\b', '', value, flags=re.I).strip()

    for fmt in DATE_FORMATS:
        try:
            d = datetime.strptime(value2, fmt)
            if d.tzinfo is None:
                d = d.replace(tzinfo=IST)
            return d.astimezone(IST)
        except Exception:
            continue

    return None

def get_age_hours(parsed_date):
    if not parsed_date:
        return 0.0
    current_time = now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)
    time_difference = current_time - parsed_date
    return time_difference.total_seconds() / 3600.0

def is_within_24_hours(parsed_date, max_age_hours=DEFAULT_MAX_AGE_HOURS):
    if not parsed_date:
        return True
    hours_diff = get_age_hours(parsed_date)
    return -24.0 <= hours_diff <= max_age_hours

# ============================================================
# TEXT CLEANING & HELPERS
# ============================================================

def clean_url(url):
    if not url: return ""
    url = str(url).strip()
    m = re.search(r'\]\((https?://[^)]+)\)', url)
    if m: url = m.group(1)
    url = re.sub(r'^\[.*?\]\(', '', url)
    url = re.sub(r'\)$', '', url)
    return url if url.startswith(("http://", "https://")) else ""

def clean_text(text):
    if not text: return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return re.sub(r'\s+', ' ', text).strip()

def clean_title(title):
    title = clean_text(title)
    title = re.sub(r'\s*[-|–—]\s*(The Hindu|Indian Express|Hindustan Times|Times of India|NDTV|Aaj Tak|ABP News|PIB|Livemint|Business Standard|Dainik Jagran|Amar Ujala).*$', '', title, flags=re.I)
    return title.strip()

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    words = re.findall(r'\S+', text)
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

def is_content_too_similar_to_title(title, content):
    title_words = set(re.findall(r'\w+', title.lower()))
    content_words = set(re.findall(r'\w+', content.lower()))
    if not title_words or not content_words: return True
    overlap = title_words.intersection(content_words)
    if len(overlap) / len(title_words) > 0.75 and len(content_words) < len(title_words) + 10:
        return True
    return False

# ============================================================
# GOOGLE RSS URL DECODER & NETWORK FETCHERS
# ============================================================

def fallback_decode_google_url(google_url):
    try:
        match = re.search(r'articles/([^?]+)', google_url)
        if match:
            encoded_str = match.group(1)
            padded = encoded_str + '=' * (-len(encoded_str) % 4)
            decoded_bytes = base64.urlsafe_b64decode(padded)
            urls = re.findall(rb'https?://[^\s"<>\\{}|^\x00-\x1f\x7f-\xff]+', decoded_bytes)
            for u in urls:
                u_str = u.decode('utf-8', errors='ignore')
                if "news.google.com" not in u_str and "google.com" not in u_str:
                    return u_str
    except Exception:
        pass
    return google_url

def get_real_publisher_url(google_rss_url):
    if not google_rss_url or "news.google.com" not in google_rss_url:
        return google_rss_url

    if decoding_func is not None:
        try:
            decoded = decoding_func(google_rss_url)
            if isinstance(decoded, dict) and decoded.get("status") and decoded.get("decoded_url"):
                return decoded["decoded_url"]
            elif isinstance(decoded, str) and decoded.startswith("http"):
                return decoded
        except Exception:
            pass

    decoded_url = fallback_decode_google_url(google_rss_url)
    if decoded_url and "news.google.com" not in decoded_url:
        return decoded_url

    try:
        r = curl_requests.get(google_rss_url, headers=HEADERS, timeout=10, impersonate="chrome", allow_redirects=True)
        if r.url and "news.google.com" not in r.url:
            return r.url
    except Exception:
        pass

    return google_rss_url

def fetch_rss_xml(url):
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=12, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400 and r.text:
            return r.text
    except Exception:
        pass

    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=12, allow_redirects=True, verify=False)
        if r.status_code < 400 and r.text:
            return r.text
    except Exception:
        pass

    return None

# ============================================================
# WEB SCRAPER ENGINE
# ============================================================

def fetch_web_article(url, source_name="Unknown"):
    real_url = get_real_publisher_url(url)
    if not real_url or "news.google.com" in real_url: 
        warn(f"[{source_name}] Failed to resolve Google URL: {url[:50]}")
        return "", real_url

    html_raw = None
    try:
        r = curl_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400: 
            html_raw = r.text
        else:
            warn(f"[{source_name}] HTTP {r.status_code} for {real_url[:50]}")
    except Exception as e:
        pass

    if not html_raw:
        try:
            r = normal_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
            if r.status_code < 400: 
                html_raw = r.text
            else:
                warn(f"[{source_name}] Fallback HTTP {r.status_code} for {real_url[:50]}")
        except Exception as e:
            warn(f"[{source_name}] Request Failed: {e}")
            return "", real_url

    if not html_raw: 
        return "", real_url

    soup = BeautifulSoup(html_raw, "lxml")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "form", "aside", "header"]):
        tag.decompose()

    candidates = []

    # 1. JSON-LD Extraction
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objects = data if isinstance(data, list) else [data]
            for obj in objects:
                if isinstance(obj, dict) and obj.get("articleBody"):
                    txt = clean_text(obj.get("articleBody"))
                    if word_count(txt) >= MIN_CONTENT_WORDS:
                        candidates.append(txt)
        except Exception:
            pass

    # 2. Article Body Selectors
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main", ".entry-content",
        "#article-body", ".full-article", ".post-content", ".td-post-content",
        ".artText", ".story-description", ".content_text"
    ]
    for selector in selectors:
        for el in soup.select(selector):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # 3. Paragraph Aggregation Fallback
    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if word_count(p) >= 6]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates: 
        return "", real_url

    best_text = max(candidates, key=lambda t: word_count(t))
    return best_text, real_url

# ============================================================
# ITEM BUILDER WITH DEBUG LOGGING
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="General News", category="General"):
    SOURCE_STATS[source]["fetched"] += 1
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_content_str:
        reason = "Empty Content / Scraping Failed"
        warn(f"❌ REJECTED [{source}] ({reason}) | {clean_title_str[:50]}")
        SOURCE_STATS[source]["rejected"] += 1
        SOURCE_STATS[source]["reasons"][reason] += 1
        return None

    if is_content_too_similar_to_title(clean_title_str, clean_content_str):
        reason = "Content Same as Title"
        warn(f"❌ REJECTED [{source}] ({reason}) | {clean_title_str[:50]}")
        SOURCE_STATS[source]["rejected"] += 1
        SOURCE_STATS[source]["reasons"][reason] += 1
        return None

    # STRICT CHECK 1: Minimum word count check (>= 60 words)
    total_words = word_count(clean_content_str)
    if total_words < MIN_CONTENT_WORDS:
        reason = f"Word count too low ({total_words} < {MIN_CONTENT_WORDS})"
        warn(f"❌ REJECTED [{source}] ({reason}) | {clean_title_str[:50]}")
        SOURCE_STATS[source]["rejected"] += 1
        SOURCE_STATS[source]["reasons"][reason] += 1
        return None

    # STRICT CHECK 2: Last 24 Hours Date Filter Check
    parsed_date = date or now_ist()
    age_hrs = round(get_age_hours(parsed_date), 1)
    if not is_within_24_hours(parsed_date):
        reason = f"Date older than 24h ({age_hrs} hrs old)"
        warn(f"❌ REJECTED [{source}] ({reason}) | {clean_title_str[:50]}")
        SOURCE_STATS[source]["rejected"] += 1
        SOURCE_STATS[source]["reasons"][reason] += 1
        return None

    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    # STRICT CHECK 3: Blacklist Check
    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        reason = f"Blacklisted word: '{matched_bad_word}'"
        warn(f"❌ REJECTED [{source}] ({reason}) | {clean_title_str[:50]}")
        SOURCE_STATS[source]["rejected"] += 1
        SOURCE_STATS[source]["reasons"][reason] += 1
        return None

    success(f"✅ ACCEPTED [{source}] ({total_words} words | {age_hrs}h old) | Title: {clean_title_str[:50]}")
    SOURCE_STATS[source]["accepted"] += 1

    return {
        "source": source,
        "category": category,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": parsed_date.strftime("%a, %d %b %Y %H:%M:%S GMT"),
        "content": clean_content_str,
        "content_chars": len(clean_content_str),
        "content_words": total_words,
        "type": item_type,
    }

def deduplicate(items):
    seen = set()
    output = []
    for item in items:
        key = item.get("url") or item.get("title")
        key_hash = hashlib.sha1(key.lower().encode("utf-8")).hexdigest()
        if key_hash not in seen:
            seen.add(key_hash)
            output.append(item)
    return output

# ============================================================
# COMPREHENSIVE PUBLIC RSS FEEDS LIST (24H WINDOW FILTER)
# ============================================================

PUBLIC_RSS_SOURCES = {
    # Direct Media RSS Feeds
    "The Hindu National": ("National News", "https://www.thehindu.com/news/national/feeder/default.rss"),
    "The Hindu Business": ("Economy & Banking", "https://www.thehindu.com/business/feeder/default.rss"),
    "Indian Express National": ("National News", "https://indianexpress.com/section/india/feed/"),
    "Indian Express Economy": ("Economy & Banking", "https://indianexpress.com/section/business/economy/feed/"),
    "Business Standard": ("Economy & Banking", "https://www.business-standard.com/rss/home_page_top_stories.rss"),
    "Livemint Economy": ("Economy & Banking", "https://www.livemint.com/rss/news"),
    "Times of India India": ("National News", "https://timesofindia.indiatimes.com/rssfeeds/-2128936835.cms"),
    "Aaj Tak National (Hindi)": ("National News", "https://www.aajtak.in/rss/national-news.xml"),
    "Amar Ujala National (Hindi)": ("National News", "https://www.amarujala.com/rss/national-news.xml"),
    "Dainik Jagran National (Hindi)": ("National News", "https://www.jagran.com/rss/news/national.xml"),
    "NDTV India": ("National News", "https://feeds.feedburner.com/ndtvnews-india-news"),
    
    # Google News Targeted Categories
    "GNews Polity": ("Polity & Governance", "https://news.google.com/rss/search?q=Supreme+Court+OR+Act+OR+Bill+when:1d&hl=en-IN&gl=IN&ceid=IN:en"),
    "GNews Schemes": ("Govt Schemes & Welfare", "https://news.google.com/rss/search?q=Govt+Scheme+OR+Pradhan+Mantri+OR+Welfare+when:1d&hl=en-IN&gl=IN&ceid=IN:en"),
    "GNews Science Tech": ("Science, Tech & Defense", "https://news.google.com/rss/search?q=ISRO+OR+NASA+OR+DRDO+OR+Defense+when:1d&hl=en-IN&gl=IN&ceid=IN:en"),
    "GNews Environment": ("Environment & Infrastructure", "https://news.google.com/rss/search?q=Ramsar+Site+OR+Expressway+OR+Renewable+Energy+when:1d&hl=en-IN&gl=IN&ceid=IN:en"),
    "GNews Bihar Schemes": ("Bihar Schemes", "https://news.google.com/rss/search?q=Bihar+scheme+OR+Mukhyamantri+yojana+OR+Bihar+welfare+when:1d&hl=hi&gl=IN&ceid=IN:hi"),
    "GNews Bihar Development": ("Bihar Development", "https://news.google.com/rss/search?q=Patna+Metro+OR+Bihar+expressway+OR+Bihar+infrastructure+when:1d&hl=hi&gl=IN&ceid=IN:hi")
}

def fetch_all_public_rss():
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING ALL PUBLIC RSS SOURCES (DEBUG ENABLED)\n" + "=" * 70)
    all_results = []

    for source_name, (category, rss_url) in PUBLIC_RSS_SOURCES.items():
        print(f"\n📡 Connecting to RSS Source: [{source_name}]")
        xml_raw = fetch_rss_xml(rss_url)
        feed = feedparser.parse(xml_raw) if xml_raw else feedparser.parse(rss_url)
        entries = feed.entries or []
        
        if not entries:
            warn(f"⚠️ [{source_name}] Returned 0 RSS items!")
            continue
            
        debug(f"[{source_name}] Found {len(entries)} items in feed. Processing top {MAX_PER_SOURCE}...")

        for entry in entries[:MAX_PER_SOURCE]:
            title = clean_title(getattr(entry, 'title', ''))
            link = clean_url(getattr(entry, 'link', ''))
            pub_date = parse_date(getattr(entry, 'published', None) or getattr(entry, 'updated', None))

            if not title or not link: continue

            # Direct Web Extraction
            content, final_url = fetch_web_article(link, source_name)

            obj = make_item(
                source=source_name,
                title=title,
                url=final_url or link,
                date=pub_date or now_ist(),
                content=content,
                item_type="Bihar News" if "Bihar" in source_name else "National News",
                category=category
            )

            if obj:
                all_results.append(obj)

    return deduplicate(all_results)

def print_source_performance_summary():
    print("\n" + "=" * 80)
    print("📊 SOURCE ACCURACY & PERFORMANCE SUMMARY")
    print("=" * 80)
    print(f"{'Source Name':<32} | {'Fetched':<8} | {'Accepted':<8} | {'Rejected':<8} | {'Status'}")
    print("-" * 80)

    for source_name in PUBLIC_RSS_SOURCES.keys():
        stats = SOURCE_STATS[source_name]
        fetched = stats["fetched"]
        accepted = stats["accepted"]
        rejected = stats["rejected"]

        if fetched == 0:
            status = "❌ BROKEN (0 Items)"
        elif accepted == 0:
            status = "⚠️ ALL REJECTED"
        elif accepted / fetched >= 0.5:
            status = "✅ EXCELLENT"
        else:
            status = "⚠️ POOR YIELD"

        print(f"{source_name:<32} | {fetched:<8} | {accepted:<8} | {rejected:<8} | {status}")
    print("=" * 80)

def build_news():
    raw_items = fetch_all_public_rss()
    
    national = [item for item in raw_items if item["type"] == "National News"]
    bihar = [item for item in raw_items if item["type"] == "Bihar News"]

    breakdown = {
        "National Accepted (<24h)": len(national),
        "Bihar Accepted (<24h)": len(bihar)
    }

    print_source_performance_summary()
    return national, bihar, breakdown

def save_output(national, bihar, breakdown):
    all_news = national + bihar

    output = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": len(bihar),
        "national_raw_count": len(national),
        "total_raw_count": len(all_news),
        "bihar_raw_news": bihar,
        "national_raw_news": national,
        "source_breakdown": breakdown,
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 {OUTPUT_FILE} saved successfully with {len(all_news)} items (>60 words & <24h old)!")
    print("=" * 80)

if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
