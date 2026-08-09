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
from groq import Groq
from dateutil import parser as date_parser

# Disable insecure request warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# -------------------------------------------------------------
# 1. API Client Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None
MODELS = ["llama-3.1-8b-instant", "llama-3.3-70b-versatile"]

def get_yesterday_info():
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   
    key_str = yesterday_dt.strftime("%Y-%m-%d")    
    return yesterday_dt, date_str, key_str

# -------------------------------------------------------------
# UNIVERSAL DATE PARSER ENGINE
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
            
    print(f"🧹 Deduplication Debug: Total Input={len(news_list)} | Duplicates Dropped={dropped_count} | Unique Sent to LLM={len(unique_news)}")
    return unique_news

# -------------------------------------------------------------
# 2. SAFE FETCHER & DEEP ARTICLE SCRAPER
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
    """
    In-depth core article parser tailored for PIB's distinct nested styling layout.
    """
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
            
        clean_text = " ".join(full_text.split())
        return clean_text[:1200]  
    except Exception as e:
        print(f"⚠️ Error parsing deep content: {e}")
        return ""

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS WITH FULL ARTICLE FETCHING
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING BIHAR NEWS ---")
    news_items = []
    source_stats = {}

    # A. Google News Bihar
    g_url = "
