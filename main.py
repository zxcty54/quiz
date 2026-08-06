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

def get_yesterday_info():
    """Subah 6 AM run hone par kal ki date aur formatted strings generate karta hai"""
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   # e.g., '05 Aug 2026'
    key_str = yesterday_dt.strftime("%Y-%m-%d")    # e.g., '2026-08-05'
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
# 2. SCRAPING FUNCTIONS
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
    """HIGH-YIELD MULTI-SOURCE PURE NATIONAL Current Affairs Scraper"""
    national_titles = []
    
    # Source A: PIB India (Central Govt Releases)
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
        res = requests.get(pib_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[PIB Central] Title: {title.strip()} | Summary: {desc[:250]}")
            print("✅ PIB Central RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error PIB India: {e}")

    # Source B: Google News - Multi-Topic Central Query
    queries = [
        '%22Union+Cabinet%22+OR+%22Central+Government%22+OR+%22Cabinet+Approves%22',
        'ISRO+OR+DRDO+OR+%22Military+Exercise%22+OR+Missile',
        '%22RBI%22+OR+%22NITI+Aayog%22+OR+%22Union+Budget%22+OR+Index',
        '%22G20%22+OR+%22BRICS%22+OR+%22SCO%22+OR+%22COP29%22+OR+%22Summit%22',
        '%22Ramsar+Site%22+OR+%22Tiger+Reserve%22+OR+%22Sports+World+Cup%22'
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
                        national_titles.append(f"[Google Central] Title: {title.strip()} | Summary: {desc[:200]}")
        except Exception as e:
            print(f"⚠️ Error Google National Query ({q}): {e}")
    print("✅ Google Central Multi-Queries fetched successfully!")

    # Source C: AIR News
    try:
        air_url = "https://newsonair.gov.in/feed/"
        res = requests.get(air_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[AIR Central] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ AIR Central News fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error AIR News: {e}")

    # Source D: The Hindu National
    try:
        hindu_url = "https://www.thehindu.com/news/national/feeder/default.rss"
        res = requests.get(hindu_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[The Hindu National] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ The Hindu National fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error The Hindu: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 3. AI SUMMARY GENERATOR (STRICT SYLLABUS FILTERS)
# -------------------------------------------------------------
def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Fact-Based Detailed Hinglish JSON summary banwata hai"""
    
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
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT any news related to Jobs, Vacancies, Recruitment, Exam Notices, Admit Cards, University/School Notices, and Results.
        2. REJECT ALL STATE-SPECIFIC LOCAL NEWS: Strictly REJECT any news that belongs to a specific State Government (e.g., REJECT State Budgets like Tamil Nadu Budget, UP Govt Schemes, State local politics/announcements).
        3. REJECT ALL Politics, Crime, & Accidents: REJECT political rallies, speeches, party disputes, political statements, crime, and local accidents.
        4. ACCEPT ONLY PURE NATIONAL / CENTRAL / INTERNATIONAL EVENTS:
           - Central Acts, Bills, Union Policies, Central Flagship Schemes (Target, Eligibility, Outlay).
           - ISRO/NASA Space Missions (Launch Vehicle name e.g. LVM3/PSLV), Defense Missiles & Joint Military Exercises (Countries + Venue).
           - RBI Monetary Policy, Union Budget, Economic Survey, NITI Aayog Reports, Global Indices (Issuing Body + India's Rank).
           - International Summits (G20, BRICS, SCO, COP) - Theme, Venue & Declarations.
           - Ramsar Sites, Tiger Reserves, National Parks.
           - Constitutional Appointments (CJI, CEC, CAG, UPSC Chief) & Major Awards (Nobel, Bharat Ratna, Padma).
           - Major Sports Events (Olympics, Asian Games, World Cups).
        """
        bullet_rules = """
        EXAMINER FOCUS BULLET RULES (NATIONAL):
        - Bullet 1 (Core Decision/Event): Core decision, Nodal Central Ministry/Org, Location/Venue, or Theme in Hinglish.
        - Bullet 2 (Exact High-Yield Exam Facts):
          * For Military Exercises: Mention Participating Countries + Exact Location.
          * For ISRO/Defense: Mention Satellite/Missile Type + Launch Vehicle name.
          * For Indices/Reports: Mention Issuing Body + India's Rank/Score.
          * For Schemes: Mention Budget Outlay + Eligibility/Nodal Ministry.
        - Bullet 3 (Context & Strategic Objective): Core objective, strategic importance, or policy framework in Hinglish.
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
        2. REJECT ALL routine administrative instructions, CM directives ("nirdesh diye"), smooth traffic arrangements, RERA routine meetings, political speeches, crime, and accidents.
        3. STRICT INFRASTRUCTURE FILTER:
           - For "Infrastructure & Projects", REJECT small/routine road repairs or local city traffic directives.
           - ACCEPT ONLY MAJOR MEGA-INFRASTRUCTURE PROJECTS that make national/state headlines (e.g., Metro lines, Mega Expressways, Major Ganga Bridges, Airports, Power Plants, or Mega Investment projects).
        4. REJECT ALL news that lacks hard facts. EVERY card MUST contain AT LEAST ONE hard fact:
           - Exact Budget/Investment Outlay in Crores (e.g. 500 Cr, 6000 Cr)
           - Specific Scheme/Act Name (e.g. Bihar Investment Promotion Policy)
           - MoU Partner Name
           - Exact Location, Highway Length, or Capacity Numbers.
        5. NEVER WRITE DISCLAIMERS: It is STRICTLY FORBIDDEN to write statements like "Koi vishisht budget/yojana nahi di gayi", "Yeh vikas ke liye avashyak hai", or "Isse logon ko labh hoga".
        6. IF NO FACTUAL NEWS IS FOUND: Return an empty list: {"news_cards": []}. It is 100x better to return 0 or 1 card than to generate useless generic news.
        """
        bullet_rules = """
        BULLET POINT RULES (IF A CARD QUALIFIES):
        1. WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH (Hindi written in Roman English script).
           - Bullet 1 (Core Decision): Detailed explanation of what specific project/scheme was launched, which Ministry/Dept is involved, and exact location in Hinglish.
           - Bullet 2 (Exact Figures): Specific budget amount, MoU partner name, capacity, target year, or numerical facts in Hinglish.
           - Bullet 3 (Policy Framework): Deep explanation of which government policy or framework it falls under (e.g., Saat Nischay-2, Krishi Road Map 4, Economic Survey) in Hinglish.
        2. DO NOT write filler lines like "Yeh BPSC ke liye important hai" or "Isse vikas hoga". Provide REAL factual context instead.
        """

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC, SSC, and Civil Services Competitive Exams.
    Below is raw news text scraped for {scope_name}:
    
    {raw_text}
    
    {category_instruction}

    {rejection_rules}

    DEDUPLICATION & QUANTITY RULE:
    - MERGE duplicate reports of the same event into ONE single card. No duplicate cards allowed.
    - GENERATE ALL VALID CARDS: Extract ALL unique qualifying news items from the input text (target generating at least 8-15 high-yield cards if raw data exists).

    LANGUAGE & BULLETS:
    - WRITE ALL TITLES AND BULLETS IN **HINGLISH** (Hindi written in Roman English Script).
    - ALWAYS WRITE EXACTLY 3 BULLET POINTS FOR EVERY CARD.
    {bullet_rules}

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category name from the list above",
          "bullets": [
            "Bullet 1: Detailed factual explanation in Hinglish",
            "Bullet 2: Exact numerical data/budget outlay in Hinglish",
            "Bullet 3: Deep explanation of policy framework in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.01,
            response_format={"type": "json_object"}
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"⚠️ Groq API Failed for {scope_name}: {e}")
        return ""

# -------------------------------------------------------------
# 4. MASTER HISTORY APPEND FUNCTIONS
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
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Master History appended under key '{yesterday_key}' into '{master_file}'!")

# -------------------------------------------------------------
# 5. MAIN EXECUTION PIPELINE (SAFE RETENTION LOGIC)
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Scraping for Yesterday ({date_str})...\n")

    # === A. PROCESS BIHAR NEWS ===
    print("📍 --- PROCESS BIHAR NEWS ---")
    raw_bihar = fetch_raw_bihar_news(target_dt)
    if raw_bihar:
        ai_bihar = generate_clean_summary(raw_bihar, date_str, is_national=False)
        if ai_bihar:
            try:
                parsed_bihar = json.loads(ai_bihar.strip())
                cards = parsed_bihar.get("news_cards", [])
                
                # SAFEGUARD: Update file ONLY IF news_cards is NOT empty!
                if cards and len(cards) > 0:
                    with open("bihar_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_news.json successfully updated with {len(cards)} new cards!")
                    append_to_master_history(cards, key_str, is_national=False)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: AI returned 0 cards. Retaining existing bihar_news.json data!")
            except Exception as e:
                print(f"❌ Bihar JSON Parsing Error: {e}. Retaining existing file!")
    else:
        print("🛡️ SAFEGUARD ACTIVATED: No raw text scraped. Retaining existing bihar_news.json data!")

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
                
                # SAFEGUARD: Update file ONLY IF news_cards is NOT empty!
                if cards_nat and len(cards_nat) > 0:
                    with open("national_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_national, f, ensure_ascii=False, indent=2)
                    print(f"✅ national_news.json successfully updated with {len(cards_nat)} new cards!")
                    append_to_master_history(cards_nat, key_str, is_national=True)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: AI returned 0 national cards. Retaining existing national_news.json data!")
            except Exception as e:
                print(f"❌ National JSON Parsing Error: {e}. Retaining existing file!")
    else:
        print("🛡️ SAFEGUARD ACTIVATED: No national raw text scraped. Retaining existing national_news.json data!")
