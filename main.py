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

# Active Groq Models
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
    Article link ke andar jaakar poora body text scrape karta hai
    """
    if not article_url or not article_url.startswith("http"):
        return ""
    
    content = safe_fetch(article_url, timeout=8)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        # Script aur style tags hatao
        for script in soup(["script", "style", "nav", "footer", "header"]):
            script.decompose()
            
        paragraphs = soup.find_all('p')
        full_text = " ".join([p.text.strip() for p in paragraphs if len(p.text.strip()) > 35])
        clean_text = " ".join(full_text.split())
        return clean_text[:800] # Maximum 800 characters per article for deep context
    except Exception as e:
        return ""

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS WITH FULL ARTICLE FETCHING
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING BIHAR NEWS (FULL ARTICLE SCRAPE) ---")
    news_items = []
    source_stats = {}

    # A. Google News Bihar
    content = safe_fetch("https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture+when:2d&hl=hi&gl=IN&ceid=IN:hi")
    if content:
        try:
            root = ET.fromstring(content)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                link = item.find('link').text if item.find('link') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    # Fetch Deep Content
                    deep_text = fetch_full_article_content(link)
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') is not None else "")[:250]
                    news_items.append(f"[Google News Bihar] Title: {title} | Full Context: {context_str}")
                    count += 1
                    if count >= 8: break
            source_stats["Google News Bihar"] = count
        except Exception as e:
            print(f"⚠️ Google News Bihar parse error: {e}")

    # B. CMO Bihar
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        cmo_count = 0
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:8]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = cols[1].text.strip()
                if title and len(title) > 10:
                    news_items.append(f"[CMO Bihar] Title: {title}")
                    cmo_count += 1
        source_stats["CMO Bihar"] = cmo_count

    print(f"📊 Source Breakdown (Bihar): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(news_items))


def fetch_raw_national_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING NATIONAL NEWS (FULL ARTICLE SCRAPE) ---")
    national_items = []
    source_stats = {}
    
    # 1. Direct PIB National Portal (reg=48)
    pib_count = 0
    pib_content = safe_fetch("https://www.pib.gov.in/Allrel.aspx?reg=48&lang=1")
    if pib_content:
        try:
            soup = BeautifulSoup(pib_content, "html.parser")
            for link in soup.find_all('a', href=True):
                title = clean_html_text(link.text)
                href = link['href']
                if ("PressRelease" in href or "PRN" in href or "relid" in href) and len(title) > 25:
                    if not any(x in title.lower() for x in ["home", "privacy", "terms", "contact", "back"]):
                        full_url = href if href.startswith("http") else f"https://www.pib.gov.in/{href}"
                        deep_text = fetch_full_article_content(full_url)
                        national_items.append(f"[PIB National] Title: {title} | Full Context: {deep_text[:600]}")
                        pib_count += 1
                        if pib_count >= 8: break
        except Exception as e:
            print(f"⚠️ PIB National Portal scrape error: {e}")
    source_stats["PIB National Portal"] = pib_count

    # 2. Standard RSS Sources with Deep Page Scraping
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
                for item in soup.find_all('item'):
                    title = item.find('title').text.strip() if item.find('title') is not None else ""
                    link = item.find('link').text.strip() if item.find('link') is not None else ""
                    pub_date_tag = item.find('pubDate') or item.find('dc:date') or item.find('published')
                    pub_date = pub_date_tag.text if pub_date_tag is not None else ""
                    
                    if title and is_yesterday_news(pub_date, target_dt):
                        deep_text = fetch_full_article_content(link)
                        context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') is not None else "")[:250]
                        national_items.append(f"[{source_name}] Title: {title} | Full Context: {context_str}")
                        count += 1
                        if count >= 4: break # 4 articles per source (deep scraped)
            except Exception as e:
                print(f"⚠️ Parsing error for {source_name}: {e}")
        source_stats[source_name] = count

    print(f"📊 Source Breakdown (National): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(national_items))

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATOR (STRICT ZERO FILLERS)
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
                max_tokens=2500,
                timeout=45,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] skipped ({e}). Trying next...")
            time.sleep(5)
    return ""

def generate_clean_summary(raw_text, target_date_str, is_national=False):
    # Safely fit within 5500 chars TPM limit
    truncated_raw = raw_text[:5500]

    scope_name = "India National" if is_national else "Bihar State"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior Current Affairs Content Director for BPSC, UPSC & Competitive Exams.
    Below is raw scraped news text containing DEEP ARTICLE CONTEXT for {scope_name} Level:
    
    {truncated_raw}
    
    STRICT ALLOWED CATEGORIES (Pick ONLY from these exact 5 names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Agriculture, Environment & GI Tags"
    4. "Appointments, Awards & Persons in News"
    5. "{"National Economy, Budget & Reports" if is_national else "Bihar Economy, Budget & Reports"}"

    STRICT DISQUALIFICATION RULES:
    1. REJECT INCOMPLETE/VAGUE NEWS: If headline lacks exact organization, ministry name, or project scope (e.g., "Govt signs MoUs for startups"), DISQUALIFY IT.
    2. REJECT ROUTINE SPEECHES: Speeches, convocation meets, ribbon cuttings, and motivational lectures without executive decisions.
    3. REJECT LOCAL/TRIVIAL NEWS: District-level train halts, traffic advisories, local crime, and local political fights.Reject other (except bihar) State based news which is not important for national and irrelevent for BPSC Exams.
    4. REJECT DUPLICATES of the same event.

    BULLET POINT QUALITY & ZERO-FILLER RULES:
    - Write EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH for each card.
    - ABSOLUTELY NO FILLER SENTENCES (e.g. NEVER write "Isse kisanon ko labh hoga", "Yeh samaroh prerit karta hai", "Isse connectivity badhegi").
    - Bullet 1 (Core Decision & Entities): Exact project/scheme name, Ministry/Department, Implementing Body, and Location.
    - Bullet 2 (Numbers, Metrics & Outlay): Exact financial outlay, capacity, percentage, ratio, or target year.
    - Bullet 3 (Policy Framework / Technical Context): Mention parent scheme (e.g. PM Matsya Sampada Yojana, APEDA Act 1985), nodal body, or statutory mechanism.

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clear Factual Headline with Specific Entities",
          "category": "Select EXACT matching category",
          "bullets": [
            "Bullet 1: Deep factual details with exact names in Hinglish",
            "Bullet 2: Specific figures, numbers, or financial metrics in Hinglish",
            "Bullet 3: Parent scheme name, statutory body, or technical context in Hinglish"
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
    print(f"🔄 Starting Pipeline Execution with Deep Scraper for Date: {date_str}...\n")

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

    # Cooling delay to reset Groq per-minute token rate limit
    print("⏳ Waiting 15 seconds to reset Groq API Rate Limit Bucket...\n")
    time.sleep(15)

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
