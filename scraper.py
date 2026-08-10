import os
import json
import re
import time
import feedparser
import ssl
import html
import warnings
import hashlib
from urllib.parse import quote, urljoin, urlparse, parse_qs
from datetime import datetime, timedelta, timezone

from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# Safe import for googlenewsdecoder across different package versions
try:
    from googlenewsdecoder.new_decodurl import new_decodurl
except ImportError:
    try:
        from googlenewsdecoder import new_decodurl
    except ImportError:
        new_decodurl = None

# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "rawnews.json"
TIMEOUT = 25
MAX_PER_CATEGORY = 5

# Word Count Rules
MIN_CONTENT_WORDS = 50       # Full article min 50 words
MIN_SUMMARY_WORDS = 20       # Fallback summary min 20 words
MAX_CONTENT_WORDS = 1000     # Max 1000 words

# Rolling Window Limit (4 Days / 96 Hours)
DEFAULT_MAX_AGE_HOURS = 96

SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "").strip()

# Current date & time in IST
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Referer": "https://www.google.com/",
    "Connection": "keep-alive",
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)


# ============================================================
# EXCLUSION BLACKLIST (Crime, Sensational News, Other States)
# ============================================================

EXCLUDE_KEYWORDS = [
    # Crime & Incidents
    "murder", "arrest", "theft", "accident", "rape", "crime", "fir", "killed", "dead", "gangster",
    # Specific Non-Bihar State News
    "uttar pradesh news", "madhya pradesh news", "rajasthan news", "maharashtra news", "mumbai news",
    "delhi news", "punjab news", "haryana news", "karnataka news", "tamil nadu news", "kerala news"
]


def check_blacklist_reason(title, content=""):
    """Returns matched blacklisted keyword for debug logging"""
    text = (title + " " + content).lower()
    for bad_word in EXCLUDE_KEYWORDS:
        if re.search(r'\b' + re.escape(bad_word) + r'\b', text):
            return bad_word
    return None


# ============================================================
# TIME & DEBUG LOGGING
# ============================================================

def now_ist():
    return datetime.now(IST)


def debug(msg):
    print(f"🔍 {msg}")


def warn(msg):
    print(f"⚠️ {msg}")


def success(msg):
    print(f"✅ {msg}")


# ============================================================
# URL RESOLUTION & CLEANING
# ============================================================

def resolve_google_news_url(google_url):
    """Decodes news.google.com/rss/articles/... links into actual publisher URLs"""
    if not google_url:
        return ""
    if "news.google.com" not in google_url:
        return google_url

    # 1. Try decoding via googlenewsdecoder
    if new_decodurl is not None:
        try:
            res = new_decodurl(google_url)
            if isinstance(res, dict) and res.get("status"):
                decoded = res.get("decoded_url")
                if decoded:
                    return decoded
        except Exception as e:
            warn(f"googlenewsdecoder failed for {google_url}: {e}")

    # 2. Fallback: Request header redirect resolution
    try:
        r = curl_requests.get(
            google_url,
            headers=HEADERS,
            timeout=10,
            impersonate="chrome",
            allow_redirects=True
        )
        if r.url and "news.google.com" not in r.url:
            return r.url
    except Exception as e:
        warn(f"HTTP Redirect fallback failed for {google_url}: {e}")

    return google_url


def clean_url(url):
    if not url:
        return ""
    url = str(url).strip()
    m = re.search(r'\]\((https?://[^)]+)\)', url)
    if m:
        url = m.group(1)
    url = re.sub(r'^\[.*?\]\(', '', url)
    url = re.sub(r'\)$', '', url)
    url = url.replace("\\&", "&").replace("\\:", ":").replace("\\_", "_").strip()
    if url.startswith("javascript:") or url.startswith("mailto:"):
        return ""
    if not url.startswith(("http://", "https://")):
        return ""
    return url


def clean_text(text):
    if not text:
        return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return re.sub(r'\s+', ' ', text).strip()


def clean_title(title):
    title = clean_text(title)
    title = re.sub(
        r'\s*[-|–—]\s*(The Hindu|Indian Express|Hindustan Times|Times of India|NDTV|Aaj Tak|ABP News).*$',
        '',
        title,
        flags=re.I
    )
    return title.strip()


def word_count(text):
    if not text:
        return 0
    return len(re.findall(r'\S+', text))


def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    words = re.findall(r'\S+', text)
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text


def remove_common_boilerplate(text):
    if not text:
        return ""
    patterns = [
        r'Help Web Information Manager.*?(?=$)',
        r'We have tried to put most accurate.*?(?=$)',
        r'Website Information.*?(?=$)',
    ]
    for pattern in patterns:
        text = re.sub(pattern, "", text, flags=re.I)
    return clean_text(text)


# ============================================================
# DATE PARSER ENGINE
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


def extract_date_from_soup(soup):
    selectors = [
        "meta[property='article:published_time']",
        "meta[property='og:published_time']",
        "meta[name='publish-date']",
        "meta[name='date']",
        "time", ".date", ".published"
    ]

    for selector in selectors:
        try:
            elements = soup.select(selector)
        except Exception:
            continue

        for el in elements:
            value = el.get("content") or el.get("datetime") or el.get_text(" ", strip=True)
            d = parse_date(value)
            if d:
                return d
    return None


def is_within_rolling_window(parsed_date, max_age_hours=DEFAULT_MAX_AGE_HOURS):
    if not parsed_date:
        return True

    current_time = now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    time_difference = current_time - parsed_date
    hours_diff = time_difference.total_seconds() / 3600.0

    if -24.0 <= hours_diff <= max_age_hours:
        return True
    return False


# ============================================================
# FETCH ENGINE
# ============================================================

def normal_fetch(url, verify=True):
    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=verify)
        if r.status_code >= 400:
            return None
        return r.text
    except Exception:
        return None


def curl_fetch(url, verify=True):
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True, verify=verify)
        if r.status_code >= 400:
            return None
        return r.text
    except Exception:
        return None


def fetch_url(url):
    url = clean_url(url)
    if not url:
        return None

    html = curl_fetch(url, verify=True) or curl_fetch(url, verify=False)
    if html:
        return html

    html = normal_fetch(url, verify=True) or normal_fetch(url, verify=False)
    if html:
        return html

    return None


# ============================================================
# CONTENT EXTRACTION
# ============================================================

def extract_article_content(soup, source=""):
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside"]):
        tag.decompose()

    candidates = []
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main"
    ]

    for selector in selectors:
        try:
            elements = soup.select(selector)
        except Exception:
            continue

        for el in elements:
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    paragraphs = []
    for p in soup.find_all(["p", "li"]):
        txt = clean_text(p.get_text(" ", strip=True))
        if word_count(txt) >= 8:
            paragraphs.append(txt)

    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates:
        return ""

    best = max(candidates, key=lambda x: len(x))
    return clean_text(best)


def fetch_generic_article_content(url, source=""):
    url = clean_url(url)
    if not url:
        return "", None

    html_raw = fetch_url(url)
    if not html_raw:
        return "", None

    soup = BeautifulSoup(html_raw, "lxml")
    date = extract_date_from_soup(soup)
    content = extract_article_content(soup, source)

    words = word_count(content)
    if words >= MIN_CONTENT_WORDS:
        success(f"{source} SCRAPED SUCCESSFULLY | {words} words")
        return content, date

    return "", None


# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Google News", category="General", ignore_time_filter=False):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_content_str or clean_content_str.lower() == clean_title_str.lower():
        return None

    total_words = word_count(clean_content_str)
    if total_words < MIN_SUMMARY_WORDS:
        return None

    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        warn(f"{source} REJECTED (Blacklist Word: '{matched_bad_word}') | Title: {clean_title_str[:50]}")
        return None

    parsed_date = date or parse_date(clean_title_str) or now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)

    if not ignore_time_filter and not is_within_rolling_window(parsed_date):
        return None

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


# ============================================================
# DEDUPLICATION
# ============================================================

def deduplicate(items):
    seen = set()
    output = []
    for item in items:
        key = item.get("url") or item.get("title")
        hash_key = hashlib.sha1(key.encode("utf-8")).hexdigest()
        if hash_key in seen:
            continue
        seen.add(hash_key)
        output.append(item)
    return output


# ============================================================
# GOOGLE NEWS CATEGORIES
# ============================================================

NATIONAL_CATEGORIES = {
    "Polity & Governance": 'Supreme Court OR "Election Commission" OR "Bill Passed"',
    "Govt Schemes & Welfare": '"Govt Scheme" OR "Pradhan Mantri" OR "Welfare Policy"',
    "Economy & Banking": '"RBI Policy" OR "Union Budget" OR "GST Council" OR Inflation',
    "International Relations": 'Bilateral OR G20 OR BRICS OR SCO OR Summit',
    "Science, Tech & Defense": 'ISRO OR NASA OR DRDO OR "Defense Exercise"',
    "Environment & GI Tags": '"Ramsar Site" OR "Tiger Reserve" OR "GI Tag"',
    "Infrastructure & Energy": 'Expressway OR "Renewable Energy" OR "Smart City"',
    "Awards & Indexes": '"Global Index" OR Rankings OR "National Award"'
}

BIHAR_CATEGORIES = {
    "Bihar Schemes & Welfare": '"Bihar Scheme" OR "Mukhyamantri Scheme" OR "Bihar Welfare"',
    "Bihar Infrastructure & Development": '"Bihar Expressway" OR "Patna Metro" OR "Bihar Infrastructure"',
    "Bihar Environment & GI Tags": '"Bihar GI Tag" OR "Bihar Tiger Reserve" OR "Bihar Ramsar"'
}


def fetch_google_news_feed(categories_dict, source_label, is_bihar=False):
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING: {source_label}\n" + "=" * 70)
    category_results = []

    for cat_name, query in categories_dict.items():
        print(f"\n🔎 Category: {cat_name}")
        encoded_q = quote(query)
        rss_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"

        feed = feedparser.parse(rss_url)
        entries = feed.entries or []
        debug(f"RSS Returned {len(entries)} raw items for [{cat_name}]")

        count = 0
        for entry in entries[:MAX_PER_CATEGORY * 2]:
            title = clean_title(getattr(entry, 'title', ''))
            raw_url = clean_url(getattr(entry, 'link', ''))

            if not title or not raw_url:
                continue

            url = resolve_google_news_url(raw_url)
            content, date = fetch_generic_article_content(url, cat_name)

            # RSS Summary Fallback if scraping full article was unsuccessful
            if not content:
                summary = clean_text(getattr(entry, 'summary', '') or getattr(entry, 'description', ''))
                if summary.lower() != title.lower() and word_count(summary) >= MIN_SUMMARY_WORDS:
                    debug(f"Using RSS summary fallback ({word_count(summary)} words)")
                    content = summary

            if not content:
                continue

            rss_date = parse_date(getattr(entry, 'published', None))

            obj = make_item(
                source="Google News Central" if not is_bihar else "Google News Bihar",
                title=title,
                url=url,
                date=rss_date or date or now_ist(),
                content=content,
                item_type="National News" if not is_bihar else "Bihar News",
                category=cat_name
            )
            if obj:
                category_results.append(obj)
                count += 1

            if count >= MAX_PER_CATEGORY:
                break

        # Fallback without strict time filter if 0 items were matched
        if count == 0 and entries:
            for entry in entries[:2]:
                title = clean_title(getattr(entry, 'title', ''))
                raw_url = clean_url(getattr(entry, 'link', ''))
                url = resolve_google_news_url(raw_url)
                summary = clean_text(getattr(entry, 'summary', '') or getattr(entry, 'description', ''))
                
                content, date = fetch_generic_article_content(url, cat_name)
                if not content and word_count(summary) >= MIN_SUMMARY_WORDS:
                    content = summary

                if content and title:
                    obj = make_item(
                        source="Google News Central" if not is_bihar else "Google News Bihar",
                        title=title,
                        url=url,
                        date=parse_date(getattr(entry, 'published', None)) or now_ist(),
                        content=content,
                        item_type="National News" if not is_bihar else "Bihar News",
                        category=cat_name,
                        ignore_time_filter=True
                    )
                    if obj:
                        category_results.append(obj)

    return deduplicate(category_results)


def build_news():
    national = fetch_google_news_feed(NATIONAL_CATEGORIES, "National News", is_bihar=False)
    bihar = fetch_google_news_feed(BIHAR_CATEGORIES, "Bihar News", is_bihar=True)

    breakdown = {
        "Google News National": len(national),
        "Google News Bihar": len(bihar)
    }

    print("\n📊 FINAL SUMMARY")
    print(f"National Accepted : {len(national)}")
    print(f"Bihar Accepted    : {len(bihar)}")

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

    print(f"💾 {OUTPUT_FILE} saved successfully with {len(all_news)} records.")


if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
