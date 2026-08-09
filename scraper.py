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

# =============================================================
# CONFIG
# =============================================================

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 12000
MIN_CONTENT_CHARS = 250
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
            if ts > 1e11:
                ts /= 1000
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
# 2. TEXT CLEANING
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


def remove_duplicate_paragraphs(paragraphs):
    seen = set()
    output = []

    for text in paragraphs:
        text = normalize_text(text)

        if len(text) < MIN_PARAGRAPH_CHARS:
            continue

        key = re.sub(r"[^a-z0-9]+", "", text.lower())

        if not key:
            continue

        if key in seen:
            continue

        seen.add(key)
        output.append(text)

    return output


# =============================================================
# 3. NOISE DETECTION
# =============================================================

NOISE_WORDS = [
    "subscribe", "subscription", "sign in", "log in", "login",
    "newsletter", "advertisement", "advertising", "privacy policy",
    "terms of use", "terms and conditions", "cookie policy", "cookie",
    "follow us", "share this", "share on", "read more", "related stories",
    "recommended", "you may also like", "download app", "app store",
    "google play", "copyright", "all rights reserved", "whatsapp",
    "telegram", "facebook", "instagram", "twitter", "linkedin", "youtube"
]


def is_noise_text(text):
    low = text.lower()

    for word in NOISE_WORDS:
        if word in low:
            if len(text) < 180:
                return True

    return False


# =============================================================
# 4. SAFE FETCHER
# =============================================================

def safe_fetch(url, timeout=15, browser=False):
    if not url:
        return None

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
        "Cache-Control": "no-cache"
    }

    try:
        res = requests.get(
            url,
            impersonate="chrome",
            headers=headers,
            timeout=timeout,
            verify=False
        )

        if res.status_code == 200:
            return res.content

        print(f"⚠️ Direct HTTP {res.status_code}: {url[:80]}")

    except Exception as e:
        print(f"⚠️ Direct fetch failed: {url[:60]} | {e}")

    if SCRAPINGANT_KEY:
        try:
            encoded_url = urllib.parse.quote(url, safe="")
            browser_value = "true" if browser else "false"

            sa_url = (
                "https://api.scrapingant.com/v2/general"
                f"?url={encoded_url}"
                f"&x-api-key={SCRAPINGANT_KEY}"
                f"&browser={browser_value}"
            )

            sa_res = requests.get(sa_url, timeout=35 if browser else 25)

            if sa_res.status_code == 200:
                print(f"✅ ScrapingAnt success (browser={browser})")
                return sa_res.content

            print(f"⚠️ ScrapingAnt HTTP {sa_res.status_code}")

        except Exception as e:
            print(f"❌ ScrapingAnt failed: {e}")

    return None


# =============================================================
# 5. JSON-LD EXTRACTION
# =============================================================

def extract_jsonld_article(soup):
    candidates = []

    for script in soup.find_all("script", type="application/ld+json"):
        raw = script.string or script.get_text()

        if not raw:
            continue

        try:
            data = json.loads(raw.strip())
        except Exception:
            try:
                raw = raw.strip()
                raw = re.sub(r",\s*}", "}", raw)
                raw = re.sub(r",\s*]", "]", raw)
                data = json.loads(raw)
            except Exception:
                continue

        objects = []
        if isinstance(data, list):
            objects.extend(data)
        elif isinstance(data, dict):
            objects.append(data)
            graph = data.get("@graph")
            if isinstance(graph, list):
                objects.extend(graph)

        for obj in objects:
            if not isinstance(obj, dict):
                continue

            obj_type = obj.get("@type", "")
            if isinstance(obj_type, list):
                obj_type = " ".join(str(x) for x in obj_type)

            obj_type = str(obj_type).lower()

            if "article" in obj_type or "newsarticle" in obj_type or "report" in obj_type:
                article_body = obj.get("articleBody")
                if article_body:
                    text = normalize_text(article_body)
                    if len(text) >= MIN_CONTENT_CHARS:
                        candidates.append(("jsonld", text))

    if candidates:
        candidates.sort(key=lambda x: len(x[1]), reverse=True)
        return candidates[0][1]

    return ""


# =============================================================
# 6. ARTICLE SCRAPERS
# =============================================================

def extract_container_text(container):
    if not container:
        return ""

    paragraphs = []
    p_tags = container.find_all("p")

    for p in p_tags:
        text = normalize_text(p.get_text(" ", strip=True))
        if len(text) >= MIN_PARAGRAPH_CHARS:
            if not is_noise_text(text):
                paragraphs.append(text)

    paragraphs = remove_duplicate_paragraphs(paragraphs)

    if len(paragraphs) < 3:
        for div in container.find_all("div"):
            text = normalize_text(div.get_text(" ", strip=True))
            if 60 <= len(text) <= 1200 and not is_noise_text(text):
                paragraphs.append(text)

    paragraphs = remove_duplicate_paragraphs(paragraphs)

    if not paragraphs:
        return ""

    return " ".join(paragraphs)


def fetch_generic_article_content(article_url):
    if not article_url or not isinstance(article_url, str) or "news.google.com" in article_url.lower():
        return ""

    content = safe_fetch(article_url, timeout=12, browser=False)

    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            jsonld_text = extract_jsonld_article(soup)

            if len(jsonld_text) >= 250:
                return jsonld_text[:MAX_ARTICLE_CHARS]

            for noise in soup.select("script, style, nav, footer, header, form, iframe, .advertisement"):
                noise.decompose()

            content_div = (
                soup.find(class_="article-body") or
                soup.find(id="content-body") or
                soup.find(class_="story-element") or
                soup.find(class_="full-details") or
                soup.find(class_="article-content")
            )

            text = extract_container_text(content_div) if content_div else extract_container_text(soup)
            if len(text) >= MIN_CONTENT_CHARS:
                return text[:MAX_ARTICLE_CHARS]

        except Exception:
            pass

    return ""


def fetch_deep_pib_content(article_url):
    if not article_url or not isinstance(article_url, str):
        return ""

    prid_match = re.search(r"PRID=(\d+)", article_url, re.IGNORECASE)

    if "pib.gov.in" in article_url.lower() and prid_match:
        prid = prid_match.group(1)
        target_url = f"https://pib.gov.in/PressReleasePage.aspx?PRID={prid}"
    else:
        target_url = article_url

    content = safe_fetch(target_url, timeout=15, browser=False)
    if not content:
        return ""

    try:
        soup = BeautifulSoup(content, "html.parser")

        for item in soup.select("script, style, nav, footer, header, form, .release_back, .share-box"):
            item.decompose()

        content_div = (
            soup.find(id="ContentPlaceHolder1_divpri") or
            soup.find(id="divpri") or
            soup.find(class_="ReleaseIdText") or
            soup.find(class_="innercontent") or
            soup.find(class_="release_text")
        )

        text = extract_container_text(content_div) if content_div else extract_container_text(soup)
        return text[:MAX_ARTICLE_CHARS]

    except Exception as e:
        print(f"⚠️ PIB parsing error: {e}")
        return ""


# =============================================================
# 7. HELPERS & LISTINGS
# =============================================================

def is_generic_bihar_portal_text(text):
    if not text:
        return True

    text_lower = text.lower()
    bad_patterns = [
        "web information manager", "copyright iprd", "department of revenue & land reform",
        "office of the chief electoral officer", "bihar is located in the eastern part"
    ]

    matches = sum(1 for p in bad_patterns if p in text_lower)
    return matches >= 2


def is_valid_article_content(text):
    if not text:
        return False
    text = normalize_text(text)
    if len(text) < MIN_CONTENT_CHARS:
        return False
    if is_generic_bihar_portal_text(text):
        return False
    return True


def absolute_url(base_url, link):
    if not link:
        return ""
    link = str(link).strip()
    if link.startswith("#"):
        return ""
    return urllib.parse.urljoin(base_url, link)


def parse_rss_items(content):
    if not content:
        return []
    items = []
    try:
        root = ET.fromstring(content)
        for item in root.findall(".//item"):
            def get(name):
                node = item.find(name)
                return clean_cdata_and_html(node.text or "") if node is not None else ""

            items.append({
                "title": get("title"),
                "link": get("link"),
                "pub_date": get("pubDate"),
                "description": get("description")
            })
        return items
    except Exception:
        try:
            soup = BeautifulSoup(content, "xml")
            for item in soup.find_all("item"):
                def bs_get(name):
                    node = item.find(name)
                    return clean_cdata_and_html(node.get_text(" ", strip=True)) if node else ""

                items.append({
                    "title": bs_get("title"),
                    "link": bs_get("link"),
                    "pub_date": bs_get("pubDate"),
                    "description": bs_get("description")
                })
            return items
        except Exception:
            return []


# =============================================================
# 8. SCRAPING SOURCES
# =============================================================

def scrape_cmo_bihar():
    items = []
    print("\n🏛️ Scraping CMO Bihar...")
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx", timeout=15)
    if not content:
        return items

    try:
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all("tr")[:15]:
            cols = row.find_all("td")
            if len(cols) >= 2:
                title = normalize_text(cols[1].get_text(" ", strip=True))
                if title and len(title) > 10:
                    items.append({
                        "source": "CMO Bihar",
                        "title": title,
                        "url": "https://cm.bihar.gov.in/users/preessrelease.aspx",
                        "date": "",
                        "content": title,
                        "type": "Title Scraped"
                    })
    except Exception as e:
        print(f"⚠️ CMO Bihar Error: {e}")

    return items


def scrape_pib():
    items = []
    print("\n🇮🇳 Scraping PIB Central...")
    pib_content = safe_fetch("https://www.pib.gov.in/RssMain.aspx?Mod=1&Lang=1")
    if not pib_content:
        return items

    target_dt = datetime.now() - timedelta(days=1)
    items_raw = parse_rss_items(pib_content)

    for item in items_raw[:15]:
        title, link, pub_date = item["title"], item["link"], item["pub_date"]
        if not title or not is_yesterday_news(pub_date, target_dt):
            continue

        deep_text = fetch_deep_pib_content(link) if link else ""
        content_to_use = deep_text if len(deep_text) >= 120 else item["description"]

        items.append({
            "source": "PIB Central",
            "title": title,
            "url": link,
            "date": pub_date,
            "content": content_to_use,
            "type": "Deep Scraped" if len(deep_text) >= 120 else "RSS Backup"
        })

    return items


def scrape_the_hindu():
    items = []
    print("\n📰 Scraping The Hindu...")
    content = safe_fetch("https://www.thehindu.com/news/national/feeder/default.rss")
    if not content:
        return items

    target_dt = datetime.now() - timedelta(days=1)
    items_raw = parse_rss_items(content)

    for item in items_raw[:12]:
        title, link, pub_date = item["title"], item["link"], item["pub_date"]
        if not title or not is_yesterday_news(pub_date, target_dt):
            continue

        deep_text = fetch_generic_article_content(link)
        content_to_use = deep_text if len(deep_text) >= 200 else item["description"]

        items.append({
            "source": "The Hindu",
            "title": title,
            "url": link,
            "date": pub_date,
            "content": content_to_use,
            "type": "Deep Scraped"
        })

    return items


def remove_duplicate_news(news_list):
    seen_titles = set()
    unique_news = []

    for news in news_list:
        if not isinstance(news, dict):
            continue
        title = normalize_text(news.get("title", ""))
        clean_title = re.sub(r"[^a-z0-9\u0900-\u097F]", "", title.lower())[:100]

        if clean_title and clean_title not in seen_titles:
            seen_titles.add(clean_title)
            unique_news.append(news)

    return unique_news


# =============================================================
# 9. MAIN SCRAPER PIPELINE
# =============================================================

def run_scraper():
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Deep News Scraper for Target Date: {date_str}\n")

    bihar_items = []
    national_items = []

    # Run Scraping
    cmo_items = scrape_cmo_bihar()
    bihar_items.extend(cmo_items)

    pib_items = scrape_pib()
    national_items.extend(pib_items)

    hindu_items = scrape_the_hindu()
    national_items.extend(hindu_items)

    # Clean
    bihar_clean = remove_duplicate_news(bihar_items)
    national_clean = remove_duplicate_news(national_items)

    raw_payload = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "target_date_str": date_str,
        "target_key_str": key_str,
        "bihar_raw_count": len(bihar_clean),
        "national_raw_count": len(national_clean),
        "bihar_raw_news": bihar_clean,
        "national_raw_news": national_clean
    }

    with open("rawnews.json", "w", encoding="utf-8") as f:
        json.dump(raw_payload, f, ensure_ascii=False, indent=2)

    print(f"\n💾 'rawnews.json' updated successfully! (Bihar: {len(bihar_clean)} | National: {len(national_clean)})")


# =============================================================
# RUN PIPELINE
# =============================================================

if __name__ == "__main__":
    run_scraper()
