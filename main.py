import os
import json
import time
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.1-8b-instant", "mixtral-8x7b-32768", "llama-3.3-70b-versatile"]

def get_yesterday_info():
    """Subah 6 AM run hone par kal ki date aur formatted strings generate karta hai"""
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   # e.g., '06 Aug 2026'
    key_str = yesterday_dt.strftime("%Y-%m-%d")    # e.g., '2026-08-06'
    return yesterday_dt, date_str, key_str

def is_yesterday_news(pub_date_str, target_dt):
    """Check karta hai ki RSS item ki publish date recent 24-48 hours ki hai ya nahi"""
    if not pub_date_str:
        return True
    try:
        pub_tuple = email.utils.parsedate_tz(pub_date_str)
        if pub_tuple:
            pub_dt = datetime.fromtimestamp(email.utils.mktime_tz(pub_tuple))
            return (target_dt - timedelta(days=1)) <= pub_dt <= (target_dt + timedelta(days=1))
    except Exception as e:
        print(f"Date parsing error: {e}")
    return True

def clean_html_text(text):
    """HTML tags ko clean text me convert karta hai"""
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. NEWS SCRAPING FUNCTIONS (WITH DEEP DATA SCRAPING)
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    """Multiple Official & Media sources se Bihar Current Affairs raw text scrape karta hai"""
    news_titles = []
    
    # Source A: GOOGLE NEWS RSS
    try:
        google_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(google_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Google News] {title}")
                    count += 1
                    if count >= 20:
                        break
            print("✅ Google News Bihar RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Google News Bihar: {e}")

    # Source B: CMO BIHAR
    try:
        cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr')[:15]:
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = cols[1].text.strip()
                    if title and len(title) > 10:
                        news_titles.append(f"[CMO Bihar] {title}")
            print("✅ CMO Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching CMO Bihar: {e}")

    # Source C: IPRD BIHAR
    try:
        iprd_url = "https://state.bihar.gov.in/prdbihar/CitizenHome.html"
        res = requests.get(iprd_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            count = 0
            for link in soup.find_all('a'):
                title = link.text.strip()
                if title and len(title) > 15:
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 12:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching IPRD Bihar: {e}")

    # Source D: PRABHAT KHABAR BIHAR
    try:
        pk_url = "https://www.prabhatkhabar.com/state/bihar/feed"
        res = requests.get(pk_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Prabhat Khabar] {title.strip()}")
                    count += 1
                    if count >= 15:
                        break
            print("✅ Prabhat Khabar Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Prabhat Khabar: {e}")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    """HIGH-YIELD MULTI-SOURCE PURE NATIONAL Current Affairs Scraper (With Full Summaries)"""
    national_titles = []
    
    # Source A: PIB India (Central Govt Releases)
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
        res = requests.get(pib_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item')[:15]:
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    # Raised character limit from 250 -> 800 for deeper AI explanation
                    national_titles.append(f"[PIB Central] Title: {title.strip()} | Summary: {desc[:800]}")
            print("✅ PIB Central RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error PIB India: {e}")

    # Source B: Google News - Multi-Topic Central Query
    queries = [
        '%22Union+Cabinet%22+OR+%22Cabinet+Approves%22',
        'ISRO+OR+DRDO+OR+%22Military+Exercise%22',
        '%22RBI%22+OR+%22NITI+Aayog%22+OR+Index'
    ]
    for q in queries:
        try:
            g_url = f"https://news.google.com/rss/search?q={q}&hl=hi&gl=IN&ceid=IN:hi"
            res = requests.get(g_url, impersonate="chrome", timeout=12, verify=False)
            if res.status_code == 200:
                root = ET.fromstring(res.text)
                for item in root.findall('.//item')[:10]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                    desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                    if title and is_yesterday_news(pub_date, target_dt):
                        # Raised limit 200 -> 600
                        national_titles.append(f"[Google Central] Title: {title.strip()} | Summary: {desc[:600]}")
        except Exception as e:
            print(f"⚠️ Error Google National Query ({q}): {e}")
    print("✅ Google Central Multi-Queries fetched successfully!")

    # Source C: The Hindu National
    try:
        hindu_url = "https://www.thehindu.com/news/national/feeder/default.rss"
        res = requests.get(hindu_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item')[:15]:
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[The Hindu National] Title: {title.strip()} | Summary: {desc[:600]}")
            print("✅ The Hindu National fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error The Hindu: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 3. AI SUMMARY GENERATOR (ENHANCED DEEP EXPLANATION PROMPT)
# -------------------------------------------------------------
def call_groq_safe(prompt, system_role="You are a JSON generator assistant."):
    """Multi-Model Fallback Executor (TPM & TPD Safe)"""
    time.sleep(2)
    for model_name in MODELS:
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_role},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"}
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] rate-limited/failed: {e}. Trying fallback...")
            time.sleep(2)
            
    print("❌ All Groq models failed for this call.")
    return ""


def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Fact-Based Detailed Hinglish JSON news summary banwata hai"""
    truncated_raw = raw_text[:8000]
    
    if is_national:
        scope_name = "India National & International Level ONLY"
        tag_name = "🎯 National Special / India Affairs"
        category_instruction = """
        STRICT ALLOWED NATIONAL CATEGORIES (Pick ONLY from these 7 exact names):
        1. "Policies, Acts & Flagship Schemes"
        2. "Science, Defense & ISRO"
        3. "Indices, Reports & Economic Affairs"
        4. "International Relations & Summits"
        5. "Environment, Ramsar Sites & Wildlife"
        6. "Appointments, Awards & Places in News"
        7. "Sports & Joint Military Exercises"
        """
        rejection_rules = """
        STRICT REJECTION RULES (CRITICAL):
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT Jobs, Vacancies, Recruitment, Exam Notices, Admit Cards, University/School Notices, and Results.
        2. REJECT ALL STATE-SPECIFIC LOCAL NEWS: Strictly REJECT news specific to individual states (e.g. Tamil Nadu Budget, UP Govt Schemes, State local politics).
        3. REJECT ALL Politics, Crime, & Accidents: REJECT political rallies, speeches, party disputes, political statements, crime, and local accidents.
        4. ACCEPT ONLY PURE NATIONAL / CENTRAL / INTERNATIONAL EVENTS.
        """
        bullet_rules = """
        EXAMINER FOCUS DEEP BULLET RULES (NATIONAL) - MANDATORY DETAILED EXPLANATIONS:
        - WRITE EXACTLY 3 DEEP, COMPREHENSIVE, AND DETAILED BULLET POINTS IN HINGLISH FOR EVERY CARD.
        - DO NOT WRITE ONE-LINE SHORT SUMMARY BULLETS. Each bullet MUST be at least 20 to 35 words long with deep context.
        - Bullet 1 (Core Announcement & Nodal Body): Detail what decision/policy/project was launched, which Central Ministry/Organization is responsible, location, and the key stakeholders in Hinglish.
        - Bullet 2 (Numerical Data & Key High-Yield Exam Facts): Include exact numbers, financial budget outlay, target years, missile range, India's rank, or participating countries in Hinglish.
        - Bullet 3 (Strategic Purpose & Background Context): Explain WHY this was done, its strategic objective, long-term impact on economy/defense/policy, or background act/framework in Hinglish.
        """
    else:
        scope_name = "Bihar State Level"
        tag_name = "🎯 BPSC Special / Bihar Current Affairs"
        category_instruction = """
        STRICT ALLOWED BIHAR CATEGORIES (Pick ONLY from these 5 exact names):
        1. "Govt Schemes & Policies"
        2. "Infrastructure & Projects"
        3. "Agriculture, Environment & GI Tags"
        4. "Appointments, Awards & Persons in News"
        5. "Bihar Economy, Budget & Reports"
        """
        rejection_rules = """
        STRICT REJECTION & DISCARD RULES (CRITICAL):
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT any Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
        2. REJECT ALL routine administrative instructions, CM directives, political speeches, crime, and accidents.
        3. STRICT INFRASTRUCTURE FILTER: ACCEPT ONLY MAJOR MEGA-INFRASTRUCTURE PROJECTS.
        4. EVERY card MUST contain AT LEAST ONE hard fact (Outlay, Specific Act Name, MoU partner).
        """
        bullet_rules = """
        BULLET POINT RULES (IF A CARD QUALIFIES):
        - WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH.
        - DO NOT write short filler lines. Provide detailed factual context in 20-30 words per bullet point.
        """

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC, SSC, and Civil Services Competitive Exams.
    Below is raw news text scraped for {scope_name}:
    
    {truncated_raw}
    
    {category_instruction}

    {rejection_rules}

    DEDUPLICATION & QUANTITY RULE:
    - MERGE duplicate reports of the same event into ONE single card. No duplicate cards allowed.
    - GENERATE ALL VALID CARDS: Extract ALL unique qualifying news items from the input text (target 8-15 cards).

    LANGUAGE & BULLETS:
    - WRITE ALL TITLES AND BULLETS IN **HINGLISH** (Hindi written in Roman English Script).
    - ALWAYS WRITE EXACTLY 3 DETAILED BULLET POINTS FOR EVERY CARD.
    {bullet_rules}

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category name from the list above",
          "bullets": [
            "Bullet 1: Comprehensive explanation of the decision, nodal ministry, and scope in Hinglish",
            "Bullet 2: Exact numerical data, financial budget outlay, or participating nations in Hinglish",
            "Bullet 3: Strategic objective, policy impact, and deep background context in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    return call_groq_safe(prompt, system_role="Senior Current Affairs Editor")

# -------------------------------------------------------------
# 4. MASTER HISTORY APPEND FUNCTIONS
# -------------------------------------------------------------
def append_to_master_history(news_cards, yesterday_key, is_national=False):
    """Appends daily news cards to the master history JSON files"""
    master_file = "all_national_news_history.json" if is_national else "all_bihar_news_history.json"
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Master History appended under key '{yesterday_key}' into '{master_file}'!")

# -------------------------------------------------------------
# 5. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting News-Only Current Affairs Pipeline ({date_str})...\n")

    # === A. PROCESS BIHAR NEWS ===
    print("📍 --- PROCESS BIHAR NEWS ---")
    raw_bihar = fetch_raw_bihar_news(target_dt)
    if raw_bihar:
        ai_bihar = generate_clean_summary(raw_bihar, date_str, is_national=False)
        if ai_bihar:
            try:
                parsed_bihar = json.loads(ai_bihar.strip())
                cards = parsed_bihar.get("news_cards", [])
                
                if cards and len(cards) > 0:
                    with open("bihar_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_news.json successfully updated with {len(cards)} new cards!")
                    append_to_master_history(cards, key_str, is_national=False)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 Bihar news cards. Retaining existing file!")
            except Exception as e:
                print(f"❌ Bihar JSON Parsing Error: {e}")

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    print("🇮🇳 --- PROCESS NATIONAL NEWS ---")
    raw_national = fetch_raw_national_news(target_dt)
    if raw_national:
        ai_national = generate_clean_summary(raw_national, date_str, is_national=True)
        if ai_national:
            try:
                parsed_national = json.loads(ai_national.strip())
                cards_nat = parsed_national.get("news_cards", [])
                
                if cards_nat and len(cards_nat) > 0:
                    with open("national_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_national, f, ensure_ascii=False, indent=2)
                    print(f"✅ national_news.json successfully updated with {len(cards_nat)} new cards!")
                    append_to_master_history(cards_nat, key_str, is_national=True)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 National news cards. Retaining existing file!")
            except Exception as e:
                print(f"❌ National JSON Parsing Error: {e}")

    print("\n🎉 Pipeline Execution Finished Successfully!")
