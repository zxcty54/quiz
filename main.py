import os
import json
import time
import urllib.parse
import re
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
from dateutil import parser as date_parser

# -------------------------------------------------------------
# 1. API Client Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

# Active Groq Models (Removed Decommissioned Llama3-8b-8192)
MODELS = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]

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
        val, unit = int(relative_match.group(1)), relative_match.group(2)
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
        clean_title = re.sub(r'\[.*?\]', '', news).strip().lower()[:35]
        clean_title = re.sub(r'[^a-z0-9]', '', clean_title)
        if clean_title and clean_title not in seen_titles:
            seen_titles.add(clean_title)
            unique_news.append(news)
        else:
            dropped_count += 1
            
    print(f"🧹 Deduplication Debug: Total={len(news_list)} | Duplicates Dropped={dropped_count} | Unique Sent to LLM={len(unique_news)}")
    return unique_news

# -------------------------------------------------------------
# 2. SAFE FETCHER
# -------------------------------------------------------------
def safe_fetch(url, timeout=12):
    try:
        res = requests.get(url, impersonate="chrome", timeout=timeout, verify=False)
        if res.status_code == 200:
            return res.content
    except Exception as e:
        print(f"⚠️ Direct fetch failed for {url[:40]}... Error: {e}")

    if SCRAPINGANT_KEY:
        print(f"🔄 Switching to ScrapingAnt Fallback for {url[:40]}...")
        try:
            encoded_url = urllib.parse.quote(url, safe='')
            sa_url = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_KEY}&browser=false"
            sa_res = requests.get(sa_url, timeout=25)
            if sa_res.status_code == 200:
                return sa_res.content
        except Exception as sa_e:
            print(f"❌ ScrapingAnt failed: {sa_e}")
    return None

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING BIHAR NEWS ---")
    news_titles = []
    source_stats = {}

    content = safe_fetch("https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture+when:2d&hl=hi&gl=IN&ceid=IN:hi")
    if content:
        try:
            root = ET.fromstring(content)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = item.find('description').text if item.find('description') is not None else ""
                clean_desc = clean_html_text(desc)[:180] # Trimmed to manage tokens
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Google News Bihar] {title} | Context: {clean_desc}")
                    count += 1
                    if count >= 12: break
            source_stats["Google News Bihar"] = count
        except Exception as e:
            print(f"⚠️ Google News Bihar parse error: {e}")

    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        cmo_count = 0
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:10]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = cols[1].text.strip()
                if title and len(title) > 10:
                    news_titles.append(f"[CMO Bihar] {title}")
                    cmo_count += 1
        source_stats["CMO Bihar"] = cmo_count

    content = safe_fetch("https://www.prabhatkhabar.com/state/bihar/feed")
    if content:
        try:
            root = ET.fromstring(content)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = item.find('description').text if item.find('description') is not None else ""
                clean_desc = clean_html_text(desc)[:180]
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Prabhat Khabar] {title.strip()} | Context: {clean_desc}")
                    count += 1
                    if count >= 10: break
            source_stats["Prabhat Khabar"] = count
        except Exception as e:
            print(f"⚠️ Prabhat Khabar parse error: {e}")

    print(f"📊 Source Breakdown (Bihar): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(news_titles))


def fetch_raw_national_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING NATIONAL NEWS ---")
    national_titles = []
    source_stats = {}
    
    # 1. Direct Scrape PIB National Portal
    pib_portal_releases = []
    pib_content = safe_fetch("https://www.pib.gov.in/Allrel.aspx?reg=3&lang=1") # PIB National Portal
    if pib_content:
        try:
            soup = BeautifulSoup(pib_content, "html.parser")
            count = 0
            for link in soup.find_all('a', href=True):
                title = clean_html_text(link.text)
                href = link['href']
                if ("PressRelease" in href or "PRN" in href or "relid" in href) and len(title) > 20:
                    if not any(x in title.lower() for x in ["home", "privacy", "terms", "contact", "back"]):
                        pib_portal_releases.append(f"[PIB National Portal] {title}")
                        count += 1
                        if count >= 10: break
        except Exception as e:
            print(f"⚠️ PIB National Portal scrape error: {e}")
    
    national_titles.extend(pib_portal_releases)
    source_stats["PIB National Portal"] = len(pib_portal_releases)

    # 2. Standard RSS Sources (Max 6 per source to fit within token limit)
    national_rss_sources = [
        ("The Hindu", "https://www.thehindu.com/news/national/feeder/default.rss"),
        ("Hindustan Times", "https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml"),
        ("Economic Times", "https://economictimes.indiatimes.com/news/economy/rssfeeds/1373380680.cms"),
        ("Livemint Policy", "https://www.livemint.com/rss/politics")
    ]

    for source_name, url in national_rss_sources:
        content = safe_fetch(url)
        count = 0
        if content:
            try:
                soup = BeautifulSoup(content, "xml")
                items = soup.find_all('item')
                for item in items:
                    title = item.find('title').text.strip() if item.find('title') is not None else ""
                    desc = item.find('description').text if item.find('description') is not None else ""
                    clean_desc = clean_html_text(desc)[:150] # Compact description
                    
                    pub_date_tag = item.find('pubDate') or item.find('dc:date') or item.find('published') or item.find('updated')
                    pub_date = pub_date_tag.text if pub_date_tag is not None else ""
                    
                    if title and is_yesterday_news(pub_date, target_dt):
                        national_titles.append(f"[{source_name}] {title} | Context: {clean_desc}")
                        count += 1
                        if count >= 6: break # Reduced per-source limit to control TPM
            except Exception as e:
                print(f"⚠️ Parsing error for {source_name}: {e}")
        source_stats[source_name] = count

    # 3. Google News National
    content = safe_fetch("https://news.google.com/rss/search?q=India+Cabinet+Decisions+OR+National+Schemes+OR+ISRO+OR+RBI+OR+National+Highways+when:2d&hl=hi&gl=IN&ceid=IN:hi")
    gnews_count = 0
    if content:
        try:
            root = ET.fromstring(content)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = item.find('description').text if item.find('description') is not None else ""
                clean_desc = clean_html_text(desc)[:150]
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    national_titles.append(f"[Google National] {title.strip()} | Context: {clean_desc}")
                    gnews_count += 1
                    if gnews_count >= 8: break
        except Exception as e:
            print(f"⚠️ XML Parsing error for Google National: {e}")
    source_stats["Google National"] = gnews_count

    print(f"📊 Source Breakdown (National): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(national_titles))

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATOR (TOKEN OPTIMIZED)
# -------------------------------------------------------------
def call_groq_safe(prompt, system_role="You are a JSON generator assistant."):
    time.sleep(1)
    for model_name in MODELS:
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_role},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                max_tokens=2500, # Safely fits within API window
                timeout=45,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] skipped ({e}). Trying next...")
            time.sleep(1)
    return ""

def generate_clean_summary(raw_text, target_date_str, is_national=False):
    # Truncate raw input string to 4500 chars max to prevent Groq TPM 413 Error
    truncated_raw = raw_text[:4500]

    scope_name = "India National" if is_national else "Bihar State"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior Content Director for BPSC, UPSC & Competitive Exams.
    Below is raw news text scraped for {scope_name} Level:
    
    {truncated_raw}
    
    STRICT CATEGORIES (Pick ONLY from these exact names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Agriculture, Environment & GI Tags"
    4. "Appointments, Awards & Persons in News"
    5. "{"National Economy, Budget & Reports" if is_national else "Bihar Economy, Budget & Reports"}"

    CRITICAL REJECTION RULES:
    1. REJECT local train approvals, local road repairs, property expos, and local health centers.
    2. REJECT political commentary, speeches, election fights, local crime, and accidents.
    3. REJECT job vacancies, admit cards, exam notices.
    4. REJECT duplicates of the same event.

    CRITICAL FACTUAL INTEGRITY (NO HALLUCINATIONS):
    - DO NOT invent numbers or negative statements like "nuksan hoga" unless explicitly written in the raw input text.
    - If exact budget figure is missing, state objective facts (Ministries involved, locations, scope) instead of inventing numbers.

    BULLET POINT RULES:
    - Write EXACTLY 3 FACTUAL BULLET POINTS IN HINGLISH.
    - ABSOLUTELY NO GENERIC FILLERS (e.g. NEVER write "This is crucial for welfare", "State ko fayda hoga").
    - Bullet 1: Core event (Who launched/approved what, location, ministry).
    - Bullet 2: Numerical facts / Target year / Objective provided in the raw text.
    - Bullet 3: Policy framework / Scope / Operational mechanism.
    - Do NOT use Markdown asterisks (**).

    Target Output: Select 6 to 10 high quality, unique news cards.

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline",
          "category": "Select EXACT matching category",
          "bullets": [
            "Bullet 1: Deep factual details in Hinglish",
            "Bullet 2: Specific figures/target/facts in Hinglish",
            "Bullet 3: Operational scope or policy mechanism in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    return call_groq_safe(prompt, system_role="Senior Current Affairs Content Director")

# -------------------------------------------------------------
# 5. MASTER HISTORY APPEND FUNCTIONS
# -------------------------------------------------------------
def append_to_master_history(news_cards, yesterday_key, is_national=False):
    master_file = "all_national_news_history.json" if is_national else "all_bihar_news_history.json"
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    if len(master_data) > 60:
        oldest_key = sorted(master_data.keys())[0]
        del master_data[oldest_key]

    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Appended under key '{yesterday_key}' into '{master_file}'!")

# -------------------------------------------------------------
# 6. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Pipeline Execution for Date: {date_str}...\n")

    # === A. PROCESS BIHAR NEWS ===
    raw_bihar = fetch_raw_bihar_news(target_dt)
    if raw_bihar:
        ai_bihar = generate_clean_summary(raw_bihar, date_str, is_national=False)
        try:
            parsed_bihar = json.loads(ai_bihar.strip())
            cards_count = len(parsed_bihar.get('news_cards', []))
            print(f"🎯 Bihar News Generated: {cards_count} Cards")
            
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
            if cards_count > 0:
                append_to_master_history(parsed_bihar["news_cards"], key_str, is_national=False)
        except Exception as e:
            print(f"❌ Bihar JSON Error: {e}")

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    raw_national = fetch_raw_national_news(target_dt)
    if raw_national:
        ai_national = generate_clean_summary(raw_national, date_str, is_national=True)
        try:
            parsed_national = json.loads(ai_national.strip())
            cards_count = len(parsed_national.get('news_cards', []))
            print(f"🎯 National News Generated: {cards_count} Cards")
            
            with open("national_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_national, f, ensure_ascii=False, indent=2)
            if cards_count > 0:
                append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Error: {e}")

    print("\n🎉 PIPELINE EXECUTION FINISHED SUCCESSFULLY!")
