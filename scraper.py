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

def get_yesterday_info():
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   
    key_str = yesterday_dt.strftime("%Y-%m-%d")    
    return yesterday_dt, date_str, key_str

# -------------------------------------------------------------
# 1. DATE PARSER ENGINE
# -------------------------------------------------------------
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
    
    relative_match = re.search(r'(\d+)\s+(hour|hr|day|min|minute)s?\s+ago', lower_str)
    if relative_match:
        val = int(relative_match.group(1))
        unit = relative_match.group(2)
        if "day" in unit:
            return now - timedelta(days=val)
        elif "hour" in unit or "hr" in unit:
            return now - timedelta(hours=val)
        elif "min" in unit:
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
        start_window = target_dt - timedelta(days=3.0)
        end_window = target_dt + timedelta(days=1.5)
        return start_window <= pub_dt <= end_window

    return True

def clean_html_text(text):
    if not text: return ""
    clean = BeautifulSoup(text, "html.parser").get_text()
    return " ".join(clean.split()).strip()

def remove_duplicate_news(news_list):
    seen_titles = set()
    unique_news = []
    dropped_count = 0
    
    for news in news_list:
        clean_title = re.sub(r'\[.*?\]', '', news)
        clean_title = clean_title.strip().lower()[:40]
        clean_title = re.sub(r'[^a-z0-9]', '', clean_title)
        if clean_title and clean_title not in seen_titles:
            seen_titles.add(clean_title)
            unique_news.append(news)
        else:
            dropped_count += 1
            
    print(f"🧹 Deduplication Debug: Total Input={len(news_list)} | Dropped={dropped_count} | Unique={len(unique_news)}")
    return unique_news

# -------------------------------------------------------------
# 2. SAFE FETCHER & DEEP PIB ARTICLE SCRAPER
# -------------------------------------------------------------
def safe_fetch(url, timeout=15):
    try:
        res = requests.get(url, impersonate="chrome", timeout=timeout, verify=False)
        if res.status_code == 200:
            return res.content
    except Exception as e:
        print(f"⚠️ Direct fetch failed for {url[:50]}... Error: {e}")

    if SCRAPINGANT_KEY:
        try:
            encoded_url = urllib.parse.quote(url, safe='')
            sa_url = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_KEY}&browser=false"
            sa_res = requests.get(sa_url, timeout=25)
            if sa_res.status_code == 200:
                return sa_res.content
        except Exception as sa_e:
            print(f"❌ ScrapingAnt failed: {sa_e}")
    return None

def fetch_deep_pib_content(article_url):
    """
    Deep Link Scraper: Follows PIB release URL and extracts full 
    article paragraphs, tables, and policy guidelines.
    """
    if not article_url or not article_url.startswith("http"):
        return ""
    
    # Standardize PIB article URL to direct PressReleasePage format if PRID is present
    prid_match = re.search(r'PRID=(\d+)', article_url, re.IGNORECASE)
    if prid_match:
        prid = prid_match.group(1)
        target_url = f"https://pib.gov.in/PressReleasePage.aspx?PRID={prid}"
    else:
        target_url = article_url

    print(f"🔗 Deep Crawling PIB Link: {target_url}")
    content = safe_fetch(target_url, timeout=12)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        
        # Remove unwanted UI elements
        noise = ["script", "style", "nav", "footer", "header", "form", ".release_back", ".share-box"]
        for item in soup(noise):
            item.decompose()
            
        # Target PIB specific content blocks
        content_div = (
            soup.find(id="ContentPlaceHolder1_divpri") or
            soup.find(class_="ReleaseIdText") or 
            soup.find(id="divpri") or
            soup.find(class_="innercontent") or
            soup.find(class_="release_text")
        )
        
        if content_div:
            # Extract paragraphs and structured table content
            text_blocks = []
            for p in content_div.find_all(['p', 'tr', 'li']):
                txt = clean_html_text(p.text)
                if len(txt) > 30 and txt not in text_blocks:
                    text_blocks.append(txt)
            full_text = " ".join(text_blocks)
        else:
            paragraphs = soup.find_all('p')
            full_text = " ".join([clean_html_text(p.text) for p in paragraphs if len(p.text.strip()) > 35])
            
        clean_full_text = " ".join(full_text.split())
        
        # Returns up to 2500 characters of deep press release content
        return clean_full_text[:2500]  
    except Exception as e:
        print(f"⚠️ Error parsing deep PIB content: {e}")
        return ""

def fetch_generic_article_content(article_url):
    """Deep article scraper for non-PIB portals (The Hindu, Indian Express, etc.)"""
    if not article_url or not article_url.startswith("http") or "news.google.com" in article_url:
        return ""

    content = safe_fetch(article_url, timeout=10)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        noise = ["script", "style", "nav", "footer", "header", "form"]
        for item in soup(noise):
            item.decompose()
            
        content_div = (
            soup.find(class_="article-body") or
            soup.find(id="content-body") or
            soup.find(class_="story-element") or
            soup.find(class_="paywall")
        )
        if content_div:
            paragraphs = content_div.find_all('p')
        else:
            paragraphs = soup.find_all('p')
            
        full_text = " ".join([clean_html_text(p.text) for p in paragraphs if len(p.text.strip()) > 35])
        return " ".join(full_text.split())[:1500]
    except Exception:
        return ""

# -------------------------------------------------------------
# 3. SCRAPING MAIN PIPELINE
# -------------------------------------------------------------
def run_scraper():
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Deep PIB & News Scraper for Date: {date_str}\n")
    
    bihar_items = []
    national_items = []
    source_stats = {}

    # =========================================================
    # A. PIB DEEP SCRAPING (NATIONAL LEVEL)
    # =========================================================
    print("🇮🇳 Scraping PIB Central (Deep Article Crawl)...")
    pib_count = 0
    
    # PIB Official Feed containing PRID links
    pib_rss_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
    pib_content = safe_fetch(pib_rss_url)
    
    if pib_content:
        try:
            soup = BeautifulSoup(pib_content, "html.parser")
            items = soup.find_all('item')[:15]
            
            for item in items:
                title = item.find('title').text.strip() if item.find('title') else ""
                link = item.find('link').text.strip() if item.find('link') else ""
                pub_date = item.find('pubdate').text if item.find('pubdate') else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    # 🔴 DEEP LINK CRAWLING HAPPENING HERE:
                    deep_text = fetch_deep_pib_content(link) if link else ""
                    
                    if len(deep_text) > 150:
                        content_to_use = deep_text
                        print(f"  ✅ PIB Deep Scraped ({len(deep_text)} chars): {title[:40]}...")
                    else:
                        # Fallback to RSS description if deep crawl fails
                        desc_node = item.find('description')
                        content_to_use = clean_html_text(desc_node.text) if desc_node else title
                        print(f"  ⚠️ PIB Deep Crawl fallback to RSS snippet: {title[:40]}...")
                        
                    national_items.append(f"[Source: PIB Central] Title: {title} | Full Release Content: {content_to_use}")
                    pib_count += 1
                    if pib_count >= 10: break
        except Exception as e:
            print(f"❌ Error during PIB Deep Crawling: {e}")
            
    source_stats["PIB Central (Deep Crawled)"] = pib_count

    # =========================================================
    # B. OTHER NATIONAL SOURCES
    # =========================================================
    print("\n📰 Scraping National News (The Hindu & Indian Express)...")
    
    # 1. The Hindu
    hindu_count = 0
    content = safe_fetch("https://www.thehindu.com/news/national/feeder/default.rss")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for item in soup.find_all('item')[:8]:
                title = item.find('title').text.strip() if item.find('title') else ""
                link = item.find('link').text.strip() if item.find('link') else ""
                pub_date = item.find('pubdate').text if item.find('pubdate') else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_generic_article_content(link)
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') else "")
                    national_items.append(f"[Source: The Hindu] Title: {title} | Content: {context_str}")
                    hindu_count += 1
                    if hindu_count >= 5: break
        except Exception as e:
            print(f"⚠️ The Hindu Error: {e}")
    source_stats["The Hindu"] = hindu_count

    # 2. Indian Express
    ie_count = 0
    content = safe_fetch("https://indianexpress.com/section/india/feed/")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for item in soup.find_all('item')[:8]:
                title = item.find('title').text.strip() if item.find('title') else ""
                link = item.find('link').text.strip() if item.find('link') else ""
                pub_date = item.find('pubdate').text if item.find('pubdate') else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_generic_article_content(link)
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') else "")
                    national_items.append(f"[Source: Indian Express] Title: {title} | Content: {context_str}")
                    ie_count += 1
                    if ie_count >= 5: break
        except Exception as e:
            print(f"⚠️ Indian Express Error: {e}")
    source_stats["Indian Express"] = ie_count

    # =========================================================
    # C. BIHAR STATE NEWS SCRAPING
    # =========================================================
    print("\n📍 Scraping Bihar News Sources...")
    
    # 1. Google News Bihar
    g_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+when:2d&hl=hi&gl=IN&ceid=IN:hi"
    content = safe_fetch(g_url)
    g_bihar_count = 0
    if content:
        try:
            root = ET.fromstring(content)
            for item in root.findall('.//item')[:10]:
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                
                if title and is_yesterday_news(pub_date, target_dt):
                    bihar_items.append(f"[Source: Google News Bihar] Title: {title} | Content: {desc}")
                    g_bihar_count += 1
                    if g_bihar_count >= 8: break
        except Exception as e:
            print(f"⚠️ Google News Bihar Error: {e}")
    source_stats["Google News Bihar"] = g_bihar_count

    # 2. CMO Bihar
    cmo_count = 0
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        try:
            soup = BeautifulSoup(content, "html.parser")
            for row in soup.find_all('tr')[:8]:
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = cols[1].text.strip()
                    if title and len(title) > 10:
                        bihar_items.append(f"[Source: CMO Bihar] Title: {title}")
                        cmo_count += 1
        except Exception as e:
            print(f"⚠️ CMO Bihar Error: {e}")
    source_stats["CMO Bihar"] = cmo_count

    # Deduplication
    bihar_clean = remove_duplicate_news(bihar_items)
    national_clean = remove_duplicate_news(national_items)

    print(f"\n📊 --- RAW SCRAPING SUMMARY BREAKDOWN ---")
    print(json.dumps(source_stats, indent=2))

    # Dump into rawnews.json
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

    print(f"\n💾 'rawnews.json' Saved! (Bihar: {len(bihar_clean)} | National Deep PIB: {len(national_clean)})")

if __name__ == "__main__":
    run_scraper()
