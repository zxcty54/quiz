"""
scraper_smart.py — scraper.py ka tez sanskaran (test ke liye).
Saare fetch-tareeke, date-scan or content-nikalne ki tarkeebein waisi ki vaisi;
nayi hai sirf kaam ki tarteeb: parallel khabarein, site-wise jeeta-hua tareeka yaad,
pehle se aayi khabar dobara nahi khulti, har source ka samay-budget.
Output: wahi rawnews.json, wahi format — summarizer ko koi farak nahi.
"""
import os
import re
import json
import time
import hashlib
import warnings
import ssl
import html

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin

import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse

from curl_cffi import requests as curl_requests
import requests as normal_requests
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "rawnews.json"
TIMEOUT = 25
MAX_PER_SOURCE = 15

MIN_CONTENT_CHARS = 400
MIN_CONTENT_WORDS = 200
MAX_CONTENT_WORDS = 700
MAX_CONTENT_CHARS = 25000

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
# SPECIAL NIC BIHAR GOVT SSL ADAPTER
# ============================================================

class CustomGovSSLAdapter(HTTPAdapter):
    """Bypasses legacy SSL/TLS ciphers for Bihar Government portals"""
    def init_poolmanager(self, *args, **kwargs):
        ctx = create_urllib3_context()
        ctx.set_ciphers('DEFAULT@SECLEVEL=1')
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        kwargs['ssl_context'] = ctx
        return super().init_poolmanager(*args, **kwargs)

gov_session = normal_requests.Session()
gov_session.mount('https://', CustomGovSSLAdapter())
gov_session.mount('http://', CustomGovSSLAdapter())


# ============================================================
# SMART ENGINE (parallel + yaad + budget)
# ============================================================

CONNECT_TIMEOUT = 6     # mrit site itne me pehchan jayegi
READ_TIMEOUT = 19       # zinda sust site ko padhne ka poora samay
MAX_WORKERS = 10        # ek sath itni khabarein khulengi
SOURCE_BUDGET_SEC = 150   # ek source isse zyada nahi ghisega
GLOBAL_BUDGET_SEC = 300   # pura run 5 minute ki hadd

RUN_DEADLINE = float('inf')
KNOWN_TODAY_URLS = set()   # aaj ki khabarein jo pehle aa chuki (dobara nahi khulegi)

_tls = threading.local()
_host_winners = {}
_host_lock = threading.Lock()


def _shared_normal_session():
    if not hasattr(_tls, 'normal'):
        sess = normal_requests.Session()
        ad = HTTPAdapter(pool_connections=32, pool_maxsize=32)
        sess.mount('https://', ad)
        sess.mount('http://', ad)
        _tls.normal = sess
    return _tls.normal


def _shared_curl_session():
    if not hasattr(_tls, 'curl'):
        _tls.curl = curl_requests.Session()
    return _tls.curl


def _time_left():
    return RUN_DEADLINE - time.time()


# ============================================================
# TIME & DEBUG
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
# URL CLEANING
# ============================================================

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


# ============================================================
# TEXT CLEANING
# ============================================================

def clean_text(text):
    if not text:
        return ""

    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return re.sub(r'\s+', ' ', text).strip()


def clean_title(title):
    title = clean_text(title)

    junk_titles = [
        "skip to main content", "skip to content", "home", "about us", 
        "contact us", "feedback", "sitemap", "disclaimer", "privacy policy",
        "accessibility options", "screen reader access", "search",
        "order/circular/notification", "order / circular / notification",
        "circulars / notifications", "office orders"
    ]
    if title.lower().strip() in junk_titles or len(title.strip()) < 15:
        return ""

    # Listing-card ka aage-wala kachra: "3 hours ago | Regional News 43 <asli title>"
    title = re.sub(
        r'^\d{1,3}\s*(?:hours?|hrs?|minutes?|mins?|days?)\s+ago\s*\|?\s*',
        '', title, flags=re.I)
    title = re.sub(
        r'^(?:regional news|national|international|business|sports|state news|states|world)\s+\d{1,4}\s+',
        '', title, flags=re.I)

    title = re.sub(
        r'\s*[-|–—]\s*(News On AIR|Prasar Bharati|Dainik Bhaskar|Amar Ujala|Prabhat Khabar|Live Hindustan)\s*$',
        '',
        title,
        flags=re.I
    )
    return title.strip()


# ============================================================
# CONTENT QUALITY & WORD LIMITERS
# ============================================================

def word_count(text):
    if not text:
        return 0
    return len(re.findall(r'\S+', text))


def trim_to_max_words(text, max_words=500):
    if not text:
        return ""
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text


def content_quality(text):
    text = clean_text(text)
    chars = len(text)
    words = word_count(text)
    valid = (chars >= MIN_CONTENT_CHARS or words >= MIN_CONTENT_WORDS)
    return valid, chars, words


# ============================================================
# BOILERPLATE CLEANING
# ============================================================

PORTAL_BOILERPLATE = [
    "accessibility options", "skip to main content", "state profile",
    "facts and figure", "distribution of population", "web information manager",
    "site owned by", "privacy policy", "terms and conditions",
    "forgot password", "quick links", "important links", "useful links"
]


def boilerplate_score(text):
    if not text:
        return 0
    low = text.lower()
    return sum(1 for x in PORTAL_BOILERPLATE if x in low)


def is_bad_portal_content(text):
    if not text:
        return True
    return boilerplate_score(text) >= 6


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
# HYPER-FLEXIBLE DATE PARSER ENGINE
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

    patterns = [
        r'\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}',
        r'\b\d{1,2}[-/]\d{1,2}[-/]\d{4}\b',
        r'\b\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4}\b',
        r'\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b',
        r'\b\d{4}-\d{2}-\d{2}\b',
    ]

    for pattern in patterns:
        m = re.search(pattern, value)
        if not m:
            continue

        raw_match = m.group(0)
        for fmt in ["%Y-%m-%dT%H:%M:%S", "%d-%m-%Y", "%d/%m/%Y", "%d-%b-%Y", "%d-%B-%Y", "%Y-%m-%d"]:
            try:
                d = datetime.strptime(raw_match, fmt)
                return d.replace(tzinfo=IST)
            except Exception:
                continue

    return None


def extract_date_from_soup(soup):
    selectors = [
        "meta[property='article:published_time']",
        "meta[property='og:published_time']",
        "meta[name='publish-date']",
        "meta[name='date']",
        "meta[name='DC.date']",
        "meta[itemprop='datePublished']",
        "meta[itemprop='dateModified']",
        "time", ".date", ".published", ".publish-date",
        ".news-date", ".article-date", ".date-time", ".post-date",
        "#lblDate", "#lblNewsDate"
    ]

    for selector in selectors:
        try:
            elements = soup.select(selector)
        except Exception:
            continue

        for el in elements:
            value = (
                el.get("content")
                or el.get("datetime")
                or el.get_text(" ", strip=True)
            )
            d = parse_date(value)
            if d:
                return d

    for script in soup.find_all("script", type="application/ld+json"):
        raw = script.string or script.get_text()
        if not raw:
            continue
        m = re.search(r'"datePublished"\s*:\s*"([^"]+)"', raw)
        if m:
            d = parse_date(m.group(1))
            if d:
                return d

    return None


# ============================================================
# STRICT "TODAY'S DATE ONLY" CHECK
# ============================================================

def is_strictly_today(parsed_date):
    if not parsed_date:
        return False

    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    today_date_ist = now_ist().date()
    return parsed_date.date() == today_date_ist


# ============================================================
# SMART FETCH
# ============================================================

def gov_special_fetch(url):
    try:
        r = gov_session.get(url, headers=HEADERS, timeout=(CONNECT_TIMEOUT, READ_TIMEOUT), verify=False)
        if r.status_code == 200 and len(r.text) > 100:
            return r.text
    except Exception as e:
        warn(f"Gov Special Fetcher Exception for {url[:50]}: {e}")
    return None


def normal_fetch(url, verify=True):
    try:
        r = _shared_normal_session().get(
            url,
            headers=HEADERS,
            timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
            allow_redirects=True,
            verify=verify
        )
        if r.status_code >= 400:
            warn(f"REQUESTS HTTP {r.status_code}: {url}")
            return None
        return r.text
    except Exception as e:
        warn(f"Requests failed: {url} | {e}")
        return None


def curl_fetch(url, verify=True):
    try:
        r = _shared_curl_session().get(
            url,
            headers=HEADERS,
            timeout=READ_TIMEOUT + CONNECT_TIMEOUT,
            impersonate="chrome",
            allow_redirects=True,
            verify=verify
        )
        if r.status_code >= 400:
            warn(f"HTTP {r.status_code}: {url}")
            return None
        return r.text
    except Exception as e:
        warn(f"CURL failed: {url} | {e}")
        return None


def scrapingant_fetch(url):
    if not SCRAPINGANT_API_KEY:
        return None

    try:
        endpoint = "https://api.scrapingant.com/v2/general"
        params = {
            "url": url,
            "x-api-key": SCRAPINGANT_API_KEY,
            "browser": "false",
        }
        r = _shared_normal_session().get(endpoint, params=params, timeout=30)
        if r.status_code >= 400:
            warn(f"ScrapingAnt HTTP {r.status_code}: {url}")
            return None

        try:
            data = r.json()
            if isinstance(data, dict) and "content" in data:
                return data["content"]
        except Exception:
            pass

        return r.text
    except Exception as e:
        warn(f"ScrapingAnt failed: {url} | {e}")
        return None


# Browser-render aam mangte se mehnga (credit) padta hai — ek run me sima rakhi.
RENDER_MAX_PER_RUN = 12
_render_used = 0
_render_lock = threading.Lock()


def _render_slot():
    global _render_used
    with _render_lock:
        if _render_used >= RENDER_MAX_PER_RUN:
            return False
        _render_used += 1
        return True


def scrapingant_render_fetch(url):
    """JavaScript se banni wali site ka browser-render mangta (browser=true).
    Khali-khokha (Loading...) wali musibat yahi suljhata hai. Render-cap khatm
    ya API key na ho to None — seedhi ke aam kadam apne-aap chal padenge."""
    if not SCRAPINGANT_API_KEY:
        return None
    if not _render_slot():
        debug(f"Render sima khatm, aam mangta chalega: {url[:60]}")
        return None
    try:
        r = _shared_normal_session().get(
            "https://api.scrapingant.com/v2/general",
            params={"url": url, "x-api-key": SCRAPINGANT_API_KEY, "browser": "true"},
            timeout=60)
        if r.status_code >= 400:
            warn(f"ScrapingAnt Render HTTP {r.status_code}: {url}")
            return None
        body = None
        try:
            data = r.json()
            if isinstance(data, dict) and "content" in data:
                body = data["content"]
        except Exception:
            pass
        if body is None:
            body = r.text
        if body:
            debug(f"ScrapingAnt render safal: {url[:60]}")
        return body
    except Exception as e:
        warn(f"ScrapingAnt Render failed: {url} | {e}")
        return None


def _ladder(url):
    """Purani seedhi, waisi ki vaisi — bas naam ke sath."""
    host = (urlparse(url).hostname or '').lower()
    steps = []
    if 'india.gov.in' in host:
        steps.append(('render', lambda: scrapingant_render_fetch(url)))
    if 'bihar.gov.in' in host:
        steps.append(('gov', lambda: gov_special_fetch(url)))
        steps.append(('plain-nossl', lambda: normal_fetch(url, verify=False)))
    elif '.gov.in' in host:
        steps.append(('plain', lambda: normal_fetch(url, verify=True)))
        steps.append(('plain-nossl', lambda: normal_fetch(url, verify=False)))
    else:
        steps.append(('curl', lambda: curl_fetch(url, verify=True)))
        steps.append(('curl-nossl', lambda: curl_fetch(url, verify=False)))
        steps.append(('plain', lambda: normal_fetch(url, verify=True)))
        steps.append(('plain-nossl', lambda: normal_fetch(url, verify=False)))
    if SCRAPINGANT_API_KEY:
        steps.append(('scrapingant', lambda: scrapingant_fetch(url)))
    return host, steps


def fetch_url(url):
    url = clean_url(url)
    if not url:
        return None

    host, steps = _ladder(url)
    # jo tareeka is site par jeeta tha, pehle wahi
    with _host_lock:
        winner = _host_winners.get(host)
    if winner and not (steps and steps[0][0] == 'render'):
        steps.sort(key=lambda st: 0 if st[0] == winner else 1)

    for name, fn in steps:
        if _time_left() < 8:
            warn(f"⏰ SAMAY KHATM (budget) — baaki koshish ruki: {url[:60]}")
            break
        out = fn()
        if out:
            with _host_lock:
                _host_winners[host] = name
            return out

    warn(f"❌ ALL FETCH METHODS FAILED: {url}")
    return None


# ============================================================
# DEEP ARTICLE CONTENT EXTRACTION
# ============================================================

def extract_article_content(soup, source=""):
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside"]):
        tag.decompose()

    target_div = (
        soup.find(id="lblNewsDetail") or
        soup.find(id="lblContent") or
        soup.find(class_="innercontent") or
        soup.find(class_="news-detail") or
        soup.find(class_="pressrelease") or
        soup.find(class_="entry-content") or
        soup.find(class_="post-content")
    )

    if target_div:
        extracted_text = clean_text(target_div.get_text(" ", strip=True))
        if len(extracted_text) >= 120:
            return trim_to_max_words(extracted_text, MAX_CONTENT_WORDS)

    jsonld_candidates = []
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objects = data if isinstance(data, list) else [data]
            for obj in objects:
                if not isinstance(obj, dict):
                    continue
                body = obj.get("articleBody")
                if body:
                    txt = clean_text(body)
                    if txt:
                        jsonld_candidates.append(txt)
        except Exception:
            pass

    selectors = [
        "#lblNewsDetail", "#lblContent", "[itemprop='articleBody']", "article",
        ".article-body", ".articleBody", ".article-content", ".articleContent",
        ".story-content", ".storyContent", ".news-content", ".newsContent",
        ".press-release", ".pressrelease", ".content-area", ".main-content", ".entry-content", ".post-content", "main",
    ]

    candidates = []
    candidates.extend(jsonld_candidates)

    for selector in selectors:
        try:
            elements = soup.select(selector)
        except Exception:
            continue

        for el in elements:
            txt = clean_text(el.get_text(" ", strip=True))
            if len(txt) >= 200:
                candidates.append(txt)

    paragraphs = []
    for p in soup.find_all(["p", "tr", "li", "td"]):
        txt = clean_text(p.get_text(" ", strip=True))
        if len(txt) >= 20:
            paragraphs.append(txt)

    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if len(joined) >= 200:
            candidates.append(joined)

    for div in soup.find_all(["div", "section"]):
        txt = clean_text(div.get_text(" ", strip=True))
        if 300 <= len(txt) <= MAX_CONTENT_CHARS:
            candidates.append(txt)

    if not candidates:
        return ""

    cleaned = []
    for text in candidates:
        text = remove_common_boilerplate(text)
        if not text:
            continue
        cleaned.append(text)

    if not cleaned:
        return ""

    def score(text):
        words = word_count(text)
        chars = len(text)
        return min(chars, MAX_CONTENT_CHARS) + min(words * 2, 50000)

    best = max(cleaned, key=score)
    clean_best = clean_text(best)
    return trim_to_max_words(clean_best, MAX_CONTENT_WORDS)


def fetch_generic_article_content(url, source=""):
    url = clean_url(url)
    if not url:
        return "", None

    debug(f"{source} ARTICLE FETCH: {url}")
    html_raw = fetch_url(url)
    if not html_raw:
        return "", None

    soup = BeautifulSoup(html_raw, "lxml")
    date = extract_date_from_soup(soup)
    content = extract_article_content(soup, source)

    valid, chars, words = content_quality(content)

    if valid:
        success(f"{source} CONTENT FOUND | {chars} chars | {words} words")
        return content, date

    debug(f"{source} CONTENT TOO SHORT | {chars} chars | {words} words | {url}")
    warn(f"{source} NO ARTICLE CONTENT: {url}")
    return "", None


# ============================================================
# ITEM BUILDER WITH STRICT TODAY'S DATE VALIDATION
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Scraped", is_bihar=False, date_hint=""):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_title_str or not clean_url_str:
        return None

    if "order/circular/notification" in clean_title_str.lower() or "rowid=2951" in clean_url_str.lower():
        warn(f"REJECTED CIRCULAR INDEX PAGE | {source} | {clean_title_str[:45]}")
        return None

    words_total = word_count(clean_content_str)
    if words_total < MIN_CONTENT_WORDS:
        warn(f"REJECTED TOO SHORT ({words_total} words < {MIN_CONTENT_WORDS}) | {source} | {clean_title_str[:45]}")
        return None

    if words_total > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)
        words_total = word_count(clean_content_str)

    parsed_date = date
    if not parsed_date and date_hint:
        parsed_date = parse_date(date_hint)
        if parsed_date:
            debug(f"DATE LISTING CARD SE ({date_hint}) | {source} | {clean_title_str[:45]}")
    if not parsed_date:
        parsed_date = parse_date(title)
    
    if not parsed_date or not is_strictly_today(parsed_date):
        pub_str = parsed_date.strftime("%d %b %Y") if parsed_date else "No Date Found"
        debug(f"REJECTED NOT TODAY ({pub_str}) | {source} | {clean_title_str[:45]}")
        return None

    dates_in_content = re.findall(r'\b\d{2}/\d{2}/\d{4}\b', clean_content_str[:300])
    if dates_in_content:
        for d_str in dates_in_content[:3]:
            d_parsed = parse_date(d_str)
            if d_parsed and not is_strictly_today(d_parsed):
                warn(f"REJECTED STALE BODY DATE ({d_str}) | {source} | {clean_title_str[:45]}")
                return None

    if is_bad_portal_content(clean_content_str):
        warn(f"DEBUG PORTAL CONTENT REJECTED | {source} | {clean_title_str[:100]}")
        return None

    return {
        "source": source,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": parsed_date.strftime("%a, %d %b %Y %H:%M:%S IST"),
        "content": clean_content_str,
        "content_chars": len(clean_content_str),
        "content_words": words_total,
        "type": item_type,
    }


# ============================================================
# HASH / DEDUP
# ============================================================

def normalize_for_hash(text):
    text = clean_text(text).lower()
    text = re.sub(r'[^a-z0-9\u0900-\u097f]+', ' ', text)
    return text.strip()


def deduplicate(items):
    seen = set()
    output = []
    dropped = 0

    for item in items:
        url = clean_url(item.get("url", ""))
        title = item.get("title", "")
        key = url or title or item.get("content", "")

        key = hashlib.sha1(normalize_for_hash(key).encode("utf-8", errors="ignore")).hexdigest()

        if key in seen:
            dropped += 1
            continue

        seen.add(key)
        output.append(item)

    print(f"🧹 Deduplication: Input={len(items)} | Dropped={dropped} | Unique={len(output)}")
    return output


# ============================================================
# PARALLEL KHABAR PROCESSOR (ladder per-URL chalegi, khabarein sath)
# ============================================================

def _card_time_hint(a):
    """Listing-card se 'X hours/minutes ago' wala samay-ishaara.
    Anchor ke apne text me na mile to card (parent) ke text me dhoondho.
    Sirf ghante/minute lete hai; 'days ago' wali kal ki khabar hoti hai,
    usey date nahi banate. Page par date ho to yahi kabhi nahi chalega."""
    texts = []
    try:
        texts.append(a.get_text(" ", strip=True))
    except Exception:
        pass
    node = a
    for _ in range(3):
        try:
            node = node.parent
        except Exception:
            break
        if node is None or getattr(node, "name", None) in ("body", "html", "[document]"):
            break
        try:
            t = node.get_text(" ", strip=True)
        except Exception:
            break
        if len(t) > 400:
            break  # poora section bandal gaya — dusri khabar ka samay ghus sakta hai
        texts.append(t)
    for t in texts:
        m = re.search(r'\b(\d{1,3})\s*(hours?|hrs?|minutes?|mins?)\s+ago\b',
                      t, flags=re.I)
        if m:
            return m.group(0)
    return ""


def _one_article(source, title, url, hint, item_type, is_bihar):
    try:
        content, date = fetch_generic_article_content(url, source)
        if not content:
            return None
        return make_item(source=source, title=title, url=url, date=date,
                         content=content, item_type=item_type, is_bihar=is_bihar,
                         date_hint=hint)
    except Exception as e:
        warn(f"ARTICLE ERROR {url[:60]}: {e!r}")
        return None


_FILE_EXT_SKIP = ('.pdf', '.doc', '.docx', '.xls', '.xlsx', '.zip', '.mp3', '.mp4')


def _process_candidates(cands, source, item_type, is_bihar):
    """Khabrein batch me, parallel. MAX_PER_SOURCE ya budget par ruk jao."""
    cands = [(t, u, h) for (t, u, h) in cands
             if not u.split('?')[0].lower().endswith(_FILE_EXT_SKIP)]
    results = []
    deadline = min(time.time() + SOURCE_BUDGET_SEC, RUN_DEADLINE)
    idx = 0
    while idx < len(cands) and len(results) < MAX_PER_SOURCE:
        if time.time() > deadline:
            warn(f"⏰ {source}: source-budget khatm, {len(results)} khabar par ruke")
            break
        batch = cands[idx:idx + MAX_WORKERS * 2]
        idx += len(batch)
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
            futs = [ex.submit(_one_article, source, t, u, h, item_type, is_bihar)
                    for t, u, h in batch]
            for fu in as_completed(futs):
                try:
                    obj = fu.result()
                except Exception:
                    obj = None
                if obj:
                    results.append(obj)
    results = deduplicate(results)
    return results[:MAX_PER_SOURCE]


def _known_filter(unique):
    if not KNOWN_TODAY_URLS:
        return unique
    fresh = [(t, u, h) for (t, u, h) in unique if clean_url(u) not in KNOWN_TODAY_URLS]
    skip = len(unique) - len(fresh)
    if skip:
        print(f"♻️ {skip} khabarein aaj pehle aa chuki — dobara nahi khulegi")
    return fresh


# ============================================================
# ACTIVE SCRAPER SOURCES
# ============================================================

# 1. NEWS ON AIR
NEWS_ON_AIR_URLS = [
    "https://newsonair.gov.in/",
]


def scrape_news_on_air():
    print("\n" + "=" * 70 + "\n📻 NEWS ON AIR (Today's Date Only)\n" + "=" * 70)
    candidates = []

    for page_url in NEWS_ON_AIR_URLS:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 20:
                continue
            if "newsonair.gov.in" not in href:
                continue

            candidates.append((title, href, _card_time_hint(a)))

    unique = []
    seen = set()
    for title, url, hint in candidates:
        if url not in seen:
            seen.add(url)
            unique.append((title, url, hint))

    unique = _known_filter(unique)
    results = _process_candidates(unique, "News On AIR", "Article", False)
    if not results:
        debug("NEWS ON AIR: Aaj ki date ka koi article nahi mila.")

    print(f"✅ News On AIR usable: {len(results)}")
    return results


# 3. INDIA.GOV.IN
INDIA_GOV_PAGES = [
    "https://www.india.gov.in/",
]


def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN (Today's Date Only)\n" + "=" * 70)
    candidates = []

    for page_url in INDIA_GOV_PAGES:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        # "News / Press Release" panel ke card hi umeedwar banege: har card par
        # khabar ka samay ("X min/hr ago") chhapa hota hai or uska link asli
        # site (NewsOnAir/PIB) par jata hai — isiliye bahari link chalega.
        # Category/Scheme wale page-panel me kabhi khabar nahi mili, rend=sifar.
        for a in soup.find_all("a", href=True):
            txt = a.get_text(" ", strip=True)
            m = re.search(r'\b\d{1,3}\s*(?:minutes?|mins?|hours?|hrs?)\s+ago\b',
                          txt, flags=re.I)
            if not m:
                continue

            href = clean_url(urljoin(page_url, a.get("href")))
            if not href or not href.startswith("http"):
                continue

            span = a.select_one('span[class*="ellipsis"]')
            if span:
                title = clean_title(span.get_text(" ", strip=True))
            else:
                title = clean_title(re.sub(
                    r'^.*?\d{1,3}\s*(?:minutes?|mins?|hours?|hrs?)\s+ago\s*',
                    '', txt, flags=re.I))

            if len(title) < 20:
                continue

            candidates.append((title, href, m.group(0)))

    unique = []
    seen = set()
    for title, url, hint in candidates:
        if url not in seen:
            seen.add(url)
            unique.append((title, url, hint))

    unique = _known_filter(unique)
    results = _process_candidates(unique, "India.gov.in", "Government Article", False)
    if not results:
        debug("INDIA.GOV.IN: Aaj ki date ka koi article nahi mila.")

    print(f"✅ India.gov.in usable: {len(results)}")
    return results


# ============================================================
# SOURCE RUNNER
# ============================================================

def safe_source(name, function):
    try:
        return function()
    except Exception as e:
        print(f"\n❌ {name} SCRAPER ERROR:")
        print(repr(e))
        return []


# ============================================================
# BUILD ALL NEWS
# ============================================================

def _load_known_today():
    """Purane rawnews.json me aaj ki jo khabarein hain, unke URL yaad kar lo."""
    KNOWN_TODAY_URLS.clear()
    if not os.path.exists(OUTPUT_FILE):
        return
    try:
        with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
            old = json.load(f)
        for item in old.get("national_raw_news", []) + old.get("bihar_raw_news", []):
            if is_strictly_today(parse_date(item.get("date", ""))):
                u = clean_url(item.get("url", ""))
                if u:
                    KNOWN_TODAY_URLS.add(u)
        print(f"♻️ Aaj ki pehle-se-maujud khabarein (dobara nahi khulegi): {len(KNOWN_TODAY_URLS)}")
    except Exception:
        pass


def build_news():
    global RUN_DEADLINE
    RUN_DEADLINE = time.time() + GLOBAL_BUDGET_SEC
    _load_known_today()
    print("\n" + "=" * 80 + f"\n🚀 STARTING TODAY'S EXCLUSIVE NEWS PIPELINE [{now_ist().strftime('%d %b %Y')}]\n" + "=" * 80)

    all_results = []
    source_results = {}

    source_results["News On AIR"] = safe_source("News On AIR", scrape_news_on_air)
    source_results["India.gov.in"] = safe_source("India.gov.in", scrape_india_gov)

    breakdown = {}

    for source, items in source_results.items():
        items = deduplicate(items)
        source_results[source] = items
        breakdown[source] = len(items)
        all_results.extend(items)

    all_results = deduplicate(all_results)

    bihar_sources = {"IPRD Bihar"}
    bihar = []
    national = []

    for item in all_results:
        source = item.get("source", "")
        if source in bihar_sources:
            bihar.append(item)
        else:
            national.append(item)

    print("\n" + "=" * 80 + "\n📊 FINAL TODAY'S SOURCE BREAKDOWN\n" + "=" * 80)
    print(json.dumps(breakdown, ensure_ascii=False, indent=2))

    print(f"\n🇮🇳 National Today : {len(national)}")
    print(f"🏛️ Bihar Today    : {len(bihar)}")
    print(f"📰 Total Today    : {len(all_results)}")

    return national, bihar, breakdown


# ============================================================
# SAVE OUTPUT (SMART MERGE & ACCUMULATE)
# ============================================================

def save_output(national, bihar, breakdown):
    existing_national = []
    existing_bihar = []

    # 1. Read existing rawnews.json
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                old_data = json.load(f)
                existing_national = old_data.get("national_raw_news", [])
                existing_bihar = old_data.get("bihar_raw_news", [])
        except Exception:
            pass

    # 2. Smart Merge: Sirf AAJ ka data rakho, kal ka automatic delete
    def merge_today_records(new_list, old_list):
        merged = list(new_list)
        seen_keys = {item.get("url") or item.get("title") for item in new_list}

        for item in old_list:
            key = item.get("url") or item.get("title")
            parsed_d = parse_date(item.get("date", ""))
            
            # Agar news AAJ ki hai aur duplicate nahi hai, toh hi add karo
            if is_strictly_today(parsed_d) and key not in seen_keys:
                merged.append(item)
                seen_keys.add(key)
        return merged

    final_national = merge_today_records(national, existing_national)
    final_bihar = merge_today_records(bihar, existing_bihar)
    all_news = final_national + final_bihar

    output = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": len(final_bihar),
        "national_raw_count": len(final_national),
        "total_raw_count": len(all_news),
        "bihar_raw_news": final_bihar,
        "national_raw_news": final_national,
        "source_breakdown": breakdown,
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 {OUTPUT_FILE} updated (All runs merged for today).")
    print(f"📦 Total today's stored records: {len(all_news)}")
    print("=" * 80)


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":
    try:
        national, bihar, breakdown = build_news()
        save_output(national, bihar, breakdown)
    except KeyboardInterrupt:
        print("\n⛔ Scraper stopped by user.")
    except Exception as e:
        print("\n❌ FATAL ERROR:")
        print(repr(e))
        raise
