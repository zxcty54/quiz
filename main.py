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

# Primary 70B Model for High Precision, 8B as Fallback
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

def pre_filter_junk_news(raw_text):
    """
    Python-Level Hard Rejection for Crime, Accidents, and Routine Political Tributes
    """
    lines = raw_text.split("\n")
    cleaned_lines = []
    
    banned_keywords = [
        r'\bshot dead\b', r'\bmurder\b', r'\bkilled\b', r'\barrested\b', r'\bcrime\b',
        r'\bpolice investigating\b', r'\bstudent representatives\b', r'\bdeadlock\b',
        r'\bheadmaster\b', r'\brape\b', r'\baccident\b', r'\brobbery\b', r'\btheft\b',
        r'\bpolitical party\b', r'\bcmnaidu\b', r'\btpcc\b', r'\belection campaign\b'
    ]
    
    for line in lines:
        lower_line = line.lower()
        if not any(re.search(pattern, lower_line) for pattern in banned_keywords):
            cleaned_lines.append(line)
            
    return "\n".join(cleaned_lines)

def remove_duplicate_news(news_list):
    """
    Fuzzy Deduplication to prevent sending repetitive news to LLM
    """
    seen_events = set()
    unique_news = []
    dropped_count = 0
    
    for news in news_list:
        clean_text = re.sub(r'\[.*?\]', '', news).strip().lower()
        words = set(re.findall(r'\b[a-z]{4,}\b', clean_text))
        
        is_duplicate = False
        for seen in seen_events:
            intersection = words.intersection(seen)
            if len(intersection) >= 3 and ('quit' in words or 'tribute' in words or 'kakori' in words or 'shradhanjali' in words):
                is_duplicate = True
                break
                
        if not is_duplicate:
            seen_events.add(frozenset(words))
            unique_news.append(news)
        else:
            dropped_count += 1
            
    print(f"🧹 Deduplication Debug: Total Input={len(news_list)} | Duplicates Dropped={dropped_count} | Unique Sent to LLM={len(unique_news)}")
    return unique_news

def validate_and_clean_cards(cards):
    """
    Post-processing filter to eliminate cards with identical/repetitive bullets or low-value fillers
    """
    valid_cards = []
    for card in cards:
        bullets = card.get("bullets", [])
        if len(bullets) == 3:
            b1, b2, b3 = bullets[0].strip().lower(), bullets[1].strip().lower(), bullets[2].strip().lower()
            # Ensure bullets are distinct and not copy-pasted or generic
            if b1 != b2 and b2 != b3 and b1 != b3:
                # Reject if filler phrases exist
                filler_check = any("prerna ka srot" in b or "naitik sarkar" in b or "shradhanjali dene" in b for b in [b1, b2, b3])
                if not filler_check:
                    valid_cards.append(card)
                else:
                    print(f"⚠️ Dropped card due to filler content: {card.get('title')}")
            else:
                print(f"⚠️ Dropped card due to repetitive bullets: {card.get('title')}")
    return valid_cards

# -------------------------------------------------------------
# 2. SAFE FETCHER & DEEP ARTICLE SCRAPER (ENHANCED)
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
    Article link ke andar jaakar REAL DEEP BODY TEXT scrape karta hai (Up to 1200 Chars)
    """
    if not article_url or not article_url.startswith("http"):
        return ""
    
    content = safe_fetch(article_url, timeout=8)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        
        # Unwanted UI tags decompose karo
        for script in soup(["script", "style", "nav", "footer", "header", "aside", "form"]):
            script.decompose()
            
        paragraphs = soup.find_all('p')
        valid_paragraphs = []
        
        for p in paragraphs:
            text = p.text.strip()
            # Ignore short junk lines, copyright notices, and share buttons
            if len(text) > 45 and not any(junk in text.lower() for x in ["subscribe", "copyright", "rights reserved", "follow us"]):
                valid_paragraphs.append(text)
                
        full_text = " ".join(valid_paragraphs)
        clean_text = " ".join(full_text.split())
        return clean_text[:1200] # Expanded to 1200 characters for deep context
    except Exception as e:
        return ""

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS WITH SOURCE-WISE DEBUGGING
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING BIHAR NEWS (FULL ARTICLE SCRAPE) ---")
    news_items = []
    source_stats = {}

    content = safe_fetch("https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture+when:2d&hl=hi&gl=IN&ceid=IN:hi")
    gnews_count = 0
    if content:
        try:
            root = ET.fromstring(content)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                link = item.find('link').text if item.find('link') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_full_article_content(link)
                    context_str = deep_text if len(deep_text) > 120 else clean_html_text(item.find('description').text if item.find('description') is not None else "")[:300]
                    news_items.append(f"[Source: Google News Bihar] Title: {title} | Article Content: {context_str}")
                    gnews_count += 1
                    if gnews_count >= 6: break
        except Exception as e:
            print(f"⚠️ Google News Bihar parse error: {e}")
    source_stats["Google News Bihar"] = gnews_count

    cmo_count = 0
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:6]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = cols[1].text.strip()
                if title and len(title) > 10:
                    news_items.append(f"[Source: CMO Bihar] Title: {title}")
                    cmo_count += 1
    source_stats["CMO Bihar"] = cmo_count

    print(f"📊 Source Breakdown (Bihar Raw Input): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(news_items))


def fetch_raw_national_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING PURE NATIONAL NEWS (FULL ARTICLE SCRAPE) ---")
    national_items = []
    source_stats = {}
    
    # 1. PIB Central
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
                        if len(deep_text) > 100:
                            national_items.append(f"[Source: PIB Central] Title: {title} | Article Content: {deep_text}")
                            pib_count += 1
                            if pib_count >= 6: break
        except Exception as e:
            print(f"⚠️ PIB National Portal scrape error: {e}")
    source_stats["PIB Central"] = pib_count

    # 2. News On AIR
    air_count = 0
    air_content = safe_fetch("https://newsonair.gov.in/category/national/")
    if air_content:
        try:
            soup = BeautifulSoup(air_content, "html.parser")
            for h3 in soup.find_all(['h2', 'h3', 'a']):
                title = clean_html_text(h3.text)
                link = h3.get('href', '')
                if len(title) > 30 and ("newsonair" in link or link.startswith("/")):
                    full_url = link if link.startswith("http") else f"https://newsonair.gov.in{link}"
                    deep_text = fetch_full_article_content(full_url)
                    if len(deep_text) > 100:
                        national_items.append(f"[Source: NewsOnAir National] Title: {title} | Article Content: {deep_text}")
                        air_count += 1
                        if air_count >= 5: break
        except Exception as e:
            print(f"⚠️ NewsOnAir scrape error: {e}")
    source_stats["NewsOnAir National"] = air_count

    # 3. Livemint Policy
    mint_count = 0
    mint_content = safe_fetch("https://www.livemint.com/rss/politics")
    if mint_content:
        try:
            soup = BeautifulSoup(mint_content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text.strip() if item.find('title') else ""
                link = item.find('link').text.strip() if item.find('link') else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') else ""
                
                if title and is_yesterday_news(pub_date, target_dt):
                    deep_text = fetch_full_article_content(link)
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') else "")[:300]
                    national_items.append(f"[Source: Livemint Policy] Title: {title} | Article Content: {context_str}")
                    mint_count += 1
                    if mint_count >= 5: break
        except Exception as e:
            print(f"⚠️ Livemint parse error: {e}")
    source_stats["Livemint Policy"] = mint_count

    print(f"📊 Source Breakdown (National Raw Input): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(national_items))

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATOR (STRICT REAL FACTS PROMPT)
# -------------------------------------------------------------
def call_groq_safe(prompt, system_role="You are a Senior Current Affairs Editor for BPSC (Civil Services) and State Competitive Exams."):
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
                max_tokens=2200,
                timeout=45,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] skipped ({e}). Trying next...")
            time.sleep(5)
    return ""

def generate_clean_summary(raw_text, target_date_str, is_national=False):
    filtered_text = pre_filter_junk_news(raw_text)
    truncated_raw = filtered_text[:4500]
    
    scope_name = "National / India Level" if is_national else "Bihar State Level"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC (Civil Services) and State Competitive Exams.
    Below is raw scraped news text containing DEEP ARTICLE TEXT for {scope_name}:

    RAW SCRAPED NEWS TEXT WITH FULL ARTICLE CONTENT:
    {truncated_raw}

    ======================================================================
    STRICT ALLOWED CATEGORIES (Classify each news card into EXACTLY one):
    ======================================================================
    1. "Govt Schemes & Policies"
    2. "Infrastructure, Economy & Reports"
    3. "Science, Defense & Environment"
    4. "International Affairs & Summits"
    5. "Appointments, Awards & Sports"

    ======================================================================
    ABSOLUTE QUALITY & REJECTION RULES:
    ======================================================================
    1. EXTRACT REAL FACTS ONLY: Do NOT fabricate or write generic statements like "Isse logon ko prerna milegi" or "Naitik sarkar ki disha mein kaam kiya".
    2. REJECT ROUTINE SPEECHES & TRIBUTES: Simple tributes, political speeches, and ceremonial greetings without specific government policy decisions or data MUST BE REJECTED.
    3. REJECT ALL Crime, Accidents, Party Politics, Local Strikes, and Other-State Local News.
    4. IF ARTICLE HAS NO HARD FACTS: DISQUALIFY IT. It is better to return FEWER high-quality cards than junk/fabricated ones.
    5. IF NO NEWS QUALIFIES: Return {{"news_cards": []}}.

    ======================================================================
    BULLET POINT RULES (EXACTLY 3 DISTINCT HARD-FACT BULLETS):
    ======================================================================
    - Bullet 1 (Core Action): Specific decision, scheme, project, or event name + Nodal Ministry/Department + Location in Hinglish.
    - Bullet 2 (Exact Figures/Data): Specific budget amount, target year, India's rank, percentage, MoU partner, or statutory body mentioned in the article text.
    - Bullet 3 (Policy Scope/Context): Objective, operational mechanism, or parent framework mentioned in the article text.
    - Write ALL Titles and Bullets in Hinglish (Hindi written in Roman English Script).
    - Capture the exact "source_name" tag from the raw text (e.g., "PIB Central", "NewsOnAir National", "Livemint Policy", "Google News Bihar", "CMO Bihar").

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clear Detailed Factual Title in Hinglish",
          "source_name": "Name of extracted source",
          "category": "Select EXACT matching category name from allowed list",
          "bullets": [
            "Bullet 1: Deep factual details with exact names/ministry in Hinglish",
            "Bullet 2: Specific figures, numbers, budget, or metrics from text in Hinglish",
            "Bullet 3: Parent policy framework or operational scope in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    return call_groq_safe(prompt, system_role="Senior Current Affairs Editor for BPSC (Civil Services) and State Competitive Exams.")

def log_generated_sources_debug(parsed_json, scope_label):
    cards = parsed_json.get("news_cards", [])
    print(f"\n📊 --- DEBUG: GENERATED CARDS SOURCE BREAKDOWN ({scope_label}) ---")
    if not cards:
        print("⚠️ No Cards Generated!")
        return
        
    counts = {}
    for card in cards:
        src = card.get("source_name", "Unknown Source")
        counts[src] = counts.get(src, 0) + 1
        print(f"  • [{src}] -> {card.get('title')[:60]}...")
    
    print(f"📈 Summary Stats ({scope_label}): {json.dumps(counts, indent=2)}\n")

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
            
            # Post-processing Token & Quality Validation
            clean_bihar_cards = validate_and_clean_cards(parsed_bihar.get("news_cards", []))
            parsed_bihar["news_cards"] = clean_bihar_cards
            
            print(f"🎯 Bihar News Generated: {len(clean_bihar_cards)} Cards")
            log_generated_sources_debug(parsed_bihar, "Bihar")
            
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
            if len(clean_bihar_cards) > 0:
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
            
            # Post-processing Token & Quality Validation
            clean_national_cards = validate_and_clean_cards(parsed_national.get("news_cards", []))
            parsed_national["news_cards"] = clean_national_cards
            
            print(f"🎯 National News Generated: {len(clean_national_cards)} Cards")
            log_generated_sources_debug(parsed_national, "National")
            
            with open("national_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_national, f, ensure_ascii=False, indent=2)
            if len(clean_national_cards) > 0:
                append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Error: {e}")

    print("\n🎉 PIPELINE EXECUTION FINISHED SUCCESSFULLY!")
