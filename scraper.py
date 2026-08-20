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
        r = gov_session.get(url, headers=HEADERS, timeout=TIMEOUT, verify=False)
        if r.status_code == 200 and len(r.text) > 100:
            return r.text
    except Exception as e:
        warn(f"Gov Special Fetcher Exception for {url[:50]}: {e}")
    return None


def normal_fetch(url, verify=True):
    try:
        r = normal_requests.get(
            url,
            headers=HEADERS,
            timeout=TIMEOUT,
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
        r = curl_requests.get(
            url,
            headers=HEADERS,
            timeout=TIMEOUT,
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
        r = normal_requests.get(endpoint, params=params, timeout=30)
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


def fetch_url(url):
    url = clean_url(url)
    if not url:
        return None

    if "bihar.gov.in" in url.lower():
        html = gov_special_fetch(url)
        if html:
            return html
        html = normal_fetch(url, verify=False)
        if html:
            return html

    if ".gov.in" in url.lower():
        html = normal_fetch(url, verify=True)
        if html:
            return html
        html = normal_fetch(url, verify=False)
        if html:
            return html

    html = curl_fetch(url, verify=True)
    if html:
        return html

    html = curl_fetch(url, verify=False)
    if html:
        return html

    html = normal_fetch(url, verify=True)
    if html:
        return html

    html = normal_fetch(url, verify=False)
    if html:
        return html

    if SCRAPINGANT_API_KEY:
        html = scrapingant_fetch(url)
        if html:
            return html

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

def make_item(source, title, url, date=None, content="", item_type="Scraped", is_bihar=False):
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

    parsed_date = date or parse_date(clean_title_str)
    
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
# ACTIVE SCRAPER SOURCES
# ============================================================

# 1. NEWS ON AIR
NEWS_ON_AIR_URLS = [
    "https://newsonair.gov.in/",
    "https://newsonair.gov.in/category/news/",
    "https://newsonair.gov.in/category/national-news/",
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

            candidates.append((title, href))

    unique = []
    seen = set()
    for title, url in candidates:
        if url not in seen:
            seen.add(url)
            unique.append((title, url))

    results = []
    for title, url in unique:
        content, date = fetch_generic_article_content(url, "News On AIR")
        if not content:
            continue

        obj = make_item(
            source="News On AIR",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Article",
            is_bihar=False
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("NEWS ON AIR: Aaj ki date ka koi article nahi mila.")

    print(f"✅ News On AIR usable: {len(results)}")
    return results


# 2. IPRD BIHAR
IPRD_PAGES = [
    "https://state.bihar.gov.in/prdbihar/",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=6996",
]


def scrape_iprd_bihar():
    print("\n" + "=" * 70 + "\n📢 IPRD BIHAR (Today's Date Only)\n" + "=" * 70)
    candidates = []

    for page_url in IPRD_PAGES:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 20:
                continue
            if "state.bihar.gov.in/prdbihar" not in href.lower():
                continue

            low = title.lower()
            if any(x in low for x in ["home", "contact", "feedback", "copyright", "web information manager", "accessibility", "previous", "next", "department", "order/circular"]):
                continue

            candidates.append((title, href))

    unique = []
    seen = set()
    for title, url in candidates:
        if url not in seen:
            seen.add(url)
            unique.append((title, url))

    results = []
    for title, url in unique:
        content, date = fetch_generic_article_content(url, "IPRD Bihar")
        if not content:
            continue

        obj = make_item(
            source="IPRD Bihar",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Press Release",
            is_bihar=True
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("IPRD BIHAR: Aaj ki date ka koi article nahi mila.")

    print(f"✅ IPRD Bihar usable: {len(results)}")
    return results


# 3. INDIA.GOV.IN
INDIA_GOV_PAGES = [
    "https://www.india.gov.in/",
    "https://www.india.gov.in/news",
    "https://www.india.gov.in/spotlight",
]


def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN (Today's Date Only)\n" + "=" * 70)
    candidates = []

    for page_url in INDIA_GOV_PAGES:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 20:
                continue
            if "india.gov.in" not in href:
                continue

            low = title.lower()
            if any(x in low for x in ["home", "about", "contact", "feedback", "sitemap", "login"]):
                continue

            candidates.append((title, href))

    unique = []
    seen = set()
    for title, url in candidates:
        if url not in seen:
            seen.add(url)
            unique.append((title, url))

    results = []
    for title, url in unique:
        content, date = fetch_generic_article_content(url, "India.gov.in")
        if not content:
            continue

        obj = make_item(
            source="India.gov.in",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Government Article",
            is_bihar=False
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
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

def build_news():
    print("\n" + "=" * 80 + f"\n🚀 STARTING TODAY'S EXCLUSIVE NEWS PIPELINE [{now_ist().strftime('%d %b %Y')}]\n" + "=" * 80)

    all_results = []
    source_results = {}

    source_results["News On AIR"] = safe_source("News On AIR", scrape_news_on_air)
    source_results["IPRD Bihar"] = safe_source("IPRD Bihar", scrape_iprd_bihar)
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
