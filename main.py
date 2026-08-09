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

# Active Groq Models Priority
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

def pre_filter_junk_news(raw_text):
    """
    Python-Level Hard Rejection Filter for Crime, Local Accidents, Political Rallies
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
    if not article_url or not article_url.startswith("http"):
        return ""
    
    content = safe_fetch(article_url, timeout=8)
    if not content:
        return ""
    
    try:
        soup = BeautifulSoup(content, "html.parser")
        for script in soup(["script", "style", "nav", "footer", "header"]):
            script.decompose()
            
        paragraphs = soup.find_all('p')
        full_text = " ".join([p.text.strip() for p in paragraphs if len(p.text.strip()) > 35])
        clean_text = " ".join(full_text.split())
        return clean_text[:800]
    except Exception as e:
        return ""

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS WITH SOURCE-WISE DEBUGGING
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    print("\n🔍 --- DEBUG: FETCHING BIHAR NEWS (FULL ARTICLE SCRAPE) ---")
    news_items = []
    source_stats = {}

    # A. Google News Bihar
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
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') is not None else "")[:250]
                    news_items.append(f"[Source: Google News Bihar] Title: {title} | Full Context: {context_str}")
                    gnews_count += 1
                    if gnews_count >= 8: break
        except Exception as e:
            print(f"⚠️ Google News Bihar parse error: {e}")
    source_stats["Google News Bihar"] = gnews_count

    # B. CMO Bihar
    cmo_count = 0
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:8]:
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
    
    # 1. PIB Central Release Portal
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
                        national_items.append(f"[Source: PIB Central] Title: {title} | Full Context: {deep_text[:600]}")
                        pib_count += 1
                        if pib_count >= 10: break
        except Exception as e:
            print(f"⚠️ PIB National Portal scrape error: {e}")
    source_stats["PIB Central"] = pib_count

    # 2. News On AIR (Akashvani National)
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
                    national_items.append(f"[Source: NewsOnAir National] Title: {title} | Full Context: {deep_text[:600]}")
                    air_count += 1
                    if air_count >= 8: break
        except Exception as e:
            print(f"⚠️ NewsOnAir scrape error: {e}")
    source_stats["NewsOnAir National"] = air_count

    # 3. Livemint Policy Feed
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
                    context_str = deep_text if len(deep_text) > 100 else clean_html_text(item.find('description').text if item.find('description') else "")[:250]
                    national_items.append(f"[Source: Livemint Policy] Title: {title} | Full Context: {context_str}")
                    mint_count += 1
                    if mint_count >= 6: break
        except Exception as e:
            print(f"⚠️ Livemint parse error: {e}")
    source_stats["Livemint Policy"] = mint_count

    print(f"📊 Source Breakdown (National Raw Input): {json.dumps(source_stats, indent=2)}")
    return "\n".join(remove_duplicate_news(national_items))

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATOR (DEBUG ENABLED PROMPT)
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
    filtered_text = pre_filter_junk_news(raw_text)
    truncated_raw = filtered_text[:5500]
    
    scope_name = "National / India Level" if is_national else "Bihar State Level"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC (Civil Services) and State Competitive Exams.
    Your task is to analyze raw news text scraped for Yesterday ({target_date_str}) at {scope_name} and generate high-yield exam-oriented news cards in structured JSON format.

    RAW SCRAPED NEWS TEXT WITH SOURCE TAGS:
    {truncated_raw}

    ======================================================================
    STRICT ALLOWED CATEGORIES (Classify each news card into EXACTLY one):
    ======================================================================
    1. "Govt Schemes & Policies"
       - Union Cabinet Decisions: Bills, Acts, Amendments, CCEA Approvals.
       - Central Flagship Schemes: Outlay, Target Year, Nodal Ministry, Beneficiary Eligibility, Portals/Apps.
       - Policy Frameworks: National Education Policy (NEP), Healthcare Initiatives, Digital India, Renewable Energy Policies.

    2. "Infrastructure, Economy & Reports"
       - Union Budget & Economic Survey: GDP Growth Estimates, Fiscal Deficit, Tax Changes, Key Allocations.
       - Reports & Indices: NITI Aayog Reports (SDG, Innovation Index), RBI Monetary Policy Rates, Global Indices (Human Development, Hunger, Press Freedom) with India's Rank & Score.
       - Mega Infrastructure: Expressways, Dedicated Freight Corridors, Metro Extensions, Airports, Ports (Sagarmala), Vande Bharat, Power Plants.

    3. "Science, Defense & Environment"
       - Space & Tech: ISRO & NASA Missions (Satellite Type, Launch Vehicle e.g. LVM3/PSLV/GSLV, Orbit, Launch Site).
       - Defense & Security: DRDO Missile Tests, Defense Purchases, Submarines, Warships, Drone Policies.
       - Military Exercises: Joint Military/Naval/Air Exercises (Participating Countries + Exercise Name + Exact Location/Venue).
       - Environment & Wildlife: Ramsar Sites, Tiger/Elephant Reserves, National Parks, COP Summits, Net-Zero Targets.

    4. "International Affairs & Summits"
       - Global Summits: G20, BRICS, SCO, ASEAN, QUAD, G7, COP Summits (Theme, Host City/Country, Declarations).
       - Bilateral Relations: India's major MoUs, Treaties, Trade Deals, Strategic Alliances.
       - Global Bodies: UN, IMF, World Bank, WHO, WTO, NATO headquarter updates and decisions.

    5. "Appointments, Awards & Sports"
       - National Appointments: CJI, Chief Election Commissioner, CAG, Attorney General, UPSC Chairman, Defense Chiefs, RBI Governor.
       - Major Awards: Bharat Ratna, Padma Awards, Sahitya Akademi, Dadasaheb Phalke, Nobel Prize, Booker Prize.
       - Sports: Olympics, Asian Games, Commonwealth Games, World Cups, Grand Slams (Winners/Runner-ups, Host Countries, India's Medal Tally).

    ======================================================================
    ABSOLUTE ZERO TOLERANCE DISQUALIFICATION RULES:
    ======================================================================
    1. REJECT ALL CRIME & ACCIDENTS: Shootings, murders, headmaster killed, police investigations, arrests, thefts, robberies.
    2. REJECT ALL LOCAL PROTESTS & STUDENT TALKS: State student union demands, local strikes, exam irregularity talks.
    3. REJECT ALL PARTY POLITICS & STATE POLITICS: TPCC appointments, Congress/BJP internal meetings, state election campaigning, state CM weather comments.
    4. ALWAYS USE "exam_tag": "{tag_name}". NEVER create tags like "🎯 State Special / Andhra Pradesh".
    5. NEVER WRITE "No numerical data available". If there are no numbers, state the Nodal Agency, Ministry Name, or Act Year in Bullet 2.
    6. IF NO NEWS QUALIFIES: Return {{"news_cards": []}}.

    ======================================================================
    BULLET POINT QUALITY RULES (EXACTLY 3 BULLETS PER CARD):
    ======================================================================
    - Bullet 1 (Core Fact): What happened, Nodal Ministry/Department, Host Country/City or Location in Hinglish.
    - Bullet 2 (Numerical/Exam Data): Specific budget outlay, target year, India's rank, percentage, or MoU details.
    - Bullet 3 (Policy Significance): Strategic importance, policy objective, or context for exams in Hinglish.
    - Write ALL Titles and Bullets in Hinglish (Hindi written in Roman English Script).
    - Capture the "source_name" from the tag in raw input (e.g., "PIB Central", "NewsOnAir National", "Livemint Policy", "Google News Bihar", "CMO Bihar").

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clear Factual Title in Hinglish",
          "source_name": "Name of extracted source e.g. PIB Central / NewsOnAir National",
          "category": "Select EXACT matching category name from allowed list",
          "bullets": [
            "Bullet 1: Core fact with Nodal Ministry/Location in Hinglish",
            "Bullet 2: Specific numerical data, budget, target year, or nodal agency in Hinglish",
            "Bullet 3: Strategic policy significance/context in Hinglish"
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
            cards_count = len(parsed_bihar.get('news_cards', []))
            print(f"🎯 Bihar News Generated: {cards_count} Cards")
            
            # Source Debug Log
            log_generated_sources_debug(parsed_bihar, "Bihar")
            
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
            
            # Source Debug Log
            log_generated_sources_debug(parsed_national, "National")
            
            with open("national_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_national, f, ensure_ascii=False, indent=2)
            if cards_count > 0:
                append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Error: {e}")

    print("\n🎉 PIPELINE EXECUTION FINISHED SUCCESSFULLY!")
