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
    # Source A: GOOGLE NEWS RSS (Bihar Govt & Education)
    # -------------------------------------------------------------
    try:
        google_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Education+OR+BPSC+OR+Infrastructure&hl=hi&gl=IN&ceid=IN:hi"
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
    """Groq AI se strict Fact-Based Categorized JSON summary banwata hai"""
    current_year = datetime.now().year

    prompt = f"""
    Tum BPSC, BSSC aur Bihar Teacher (TRE) Exams ke Senior Current Affairs Editor ho.
    Niche Google News, CMO Bihar, IPRD Bihar aur Prabhat Khabar se li gayi raw headlines hain:
    
    {raw_text}
    
    STRICT CATEGORIES (Pick ONLY from these 7 exact category names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Education & Recruitment Updates"
    4. "Agriculture, Environment & GI Tags"
    5. "Appointments, Awards & Persons in News"
    6. "Bihar Economy, Budget & Reports"
    7. "Art, Culture & Tourism"

    STRICT EXAM RELEVANCE & FACT-CHECKING RULES:
    1. STRICTLY REJECT: 
       - Murder, Crime, Accidents, Political Speeches, Rallies, Elections, Entertainment, aur previous years ({current_year-1} or older) ki news.
       - Routine school timetable changes, local village school sanctions, motivational speeches, or general congratulatory statements.
    2. ACCEPT ONLY HIGH-YIELD FACTUAL NEWS:
       - Every card MUST contain at least ONE hard fact: Specific Scheme Name, Government Policy, Place Name, Budget/Amount, Committee Name, Rank, GI Tag, or Official Exam/Job Notification.
    3. BULLETS MUST BE HIGHLY FACTUAL:
       - Do NOT write generic filler lines like "यह निर्णय शिक्षा प्रणाली में सुधार के लिए महत्वपूर्ण है" or "इससे छात्रों को लाभ होगा".
       - Bullet 1: Core factual news and decision.
       - Bullet 2: Key numerical data, budget, target date, or scope.
       - Bullet 3: Exact exam/subject relevance or ministry involved.
    4. QUALITY OVER QUANTITY:
       - Include ALL valid exam-oriented news (No fixed count like 5 or 7. If there are 3, output 3; if 8, output 8).
    5. Set "date": "{target_date_str}" in all news items.
    6. Return STRICTLY valid JSON inside `news_cards` key without markdown wrapping.
    
    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Headline with Specific Keywords",
          "category": "Select exact matching name from 7 categories above",
          "bullets": [
            "Fact 1: Exact decision and location/scheme details",
            "Fact 2: Budget amount, target year or capacity data",
            "Fact 3: BPSC/SSC exam point of view / Ministry involved"
          ],
          "exam_tag": "🎯 BPSC TRE / BSSC Special",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.1,  # Low temperature forces exact factual adherence
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
