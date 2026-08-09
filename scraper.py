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
# DATE PARSER ENGINE
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
        start_window = target_dt - timedelta(days=2.5)
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
        clean_title = clean_title.strip().lower()[:35]
        clean_title = re.sub(r'[^a-z0-9]', '', clean_title)
        if clean_title and clean_title not in seen_titles:
            seen_titles.add(clean_title)
            unique_news.append(news)
        else:
            dropped_count += 1
            
    print(f"🧹 Deduplication: Input={len(news_list)} | Dropped={dropped_count} | Unique={len(unique_news)}")
    return unique_news

# -------------------------------------------------------------
# SAFE FETCHER & DEEP SCRAPER
# -------------------------------------------------------------
def safe_fetch(url, timeout=12):
    try:
        res = requests.get(url, impersonate="chrome", timeout=timeout, verify=False)
        if res.status_code == 200:
            return res.content
    except Exception as e:
        print(f"⚠️ Direct fetch failed for {url[:40]}... Error: {e}")

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

def fetch_full_article_content(article_url):
    if not article_url or not article_url.startswith("http"):
        return ""
    
    content = safe_fetch(article_url, timeout=8)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        noise = ["script", "style", "nav", "footer", "header", "form", ".release_back"]
        for item in soup(noise):
            item.decompose()
            
        content_div = (
            soup.find(class_="innercontent") or 
            soup.find(class_="ReleaseIdText") or 
            soup.find(id="divpri") or
            soup.find(class_="release_text") or
            soup.find(id="ContentPlaceHolder1_divpri")
        )
        
        if content_div:
            elements = content_div.find_all(['p', 'tr', 'div'])
            text_blocks = []
            for el in elements:
                txt = el.get_text().strip()
                if len(txt) > 30 and txt not in text_blocks:
                    text_blocks.append(txt)
            full_text = " ".join(text_blocks)
        else:
            paragraphs = soup.find_all('p')
            full_text = " ".join([p.text.strip() for p in paragraphs if len(p.text.strip()) > 35])
            
        return " ".join(full_text.split())[:1200]  
    except Exception as e:
        print(f"⚠️ Deep parsing error: {e}")
        return ""

# -------------------------------------------------------------
# SCRAPING MAIN LOGIC
# -------------------------------------------------------------
def run_scraper():
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Scraping for Date: {date_str}...\n")
    
    bihar_items = []
    national_items = []

    # 1. BIHAR NEWS - Google News
    g_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+when:2d&hl=hi&gl=IN&ceid=IN:hi"
    content = safe_fetch(g_url)
    if content:
        try:
            root = ET.fromstring(content)
            for item in root.findall('.//item')[:10]:
                title = item.find('title').text if item.find('title') is not None else ""
                link = item.find('link').text if item.find('link') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_full_article_content(link)
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') is not None else "")[:250]
                    bihar_items.append(f"[Google News Bihar] Title: {title} | Context: {context_str}")
        except Exception as e:
            print(f"⚠️ Bihar Google News error: {e}")

    # 2. BIHAR NEWS - CMO Bihar
    cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
    content = safe_fetch(cmo_url)
    if content:
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:8]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = cols[1].text.strip()
                if title and len(title) > 10:
                    bihar_items.append(f"[CMO Bihar] Title: {title}")

    # 3. NATIONAL NEWS - PIB India
    pib_rss_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
    pib_content = safe_fetch(pib_rss_url)
    if pib_content:
        try:
            soup = BeautifulSoup(pib_content, "html.parser")
            for item in soup.find_all('item')[:12]:
                title_node = item.find('title')
                link_node = item.find('link')
                pub_node = item.find('pubdate') or item.find('pubDate')
                
                title = title_node.text.strip() if title_node else ""
                link = link_node.text.strip() if link_node else ""
                pub_date = pub_node.text.strip() if pub_node else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_full_article_content(link) if link else ""
                    content_to_use = deep_text if len(deep_text) > 50 else (clean_html_text(item.find('description').text) if item.find('description') else title)
                    national_items.append(f"[PIB India] Title: {title} | Content: {content_to_use}")
        except Exception as e:
            print(f"❌ PIB Error: {e}")

    # 4. NATIONAL NEWS - Google National
    g_nat_url = "https://news.google.com/rss/search?q=India+Cabinet+Decisions+OR+National+Schemes+OR+ISRO+when:2d&hl=hi&gl=IN&ceid=IN:hi"
    g_nat_content = safe_fetch(g_nat_url)
    if g_nat_content:
        try:
            root = ET.fromstring(g_nat_content)
            for item in root.findall('.//item')[:8]:
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    national_items.append(f"[Google National] Title: {title}")
        except Exception as e:
            print(f"⚠️ Google National Error: {e}")

    # Clean duplicates
    bihar_clean = remove_duplicate_news(bihar_items)
    national_clean = remove_duplicate_news(national_items)

    # Dump into rawnews.json
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

    print(f"💾 Step 1 Done: 'rawnews.json' created! (Bihar: {len(bihar_clean)} | National: {len(national_clean)})\n")

if __name__ == "__main__":
    run_scraper()
