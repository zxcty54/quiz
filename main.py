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

def fetch_raw_bihar_news(target_dt):
    """Multiple Official & Media sources se Bihar Current Affairs raw text scrape karta hai"""
    news_titles = []
    
    # -------------------------------------------------------------
    # Source A: GOOGLE NEWS RSS (Govt Schemes, Infrastructure, Economy, Agriculture)
    # -------------------------------------------------------------
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
                    if count >= 15:
                        break
            print("✅ Google News RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Google News: {e}")

    # -------------------------------------------------------------
    # Source B: CMO BIHAR (Chief Minister Secretariat)
    # -------------------------------------------------------------
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
            print("✅ CMO Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching CMO Bihar: {e}")

    # -------------------------------------------------------------
    # Source C: IPRD BIHAR (Information & Public Relations Dept)
    # -------------------------------------------------------------
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
                    if count >= 8:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching IPRD Bihar: {e}")

    # -------------------------------------------------------------
    # Source D: PRABHAT KHABAR BIHAR (RSS Feed)
    # -------------------------------------------------------------
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
                    if count >= 10:
                        break
            print("✅ Prabhat Khabar Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Prabhat Khabar: {e}")

    return "\n".join(news_titles)

def generate_clean_summary(raw_text, target_date_str):
    """Groq AI se Strict Fact-Based Detailed Hinglish BPSC Exam JSON summary banwata hai"""
    current_year = datetime.now().year

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC and Bihar State Competitive Exams.
    Below is raw news text scraped from Bihar official portals and news feeds:
    
    {raw_text}
    
    STRICT ALLOWED CATEGORIES (Pick ONLY from these 5 exact names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Agriculture, Environment & GI Tags"
    4. "Appointments, Awards & Persons in News"
    5. "Bihar Economy, Budget & Reports"

    STRICT REJECTION & DISCARD RULES (CRITICAL):
    1. REJECT ALL routine administrative instructions, CM directives ("nirdesh diye"), smooth traffic arrangements, RERA routine meetings, or generic press statements.
    2. REJECT ALL Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
    3. STRICT INFRASTRUCTURE FILTER:
       - For "Infrastructure & Projects", REJECT small/routine road repairs or local city traffic directives.
       - ACCEPT ONLY MAJOR MEGA-INFRASTRUCTURE PROJECTS that make national/state headlines (e.g., Metro lines, Mega Expressways, Major Ganga Bridges, Airports, Power Plants, or Mega Investment projects).
    4. REJECT ALL news that lacks hard facts. EVERY card MUST contain AT LEAST ONE hard fact:
       - Exact Budget/Investment Outlay in Crores (e.g. 500 Cr, 6000 Cr)
       - Specific Scheme/Act Name (e.g. Bihar Investment Promotion Policy)
       - MoU Partner Name
       - Exact Location, Highway Length, or Capacity Numbers.
    5. NEVER WRITE DISCLAIMERS: It is STRICTLY FORBIDDEN to write statements like "Koi vishisht budget/yojana nahi di gayi", "Yeh vikas ke liye avashyak hai", or "Isse logon ko labh hoga".
    6. IF NO FACTUAL NEWS IS FOUND: Return an empty list: {{"news_cards": []}}. It is 100x better to return 0 or 1 card than to generate useless generic news.

    BULLET POINT RULES (IF A CARD QUALIFIES):
    1. WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH (Hindi written in Roman English script).
       - Bullet 1 (Core Decision): Detailed explanation of what specific project/scheme was launched, which Ministry/Dept is involved, and exact location in Hinglish.
       - Bullet 2 (Exact Figures): Specific budget amount, MoU partner name, capacity, target year, or numerical facts in Hinglish.
       - Bullet 3 (Policy Framework): Deep explanation of which government policy or framework it falls under (e.g., Saat Nischay-2, Krishi Road Map 4, Economic Survey) in Hinglish.
    2. DO NOT write filler lines like "Yeh BPSC ke liye important hai" or "Isse vikas hoga". Provide REAL factual context instead.

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category from the 5 allowed categories above",
          "bullets": [
            "Bullet 1: Detailed factual explanation of decision, department, and location in Hinglish",
            "Bullet 2: Exact numerical data, budget outlay, MoU partner, or project scale details in Hinglish",
            "Bullet 3: Deep explanation of policy framework or state development context in Hinglish"
          ],
          "exam_tag": "🎯 BPSC Special / Bihar Current Affairs",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.01,  # Ultra-low temperature prevents generic filler text
        response_format={"type": "json_object"}
    )
    return response.choices[0].message.content

def append_to_master_history(news_cards, yesterday_key):
    """Master Lifetime History File (all_bihar_news_history.json) me kal ki key me append karta hai"""
    master_file = "all_bihar_news_history.json"
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History file read error: {e}")
            
    master_data[yesterday_key] = news_cards
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Master History appended under key '{yesterday_key}' into '{master_file}'!")

if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Scraping news covering full day of yesterday ({date_str})...")
    raw_news = fetch_raw_bihar_news(target_dt)
    
    if raw_news:
        print("🧠 Categorizing news with Groq (Llama-3.3-70b)...")
        ai_response = generate_clean_summary(raw_news, date_str)
        clean_json_str = ai_response.strip()
        
        try:
            parsed_json = json.loads(clean_json_str)
            
            # 1. Update Daily App JSON File
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_json, f, ensure_ascii=False, indent=2)
            print("✅ bihar_news.json successfully updated!")
            
            # 2. Append to Master History File with yesterday's YYYY-MM-DD key
            if "news_cards" in parsed_json:
                append_to_master_history(parsed_json["news_cards"], key_str)
                
        except Exception as e:
            print(f"❌ JSON Parsing Error: {e}\nRaw Output:\n{ai_response}")
    else:
        print("❌ No news data scraped to process.")
