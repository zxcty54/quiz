import os
import re
import json
import time
import hashlib
import warnings
import feedparser
import ssl
import html

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, parse_qs, unquote

from curl_cffi import requests as curl_requests
import requests as normal_requests
from requests.adapters import HTTPAdapter
from urllib3.util.ssl_ import create_urllib3_context

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "trialoutput.json"
TIMEOUT = 12  # Fast per-request timeout to prevent hangs
MAX_PER_SOURCE = 15

MIN_CONTENT_CHARS = 150
MIN_CONTENT_WORDS = 30  
MAX_CONTENT_WORDS = 800

DEFAULT_PIB_FEED = "https://www.google.com/alerts/feeds/18398184577640792063/4294037665781559395"
PIB_ALERT_FEED_URL = os.environ.get("PIB_ALERT_FEED_URL", "").strip() or DEFAULT_PIB_FEED

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
# HELPER & TEXT CLEANING
# ============================================================

def now_ist():
    return datetime.now(IST)

def debug(msg): print(f"🔍 {msg}")
def warn(msg): print(f"⚠️ {msg}")
def success(msg): print(f"✅ {msg}")

def extract_real_google_url(google_url):
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
        match = re.search(r'(https?://[^\s&]+)', google_url)
        if match:
            return match.group(1)
    except Exception as e:
        warn(f"URL Extraction Error: {e}")
    return google_url

def clean_url(url):
    if not url: return ""
    url = extract_real_google_url(str(url).strip())
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
    return html.unescape(re.sub(r'\s+', ' ', text)).strip()

def clean_title(title):
    title = clean_text(title)
    junk_titles = ["skip to main content", "skip to content", "home", "about us", "contact us"]
    if title.lower().strip() in junk_titles or len(title.strip()) < 10:
        return ""
    return title.strip()

def word_count(text):
    if not text: return 0
    return len(re.findall(r'\S+', text))

def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    if not text: return ""
    words = text.split()
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

# ============================================================
# FETCHERS WITH FAST FAILOVER
# ============================================================

def normal_fetch(url, verify=True):
    try:
        r = normal_requests.get(url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=verify)
        if r.status_code >= 400: return None
        return r.text
    except Exception: return None

def curl_fetch(url, verify=True):
    try:
        r = curl_requests.get(url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True, verify=verify)
        if r.status_code >= 400: return None
        return r.text
    except Exception: return None

def fetch_url(url):
    url = clean_url(url)
    if not url: return None
    
    if "bihar.gov.in" in url.lower():
        try:
            r = gov_session.get(url, headers=HEADERS, timeout=TIMEOUT, verify=False)
            if r.status_code == 200 and len(r.text) > 100: return r.text
        except Exception: pass

    res = curl_fetch(url, verify=True) or normal_fetch(url, verify=True) or normal_fetch(url, verify=False)
    return res

def fetch_generic_article_content(url, source=""):
    url = clean_url(url)
    if not url: return "", None
    html_raw = fetch_url(url)
    if not html_raw: return "", None

    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "header"]):
            tag.decompose()

        target_div = soup.find("div", class_="ReleaseContentDiv") or soup.find("form", id="form1") or soup.find("article")
        text = target_div.get_text(" ", strip=True) if target_div else soup.get_text(" ", strip=True)
        cleaned = clean_text(text)
        return trim_to_max_words(cleaned, MAX_CONTENT_WORDS), now_ist()
    except Exception:
        return "", None

# ============================================================
# ITEM BUILDER & DEDUP
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Scraped"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    if not clean_title_str or not clean_url_str or word_count(clean_content_str) < MIN_CONTENT_WORDS:
        return None

    dt_str = date.strftime("%a, %d %b %Y %H:%M:%S IST") if isinstance(date, datetime) else str(date or now_ist().strftime("%a, %d %b %Y %H:%M:%S IST"))

    return {
        "source": source,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": dt_str,
        "content": clean_content_str,
        "content_chars": len(clean_content_str),
        "content_words": word_count(clean_content_str),
        "type": item_type,
    }

def deduplicate(items):
    seen, output = set(), []
    for item in items:
        key = hashlib.sha1(clean_text(item.get("url", "") or item.get("title", "")).lower().encode()).hexdigest()
        if key not in seen:
            seen.add(key)
            output.append(item)
    return output

# ============================================================
# INDIVIDUAL SCRAPER SOURCES (ISOLATED)
# ============================================================

# 1. PIB GOOGLE ALERTS
def scrape_pib_news():
    print("\n" + "=" * 70 + "\n📰 PIB (GOVERNMENT PRESS INFORMATION BUREAU - GOOGLE ALERTS)\n" + "=" * 70)
    try:
        feed = feedparser.parse(PIB_ALERT_FEED_URL)
        entries = feed.entries
    except Exception as e:
        warn(f"Failed to parse PIB RSS feed: {e}")
        return []

    results = []
    for idx, entry in enumerate(entries[:MAX_PER_SOURCE], 1):
        try:
            raw_title = entry.get("title", "")
            raw_link = entry.get("link", "")
            feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

            clean_t = clean_title(raw_title)
            real_url = extract_real_google_url(raw_link)

            if not clean_t or not real_url: continue

            # Direct fallback logic to avoid hanging on slow target pages
            content = clean_text(feed_snippet)
            if word_count(content) < MIN_CONTENT_WORDS:
                scraped_content, _ = fetch_generic_article_content(real_url, "PIB")
                if scraped_content: content = scraped_content

            obj = make_item("PIB India", clean_t, real_url, now_ist(), content, "Press Release")
            if obj: results.append(obj)
        except Exception as e:
            warn(f"PIB Item {idx} Skip: {e}")
            continue

    return deduplicate(results)

# 2. NEWS ON AIR
def scrape_news_on_air():
    print("\n" + "=" * 70 + "\n📻 NEWS ON AIR\n" + "=" * 70)
    html_raw = fetch_url("https://newsonair.gov.in/category/national-news/")
    if not html_raw: return []
    
    results = []
    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin("https://newsonair.gov.in/", a.get("href")))
            title = clean_title(a.get_text())
            if "newsonair.gov.in" in href and len(title) > 20:
                content, date = fetch_generic_article_content(href, "News On AIR")
                item = make_item("News On AIR", title, href, date, content, "Article")
                if item: results.append(item)
                if len(results) >= MAX_PER_SOURCE: break
    except Exception as e:
        warn(f"News On AIR Exception: {e}")
    return deduplicate(results)

# 3. IPRD BIHAR
def scrape_iprd_bihar():
    print("\n" + "=" * 70 + "\n📢 IPRD BIHAR\n" + "=" * 70)
    html_raw = fetch_url("https://state.bihar.gov.in/prdbihar/")
    if not html_raw: return []
    
    results = []
    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin("https://state.bihar.gov.in/prdbihar/", a.get("href")))
            title = clean_title(a.get_text())
            if "state.bihar.gov.in/prdbihar" in href.lower() and len(title) > 20:
                content, date = fetch_generic_article_content(href, "IPRD Bihar")
                item = make_item("IPRD Bihar", title, href, date, content, "Press Release")
                if item: results.append(item)
                if len(results) >= MAX_PER_SOURCE: break
    except Exception as e:
        warn(f"IPRD Bihar Exception: {e}")
    return deduplicate(results)

# 4. BIHAR CABINET
def scrape_bihar_cabinet():
    print("\n" + "=" * 70 + "\n🏛️ BIHAR CABINET\n" + "=" * 70)
    html_raw = fetch_url("https://state.bihar.gov.in/csd/")
    if not html_raw: return []
    
    results = []
    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin("https://state.bihar.gov.in/csd/", a.get("href")))
            title = clean_title(a.get_text())
            if "cabinet" in title.lower() or "approval" in title.lower():
                content, date = fetch_generic_article_content(href, "Bihar Cabinet")
                item = make_item("Bihar Cabinet", title, href, date, content, "Cabinet Decision")
                if item: results.append(item)
                if len(results) >= MAX_PER_SOURCE: break
    except Exception as e:
        warn(f"Bihar Cabinet Exception: {e}")
    return deduplicate(results)

# 5. INDIA GOV
def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN\n" + "=" * 70)
    html_raw = fetch_url("https://www.india.gov.in/news")
    if not html_raw: return []
    
    results = []
    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin("https://www.india.gov.in/", a.get("href")))
            title = clean_title(a.get_text())
            if "india.gov.in" in href and len(title) > 20:
                content, date = fetch_generic_article_content(href, "India.gov.in")
                item = make_item("India.gov.in", title, href, date, content, "Government Article")
                if item: results.append(item)
                if len(results) >= MAX_PER_SOURCE: break
    except Exception as e:
        warn(f"India Gov Exception: {e}")
    return deduplicate(results)

# 6. BIHAR CM OFFICE
def scrape_bihar_cm():
    print("\n" + "=" * 70 + "\n🏛️ BIHAR CM PRESS RELEASE\n" + "=" * 70)
    url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
    html_raw = fetch_url(url)
    if not html_raw: return []
    
    results = []
    try:
        soup = BeautifulSoup(html_raw, "html.parser")
        for row in soup.find_all('tr')[:12]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = clean_title(cols[1].text.strip())
                link_tag = cols[1].find('a') or row.find('a')
                href = clean_url(urljoin(url, link_tag['href'])) if link_tag and link_tag.get('href') else url
                if title and len(title) > 10:
                    content, date = fetch_generic_article_content(href, "CMO Bihar")
                    if not content or word_count(content) < MIN_CONTENT_WORDS:
                        content = f"Official Press Release issued by CMO Bihar: {title}."
                    item = make_item("Bihar CM Office", title, href, date or now_ist(), content, "Press Release")
                    if item: results.append(item)
    except Exception as e:
        warn(f"Bihar CM Exception: {e}")
    return deduplicate(results)

# ============================================================
# SAFE INDIVIDUAL RUNNER
# ============================================================

def run_isolated_source(name, scraper_func):
    """Executes each scraper in an isolated sandbox. Crash in one will NOT affect others."""
    print(f"\n⚡ Starting Isolated Engine: [{name}]...")
    start_time = time.time()
    try:
        data = scraper_func()
        duration = round(time.time() - start_time, 2)
        success(f"[{name}] Completed in {duration}s | Extracted: {len(data)} items")
        return data
    except Exception as e:
        warn(f"[{name}] FAILED WITH ERROR: {e}")
        return []

# ============================================================
# MAIN PIPELINE
# ============================================================

def build_news():
    print("\n" + "=" * 80 + "\n🚀 STARTING ISOLATED SCRAPER PIPELINE\n" + "=" * 80)
    all_results, breakdown = [], {}

    sources = [
        ("News On AIR", scrape_news_on_air),
        ("PIB India", scrape_pib_news),
        ("IPRD Bihar", scrape_iprd_bihar),
        ("Bihar Cabinet", scrape_bihar_cabinet),
        ("India.gov.in", scrape_india_gov),
        ("Bihar CM Office", scrape_bihar_cm)
    ]

    for name, fn in sources:
        res = run_isolated_source(name, fn)
        breakdown[name] = len(res)
        all_results.extend(res)

    all_results = deduplicate(all_results)
    bihar_sources = {"IPRD Bihar", "Bihar Cabinet", "Bihar CM Office"}
    
    bihar = [x for x in all_results if x.get("source") in bihar_sources]
    national = [x for x in all_results if x.get("source") not in bihar_sources]

    output = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": len(bihar),
        "national_raw_count": len(national),
        "total_raw_count": len(all_results),
        "bihar_raw_news": bihar,
        "national_raw_news": national,
        "source_breakdown": breakdown,
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 File Output saved to '{OUTPUT_FILE}' with {len(all_results)} total items.")
    print("=" * 80)

if __name__ == "__main__":
    build_news()
