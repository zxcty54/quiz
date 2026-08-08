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

# -------------------------------------------------------------
# 1. API Client Setup (Groq & ScrapingAnt)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

# Token Saver Priority Models
MODELS = ["llama-3.1-8b-instant", "llama3-8b-8192", "llama-3.3-70b-versatile"]

def get_yesterday_info():
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   
    key_str = yesterday_dt.strftime("%Y-%m-%d")    
    return yesterday_dt, date_str, key_str

def is_yesterday_news(pub_date_str, target_dt):
    if not pub_date_str:
        return True
    try:
        pub_tuple = email.utils.parsedate_tz(pub_date_str)
        if pub_tuple:
            pub_dt = datetime.fromtimestamp(email.utils.mktime_tz(pub_tuple))
            return (target_dt - timedelta(days=2)) <= pub_dt <= (target_dt + timedelta(days=1))
    except Exception:
        pass
    return True

def clean_html_text(text):
    if not text: return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. UNIVERSAL SAFE FETCHER (WITH SCRAPINGANT FALLBACK)
# -------------------------------------------------------------
def safe_fetch(url, timeout=10):
    """
    Pehle direct try karega. Agar Fail/Timeout hua toh ScrapingAnt API use karega.
    """
    try:
        res = requests.get(url, impersonate="chrome", timeout=timeout, verify=False)
        if res.status_code == 200:
            return res.content
    except Exception as e:
        print(f"⚠️ Direct fetch failed for {url[:40]}... Error: {e}")

    # Fallback to ScrapingAnt
    if SCRAPINGANT_KEY:
        print(f"🔄 Switching to ScrapingAnt Fallback for {url[:40]}...")
        try:
            encoded_url = urllib.parse.quote(url, safe='')
            sa_url = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_KEY}&browser=false"
            sa_res = requests.get(sa_url, timeout=25)
            if sa_res.status_code == 200:
                return sa_res.content
        except Exception as sa_e:
            print(f"❌ ScrapingAnt also failed: {sa_e}")
    else:
        print("ℹ️ ScrapingAnt Key not found. Skipping fallback.")
        
    return None

# -------------------------------------------------------------
# 3. SCRAPING FUNCTIONS
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    news_titles = []
    
    # A. Google News Bihar
    content = safe_fetch("https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture&hl=hi&gl=IN&ceid=IN:hi")
    if content:
        root = ET.fromstring(content)
        count = 0
        for item in root.findall('.//item'):
            title = item.find('title').text if item.find('title') is not None else ""
            pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
            if title and is_yesterday_news(pub_date, target_dt):
                news_titles.append(f"[Google News] {title}")
                count += 1
                if count >= 12: break
        print("✅ Google News Bihar fetched!")

    # B. CMO Bihar
    content = safe_fetch("https://cm.bihar.gov.in/users/preessrelease.aspx")
    if content:
        soup = BeautifulSoup(content, "html.parser")
        for row in soup.find_all('tr')[:8]:
            cols = row.find_all('td')
            if len(cols) >= 2:
                title = cols[1].text.strip()
                if title and len(title) > 10:
                    news_titles.append(f"[CMO Bihar] {title}")
        print("✅ CMO Bihar fetched!")

    # C. Prabhat Khabar
    content = safe_fetch("https://www.prabhatkhabar.com/state/bihar/feed")
    if content:
        root = ET.fromstring(content)
        count = 0
        for item in root.findall('.//item'):
            title = item.find('title').text if item.find('title') is not None else ""
            pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
            if title and is_yesterday_news(pub_date, target_dt):
                news_titles.append(f"[Prabhat Khabar] {title.strip()}")
                count += 1
                if count >= 10: break
        print("✅ Prabhat Khabar Bihar fetched!")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    national_titles = []
    
    national_rss_sources = [
        ("PIB India", "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"),
        ("The Hindu", "https://www.thehindu.com/news/national/feeder/default.rss"),
        ("Indian Express", "https://indianexpress.com/section/india/feed/"),
        ("Hindustan Times", "https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml")
    ]

    # Fetch from Standard RSS Sources
    for source_name, url in national_rss_sources:
        content = safe_fetch(url)
        if content:
            try:
                soup = BeautifulSoup(content, "xml")
                count = 0
                for item in soup.find_all('item'):
                    title = item.find('title').text if item.find('title') is not None else ""
                    pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                    if title and is_yesterday_news(pub_date, target_dt):
                        national_titles.append(f"[{source_name}] {title.strip()}")
                        count += 1
                        if count >= 8: break # Max 8 per source to avoid token limit
                print(f"✅ {source_name} fetched!")
            except Exception as e:
                print(f"⚠️ XML Parsing error for {source_name}: {e}")

    # Google News National (Cabinet, ISRO, Economy)
    content = safe_fetch("https://news.google.com/rss/search?q=India+Cabinet+Decisions+OR+National+Schemes+OR+ISRO+OR+RBI+OR+National+Highways&hl=hi&gl=IN&ceid=IN:hi")
    if content:
        try:
            root = ET.fromstring(content)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    national_titles.append(f"[Google National] {title.strip()}")
                    count += 1
                    if count >= 10: break
            print("✅ Google National RSS fetched!")
        except Exception as e:
            print(f"⚠️ XML Parsing error for Google National: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATOR
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
                max_tokens=3000,
                timeout=45,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] skipped ({e}). Trying next...")
            time.sleep(1)
    return ""

def generate_clean_summary(raw_text, target_date_str, is_national=False):
    # TOKEN SAVER
    truncated_raw = raw_text[:5000]

    scope_name = "India National" if is_national else "Bihar State"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC and Competitive Exams in India.
    Below is raw news text scraped for {scope_name} Level:
    
    {truncated_raw}
    
    STRICT ALLOWED CATEGORIES (Pick ONLY from these 5 exact names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure & Projects"
    3. "Agriculture, Environment & GI Tags"
    4. "Appointments, Awards & Persons in News"
    5. "Bihar Economy, Budget & Reports" (Use "National Economy, Budget & Reports" for National news)

    STRICT REJECTION & DISCARD RULES:
    1. REJECT ALL routine administrative instructions, CM/PM directives, traffic directives, and local politics.
    2. REJECT ALL Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
    3. REJECT ALL Accidents, Crime, Theft, and Viral Lifestyle Hangout spots.
    4. REJECT small/routine road repairs. ACCEPT ONLY MEGA INFRASTRUCTURE PROJECTS (Expressways, Airports, Space Missions, Power Plants).
    5. REJECT ALL news that lacks hard facts (Budget outlay, Scheme Name, MoU Partner, Ministry Name).
    6. NEVER WRITE DISCLAIMERS. IF NO FACTUAL NEWS FOUND: Return empty list {{"news_cards": []}}.

    BULLET POINT RULES (IF A CARD QUALIFIES):
    1. WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH (Hindi written in Roman English script).
       - Bullet 1 (Core Decision): Detailed explanation of what project/scheme was launched, Ministry involved, and location.
       - Bullet 2 (Exact Figures): Specific budget amount, MoU partner name, capacity, target year, or numerical facts.
       - Bullet 3 (Policy Framework): Deep explanation of government framework or national/state development context.
       - Do NOT use Markdown asterisks (**).

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category",
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
    
    return call_groq_safe(prompt, system_role="Senior Current Affairs Editor")

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
            print(f"⚠️ Master History file read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    # Keep only the last 60 days 
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
            if "news_cards" in parsed_bihar and len(parsed_bihar["news_cards"]) > 0:
                append_to_master_history(parsed_bihar["news_cards"], key_str, is_national=False)
        except Exception as e:
            print(f"❌ Bihar JSON Error: {e}")

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
            if "news_cards" in parsed_national and len(parsed_national["news_cards"]) > 0:
                append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Error: {e}")

    print("\n🎉 PIPELINE EXECUTION FINISHED SUCCESSFULLY!")
