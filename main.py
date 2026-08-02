import os
import json
import xml.etree.ElementTree as ET
from curl_cffi import requests
from bs4 import BeautifulSoup
from google import genai

# -------------------------------------------------------------
# 1. API Client Setup (Using GOOGLE_API_KEY from GitHub Secret)
# -------------------------------------------------------------
GOOGLE_KEY = os.environ.get("GOOGLE_API_KEY")
client = genai.Client(api_key=GOOGLE_KEY) if GOOGLE_KEY else None

def fetch_raw_bihar_news():
    """Teeno Official Sources (CMO, IPRD, PIB) se raw news text scrape karta hai"""
    news_titles = []
    
    # -------------------------------------------------------------
    # Source A: PIB PATNA (RSS Feed)
    # -------------------------------------------------------------
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=2&Regid=3"
        res = requests.get(pib_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            for item in root.findall('.//item')[:4]:
                title = item.find('title').text if item.find('title') is not None else ""
                if title:
                    news_titles.append(f"[PIB Patna] {title}")
            print("✅ PIB Patna news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching PIB Patna: {e}")

    # -------------------------------------------------------------
    # Source B: CMO BIHAR (Chief Minister Secretariat Scrape)
    # -------------------------------------------------------------
    try:
        cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr')[:5]:
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
        # verify=False added to bypass SSL Certificate verification error
        res = requests.get(iprd_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            count = 0
            for link in soup.find_all('a'):
                title = link.text.strip()
                if title and len(title) > 20 and any(keyword in title for keyword in ["योजना", "विकास", "विभाग", "बिहार", "सूचना"]):
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 4:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching IPRD Bihar: {e}")

    return "\n".join(news_titles)

def generate_app_summary_json(raw_text):
    """Gemini AI se strict JSON format me summary banwata hai"""
    prompt = f"""
    Tum BPSC aur Bihar Competitive Exams ke Current Affairs Editor ho.
    Niche CMO Bihar, IPRD Bihar aur PIB Patna se li gayi latest raw news hai:
    
    {raw_text}
    
    RULES:
    1. Politics, Crime, Elections, Murder, aur Raajneeti ki news ko Bilkul REJECT (discard) kar do.
    2. Sirf Education, Government Schemes, Infrastructure, Agriculture, aur Development ki TOP 4-5 news chuno.
    3. Output STRICTLY VALID JSON format me hona chahiye (No Markdown formatting, No ```json tag).
    
    JSON SCHEMA OUTPUT:
    [
      {{
        "id": "news_01",
        "title": "Short Clean Headline in Hindi",
        "category": "Education / Govt Schemes / Infrastructure",
        "bullets": [
          "Point 1: Main update kya hai",
          "Point 2: Kisko fayda milega ya key details",
          "Point 3: BPSC/SSC exam ke hisaab se kyo important hai"
        ],
        "exam_tag": "🎯 BPSC TRE / BSSC Special",
        "date": "Today's Date"
      }}
    ]
    """
    
    # FIXED: Using latest supported model gemini-2.5-flash for google-genai SDK
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt
    )
    return response.text

if __name__ == "__main__":
    if not GOOGLE_KEY:
        print("❌ Error: GOOGLE_API_KEY environment variable not found!")
        exit(1)
        
    print("🔄 Scraping news from 3 official sources...")
    raw_news = fetch_raw_bihar_news()
    
    if raw_news:
        print("🧠 Processing news summary with Gemini AI...")
        ai_response = generate_app_summary_json(raw_news)
        
        # Cleanup Markdown formatting if present
        clean_json_str = ai_response.replace("```json", "").replace("```", "").strip()
        
        # Validate and write JSON file
        try:
            json_data = json.loads(clean_json_str)
            with open("bihar_news.json", "w", encoding="utf-8") as f:
                json.dump(json_data, f, ensure_ascii=False, indent=2)
            print("✅ bihar_news.json successfully updated with fresh news!")
        except Exception as e:
            print(f"❌ JSON Parsing Error: {e}\nRaw Output: {ai_response}")
    else:
        print("❌ No news data scraped to process.")
