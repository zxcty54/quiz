import os
import re
import json
import time
import hashlib
import warnings
import feedparser
import ssl
import html
import xml.etree.ElementTree as ET

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
MAX_PER_SOURCE = 15

MIN_CONTENT_CHARS = 200
MIN_CONTENT_WORDS = 40
MAX_CONTENT_CHARS = 25000  # Strictly enforce max 25k characters

# Rolling 24 Hours Window for max coverage
MAX_NEWS_AGE_HOURS = 24

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

def debug(msg): print(f"🔍 {msg}")
def warn(msg): print(f"⚠️ {msg}")
def success(msg): print(f"✅ {msg}")


# ============================================================
# URL CLEANING
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


# ============================================================
# TEXT CLEANING
# ============================================================

def clean_text(text):
    if not text: return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return re.sub(r'\s+', ' ', text).strip()

def clean_title(title):
    title = clean_text(title)
    junk_titles = [
        "skip to main content", "skip to content", "home", "about us", 
        "contact us", "feedback", "sitemap", "disclaimer", "privacy policy",
        "accessibility options", "screen reader access", "search"
    ]
    if title.lower().strip() in junk_titles or len(title.strip()) < 15:
        return ""

    title = re.sub(
        r'\s*[-|–—]\s*(News On AIR|Prasar Bharati|MyGov)\s*$',
        '',
        title,
        flags=re.I
    )
    return title.strip()


# ============================================================
# CONTENT QUALITY
# ============================================================

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

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
    if not text: return 0
    low = text.lower()
    return sum(1 for x in PORTAL_BOILERPLATE if x in low)

def is_bad_portal_content(text):
    if not text: return True
    return boilerplate_score(text) >= 6

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
        except Exception: continue
    return None

def extract_date_from_soup(soup):
    selectors = [
        "meta[property='article:published_time']", "meta[property='og:published_time']",
        "meta[name='publish-date']", "meta[name='date']", "time", ".date", ".published"
    ]
    for selector in selectors:
        try:
            elements = soup.select(selector)
            for el in elements:
                value = el.get("content") or el.get("datetime") or el.get_text(" ", strip=True)
                d = parse_date(value)
                if d: return d
        except Exception: continue
    return None

def is_within_rolling_window(parsed_date):
    if not parsed_date: return True
    current_time = now_ist()
    parsed_date = parsed_date.replace(tzinfo=IST) if parsed_date.tzinfo is None else parsed_date.astimezone(IST)
    hours_diff = (current_time - parsed_date).total_seconds() / 3600.0
    return -2.0 <= hours_diff <= MAX_NEWS_AGE_HOURS


# ============================================================
# SMART FETCH ENGINE
# ============================================================

def fetch_url(url):
    url = clean_url(url)
    if not url: return None

    if "bihar.gov.in" in url.lower():
        try:
            r = gov_session.get(url, headers=HEADERS, timeout=TIMEOUT, verify=False)
            if r.status_code == 200 and len(r.text) > 100: return r.text
        except Exception: pass

    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400: return r.text
    except Exception: pass

    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
        if r.status_code < 400: return r.text
    except Exception: pass

    return None


# ============================================================
# ARTICLE CONTENT EXTRACTION
# ============================================================

def extract_article_content(soup, source=""):
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "form", "aside"]):
        tag.decompose()

    target_div = (
        soup.find(id="lblNewsDetail") or soup.find(id="lblContent") or
        soup.find(class_="innercontent") or soup.find(class_="news-detail") or
        soup.find(class_="pressrelease") or soup.find(class_="entry-content")
    )
    if target_div:
        extracted_text = clean_text(target_div.get_text(" ", strip=True))
        if len(extracted_text) >= 120: return extracted_text

    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if len(p) >= 20]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if len(joined) >= 150: return joined

    return clean_text(soup.get_text(" ", strip=True))

def fetch_generic_article_content(url, source=""):
    html_raw = fetch_url(url)
    if not html_raw: return "", None
    soup = BeautifulSoup(html_raw, "lxml")
    date = extract_date_from_soup(soup)
    content = extract_article_content(soup, source)
    return content, date


# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Scraped"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_title_str or not clean_url_str: return None

    # Fallback to Title if content is short
    if len(clean_content_str) < 50:
        clean_content_str = f"{clean_title_str}. Full official details published by {source} on {now_ist().strftime('%d %b %Y')}."

    if len(clean_content_str) > MAX_CONTENT_CHARS:
        clean_content_str = clean_content_str[:MAX_CONTENT_CHARS].rsplit(' ', 1)[0] + "..."

    parsed_date = date or parse_date(clean_title_str) or now_ist()
    parsed_date = parsed_date.replace(tzinfo=IST) if parsed_date.tzinfo is None else parsed_date.astimezone(IST)

    if not is_within_rolling_window(parsed_date): return None

    return {
        "source": source,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": parsed_date.strftime("%a, %d %b %Y %H:%M:%S IST"),
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
# BIHAR SPECIFIC SCRAPERS (CMO TABLE PARSER & GNEWS BIHAR)
# ============================================================

# 1. CMO BIHAR PRESS RELEASE (HTML Table Parser from Old Code)
CMO_BIHAR_URL = "https://cm.bihar.gov.in/users/preessrelease.aspx"

def scrape_cmo_bihar():
    print("\n" + "=" * 70 + "\n🏛️ SCRAPING CMO BIHAR PRESS RELEASE (TABLE PARSER)\n" + "=" * 70)
    html = fetch_url(CMO_BIHAR_URL)
    if not html:
        warn("⚠️ CMO Bihar page fetch failed!")
        return []

    soup = BeautifulSoup(html, "html.parser")
    results = []

    # Old code table parsing logic
    for row in soup.find_all('tr')[:12]:
        cols = row.find_all('td')
        if len(cols) >= 2:
            title = cols[1].text.strip()
            link_tag = cols[1].find('a') or row.find('a')
            href = clean_url(urljoin(CMO_BIHAR_URL, link_tag['href'])) if link_tag and link_tag.get('href') else CMO_BIHAR_URL

            if title and len(title) > 10:
                content, date = fetch_generic_article_content(href, "CMO Bihar")
                
                # If page inside doesn't load, use Title as content
                if not content or len(content) < 50:
                    content = f"Official CMO Bihar Release: {title}"

                obj = make_item(
                    source="CMO Bihar",
                    title=title,
                    url=href,
                    date=date or now_ist(),
                    content=content,
                    item_type="Press Release"
                )
                if obj:
                    results.append(obj)

    results = deduplicate(results)
    print(f"✅ CMO Bihar usable: {len(results)}")
    return results


# 2. GOOGLE NEWS BIHAR SCHEMES (XML Parser from Old Code)
GOOGLE_BIHAR_RSS = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture+when:2d&hl=hi&gl=IN&ceid=IN:hi"

def scrape_google_news_bihar():
    print("\n" + "=" * 70 + "\n🌐 SCRAPING GOOGLE NEWS BIHAR SCHEMES & INFRA\n" + "=" * 70)
    xml_text = fetch_url(GOOGLE_BIHAR_RSS)
    results = []

    if xml_text:
        try:
            root = ET.fromstring(xml_text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                link = item.find('link').text if item.find('link') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""

                if title and link:
                    content, date = fetch_generic_article_content(link, "Google News Bihar")
                    
                    if not content or len(content) < 50:
                        desc_tag = item.find('description')
                        content = clean_text(desc_tag.text) if desc_tag is not None else title

                    parsed_d = parse_date(pub_date) or date or now_ist()

                    obj = make_item(
                        source="Google News Bihar",
                        title=title,
                        url=link,
                        date=parsed_d,
                        content=content,
                        item_type="News Article"
                    )
                    if obj:
                        results.append(obj)
                        count += 1
                        if count >= MAX_PER_SOURCE: break
        except Exception as e:
            warn(f"⚠️ Google News Bihar XML Parse Error: {e}")

    results = deduplicate(results)
    print(f"✅ Google News Bihar usable: {len(results)}")
    return results


# ============================================================
# STANDARD SCRAPERS (NEWS ON AIR, MYGOV, IPRD, CABINET, INDIA.GOV)
# ============================================================

def scrape_news_on_air():
    print("\n" + "=" * 70 + "\n📻 NEWS ON AIR\n" + "=" * 70)
    urls = ["https://newsonair.gov.in/", "https://newsonair.gov.in/category/news/"]
    results = []
    for page_url in urls:
        html = fetch_url(page_url)
        if not html: continue
        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "newsonair.gov.in" in href:
                content, date = fetch_generic_article_content(href, "News On AIR")
                if content:
                    obj = make_item("News On AIR", title, href, date, content, "Article")
                    if obj: results.append(obj)
            if len(results) >= MAX_PER_SOURCE: break
    return deduplicate(results)

def scrape_mygov():
    print("\n" + "=" * 70 + "\n🇮🇳 MYGOV BLOG\n" + "=" * 70)
    feed = feedparser.parse("https://blog.mygov.in/feed/")
    results = []
    for entry in feed.entries[:MAX_PER_SOURCE]:
        title = clean_title(getattr(entry, 'title', ''))
        url = clean_url(getattr(entry, 'link', ''))
        if title and url:
            content, date = fetch_generic_article_content(url, "MyGov Blog")
            obj = make_item("MyGov Blog", title, url, date or parse_date(getattr(entry, 'published', None)), content or title, "Blog Article")
            if obj: results.append(obj)
    return deduplicate(results)

def scrape_iprd_bihar():
    print("\n" + "=" * 70 + "\n📢 IPRD BIHAR\n" + "=" * 70)
    urls = ["https://state.bihar.gov.in/prdbihar/"]
    results = []
    for page_url in urls:
        html = fetch_url(page_url)
        if not html: continue
        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "prdbihar" in href.lower():
                content, date = fetch_generic_article_content(href, "IPRD Bihar")
                obj = make_item("IPRD Bihar", title, href, date, content or title, "Press Release")
                if obj: results.append(obj)
            if len(results) >= MAX_PER_SOURCE: break
    return deduplicate(results)

def scrape_bihar_cabinet():
    print("\n" + "=" * 70 + "\n🏛️ BIHAR CABINET\n" + "=" * 70)
    urls = ["https://state.bihar.gov.in/csd/"]
    results = []
    for page_url in urls:
        html = fetch_url(page_url)
        if not html: continue
        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "csd" in href.lower():
                content, date = fetch_generic_article_content(href, "Bihar Cabinet")
                obj = make_item("Bihar Cabinet", title, href, date, content or title, "Cabinet Decision")
                if obj: results.append(obj)
            if len(results) >= MAX_PER_SOURCE: break
    return deduplicate(results)

def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN\n" + "=" * 70)
    urls = ["https://www.india.gov.in/news"]
    results = []
    for page_url in urls:
        html = fetch_url(page_url)
        if not html: continue
        soup = BeautifulSoup(html, "lxml")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "india.gov.in" in href:
                content, date = fetch_generic_article_content(href, "India.gov.in")
                obj = make_item("India.gov.in", title, href, date, content or title, "Government Article")
                if obj: results.append(obj)
            if len(results) >= MAX_PER_SOURCE: break
    return deduplicate(results)


# ============================================================
# SOURCE RUNNER & BUILD NEWS
# ============================================================

def safe_source(name, function):
    try:
        return function()
    except Exception as e:
        print(f"\n❌ {name} SCRAPER ERROR: {e}")
        return []

def build_news():
    print("\n" + "=" * 80 + "\n🚀 STARTING ALL NEWS SOURCES PIPELINE\n" + "=" * 80)

    all_results = []
    source_results = {}

    source_results["Google News Bihar"] = safe_source("Google News Bihar", scrape_google_news_bihar)
    source_results["CMO Bihar"] = safe_source("CMO Bihar", scrape_cmo_bihar)
    source_results["IPRD Bihar"] = safe_source("IPRD Bihar", scrape_iprd_bihar)
    source_results["Bihar Cabinet"] = safe_source("Bihar Cabinet", scrape_bihar_cabinet)
    source_results["News On AIR"] = safe_source("News On AIR", scrape_news_on_air)
    source_results["MyGov Blog"] = safe_source("MyGov Blog", scrape_mygov)
    source_results["India.gov.in"] = safe_source("India.gov.in", scrape_india_gov)

    breakdown = {}
    for source, items in source_results.items():
        items = deduplicate(items)
        breakdown[source] = len(items)
        all_results.extend(items)

    all_results = deduplicate(all_results)

    bihar_sources = {"Google News Bihar", "CMO Bihar", "IPRD Bihar", "Bihar Cabinet"}
    bihar = []
    national = []

    for item in all_results:
        if item.get("source") in bihar_sources:
            bihar.append(item)
        else:
            national.append(item)

    print("\n" + "=" * 80 + "\n📊 FINAL SOURCE BREAKDOWN\n" + "=" * 80)
    print(json.dumps(breakdown, ensure_ascii=False, indent=2))
    print(f"\n🇮🇳 National / Other : {len(national)}")
    print(f"🏛️ Bihar               : {len(bihar)}")
    print(f"📰 Total                : {len(all_results)}")

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
    print(f"💾 {OUTPUT_FILE} saved successfully!")
    print(f"📦 Total records: {len(all_news)}")
    print("=" * 80)

if __name__ == "__main__":
    try:
        national, bihar, breakdown = build_news()
        save_output(national, bihar, breakdown)
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
