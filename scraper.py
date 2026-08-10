import os
import json
import re
import time
import hashlib
import feedparser
import warnings
from urllib.parse import quote, unquote, urlparse, parse_qs
from datetime import datetime, timedelta, timezone

from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "rawnews.json"
TIMEOUT = 25
MAX_PER_CATEGORY = 5

MIN_CONTENT_WORDS = 60      # Minimum 60 words (no short text)
MAX_CONTENT_WORDS = 1500    # Maximum 1500 words limit
DEFAULT_MAX_AGE_HOURS = 48  # 48 Hours window for stable daily news

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Connection": "keep-alive"
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

# ============================================================
# STRICT EXCLUSION BLACKLIST
# ============================================================

EXCLUDE_KEYWORDS = [
    "murder", "police", "arrest", "theft", "accident", "rape", "crime", "fir", "killed", "dead", "gang",
    "bjp", "congress", "rjd", "jdu", "aap", "election campaign", "rally", "neta", "mp", "mla",
    "party", "opposition", "voter", "vote", "seat", "by-poll",
    "uttar pradesh", "up news", "madhya pradesh", "rajasthan", "maharashtra", "mumbai",
    "delhi news", "punjab", "haryana", "karnataka", "tamil nadu", "kerala", "gujarat", "bengal",
    "chief minister", "yogi", "siddaramaiah", "stalin", "mamata", "kejriwal", "hemant",
    "fadnavis", "shinde", "gehlot", "chouhan"
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
# TEXT & URL CLEANING
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
    title = re.sub(r'\s*[-|–—]\s*(The Hindu|Indian Express|Hindustan Times|Times of India|NDTV|Aaj Tak|ABP News|PIB).*$', '', title, flags=re.I)
    return title.strip()

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    words = re.findall(r'\S+', text)
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

# ============================================================
# GOOGLE LINK UNPACKER & WEB SCRAPER
# ============================================================

def resolve_real_url(google_url):
    """Resolves Google RSS redirect URL to actual news article URL"""
    try:
        r = curl_requests.get(google_url, headers=HEADERS, timeout=12, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400 and r.url and "news.google.com" not in r.url:
            return r.url, r.text
        return google_url, r.text
    except Exception:
        return google_url, None

def fetch_web_article(url):
    url = clean_url(url)
    if not url: return "", ""

    resolved_url, html_raw = resolve_real_url(url)
    
    if not html_raw:
        try:
            r = normal_requests.get(resolved_url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
            if r.status_code < 400:
                html_raw = r.text
        except Exception:
            return "", resolved_url

    if not html_raw: return "", resolved_url

    soup = BeautifulSoup(html_raw, "lxml")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "form", "aside", "header"]):
        tag.decompose()

    candidates = []

    # 1. JSON-LD Body
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objects = data if isinstance(data, list) else [data]
            for obj in objects:
                if isinstance(obj, dict) and obj.get("articleBody"):
                    candidates.append(clean_text(obj.get("articleBody")))
        except Exception:
            pass

    # 2. Main Article Selectors
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main", ".entry-content"
    ]
    for selector in selectors:
        for el in soup.select(selector):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # 3. Paragraph Fallback
    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if word_count(p) >= 8]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates: return "", resolved_url

    best_text = max(candidates, key=lambda t: word_count(t))
    return best_text, resolved_url

# ============================================================
# ITEM BUILDER (STRICT VALIDATION)
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Google News", category="General"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    # STRICT CHECK 1: Title & Content must NOT be same / empty
    if not clean_content_str or clean_content_str.lower() == clean_title_str.lower():
        warn(f"REJECTED (Content same as title or empty) | Title: {clean_title_str[:50]}")
        return None

    # STRICT CHECK 2: Minimum word count threshold
    total_words = word_count(clean_content_str)
    if total_words < MIN_CONTENT_WORDS:
        warn(f"REJECTED (Too Short: {total_words} words < min {MIN_CONTENT_WORDS}) | Title: {clean_title_str[:50]}")
        return None

    # STRICT CHECK 3: Max 1500 words limit
    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    # STRICT CHECK 4: Exclusion Filter
    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        warn(f"REJECTED (Blacklisted: '{matched_bad_word}') | Title: {clean_title_str[:50]}")
        return None

    parsed_date = date or now_ist()

    success(f"ACCEPTED | Words: {word_count(clean_content_str)} | Title: {clean_title_str[:50]}")

    return {
        "source": source,
        "category": category,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": parsed_date.strftime("%a, %d %b %Y %H:%M:%S GMT"),
        "content": clean_content_str,
        "content_chars": len(clean_content_str),
        "content_words": word_count(clean_content_str),
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
# CATEGORY DEFINITIONS & PIB SOURCES
# ============================================================

NATIONAL_CATEGORIES = {
    "Polity & Governance": '("Supreme Court" OR "Act" OR "Bill" OR "Constitutional Amendment")',
    "Govt Schemes & Welfare": '("Govt Scheme" OR "Pradhan Mantri" OR "Cabinet Approves")',
    "Economy & Banking": '("RBI Policy" OR "Union Budget" OR "Economic Survey" OR "GST Council")',
    "International Relations": '("Bilateral" OR "G20" OR "BRICS" OR "Quad" OR "Summit")',
    "Science, Tech & Defense": '("ISRO" OR "NASA" OR "Defense Exercise" OR "DRDO")',
    "Environment & Infrastructure": '("Ramsar Site" OR "Expressway" OR "Renewable Energy" OR "GI Tag")'
}

BIHAR_CATEGORIES = {
    "Bihar Schemes & Welfare": '("Bihar Scheme" OR "Mukhyamantri Scheme" OR "Bihar Welfare")',
    "Bihar Development": '("Bihar Expressway" OR "Patna Metro" OR "Bihar Infrastructure" OR "Bihar Development")'
}

# Guaranteed Government Source (PIB RSS)
PIB_FEEDS = {
    "Govt Schemes & Welfare": "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1",
    "Polity & Governance": "https://pib.gov.in/RssMain.aspx?ModId=1&Lang=1",
}

def fetch_pib_news():
    print(f"\n🌐 SCRAPING DIRECT GOVT SOURCE: PIB India")
    pib_items = []
    for cat_name, rss_url in PIB_FEEDS.items():
        feed = feedparser.parse(rss_url)
        for entry in (feed.entries or [])[:3]:
            title = clean_title(getattr(entry, 'title', ''))
            link = clean_url(getattr(entry, 'link', ''))
            if not title or not link: continue

            content, final_url = fetch_web_article(link)
            if content and word_count(content) >= MIN_CONTENT_WORDS:
                obj = make_item(
                    source="PIB India",
                    title=title,
                    url=final_url or link,
                    date=now_ist(),
                    content=content,
                    item_type="National News",
                    category=cat_name
                )
                if obj: pib_items.append(obj)
    return pib_items

def fetch_google_news_feed(categories_dict, source_label, is_bihar=False):
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING SOURCE: {source_label}\n" + "=" * 70)
    category_results = []

    for cat_name, query in categories_dict.items():
        encoded_q = quote(f"{query} when:3d")  # 3 days window for rich candidate availability
        rss_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"

        feed = feedparser.parse(rss_url)
        entries = feed.entries or []
        debug(f"RSS returned {len(entries)} items for [{cat_name}]")

        count = 0
        for entry in entries[:MAX_PER_CATEGORY * 4]:
            title = clean_title(getattr(entry, 'title', ''))
            rss_link = clean_url(getattr(entry, 'link', ''))

            if not title or not rss_link: continue

            # Direct Web Scrape with Google URL Decoder
            content, final_url = fetch_web_article(rss_link)

            # Strict Drop if < 60 words
            if not content or word_count(content) < MIN_CONTENT_WORDS:
                continue

            obj = make_item(
                source="Google News Central" if not is_bihar else "Google News Bihar",
                title=title,
                url=final_url or rss_link,
                date=now_ist(),
                content=content,
                item_type="National News" if not is_bihar else "Bihar News",
                category=cat_name
            )

            if obj:
                category_results.append(obj)
                count += 1

            if count >= MAX_PER_CATEGORY:
                break

    return deduplicate(category_results)

def build_news():
    national = fetch_google_news_feed(NATIONAL_CATEGORIES, "National", is_bihar=False)
    pib = fetch_pib_news()
    bihar = fetch_google_news_feed(BIHAR_CATEGORIES, "Bihar", is_bihar=True)

    national_all = deduplicate(national + pib)

    breakdown = {
        "Google News National": len(national),
        "PIB Govt Portal": len(pib),
        "Google News Bihar": len(bihar)
    }

    return national_all, bihar, breakdown

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
    print(f"💾 {OUTPUT_FILE} saved successfully with {len(all_news)} full-length items!")
    print("=" * 80)

if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
