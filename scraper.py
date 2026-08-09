import os
import json
import time
import urllib.parse
import re
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET
import urllib3

from curl_cffi import requests
from bs4 import BeautifulSoup
from dateutil import parser as date_parser

# Disable insecure request warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_PARAGRAPH_CHARS = 35

# =============================================================
# 1. DATE ENGINE
# =============================================================

def get_yesterday_info():
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")
    key_str = yesterday_dt.strftime("%Y-%m-%d")
    return yesterday_dt, date_str, key_str

def parse_any_date(date_str):
    if not date_str:
        return None

    date_str = str(date_str).strip()
    now = datetime.now()
    lower_str = date_str.lower()

    if "yesterday" in lower_str:
        return now - timedelta(days=1)
    if "today" in lower_str:
        return now

    relative_match = re.search(r"(\d+)\s+(hour|hr|day|min|minute)s?\s+ago", lower_str)
    if relative_match:
        val = int(relative_match.group(1))
        unit = relative_match.group(2)
        if "day" in unit:
            return now - timedelta(days=val)
        if "hour" in unit or "hr" in unit:
            return now - timedelta(hours=val)
        if "min" in unit:
            return now - timedelta(minutes=val)

    if date_str.isdigit():
        try:
            ts = int(date_str)
            if ts > 1e11: ts /= 1000
            return datetime.fromtimestamp(ts)
        except Exception:
            pass

    try:
        pub_tuple = email.utils.parsedate_tz(date_str)
        if pub_tuple:
            return datetime.fromtimestamp(email.utils.mktime_tz(pub_tuple))
    except Exception:
        pass

    try:
        parsed_dt = date_parser.parse(date_str, fuzzy=True, dayfirst=True)
        if parsed_dt.tzinfo is not None:
            parsed_dt = parsed_dt.astimezone().replace(tzinfo=None)
        return parsed_dt
    except Exception:
        pass

    return None

def is_yesterday_news(pub_date_str, target_dt):
    if not pub_date_str:
        return True
    pub_dt = parse_any_date(pub_date_str)
    if pub_dt:
        start_window = target_dt - timedelta(days=3)
        end_window = target_dt + timedelta(days=1.5)
        return start_window <= pub_dt <= end_window
    return True

# =============================================================
# 2. TEXT CLEANING & NOISE REMOVER
# =============================================================

def clean_cdata_and_html(text):
    if not text:
        return ""
    text = str(text)
    text = re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", text, flags=re.DOTALL)
    soup = BeautifulSoup(text, "html.parser")
    return " ".join(soup.get_text(" ", strip=True).split()).strip()

def normalize_text(text):
    if not text:
        return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = re.sub(r"\s+", " ", text)
    return text.strip()

# =============================================================
# 3. SAFE FETCHER WITH BROWSER HEADERS
# =============================================================

def safe_fetch(url, timeout=12):
    if not url:
        return None

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9,hi;q=0.8"
    }

    try:
        res = requests.get(url, impersonate="chrome", headers=headers, timeout=timeout, verify=False)
        if res.status_code == 200:
            return res.content
    except Exception as e:
        print(f"⚠️ Direct fetch failed: {url[:50]} | {e}")

    if SCRAPINGANT_KEY:
        try:
            encoded_url = urllib.parse.quote(url, safe="")
            sa_url = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_KEY}&browser=false"
            sa_res = requests.get(sa_url, timeout=20)
            if sa_res.status_code == 200:
                return sa_res.content
        except Exception as e:
            print(f"❌ ScrapingAnt failed: {e}")

    return None

# =============================================================
# 4. JSON-LD & DEEP PIB EXTRACTION ENGINE
# =============================================================

def extract_jsonld_article(soup):
    """Grok's JSON-LD Schema Extractor"""
    for script in soup.find_all("script", type="application/ld+json"):
        raw = script.string or script.get_text()
        if not raw: continue
        try:
            data = json.loads(raw.strip())
            objects = data if isinstance(data, list) else [data]
            if isinstance(data, dict) and isinstance(data.get("@graph"), list):
                objects.extend(data["@graph"])

            for obj in objects:
                if isinstance(obj, dict):
                    obj_type = str(obj.get("@type", "")).lower()
                    if "article" in obj_type or "newsarticle" in obj_type:
                        body = obj.get("articleBody")
                        if body and len(body) >= MIN_CONTENT_CHARS:
                            return normalize_text(body)
        except Exception:
            continue
    return ""

def fetch_deep_pib_content(article_url):
    """Guaranteed PIB Deep Scraper with PRID Extraction"""
    if not article_url or not isinstance(article_url, str):
        return ""

    prid_match = re.search(r"PRID=(\d+)", article_url, re.IGNORECASE)
    if "pib.gov.in" in article_url.lower() and prid_match:
        prid = prid_match.group(1)
        target_url = f"https://pib.gov.in/PressReleasePage.aspx?PRID={prid}"
    else:
        target_url = article_url

    content = safe_fetch(target_url, timeout=12)
    if not content:
        return ""

    try:
        soup = BeautifulSoup(content, "html.parser")
        for noise in soup.select("script, style, nav, footer, header, form, .release_back, .share-box"):
            noise.decompose()

        content_div = (
            soup.find(id="ContentPlaceHolder1_divpri") or
            soup.find(id="divpri") or
            soup.find(class_="ReleaseIdText") or
            soup.find(class_="innercontent") or
            soup.find(class_="release_text")
        )

        if content_div:
            elements = content_div.find_all(['p', 'tr', 'li'])
            text_blocks = [normalize_text(el.text) for el in elements if len(normalize_text(el.text)) > 35]
            full_text = " ".join(text_blocks)
        else:
            paragraphs = soup.find_all('p')
            full_text = " ".join([normalize_text(p.text) for p in paragraphs if len(normalize_text(p.text)) > 35])

        result = normalize_text(full_text)
        return result[:MAX_ARTICLE_CHARS]
    except Exception as e:
        print(f"⚠️ PIB parsing error: {e}")
        return ""

def fetch_generic_article_content(article_url):
    """Scrapes The Hindu, Indian Express, and other major portals with JSON-LD Fallback"""
    if not article_url or not isinstance(article_url, str) or "news.google.com" in article_url:
        return ""

    content = safe_fetch(article_url, timeout=10)
    if not content:
        return ""

    try:
        soup = BeautifulSoup(content, "html.parser")

        # 1. Try JSON-LD First (Grok's technique)
        jsonld_text = extract_jsonld_article(soup)
        if len(jsonld_text) >= 250:
            return jsonld_text[:MAX_ARTICLE_CHARS]

        # 2. HTML Containers Fallback
        for noise in soup.select("script, style, nav, footer, header, form, iframe, .advertisement"):
            noise.decompose()

        content_div = (
            soup.find(class_="article-body") or
            soup.find(id="content-body") or
            soup.find(class_="story-element") or
            soup.find(class_="paywall") or
            soup.find(class_="full-details")
        )

        elements = content_div.find_all('p') if content_div else soup.find_all('p')
        text_blocks = [normalize_text(p.text) for p in elements if len(normalize_text(p.text)) > 35]
        return " ".join(text_blocks)[:MAX_ARTICLE_CHARS]
    except Exception:
        return ""

# =============================================================
# 5. DEDUPLICATION
# =============================================================

def remove_duplicate_news(news_list):
    seen_titles = set()
    unique_news = []
    dropped_count = 0

    for news in news_list:
        clean_title = re.sub(r"\[.*?\]", "", news).strip().lower()[:80]
        clean_title = re.sub(r"[^a-z0-9]", "", clean_title)
        if clean_title and clean_title not in seen_titles:
            seen_titles.add(clean_title)
            unique_news.append(news)
        else:
            dropped_count += 1

    print(f"🧹 Deduplication: Input={len(news_list)} | Dropped={dropped_count} | Unique={len(unique_news)}")
    return unique_news

# =============================================================
# 6. MAIN SCRAPER
# =============================================================

def run_scraper():
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Optimized Deep Scraper for Date: {date_str}\n")

    bihar_items = []
    national_items = []
    source_stats = {}

    # A. PIB CENTRAL
    print("🇮🇳 Scraping PIB Central Releases (PRID Deep Engine)...")
    pib_count = 0
    pib_rss_url = "https://www.pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
    pib_content = safe_fetch(pib_rss_url)

    if pib_content:
        try:
            soup = BeautifulSoup(pib_content, "html.parser")
            for item in soup.find_all("item")[:15]:
                title = clean_cdata_and_html(item.find("title").text) if item.find("title") else ""
                link = clean_cdata_and_html(item.find("link").text) if item.find("link") else ""
                pub_date = clean_cdata_and_html(item.find("pubdate").text) if item.find("pubdate") else ""

                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_deep_pib_content(link) if link else ""
                    if len(deep_text) >= 120:
                        content_to_use = deep_text
                        print(f"  ✅ PIB Deep ({len(deep_text)} chars): {title[:50]}...")
                    else:
                        desc = item.find("description")
                        content_to_use = clean_cdata_and_html(desc.text) if desc else title
                        print(f"  ⚠️ PIB RSS fallback: {title[:50]}...")

                    national_items.append(f"[Source: PIB Central] Title: {title} | Article Content: {content_to_use}")
                    pib_count += 1
                    if pib_count >= 10: break
        except Exception as e:
            print(f"⚠️ PIB RSS Error: {e}")
    source_stats["PIB Central"] = pib_count

    # B. THE HINDU
    print("\n📰 Scraping The Hindu...")
    hindu_count = 0
    content = safe_fetch("https://www.thehindu.com/news/national/feeder/default.rss")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for item in soup.find_all("item")[:12]:
                title = clean_cdata_and_html(item.find("title").text) if item.find("title") else ""
                link = clean_cdata_and_html(item.find("link").text) if item.find("link") else ""
                pub_date = clean_cdata_and_html(item.find("pubdate").text) if item.find("pubdate") else ""

                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_generic_article_content(link)
                    desc = item.find("description")
                    final_content = deep_text if len(deep_text) >= 200 else (clean_cdata_and_html(desc.text) if desc else title)

                    national_items.append(f"[Source: The Hindu] Title: {title} | Article Content: {final_content}")
                    hindu_count += 1
                    if hindu_count >= 6: break
        except Exception as e:
            print(f"⚠️ The Hindu Error: {e}")
    source_stats["The Hindu"] = hindu_count

    # C. INDIAN EXPRESS
    print("\n📰 Scraping Indian Express...")
    ie_count = 0
    content = safe_fetch("https://indianexpress.com/section/india/feed/")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for item in soup.find_all("item")[:12]:
                title = clean_cdata_and_html(item.find("title").text) if item.find("title") else ""
                link = clean_cdata_and_html(item.find("link").text) if item.find("link") else ""
                pub_date = clean_cdata_and_html(item.find("pubdate").text) if item.find("pubdate") else ""

                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_generic_article_content(link)
                    desc = item.find("description")
                    final_content = deep_text if len(deep_text) >= 200 else (clean_cdata_and_html(desc.text) if desc else title)

                    national_items.append(f"[Source: Indian Express] Title: {title} | Article Content: {final_content}")
                    ie_count += 1
                    if ie_count >= 6: break
        except Exception as e:
            print(f"⚠️ Indian Express Error: {e}")
    source_stats["Indian Express"] = ie_count

    # D. GOOGLE NEWS BIHAR
    print("\n📍 Scraping Bihar News...")
    g_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+when:2d&hl=hi&gl=IN&ceid=IN:hi"
    content = safe_fetch(g_url)
    g_bihar_count = 0
    if content:
        try:
            root = ET.fromstring(content)
            for item in root.findall(".//item")[:15]:
                title = clean_cdata_and_html(item.find("title").text) if item.find("title") is not None else ""
                pub_date = clean_cdata_and_html(item.find("pubDate").text) if item.find("pubDate") is not None else ""
                desc = clean_cdata_and_html(item.find("description").text) if item.find("description") is not None else ""

                if title and is_yesterday_news(pub_date, target_dt):
                    bihar_items.append(f"[Source: Google News Bihar] Title: {title} | Article Content: {desc}")
                    g_bihar_count += 1
                    if g_bihar_count >= 8: break
        except Exception as e:
            print(f"⚠️ Google News Bihar Error: {e}")
    source_stats["Google News Bihar"] = g_bihar_count

    # E. CMO BIHAR
    print("\n🏛️ Scraping CMO Bihar...")
    cmo_count = 0
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for row in soup.find_all("tr")[:15]:
                cols = row.find_all("td")
                if len(cols) >= 2:
                    title = normalize_text(cols[1].get_text(" ", strip=True))
                    if title and len(title) > 10:
                        bihar_items.append(f"[Source: CMO Bihar] Title: {title}")
                        cmo_count += 1
                        if cmo_count >= 8: break
        except Exception as e:
            print(f"⚠️ CMO Bihar Error: {e}")
    source_stats["CMO Bihar"] = cmo_count

    # Clean duplicates
    bihar_clean = remove_duplicate_news(bihar_items)
    national_clean = remove_duplicate_news(national_items)

    print(f"\n📊 --- RAW SCRAPING SUMMARY BREAKDOWN ---")
    print(json.dumps(source_stats, indent=2, ensure_ascii=False))

    # Save to rawnews.json
    raw_payload = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "target_date_str": date_str,
        "target_key_str": key_str,
        "source_stats": source_stats,
        "bihar_raw_count": len(bihar_clean),
        "national_raw_count": len(national_clean),
        "bihar_raw_news": bihar_clean,
        "national_raw_news": national_clean
    }

    with open("rawnews.json", "w", encoding="utf-8") as f:
        json.dump(raw_payload, f, ensure_ascii=False, indent=2)

    print(f"\n💾 'rawnews.json' updated successfully!")

if __name__ == "__main__":
    run_scraper()
