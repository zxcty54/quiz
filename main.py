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

def is_recent_news(pub_date_str):
    """Check karta hai ki news pichle 2 dino ki hai ya purani"""
    if not pub_date_str:
        return True
    try:
        pub_tuple = email.utils.parsedate_tz(pub_date_str)
        if pub_tuple:
            pub_dt = datetime.fromtimestamp(email.utils.mktime_tz(pub_tuple))
            two_days_ago = datetime.now() - timedelta(days=2)
            return pub_dt >= two_days_ago
    except Exception as e:
        print(f"Date parsing error: {e}")
    return True

def fetch_raw_bihar_news():
    """Google News RSS + CMO Bihar + IPRD Bihar se raw news scrape karta hai"""
    news_titles = []
    
    # -------------------------------------------------------------
    # Source A: GOOGLE NEWS RSS (Bihar Govt & Education - Hindi)
    # -------------------------------------------------------------
    try:
        google_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+Education+BPSC&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(google_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_recent_news(pub_date):
                    news_titles.append(f"[Google News] {title}")
                    count += 1
                    if count >= 6:
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
            for row in soup.find_all('tr')[:4]:
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
                if title and len(title) > 20 and any(keyword in title for keyword in ["योजना", "विकास", "विभाग", "बिहार", "सूचना"]):
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 3:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching IPRD Bihar: {e}")

    return "\n".join(news_titles)

def generate_clean_summary(raw_text):
    """Groq API (Llama-3.3-70b) se strict filtered JSON summary banwata hai"""
    today_str = datetime.now().strftime("%d %b %Y")
    current_year = datetime.now().year

    prompt = f"""
    Tum BPSC aur Bihar Competitive Exams ke Current Affairs Editor ho.
    Niche Google News, CMO Bihar aur IPRD Bihar se li gayi raw headlines hain:
    
    {raw_text}
    
    STRICT FILTERING RULES:
    1. STRICTLY REJECT: Murder, Crime, Accidents, Political Rallies, Raajneeti speeches, Entertainment, aur previous years ({current_year-1} or older) ki news.
    2. STRICTLY REJECT DUPLICATES: Same event par multiple news entries bilkul na chunen.
    3. ACCEPT ONLY: Education, Bihar Govt Schemes, BPSC/BSSC updates, Infrastructure, Economy, Agriculture.
    4. Select TOP 4-5 high quality cards.
    5. Return STRICTLY valid JSON inside `news_cards` key without markdown syntax.
    
    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Short Clean Headline in Hindi",
          "category": "Education / Schemes / Infrastructure",
          "bullets": [
            "Point 1: Main update kya hai",
            "Point 2: Key details / Benefit",
            "Point 3: BPSC/SSC exam ke hisaab se kyo important hai"
          ],
          "exam_tag": "🎯 BPSC TRE / BSSC Special",
          "date": "{today_str}"
        }}
      ]
    }}
    """
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
        response_format={"type": "json_object"}
    )
    return response.choices[0].message.content

def append_to_master_history(news_cards):
    """Master Lifetime History File (all_bihar_news_history.json) me date-wise data append karta hai"""
    master_file = "all_bihar_news_history.json"
    today_key = datetime.now().strftime("%Y-%m-%d")
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History file read error: {e}")
            
    # Key update (No override of past dates, only appends/updates current date key)
    master_data[today_key] = news_cards
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Master History appended into '{master_file}'!")

if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    print("🔄 Scraping news from Google News, CMO Bihar & IPRD Bihar...")
    raw_news = fetch_raw_bihar_news()
    
    if raw_news:
        print("🧠 Processing news summary with Groq (Llama-3.3-70b)...")
        ai_response = generate_clean_summary(raw_news)
        
        # Cleanup response text
        clean_json_str = ai_response.strip()
        
        try:
            parsed_json = json.loads(clean_json_str)
            
            # 1. Update Daily App JSON File
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(parsed_json, f, ensure_ascii=False, indent=2)
            print("✅ bihar_news.json successfully updated!")
            
            # 2. Append to Master History File
            if "news_cards" in parsed_json:
                append_to_master_history(parsed_json["news_cards"])
                
        except Exception as e:
            print(f"❌ JSON Parsing Error: {e}\nRaw Output:\n{ai_response}")
    else:
        print("❌ No news data scraped to process.")
