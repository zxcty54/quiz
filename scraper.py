import os
import json
import re
import time
import base64
import hashlib
import feedparser
import warnings
from urllib.parse import quote
from datetime import datetime, timedelta, timezone

from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# Safe import for googlenewsdecoder if available
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
TIMEOUT = 25
MAX_PER_CATEGORY = 10

MIN_CONTENT_WORDS = 35      # Min 35 words for valid news
MAX_CONTENT_WORDS = 2000    # Max 2000 words limit

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
# TEXT CLEANING
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
    title = re.sub(r'\s*[-|–—]\s*(The Hindu|Indian Express|Hindustan Times|Times of India|NDTV|Aaj Tak|ABP News|PIB|Livemint|Business Standard).*$', '', title, flags=re.I)
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
# RELIABLE GOOGLE URL DECODER & NETWORK FETCHERS
# ============================================================

def fallback_decode_google_url(google_url):
    """Base64/String parser fallback for Google RSS URLs"""
    try:
        match = re.search(r'articles/([^?]+)', google_url)
        if match:
            encoded_str = match.group(1)
            # Add padding
            padded = encoded_str + '=' * (-len(encoded_str) % 4)
            decoded_bytes = base64.urlsafe_b64decode(padded)
            # Find URLs inside raw binary protobuf response
            urls = re.findall(rb'https?://[^\s"<>\\{}|^\x00-\x1f\x7f-\xff]+', decoded_bytes)
            for u in urls:
                u_str = u.decode('utf-8', errors='ignore')
                if "news.google.com" not in u_str and "google.com" not in u_str:
                    return u_str
    except Exception:
        pass
    return google_url

def get_real_publisher_url(google_rss_url):
    """Resolves google news RSS links to real domain"""
    if not google_rss_url or "news.google.com" not in google_rss_url:
        return google_rss_url

    # Method 1: Library
    if decoding_func is not None:
        try:
            decoded = decoding_func(google_rss_url)
            if isinstance(decoded, dict) and decoded.get("status") and decoded.get("decoded_url"):
                return decoded["decoded_url"]
            elif isinstance(decoded, str) and decoded.startswith("http"):
                return decoded
        except Exception:
            pass

    # Method 2: Custom Base64 Protobuf Parser
    decoded_url = fallback_decode_google_url(google_rss_url)
    if decoded_url and "news.google.com" not in decoded_url:
        return decoded_url

    # Method 3: HTTP Redirect Follow
    try:
        r = curl_requests.get(google_rss_url, headers=HEADERS, timeout=12, impersonate="chrome", allow_redirects=True)
        if r.url and "news.google.com" not in r.url:
            return r.url
    except Exception:
        pass

    return google_rss_url

def fetch_rss_xml(url):
    """Downloads RSS XML bypassing SSL / User-Agent blocks"""
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=15, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400 and r.text:
            return r.text
    except Exception:
        pass

    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=15, allow_redirects=True, verify=False)
        if r.status_code < 400 and r.text:
            return r.text
    except Exception:
        pass

    return None

def fetch_web_article(url):
    real_url = get_real_publisher_url(url)
    if not real_url or "news.google.com" in real_url: 
        return "", real_url

    # PIB Special URL Handling: Convert Iframe URL to Printable Full Page URL
    if "pib.gov.in" in real_url and "PressReleaseIframePage.aspx" in real_url:
        real_url = real_url.replace("PressReleaseIframePage.aspx", "PressReleasePage.aspx")

    html_raw = None
    try:
        r = curl_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400: html_raw = r.text
    except Exception:
        pass

    if not html_raw:
        try:
            r = normal_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
            if r.status_code < 400: html_raw = r.text
        except Exception:
            return "", real_url

    if not html_raw: return "", real_url

    soup = BeautifulSoup(html_raw, "lxml")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "form", "aside", "header"]):
        tag.decompose()

    candidates = []

    # 1. PIB Specific Selectors
    pib_selectors = [".ReleaseText", "#pnlPrint", "#ReleaseText", ".content-area", "#divPrint"]
    for sel in pib_selectors:
        for el in soup.select(sel):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # 2. JSON-LD Extraction
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

    # 3. Main Article Selectors
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main", ".entry-content",
        "#article-body", ".full-article", ".post-content", ".td-post-content"
    ]
    for selector in selectors:
        for el in soup.select(selector):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # 4. Paragraph Aggregation Fallback
    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if word_count(p) >= 6]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates: return "", real_url

    best_text = max(candidates, key=lambda t: word_count(t))
    return best_text, real_url

# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="General News", category="General"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_content_str or is_content_too_similar_to_title(clean_title_str, clean_content_str):
        warn(f"REJECTED (Content same as Title) | {clean_title_str[:50]}")
        return None

    total_words = word_count(clean_content_str)
    if total_words < MIN_CONTENT_WORDS:
        warn(f"REJECTED ({total_words} words < min {MIN_CONTENT_WORDS}) | {clean_title_str[:50]}")
        return None

    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        warn(f"REJECTED (Blacklisted: '{matched_bad_word}') | {clean_title_str[:50]}")
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
# MAIN SCRAPING PIPELINE
# ============================================================

NATIONAL_CATEGORIES = {
    "Polity & Governance": '("Supreme Court" OR "Cabinet Approves" OR "Act" OR "Bill")',
    "Govt Schemes & Welfare": '("Govt Scheme" OR "Pradhan Mantri" OR "Welfare")',
    "Economy & Banking": '("RBI Policy" OR "Union Budget" OR "Economic Survey" OR "GST Council")',
    "International Relations": '("Bilateral" OR "G20" OR "BRICS" OR "Quad" OR "Summit")',
    "Science, Tech & Defense": '("ISRO" OR "NASA" OR "Defense Exercise" OR "DRDO")',
    "Environment & Infrastructure": '("Ramsar Site" OR "Expressway" OR "Renewable Energy" OR "GI Tag")'
}

BIHAR_CATEGORIES = {
    "Bihar Schemes & Welfare": '("Bihar Scheme" OR "Mukhyamantri Scheme" OR "Bihar Welfare")',
    "Bihar Development": '("Bihar Expressway" OR "Patna Metro" OR "Bihar Infrastructure" OR "Bihar Development")'
}

PIB_HINDI_FEEDS = {
    "PIB General Release": "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1",
    "PIB Finance & Economy": "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"
}

def fetch_google_news_feed(categories_dict, source_label, is_bihar=False):
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING SOURCE: {source_label}\n" + "=" * 70)
    category_results = []

    for cat_name, query in categories_dict.items():
        encoded_q = quote(f"{query} when:3d")
        rss_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"

        xml_raw = fetch_rss_xml(rss_url)
        feed = feedparser.parse(xml_raw) if xml_raw else feedparser.parse(rss_url)
        entries = feed.entries or []
        debug(f"RSS returned {len(entries)} items for [{cat_name}]")

        count = 0
        for entry in entries[:MAX_PER_CATEGORY * 3]:
            title = clean_title(getattr(entry, 'title', ''))
            rss_link = clean_url(getattr(entry, 'link', ''))

            if not title or not rss_link: continue

            content, final_url = fetch_web_article(rss_link)

            if not content or word_count(content) < MIN_CONTENT_WORDS:
                warn(f"REJECTED (Scraping Failed/Blocked) | {title[:50]}")
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

def fetch_all_pib_news():
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING ALL PIB HINDI RELEASES\n" + "=" * 70)
    pib_results = []

    for feed_name, feed_url in PIB_HINDI_FEEDS.items():
        xml_raw = fetch_rss_xml(feed_url)
        feed = feedparser.parse(xml_raw) if xml_raw else feedparser.parse(feed_url)
        entries = feed.entries or []
        debug(f"PIB RSS returned {len(entries)} raw items for [{feed_name}]")

        for entry in entries:
            title = clean_title(getattr(entry, 'title', ''))
            link = clean_url(getattr(entry, 'link', ''))

            if not title or not link: continue

            content, final_url = fetch_web_article(link)

            if not content or word_count(content) < MIN_CONTENT_WORDS:
                continue

            obj = make_item(
                source="PIB Press Release",
                title=title,
                url=final_url or link,
                date=now_ist(),
                content=content,
                item_type="National News",
                category="PIB Release"
            )

            if obj:
                pib_results.append(obj)

    return deduplicate(pib_results)

def build_news():
    national = fetch_google_news_feed(NATIONAL_CATEGORIES, "National", is_bihar=False)
    pib_news = fetch_all_pib_news()
    
    national = deduplicate(national + pib_news)
    bihar = fetch_google_news_feed(BIHAR_CATEGORIES, "Bihar", is_bihar=True)

    breakdown = {
        "Google News National": len(national),
        "Google News Bihar": len(bihar),
        "PIB Releases": len(pib_news)
    }

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
    print(f"💾 {OUTPUT_FILE} saved successfully with {len(all_news)} full-length items!")
    print("=" * 80)

if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
