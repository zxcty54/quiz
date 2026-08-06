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

# -------------------------------------------------------------
# 2. SCRAPING FUNCTIONS
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    """Bihar Specific Current Affairs Raw Text Scraper"""
    news_titles = []
    
    # Source A: Google News Bihar
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
                    if count >= 15: break
            print("✅ Google News Bihar RSS fetched!")
    except Exception as e:
        print(f"⚠️ Error Bihar Google News: {e}")

    # Source B: CMO Bihar
    try:
        cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr')[:10]:
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
            count = 0
            for link in soup.find_all('a'):
                title = link.text.strip()
                if title and len(title) > 15:
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 8: break
            print("✅ IPRD Bihar news fetched!")
    except Exception as e:
        print(f"⚠️ Error IPRD Bihar: {e}")

    # Source D: Prabhat Khabar
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
                    if count >= 10: break
            print("✅ Prabhat Khabar Bihar fetched!")
    except Exception as e:
        print(f"⚠️ Error Prabhat Khabar: {e}")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    """National Current Affairs Scraper (PIB India + Google National)"""
    national_titles = []
    
    # Source A: PIB (Press Information Bureau India - XML BeautifulSoup Parser)
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
        res = requests.get(pib_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            count = 0
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                if title:
                    national_titles.append(f"[PIB India] {title.strip()}")
                    count += 1
                    if count >= 12: break
            print("✅ PIB National RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error PIB India: {e}")

    # Source B: Google News National
    try:
        g_url = "https://news.google.com/rss/search?q=India+Cabinet+Decisions+OR+National+Schemes+OR+ISRO+OR+RBI+OR+National+Highways&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(g_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    national_titles.append(f"[National News] {title.strip()}")
                    count += 1
                    if count >= 12: break
            print("✅ Google National RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error Google National: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 3. AI SUMMARY GENERATOR (STRICT FILTERS)
# -------------------------------------------------------------
def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Strict Fact-Based Detailed Hinglish JSON summary banwata hai"""
    
    scope_name = "India National" if is_national else "Bihar State"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"
    
    economy_category = "National Economy, Budget & Reports" if is_national else "Bihar Economy, Budget & Reports"

    prompt = f"""
    You are a Senior Current Affairs Editor for Competitive Exams in India.
    Below is raw news text scraped for {scope_name} Level:
    
    {raw_text}
    
    STRICT ALLOWED CATEGORIES (Pick ONLY from these 5 exact names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Agriculture, Environment & GI Tags"
    4. "Appointments, Awards & Persons in News"
    5. "{economy_category}"

    STRICT REJECTION & DISCARD RULES:
    1. REJECT ALL routine administrative instructions, CM/PM directives ("nirdesh diye"), traffic directives, or generic press statements.
    2. REJECT ALL Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
    3. REJECT small/routine road repairs or local city directives. ACCEPT ONLY MEGA INFRASTRUCTURE PROJECTS (Expressways, Airports, Space Missions, Power Plants).
    4. REJECT ALL news that lacks hard facts (Budget outlay, Scheme Name, MoU Partner, Ministry Name).
    5. NEVER WRITE DISCLAIMERS: Forbidden to write "Koi budget/yojana nahi di gayi", "Yeh vikas ke liye avashyak hai".
    6. IF NO FACTUAL NEWS FOUND: Return empty list {{"news_cards": []}}.

    BULLET POINT RULES (IF A CARD QUALIFIES):
    1. WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH (Hindi written in Roman English script).
       - Bullet 1 (Core Decision): Detailed explanation of what project/scheme was launched, Ministry involved, and exact location.
       - Bullet 2 (Exact Figures): Specific budget amount, MoU partner name, capacity, target year, or numerical facts.
       - Bullet 3 (Policy Framework): Deep explanation of government framework or national/state development context.

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category from the 5 allowed above",
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
        print(f"⚠️ Groq API Call Failed for {scope_name}: {e}")
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
            print(f"⚠️ Master History file read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Appended under key '{yesterday_key}' into '{master_file}'!")

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
        print("ℹ️ Empty bihar_news.json created (No raw text).")

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    print("🇮🇳 --- PROCESS NATIONAL NEWS ---")
    raw_national = fetch_raw_national_news(target_dt)
    
    # ALWAYS MANDATORY WRITE national_news.json
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
            print("⚠️ Fallback empty national_news.json written.")
    else:
        with open("national_news.json", "w", encoding="utf-8") as f:
            json.dump({"news_cards": []}, f, ensure_ascii=False, indent=2)
        print("ℹ️ Created empty national_news.json (No raw headlines fetched).")
