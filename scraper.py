import os
import json
import re
import time
import hashlib
import feedparser
import ssl
import html
import warnings
from urllib.parse import quote, urljoin, urlparse, parse_qs
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

# Strict Word Count Rules
MIN_CONTENT_WORDS = 40      # Min 40 words (Slightly relaxed to avoid zero-item failures)
MAX_CONTENT_WORDS = 1500    # Max 1500 words limit

# Rolling Window Limit (1 Day / 24 Hours)
DEFAULT_MAX_AGE_HOURS = 24

# Current date & time in IST
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Connection": "keep-alive",
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)


# ============================================================
# STRICT EXCLUSION BLACKLIST (Crime, Daily Politics, CMs, Other States)
# ============================================================

EXCLUDE_KEYWORDS = [
    # Crime & Incidents
    "murder", "police", "arrest", "theft", "accident", "rape", "crime", "fir", "killed", "dead", "gang",
    # Local & Daily Politics
    "bjp", "congress", "rjd", "jdu", "aap", "election campaign", "rally", "neta", "mp", "mla",
    "party", "opposition", "voter", "vote", "seat", "by-poll",
    # Other States
    "uttar pradesh", "up news", "madhya pradesh", "mp news", "rajasthan", "maharashtra", "mumbai",
    "delhi news", "punjab", "haryana", "karnataka", "tamil nadu", "kerala", "gujarat", "bengal",
    # CM / Leader Names Blocking
    "chief minister", "cm", "yogi", "siddaramaiah", "stalin", "mamata", "kejriwal", "hemant",
    "fadnavis", "shinde", "gehlot", "chouhan"
]


def check_blacklist_reason(title, content=""):
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

def debug(msg): print(f"🔍 {msg}")
def warn(msg): print(f"⚠️ {msg}")
def success(msg): print(f"✅ {msg}")


# ============================================================
# URL & TEXT CLEANING
# ============================================================

def clean_url(url):
    if not url: return ""
    url = str(url).strip()
    m = re.search(r'\]\((https?://[^)]+)\)', url)
    if m: url = m.group(1)
    url = re.sub(r'^\[.*?\]\(', '', url)
    url = re.sub(r'\)$', '', url)
    url = url.replace("\\&", "&").replace("\\:", ":").replace("\\_", "_").strip()
    if url.startswith("javascript:") or url.startswith("mailto:"): return ""
    if not url.startswith(("http://", "https://")): return ""
    return url


def clean_text(text):
    if not text: return ""
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
    if not text: return 0
    return len(re.findall(r'\S+', text))


def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    words = re.findall(r'\S+', text)
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text


def remove_common_boilerplate(text):
    if not text: return ""
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
    if not value: return None
    value = clean_text(str(value))
    lower_val = value.lower()
    current_now = now_ist()

    if any(k in lower_val for k in ["ago", "today", "yesterday", "घंटे पहले", "दिन पहले", "आज", "कल"]):
        if "today" in lower_val or "आज" in lower_val: return current_now
        if "yesterday" in lower_val or "कल" in lower_val: return current_now - timedelta(days=1)
        match = re.search(r'(\d+)\s*(hour|hr|day|min|minute|घंटे|मिनट|दिन)s?\s*(ago|पहले)?', lower_val)
        if match:
            num = int(match.group(1))
            unit = match.group(2)
            if "day" in unit or "दिन" in unit: return current_now - timedelta(days=num)
            elif "hour" in unit or "hr" in unit or "घंटे" in unit: return current_now - timedelta(hours=num)
            elif "min" in unit or "मिनट" in unit: return current_now - timedelta(minutes=num)

    value2 = re.sub(r'\b(IST|GMT|UTC)\b', '', value, flags=re.I).strip()
    for fmt in DATE_FORMATS:
        try:
            d = datetime.strptime(value2, fmt)
            if d.tzinfo is None: d = d.replace(tzinfo=IST)
            return d.astimezone(IST)
        except Exception:
            continue
    return None


def is_within_rolling_window(parsed_date, max_age_hours=DEFAULT_MAX_AGE_HOURS):
    if not parsed_date: return True
    current_time = now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    hours_diff = (current_time - parsed_date).total_seconds() / 3600.0
    return -24.0 <= hours_diff <= max_age_hours


# ============================================================
# FETCH ENGINE
# ============================================================

def normal_fetch(url, verify=True):
    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=verify)
        if r.status_code >= 400: return None
        return r.text
    except Exception:
        return None


def curl_fetch(url, verify=True):
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True, verify=verify)
        if r.status_code >= 400: return None
        return r.text
    except Exception:
        return None


def fetch_url(url):
    url = clean_url(url)
    if not url: return None
    return curl_fetch(url, True) or curl_fetch(url, False) or normal_fetch(url, True) or normal_fetch(url, False)


# ============================================================
# CONTENT EXTRACTION
# ============================================================

def extract_article_content(soup, source=""):
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside"]):
        tag.decompose()

    candidates = []
    
    # JSON-LD Body
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objects = data if isinstance(data, list) else [data]
            for obj in objects:
                if isinstance(obj, dict) and obj.get("articleBody"):
                    candidates.append(clean_text(obj.get("articleBody")))
        except Exception:
            pass

    # DOM Selectors
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main", ".entry-content"
    ]
    for selector in selectors:
        for el in soup.select(selector):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # Paragraph Fallback
    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if word_count(p) >= 8]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates: return ""

    cleaned = [remove_common_boilerplate(c) for c in candidates if remove_common_boilerplate(c)]
    if not cleaned: return ""

    return max(cleaned, key=lambda t: word_count(t))


def fetch_generic_article_content(url, source=""):
    url = clean_url(url)
    if not url: return "", None

    html_raw = fetch_url(url)
    if not html_raw: return "", None

    soup = BeautifulSoup(html_raw, "lxml")
    content = extract_article_content(soup, source)

    if word_count(content) >= MIN_CONTENT_WORDS:
        return content, now_ist()

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
    if total_words < MIN_CONTENT_WORDS:
        return None

    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        warn(f"REJECTED Blacklisted Word: '{matched_bad_word}' | Title: {clean_title_str[:50]}")
        return None

    parsed_date = date or parse_date(clean_title_str) or now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)

    if not ignore_time_filter and not is_within_rolling_window(parsed_date):
        return None

    if not clean_title_str or not clean_url_str:
        return None

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
# CATEGORY DEFINITIONS
# ============================================================

NATIONAL_CATEGORIES = {
    "Polity & Governance": '("Supreme Court" OR "Cabinet Approves" OR "Act") -crime -politics',
    "Govt Schemes & Welfare": '("Govt Scheme" OR "Pradhan Mantri" OR "Welfare") -crime',
    "Economy & Banking": '("RBI Policy" OR "Economic" OR "GST Council" OR "Inflation")',
    "International Relations": '("Bilateral" OR "G20" OR "BRICS" OR "Summit")',
    "Science, Tech & Defense": '("ISRO" OR "NASA" OR "DRDO" OR "Defense Exercise")',
    "Environment & Infrastructure": '("Ramsar Site" OR "Expressway" OR "Renewable Energy" OR "GI Tag")'
}

BIHAR_CATEGORIES = {
    "Bihar Schemes & Welfare": '("Bihar Scheme" OR "Mukhyamantri Scheme" OR "Bihar Welfare") -politics -crime',
    "Bihar Development": '("Bihar Infrastructure" OR "Patna Metro" OR "Bihar Expressway") -crime'
}


def fetch_google_news_feed(categories_dict, source_label, is_bihar=False):
    print(f"\n🌐 SCRAPING SOURCE: {source_label}")
    category_results = []

    for cat_name, query in categories_dict.items():
        # Append time dork for Google News
        full_query = f"{query} when:2d" 
        encoded_q = quote(full_query)
        rss_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"

        feed = feedparser.parse(rss_url)
        entries = feed.entries or []
        debug(f"RSS returned {len(entries)} raw items for [{cat_name}]")

        count = 0
        for entry in entries[:MAX_PER_CATEGORY * 3]:
            title = clean_title(getattr(entry, 'title', ''))
            url = clean_url(getattr(entry, 'link', ''))

            if not title or not url: continue

            # Primary Attempt: Direct Article Scraping
            content, date = fetch_generic_article_content(url, cat_name)

            # Fallback Attempt: Extract from RSS Feed Summary / HTML Snippet
            if not content:
                raw_summary = getattr(entry, 'summary', '') or getattr(entry, 'description', '')
                cleaned_summary = clean_text(raw_summary)
                if cleaned_summary and word_count(cleaned_summary) >= MIN_CONTENT_WORDS:
                    debug(f"Using RSS summary fallback for '{title[:40]}'")
                    content = cleaned_summary

            if not content: continue

            rss_date = parse_date(getattr(entry, 'published', None)) or date or now_ist()

            obj = make_item(
                source="Google News Central" if not is_bihar else "Google News Bihar",
                title=title,
                url=url,
                date=rss_date,
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
    bihar = fetch_google_news_feed(BIHAR_CATEGORIES, "Bihar", is_bihar=True)

    breakdown = {
        "Google News National": len(national),
        "Google News Bihar": len(bihar)
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

    print(f"\n💾 {OUTPUT_FILE} saved successfully with {len(all_news)} items!")


if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
