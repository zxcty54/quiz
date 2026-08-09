import os
import json
import re
import time
import feedparser
import ssl
import warnings
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse, parse_qs, urljoin

from curl_cffi import requests
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# -------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------
OUTPUT_FILE = "rawnews.json"
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/150.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

def now_ist():
    return datetime.now(IST)

def debug(msg):
    print(f"🔍 {msg}")

def warn(msg):
    print(f"⚠️ {msg}")

def success(msg):
    print(f"✅ {msg}")

def clean_text(text):
    if not text:
        return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return " ".join(text.split()).strip()

def clean_title(title):
    title = clean_text(title)
    title = re.sub(
        r'\s*[-|–—]\s*(PIB|Press Information Bureau|News On AIR|Prasar Bharati|MyGov).*$',
        '',
        title,
        flags=re.I
    )
    return title.strip()

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

# -------------------------------------------------------------
# PIB PROVEN EXTRACTION ENGINE (YOUR WORKING CODE)
# -------------------------------------------------------------
def convert_pib_url(url):
    """RSS Iframe URL ko Full Article Page URL mein convert karta hai"""
    if not url:
        return ""
    parsed = urlparse(url)
    if "PressReleaseIframePage.aspx" in parsed.path:
        qs = parse_qs(parsed.query)
        prid = qs.get("PRID", [""])[0] or qs.get("prid", [""])[0]
        if prid:
            return f"https://www.pib.gov.in/PressReleasePage.aspx?PRID={prid}&reg=3&lang=1"
    return url

def fetch_pib_full_article(article_url):
    """Press Release Page se targeted body text extract karta hai"""
    try:
        res = requests.get(article_url, headers=HEADERS, timeout=15, impersonate="chrome", verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            
            # Clean unwanted UI components
            for tag in soup(["script", "style", "nav", "footer", "header", "form", "aside"]):
                tag.decompose()
                
            # PIB specific content containers
            content_div = (
                soup.find("div", class_="ReleaseContentText") or
                soup.find("div", class_="content-area") or
                soup.find("div", id="Title") or
                soup.find("td", class_="text_just") or
                soup.find(id="ContentPlaceHolder1_divpri") or
                soup.find(id="divpri")
            )
            
            if content_div:
                paragraphs = content_div.find_all(["p", "div", "td", "tr"])
                clean_paragraphs = []
                for p in paragraphs:
                    txt = clean_text(p.text)
                    if len(txt) > 35 and not any(junk in txt.lower() for junk in ["copyright", "pib release", "posted on"]):
                        clean_paragraphs.append(txt)
                        
                full_content = " ".join(clean_paragraphs)
                if len(full_content) > 100:
                    return full_content[:15000]

            # Fallback: All paragraphs on the page
            paragraphs = soup.find_all("p")
            all_text = " ".join([clean_text(p.text) for p in paragraphs if len(clean_text(p.text)) > 30])
            if len(all_text) > 100:
                return all_text[:15000]

    except Exception as e:
        warn(f"Failed to fetch full PIB article from {article_url}: {e}")
        
    return ""

def scrape_pib():
    pib_rss_url = "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"
    print(f"\n" + "=" * 70 + f"\n📡 Scraping PIB Central: {pib_rss_url}\n" + "=" * 70)
    
    try:
        res = requests.get(pib_rss_url, headers=HEADERS, timeout=20, impersonate="chrome", verify=False)
        if res.status_code != 200:
            warn(f"Failed to fetch PIB RSS Feed. Status: {res.status_code}")
            return []
    except Exception as e:
        warn(f"PIB RSS Network Error: {e}")
        return []

    parsed = feedparser.parse(res.content)
    entries = parsed.entries or []
    debug(f"Found {len(entries)} items in PIB RSS Feed.")

    pib_items = []

    for entry in entries[:15]:
        title = clean_title(entry.get("title", ""))
        rss_link = entry.get("link", "").strip()
        pub_date = entry.get("published", "") or entry.get("pubDate", "")

        if not title or not rss_link:
            continue

        full_url = convert_pib_url(rss_link)
        debug(f"PIB Processing: {title[:70]}...")

        full_content = fetch_pib_full_article(full_url)
        
        if not full_content or len(full_content) < 100:
            warn(f"Skipped PIB (No Body Content Scraped): {title[:60]}")
            continue

        pib_items.append({
            "source": "PIB Central",
            "title": title,
            "url": full_url,
            "date": pub_date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": full_content,
            "content_chars": len(full_content),
            "type": "PIB Press Release"
        })
        success(f"PIB CONTENT FOUND | {len(full_content)} chars")
        time.sleep(0.4)

    return pib_items

# -------------------------------------------------------------
# GENERIC SCRAPER ENGINE FOR OTHER SOURCES
# -------------------------------------------------------------
def fetch_generic_html(url):
    url = clean_url(url)
    if not url:
        return ""
    try:
        res = requests.get(url, headers=HEADERS, timeout=20, impersonate="chrome", verify=False)
        if res.status_code == 200:
            return res.text
    except Exception as e:
        warn(f"Fetch failed for {url}: {e}")
    return ""

def extract_generic_content(soup):
    for tag in soup(["script", "style", "noscript", "svg", "canvas", "nav", "footer", "form", "aside"]):
        tag.decompose()

    target_div = (
        soup.find(id="lblNewsDetail") or
        soup.find(id="lblContent") or
        soup.find(class_="innercontent") or
        soup.find(class_="news-detail") or
        soup.find(class_="entry-content") or
        soup.find(class_="post-content") or
        soup.find(class_="article-body") or
        soup.find("article")
    )

    if target_div:
        txt = clean_text(target_div.get_text(" ", strip=True))
        if len(txt) >= 120:
            return txt

    paragraphs = [clean_text(p.text) for p in soup.find_all(["p", "tr", "li"]) if len(clean_text(p.text)) >= 25]
    joined = clean_text(" ".join(paragraphs))
    if len(joined) >= 200:
        return joined

    return ""

def fetch_generic_article_content(url, source=""):
    html_raw = fetch_generic_html(url)
    if not html_raw:
        return "", None

    soup = BeautifulSoup(html_raw, "html.parser")
    content = extract_generic_content(soup)
    
    if content and len(content) >= 150:
        success(f"{source} CONTENT FOUND | {len(content)} chars")
        return content, now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT")
    
    warn(f"{source} NO ARTICLE CONTENT: {url}")
    return "", None

# -------------------------------------------------------------
# ACTIVE SOURCES
# -------------------------------------------------------------

# 1. NEWS ON AIR
def scrape_news_on_air():
    print("\n" + "=" * 70 + "\n📻 NEWS ON AIR\n" + "=" * 70)
    urls = [
        "https://newsonair.gov.in/",
        "https://newsonair.gov.in/category/news/",
        "https://newsonair.gov.in/category/national-news/",
    ]
    candidates = []
    for page_url in urls:
        html = fetch_generic_html(page_url)
        if not html:
            continue
        soup = BeautifulSoup(html, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "newsonair.gov.in" in href:
                candidates.append((title, href))

    results = []
    seen = set()
    for title, url in candidates:
        if url in seen:
            continue
        seen.add(url)

        content, date = fetch_generic_article_content(url, "News On AIR")
        if not content:
            continue

        results.append({
            "source": "News On AIR",
            "title": title,
            "url": url,
            "date": date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": content,
            "content_chars": len(content),
            "type": "Article"
        })
        if len(results) >= MAX_PER_SOURCE:
            break

    print(f"✅ News On AIR usable: {len(results)}")
    return results

# 2. MYGOV BLOG
def scrape_mygov():
    print("\n" + "=" * 70 + "\n🇮🇳 MYGOV BLOG\n" + "=" * 70)
    mygov_rss = "https://blog.mygov.in/feed/"
    try:
        res = requests.get(mygov_rss, headers=HEADERS, timeout=20, impersonate="chrome", verify=False)
        if res.status_code != 200:
            return []
        parsed = feedparser.parse(res.content)
    except Exception as e:
        warn(f"MyGov Blog Network Error: {e}")
        return []

    results = []
    for entry in (parsed.entries or [])[:MAX_PER_SOURCE * 2]:
        title = clean_title(getattr(entry, 'title', ''))
        url = clean_url(getattr(entry, 'link', ''))
        if not title or not url:
            continue

        content, date = fetch_generic_article_content(url, "MyGov Blog")

        if not content:
            summary = clean_text(getattr(entry, 'summary', '') or getattr(entry, 'description', ''))
            if len(summary) >= 200:
                content = summary

        if not content:
            continue

        results.append({
            "source": "MyGov Blog",
            "title": title,
            "url": url,
            "date": date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": content,
            "content_chars": len(content),
            "type": "Blog Article"
        })
        if len(results) >= MAX_PER_SOURCE:
            break

    print(f"✅ MyGov Blog usable: {len(results)}")
    return results

# 3. IPRD BIHAR
def scrape_iprd_bihar():
    print("\n" + "=" * 70 + "\n📢 IPRD BIHAR\n" + "=" * 70)
    pages = [
        "https://state.bihar.gov.in/prdbihar/",
        "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931",
        "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930",
    ]
    candidates = []
    for page_url in pages:
        html = fetch_generic_html(page_url)
        if not html:
            continue
        soup = BeautifulSoup(html, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "state.bihar.gov.in/prdbihar" in href.lower():
                if not any(x in title.lower() for x in ["home", "contact", "feedback", "copyright"]):
                    candidates.append((title, href))

    results = []
    seen = set()
    for title, url in candidates:
        if url in seen:
            continue
        seen.add(url)

        content, date = fetch_generic_article_content(url, "IPRD Bihar")
        if not content:
            continue

        results.append({
            "source": "IPRD Bihar",
            "title": title,
            "url": url,
            "date": date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": content,
            "content_chars": len(content),
            "type": "Press Release"
        })
        if len(results) >= MAX_PER_SOURCE:
            break

    print(f"✅ IPRD Bihar usable: {len(results)}")
    return results

# 4. BIHAR CABINET
def scrape_bihar_cabinet():
    print("\n" + "=" * 70 + "\n🏛️ BIHAR CABINET\n" + "=" * 70)
    pages = [
        "https://state.bihar.gov.in/csd/",
        "https://state.bihar.gov.in/csd/CitizenHome.html",
        "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=2929",
    ]
    candidates = []
    for page_url in pages:
        html = fetch_generic_html(page_url)
        if not html:
            continue
        soup = BeautifulSoup(html, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "state.bihar.gov.in/csd" in href.lower():
                if any(x in title.lower() for x in ["cabinet", "decision", "press", "approval"]):
                    candidates.append((title, href))

    results = []
    seen = set()
    for title, url in candidates:
        if url in seen:
            continue
        seen.add(url)

        content, date = fetch_generic_article_content(url, "Bihar Cabinet")
        if not content:
            continue

        results.append({
            "source": "Bihar Cabinet",
            "title": title,
            "url": url,
            "date": date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": content,
            "content_chars": len(content),
            "type": "Cabinet Decision"
        })
        if len(results) >= MAX_PER_SOURCE:
            break

    print(f"✅ Bihar Cabinet usable: {len(results)}")
    return results

# 5. INDIA.GOV.IN
def scrape_india_gov():
    print("\n" + "=" * 70 + "\n🇮🇳 INDIA.GOV.IN\n" + "=" * 70)
    pages = [
        "https://www.india.gov.in/",
        "https://www.india.gov.in/news",
        "https://www.india.gov.in/spotlight",
    ]
    candidates = []
    for page_url in pages:
        html = fetch_generic_html(page_url)
        if not html:
            continue
        soup = BeautifulSoup(html, "html.parser")
        for a in soup.find_all("a", href=True):
            href = clean_url(urljoin(page_url, a.get("href")))
            title = clean_title(a.get_text(" ", strip=True))
            if href and len(title) >= 20 and "india.gov.in" in href:
                if not any(x in title.lower() for x in ["home", "about", "contact", "feedback"]):
                    candidates.append((title, href))

    results = []
    seen = set()
    for title, url in candidates:
        if url in seen:
            continue
        seen.add(url)

        content, date = fetch_generic_article_content(url, "India.gov.in")
        if not content:
            continue

        results.append({
            "source": "India.gov.in",
            "title": title,
            "url": url,
            "date": date or now_ist().strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "content": content,
            "content_chars": len(content),
            "type": "Government Article"
        })
        if len(results) >= MAX_PER_SOURCE:
            break

    print(f"✅ India.gov.in usable: {len(results)}")
    return results

# -------------------------------------------------------------
# BUILD & DEDUPLICATE ALL NEWS
# -------------------------------------------------------------
def safe_source(name, function):
    try:
        return function()
    except Exception as e:
        warn(f"{name} SCRAPER ERROR: {e}")
        return []

def deduplicate(items):
    seen = set()
    output = []
    for item in items:
        url = clean_url(item.get("url", ""))
        title = clean_text(item.get("title", "")).lower()
        key = url or title
        if key and key not in seen:
            seen.add(key)
            output.append(item)
    return output

def build_news():
    print("\n" + "=" * 80 + "\n🚀 STARTING ALL NEWS SOURCES\n" + "=" * 80)

    source_results = {}
    source_results["PIB Central"] = safe_source("PIB", scrape_pib)
    source_results["News On AIR"] = safe_source("News On AIR", scrape_news_on_air)
    source_results["MyGov Blog"] = safe_source("MyGov Blog", scrape_mygov)
    source_results["IPRD Bihar"] = safe_source("IPRD Bihar", scrape_iprd_bihar)
    source_results["Bihar Cabinet"] = safe_source("Bihar Cabinet", scrape_bihar_cabinet)
    source_results["India.gov.in"] = safe_source("India.gov.in", scrape_india_gov)

    bihar_sources = {"IPRD Bihar", "Bihar Cabinet"}
    bihar = []
    national = []
    breakdown = {}

    for source_name, items in source_results.items():
        clean_items = deduplicate(items)
        breakdown[source_name] = len(clean_items)

        if source_name in bihar_sources:
            bihar.extend(clean_items)
        else:
            national.extend(clean_items)

    national = deduplicate(national)
    bihar = deduplicate(bihar)
    all_news = national + bihar

    print("\n" + "=" * 80 + "\n📊 FINAL SOURCE BREAKDOWN\n" + "=" * 80)
    print(json.dumps(breakdown, ensure_ascii=False, indent=2))
    print(f"\n🇮🇳 National : {len(national)}")
    print(f"🏛️ Bihar    : {len(bihar)}")
    print(f"📰 Total    : {len(all_news)}")

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
    except KeyboardInterrupt:
        print("\n⛔ Scraper stopped by user.")
    except Exception as e:
        print(f"\n❌ FATAL ERROR: {e}")
        raise
