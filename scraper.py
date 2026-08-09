import os
import re
import json
import time
import hashlib
import warnings
import feedparser
import ssl

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, parse_qs

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
MAX_PER_SOURCE = 10

MIN_CONTENT_CHARS = 200
MIN_CONTENT_WORDS = 40
MAX_CONTENT_CHARS = 30000

# Rolling 36 Hours Window for max flexibility
MAX_NEWS_AGE_HOURS = 36

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
    title = re.sub(
        r'\s*[-|–—]\s*(PIB|Press Information Bureau|News On AIR|Prasar Bharati).*$',
        '',
        title,
        flags=re.I
    )
    return title.strip()


# ============================================================
# CONTENT QUALITY
# ============================================================

def word_count(text):
    if not text:
        return 0
    return len(re.findall(r'\S+', text))


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

    # Relative Time Parser (English & Hindi)
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


def is_within_rolling_window(parsed_date):
    if not parsed_date:
        return True  # Fallback: Accept active live items

    current_time = now_ist()
    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    time_difference = current_time - parsed_date
    hours_diff = time_difference.total_seconds() / 3600.0

    if -2.0 <= hours_diff <= MAX_NEWS_AGE_HOURS:
        return True
    return False


# ============================================================
# SMART FETCH WITH GOV.IN RESILIENCE
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
# PERFECT PIB URL CONVERTER (MOBILE HTML + DESKTOP FALLBACK)
# ============================================================

def convert_pib_article_url(url):
    url = clean_url(url)
    if not url:
        return ""

    parsed = urlparse(url)
    query = parse_qs(parsed.query)

    prid = query.get("PRID", [None])[0]
    reg = query.get("reg", ["3"])[0]
    lang = query.get("lang", ["1"])[0]

    if not prid:
        m = re.search(r'PRID=(\d+)', url, flags=re.I)
        if m:
            prid = m.group(1)

    if not prid:
        return url

    # Primary: Direct Mobile HTML endpoint (PressReleseDetailm.aspx - No heavy JS shell)
    return f"https://www.pib.gov.in/PressReleseDetailm.aspx?PRID={prid}&reg={reg}&lang={lang}"


def pib_article_urls(url):
    urls = []
    original = clean_url(url)

    converted_mobile = convert_pib_article_url(original)
    if converted_mobile:
        urls.append(converted_mobile)

    # Secondary: Desktop Page with www force
    if "PRID=" in original:
        prid_m = re.search(r'PRID=(\d+)', original, flags=re.I)
        if prid_m:
            prid = prid_m.group(1)
            urls.append(f"https://www.pib.gov.in/PressReleasePage.aspx?PRID={prid}&reg=3&lang=1")

    if original and original not in urls:
        urls.append(original)

    # Tertiary: Iframe Container
    if converted_mobile and "PRID=" in converted_mobile:
        prid_m = re.search(r'PRID=(\d+)', converted_mobile, flags=re.I)
        if prid_m:
            urls.append(f"https://www.pib.gov.in/PressReleaseIframePage.aspx?PRID={prid_m.group(1)}")

    output = []
    seen = set()
    for u in urls:
        if u and u not in seen:
            seen.add(u)
            output.append(u)

    return output


# ============================================================
# DEEP ARTICLE CONTENT EXTRACTION
# ============================================================

def extract_article_content(soup, source=""):
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside"]):
        tag.decompose()

    # High-Priority Target Containers for PIB & Bihar Portals
    target_div = (
        soup.find(id="ContentPlaceHolder1_divpri") or
        soup.find(id="divpri") or
        soup.find(id="lblNewsDetail") or
        soup.find(id="lblContent") or
        soup.find(class_="ReleaseIdText") or
        soup.find(class_="release_text") or
        soup.find(class_="innercontent") or
        soup.find(class_="news-detail") or
        soup.find(class_="pressrelease")
    )

    if target_div:
        extracted_text = clean_text(target_div.get_text(" ", strip=True))
        if len(extracted_text) >= 120:
            return extracted_text

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
        "#ContentPlaceHolder1_divpri", "#divpri", "#lblNewsDetail", "#lblContent",
        ".ReleaseIdText", ".release_text", "[itemprop='articleBody']", "article",
        ".article-body", ".articleBody", ".article-content", ".articleContent",
        ".story-content", ".storyContent", ".news-content", ".newsContent",
        ".press-release", ".pressrelease", ".content-area", ".main-content", "main",
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
        if 300 <= len(txt) <= 150000:
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
        return min(chars, 100000) + min(words * 2, 50000)

    best = max(cleaned, key=score)
    return clean_text(best)


def fetch_generic_article_content(url, source=""):
    url = clean_url(url)
    if not url:
        return "", None

    candidate_urls = [url]
    if source == "PIB":
        candidate_urls = pib_article_urls(url)

    for candidate_url in candidate_urls:
        debug(f"{source} ARTICLE FETCH: {candidate_url}")
        html = fetch_url(candidate_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        date = extract_date_from_soup(soup)
        content = extract_article_content(soup, source)

        valid, chars, words = content_quality(content)

        if valid:
            success(f"{source} CONTENT FOUND | {chars} chars | {words} words")
            return content, date

        debug(f"{source} CONTENT TOO SHORT | {chars} chars | {words} words | {candidate_url}")

    warn(f"{source} NO ARTICLE CONTENT: {url}")
    return "", None


# ============================================================
# ITEM BUILDER WITH DYNAMIC DATE FALLBACKS
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Scraped"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    parsed_date = date

    # Fallback 1: Extract from Title
    if not parsed_date:
        parsed_date = parse_date(clean_title_str)

    # Fallback 2: Extract from Content Start or End
    if not parsed_date:
        parsed_date = parse_date(clean_content_str[:400]) or parse_date(clean_content_str[-400:])

    if isinstance(parsed_date, str):
        parsed_date = parse_date(parsed_date)

    # Fallback 3: Assign current execution time if fetched from live active listing
    if not parsed_date:
        parsed_date = now_ist()
        debug(f"FALLBACK CURRENT TIME ASSIGNED | {source} | {clean_title_str[:80]}")

    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    # Dynamic Rolling Window Filter
    if not is_within_rolling_window(parsed_date):
        debug(
            f"DATE OUTSIDE WINDOW REJECTED | {source} | "
            f"article_time={parsed_date.strftime('%Y-%m-%d %H:%M IST')} | "
            f"{clean_title_str[:100]}"
        )
        return None

    debug(
        f"DATE ACCEPTED | {source} | "
        f"article_time={parsed_date.strftime('%Y-%m-%d %H:%M IST')} | "
        f"{clean_title_str[:100]}"
    )

    date = parsed_date

    if not clean_title_str or not clean_url_str:
        return None

    if not clean_content_str or clean_content_str.lower() == clean_title_str.lower():
        warn(f"DEBUG NO CONTENT | {source} | {clean_title_str[:120]}")
        return None

    valid, chars, words = content_quality(clean_content_str)

    if not valid:
        warn(f"DEBUG CONTENT TOO SHORT | {source} | {chars} chars | {words} words | {clean_title_str[:100]}")
        return None

    if is_bad_portal_content(clean_content_str):
        warn(f"DEBUG PORTAL CONTENT REJECTED | {source} | {clean_title_str[:100]}")
        return None

    return {
        "source": source,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": date.strftime("%a, %d %b %Y %H:%M:%S GMT"),
        "content": clean_content_str,
        "content_chars": chars,
        "content_words": words,
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

PIB_FEEDS = [
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=2&Regid=48",
]


def scrape_pib():
    print("\n" + "=" * 70 + "\n🇮🇳 PIB\n" + "=" * 70)
    entries = []

    for feed_url in PIB_FEEDS:
        html = fetch_url(feed_url)
        if not html:
            continue

        parsed = feedparser.parse(html)
        for entry in parsed.entries or []:
            title = clean_title(entry.get("title", ""))
            link = clean_url(entry.get("link", ""))
            if not title or not link:
                continue

            date = None
            for field in ["published", "updated", "pubDate", "date"]:
                value = entry.get(field)
                if value:
                    date = parse_date(value)
                    if date:
                        break

            entries.append({"title": title, "url": link, "date": date})

    results = []
    for item in entries[:MAX_PER_SOURCE * 2]:
        content, article_date = fetch_generic_article_content(item["url"], "PIB")
        if not content:
            continue

        final_date = article_date or item["date"]
        obj = make_item(
            source="PIB",
            title=item["title"],
            url=item["url"],
            date=final_date,
            content=content,
            item_type="RSS + Article"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("PIB: Recent rolling window ka koi data nahi mila.")

    print(f"✅ PIB usable: {len(results)}")
    return results


NEWS_ON_AIR_URLS = [
    "https://newsonair.gov.in/",
    "https://newsonair.gov.in/category/news/",
    "https://newsonair.gov.in/category/national-news/",
]


def scrape_news_on_air():
    print("\n" + "=" * 70 + "\n📻 NEWS ON AIR\n" + "=" * 70)
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
            item_type="Article"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("NEWS ON AIR: Recent rolling window ka koi data nahi mila.")

    print(f"✅ News On AIR usable: {len(results)}")
    return results


# ACTIVE CMO BIHAR URLS INCLUDING WORKING news.aspx
CMO_URLS = [
    "https://cm.bihar.gov.in/users/news.aspx",
    "https://cm.bihar.gov.in/users/preessrelease.aspx",
    "https://cm.bihar.gov.in/",
]


def scrape_cmo_bihar():
    print("\n" + "=" * 70 + "\n🏛️ CMO BIHAR\n" + "=" * 70)
    candidates = []

    for page_url in CMO_URLS:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 15:
                continue
            if "cm.bihar.gov.in" not in href:
                continue

            low = title.lower()
            if any(x in low for x in ["home", "contact", "login", "gallery", "photo", "feedback", "sitemap"]):
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
        content, date = fetch_generic_article_content(url, "CMO Bihar")
        if not content:
            continue

        obj = make_item(
            source="CMO Bihar",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Press Release"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("CMO BIHAR: Recent rolling window ka koi data nahi mila.")

    print(f"✅ CMO Bihar usable: {len(results)}")
    return results


IPRD_PAGES = [
    "https://state.bihar.gov.in/prdbihar/",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=6996",
]


def scrape_iprd_bihar():
    print("\n" + "=" * 70 + "\n📢 IPRD BIHAR\n" + "=" * 70)
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
            if any(x in low for x in ["home", "contact", "feedback", "copyright", "web information manager", "accessibility", "previous", "next", "department"]):
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
            item_type="Press Release"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("IPRD BIHAR: Recent rolling window ka koi data nahi mila.")

    print(f"✅ IPRD Bihar usable: {len(results)}")
    return results


CABINET_PAGES = [
    "https://state.bihar.gov.in/csd/",
    "https://state.bihar.gov.in/csd/CitizenHome.html",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=2929",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=1323",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=4935",
]


def scrape_bihar_cabinet():
    print("\n" + "=" * 70 + "\n🏛️ BIHAR CABINET\n" + "=" * 70)
    candidates = []

    for page_url in CABINET_PAGES:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 20:
                continue
            if "state.bihar.gov.in/csd" not in href.lower():
                continue

            low = title.lower()
            if not any(x in low for x in ["cabinet", "decision", "decisions", "press", "approval", "approved"]):
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
        content, date = fetch_generic_article_content(url, "Bihar Cabinet")
        if not content:
            continue

        obj = make_item(
            source="Bihar Cabinet",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Cabinet Decision"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("BIHAR CABINET: Recent rolling window ka koi data nahi mila.")

    print(f"✅ Bihar Cabinet usable: {len(results)}")
    return results


PTI_PAGES = [
    "https://www.ptinews.com/",
    "https://www.ptinews.com/latest-news",
    "https://www.ptinews.com/category/national",
]


def scrape_pti():
    print("\n" + "=" * 70 + "\n📰 PTI\n" + "=" * 70)
    candidates = []

    for page_url in PTI_PAGES:
        html = fetch_url(page_url)
        if not html:
            continue

        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))

            if not href or len(title) < 20:
                continue
            if "ptinews.com" not in href:
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
        content, date = fetch_generic_article_content(url, "PTI")
        if not content:
            continue

        obj = make_item(
            source="PTI",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="PTI Article"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("PTI: Recent rolling window ka koi data nahi mila.")

    print(f"✅ PTI usable: {len(results)}")
    return results


INDIA_GOV_PAGES = [
    "https://www.india.gov.in/",
    "https://www.india.gov.in/news",
    "https://www.india.gov.in/spotlight",
]


def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN\n" + "=" * 70)
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
            item_type="Government Article"
        )
        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)
    if not results:
        debug("INDIA.GOV.IN: Recent rolling window ka koi data nahi mila.")

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
    print("\n" + "=" * 80 + "\n🚀 STARTING ALL NEWS SOURCES\n" + "=" * 80)

    all_results = []
    source_results = {}

    source_results["PIB"] = safe_source("PIB", scrape_pib)
    source_results["News On AIR"] = safe_source("News On AIR", scrape_news_on_air)
    source_results["CMO Bihar"] = safe_source("CMO Bihar", scrape_cmo_bihar)
    source_results["IPRD Bihar"] = safe_source("IPRD Bihar", scrape_iprd_bihar)
    source_results["Bihar Cabinet"] = safe_source("Bihar Cabinet", scrape_bihar_cabinet)
    source_results["PTI"] = safe_source("PTI", scrape_pti)
    source_results["India.gov.in"] = safe_source("India.gov.in", scrape_india_gov)

    breakdown = {}

    for source, items in source_results.items():
        items = deduplicate(items)
        source_results[source] = items
        breakdown[source] = len(items)
        all_results.extend(items)

    all_results = deduplicate(all_results)

    bihar_sources = {"CMO Bihar", "IPRD Bihar", "Bihar Cabinet"}
    bihar = []
    national = []

    for item in all_results:
        source = item.get("source", "")
        if source in bihar_sources:
            bihar.append(item)
        else:
            national.append(item)

    print("\n" + "=" * 80 + "\n📊 FINAL SOURCE BREAKDOWN\n" + "=" * 80)
    print(json.dumps(breakdown, ensure_ascii=False, indent=2))

    print(f"\n🇮🇳 National / Other : {len(national)}")
    print(f"🏛️ Bihar               : {len(bihar)}")
    print(f"📰 Total               : {len(all_results)}")

    print("\n⚠️ SOURCE ZERO REPORT")
    for source, count in breakdown.items():
        if count == 0:
            print(f"❌ {source}: 0")
        else:
            print(f"✅ {source}: {count}")

    return national, bihar, breakdown


# ============================================================
# SAVE OUTPUT
# ============================================================

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
    print(f"💾 {OUTPUT_FILE} saved")
    print(f"📦 Total records: {len(all_news)}")
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
