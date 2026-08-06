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
    date_str = yesterday_dt.strftime("%d %b %Y")   # e.g., '02 Aug 2026'
    key_str = yesterday_dt.strftime("%Y-%m-%d")    # e.g., '2026-08-02'
    return yesterday_dt, date_str, key_str

def clean_html_text(text):
    """HTML tags ko clean text me convert karta hai"""
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. SCRAPING FUNCTIONS
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    """Bihar Specific Raw News Scraper"""
    news_titles = []
    
    # Source A: Google News Bihar
    try:
        google_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(google_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    news_titles.append(f"[Google News Bihar] Title: {title} | Details: {desc[:200]}")
            print("✅ Google News Bihar RSS fetched!")
    except Exception as e:
        print(f"⚠️ Error Bihar Google News: {e}")

    # Source B: CMO Bihar
    try:
        cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr'):
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = cols[1].text.strip()
                    if title and len(title) > 10:
                        news_titles.append(f"[CMO Bihar] {title}")
            print("✅ CMO Bihar news fetched!")
    except Exception as e:
        print(f"⚠️ Error CMO Bihar: {e}")

    # Source C: IPRD Bihar
    try:
        iprd_url = "https://state.bihar.gov.in/prdbihar/CitizenHome.html"
        res = requests.get(iprd_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for link in soup.find_all('a'):
                title = link.text.strip()
                if title and len(title) > 15:
                    news_titles.append(f"[IPRD Bihar] {title}")
            print("✅ IPRD Bihar news fetched!")
    except Exception as e:
        print(f"⚠️ Error IPRD Bihar: {e}")

    # Source D: Prabhat Khabar
    try:
        pk_url = "https://www.prabhatkhabar.com/state/bihar/feed"
        res = requests.get(pk_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    news_titles.append(f"[Prabhat Khabar] Title: {title} | Details: {desc[:200]}")
            print("✅ Prabhat Khabar Bihar fetched!")
    except Exception as e:
        print(f"⚠️ Error Prabhat Khabar: {e}")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    """PURE NATIONAL Current Affairs Scraper (No State News Allowed)"""
    national_titles = []
    
    # Source A: PIB (Press Information Bureau India - Pure Central Govt Releases)
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
        res = requests.get(pib_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[PIB Union Govt] Title: {title.strip()} | Summary: {desc[:250]}")
            print("✅ PIB Union Govt RSS fetched!")
    except Exception as e:
        print(f"⚠️ Error PIB India: {e}")

    # Source B: Google News - PURE CENTRAL / UNION GOVT SEARCH
    try:
        g_url = "https://news.google.com/rss/search?q=%22Union+Cabinet%22+OR+%22Central+Government%22+OR+ISRO+OR+DRDO+OR+%22RBI%22+OR+%22NITI+Aayog%22+OR+%22Military+Exercise%22+OR+%22G20%22+OR+%22BRICS%22&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(g_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[Central News] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ Google Central/National RSS fetched!")
    except Exception as e:
        print(f"⚠️ Error Google National: {e}")

    # Source C: AIR News (All India Radio Central Bulletin)
    try:
        air_url = "https://newsonair.gov.in/feed/"
        res = requests.get(air_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[AIR National] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ AIR Central News fetched!")
    except Exception as e:
        print(f"⚠️ Error AIR News: {e}")

    # Source D: The Hindu (National Desk)
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
            print("✅ The Hindu National fetched!")
    except Exception as e:
        print(f"⚠️ Error The Hindu: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 3. AI SUMMARY GENERATOR (EXAM SYLLABUS GRID ENFORCED)
# -------------------------------------------------------------
def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Factual Hinglish JSON summary banwata hai"""
    
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
        STRICT REJECTION RULES (PURE NATIONAL FILTER):
        1. REJECT ALL STATE-SPECIFIC NEWS: Strictly reject news specific to individual states (e.g. UP govt schemes, MP politics, Rajasthan local events, Delhi municipal news, State assembly debates).
        2. ACCEPT ONLY PURE NATIONAL / CENTRAL EVENTS: Union Cabinet decisions, Central Ministries, ISRO/DRDO/Defense, RBI, NITI Aayog, International Bilateral Relations, National Level Indices/Reports, Global Summits, and National/International Sports/Awards.
        3. REJECT political rallies, speeches, party disputes, crime, accidents.
        4. REJECT ALL Education, Schools, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
        """
        bullet_rules = """
        EXAMINER FOCUS BULLET RULES (NATIONAL):
        - Bullet 1 (Core Event & Details): Core event/decision, Nodal Union Ministry/Org, Location/Host City or Theme.
        - Bullet 2 (Exact High-Yield Exam Facts): 
          * For Military Exercises: Mention Participating Countries + Exact Exercise Location.
          * For ISRO/Defense: Mention Missile/Satellite Type + Launch Vehicle (e.g. LVM3, PSLV).
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
        STRICT REJECTION RULES (BIHAR):
        1. REJECT political speeches, rallies, local city traffic orders, crime, accidents.
        2. REJECT ALL Education, Schools, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
        3. REJECT local small road repairs. Accept only Mega Projects.
        """
        bullet_rules = """
        BULLET RULES (BIHAR):
        - Bullet 1 (Core Decision): Detailed explanation of decision, ministry/department, and location.
        - Bullet 2 (Factual Data): Specific budget outlay, capacity, target year, or MoU partner.
        - Bullet 3 (Policy Context): Policy framework (e.g., Saat Nischay-2, Krishi Road Map 4, etc.).
        """

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC, SSC, and Civil Services Competitive Exams.
    Below is raw news text scraped for {scope_name}:
    
    {raw_text}
    
    {category_instruction}

    {rejection_rules}

    DEDUPLICATION RULE:
    - MERGE duplicate reports of the same event into ONE single card. No duplicate cards allowed.
    - NO CARD LIMIT: Generate cards for ALL valid unique exam-relevant events found.

    LANGUAGE & BULLETS:
    - WRITE ALL TITLES AND BULLETS IN **HINGLISH** (Hindi written in Roman English Script, e.g. "India aur Japan ke beech Dharma Guardian exercise Rajasthan me shuru hui").
    - ALWAYS WRITE EXACTLY 3 BULLET POINTS FOR EVERY CARD.
    {bullet_rules}

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Factual Hinglish Headline",
          "category": "Select EXACT matching category name from the list above",
          "bullets": [
            "Point 1 in Hinglish",
            "Point 2 in Hinglish",
            "Point 3 in Hinglish"
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
            temperature=0.05,
            response_format={"type": "json_object"}
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"⚠️ Groq API Failed for {scope_name}: {e}")
        return '{"news_cards": []}'

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
# 5. MAIN EXECUTION PIPELINE
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
        try:
            parsed_bihar = json.loads(ai_bihar.strip())
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
            print("✅ bihar_news.json successfully updated!")
            if "news_cards" in parsed_bihar:
                append_to_master_history(parsed_bihar["news_cards"], key_str, is_national=False)
        except Exception as e:
            print(f"❌ Bihar JSON Parsing Error: {e}")
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump({"news_cards": []}, f, ensure_ascii=False, indent=2)
    else:
        with open("bihar_news.json", "w", encoding="utf-8") as f:
            json.dump({"news_cards": []}, f, ensure_ascii=False, indent=2)

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    print("🇮🇳 --- PROCESS NATIONAL NEWS ---")
    raw_national = fetch_raw_national_news(target_dt)
    if raw_national:
        ai_national = generate_clean_summary(raw_national, date_str, is_national=True)
        try:
            parsed_national = json.loads(ai_national.strip())
            with open("national_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_national, f, ensure_ascii=False, indent=2)
            print("✅ national_news.json successfully updated!")
            
            if "news_cards" in parsed_national:
                append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Parsing Error: {e}")
            with open("national_news.json", "w", encoding="utf-8") as f:
                json.dump({"news_cards": []}, f, ensure_ascii=False, indent=2)
    else:
        with open("national_news.json", "w", encoding="utf-8") as f:
            json.dump({"news_cards": []}, f, ensure_ascii=False, indent=2)
