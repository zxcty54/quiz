import os
import json
import time
import re
from datetime import datetime, timedelta
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

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

# Output JSON Filenames
BIHAR_NEWS_JSON = "bihar_news.json"
NATIONAL_NEWS_JSON = "national_news.json"
BIHAR_HISTORY_JSON = "all_bihar_news_history.json"
NATIONAL_HISTORY_JSON = "all_national_news_history.json"

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_yesterday_news(pub_date_str, target_dt):
    if not pub_date_str:
        return True
    try:
        # Match basic date formats
        d_match = re.search(r'\d{1,2}\s+[A-Za-z]{3}\s+\d{4}', pub_date_str)
        if d_match:
            pub_dt = datetime.strptime(d_match.group(0), "%d %b %Y").date()
            return pub_dt >= (target_dt - timedelta(days=2)).date()
    except Exception:
        pass
    return True

# -------------------------------------------------------------
# 2. RAW NEWS SCRAPERS (BIHAR & NATIONAL)
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    news_titles = []
    
    # Source A: Google News Bihar RSS
    try:
        g_url = "https://news.google.com/rss/search?q=Bihar+News&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(g_url, impersonate="chrome", timeout=15, verify=False)
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
        print(f"⚠️ Error Google News Bihar: {e}")

    # Source B: CMO Bihar Press Releases
    try:
        cmo_url = "https://cm.bihar.gov.in/users/home.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr')[:15]:
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = cols[1].text.strip()
                    if title and len(title) > 10:
                        news_titles.append(f"[CMO Bihar] {title}")
            print("✅ CMO Bihar Press Releases fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error CMO Bihar: {e}")

    # Source C: IPRD Bihar
    try:
        iprd_url = "https://iprd.bihar.gov.in/"
        res = requests.get(iprd_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            count = 0
            for a in soup.find_all('a', href=True):
                title = a.text.strip()
                if title and len(title) > 15:
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 12:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error IPRD Bihar: {e}")

    # Source D: Prabhat Khabar Bihar
    try:
        pk_url = "https://www.prabhatkhabar.com/state/bihar/feed"
        res = requests.get(pk_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            count = 0
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Prabhat Khabar] {title.strip()}")
                    count += 1
                    if count >= 15:
                        break
            print("✅ Prabhat Khabar Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error Prabhat Khabar: {e}")

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
            for item in soup.find_all('item')[:15]:
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
            for item in soup.find_all('item')[:15]:
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
            for item in soup.find_all('item')[:15]:
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
def call_groq_safe(prompt, system_role="You are a JSON generator assistant."):
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
                response_format={"type": "json_object"},
                max_tokens=8000,
                timeout=120,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] error: {e}. Trying fallback...")
            time.sleep(2)
    return ""

def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Fact-Based Detailed Hinglish JSON summary banwata hai"""
    truncated_raw = raw_text[:20000]

    if is_national:
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
        cat_tag = "National News"
    else:
        rejection_rules = """
        STRICT REJECTION & DISCARD RULES (CRITICAL):
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT any Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
        2. REJECT ALL routine administrative instructions, CM directives ("nirdesh diye"), smooth traffic arrangements, RERA routine meetings, political speeches, crime, and accidents.
        3. STRICT INFRASTRUCTURE FILTER:
           - For "Infrastructure & Projects", REJECT small/routine road repairs or local city traffic directives.
           - ACCEPT ONLY MAJOR MEGA-INFRASTRUCTURE PROJECTS that make national/state headlines (e.g., Metro lines, Mega Expressways, Major Ganga Bridges, Airports, Power Plants, or Mega Investment projects).
        """
        bullet_rules = """
        EXAMINER FOCUS BULLET RULES (BIHAR):
        - Bullet 1 (Core Fact): Core event, Nodal Department, District/Venue in Hinglish.
        - Bullet 2 (Exam Numerical Facts): Exact budget allocation, target year, capacities, lengths, or beneficiary numbers.
        - Bullet 3 (Strategic Purpose): Main objective or strategic importance for Bihar in Hinglish.
        """
        cat_tag = "Bihar News"

    prompt = f"""
    You are an expert Exam Current Affairs Editor.
    Below is raw news text scraped for {cat_tag}. Process it into structured Hinglish JSON.

    RAW TEXT:
    {truncated_raw}

    {rejection_rules}

    {bullet_rules}

    DEDUPLICATION & QUANTITY RULE:
    - MERGE duplicate reports of the same event into ONE single card. No duplicate cards allowed.
    - GENERATE ALL VALID CARDS: Extract ALL unique qualifying news items from the input text (target generating at least 8-15 high-yield cards if raw data exists).

    LANGUAGE & BULLETS:
    - WRITE ALL TITLES AND BULLETS IN **HINGLISH** (Hindi written in Roman English Script).
    - Do NOT use markdown stars (**) in strings.

    JSON SCHEMA OUTPUT:
    {{
      "latest_news": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Title",
          "category": "{cat_tag}",
          "summary_bullets": [
            "Bullet 1 text",
            "Bullet 2 text",
            "Bullet 3 text"
          ],
          "date_added": "{target_date_str}"
        }}
      ]
    }}
    """
    return call_groq_safe(prompt, system_role="Exam Current Affairs Data Editor")

# -------------------------------------------------------------
# 4. HISTORY APPEND & DEDUPLICATION
# -------------------------------------------------------------
def update_news_history_file(history_filename, new_items):
    existing_history = []
    if os.path.exists(history_filename):
        try:
            with open(history_filename, "r", encoding="utf-8") as f:
                data = json.load(f)
                existing_history = data.get("history", [])
        except Exception as e:
            print(f"⚠️ Warning reading history file {history_filename}: {e}")

    existing_titles = {item.get("title", "").lower().strip() for item in existing_history if item.get("title")}
    
    appended_count = 0
    for item in new_items:
        clean_t = item.get("title", "").lower().strip()
        if clean_t and clean_t not in existing_titles:
            existing_history.insert(0, item)
            existing_titles.add(clean_t)
            appended_count += 1

    existing_history = existing_history[:500]

    history_payload = {
        "status": "success",
        "total_history_count": len(existing_history),
        "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "history": existing_history
    }

    with open(history_filename, "w", encoding="utf-8") as f:
        json.dump(history_payload, f, ensure_ascii=False, indent=2)

    print(f"📦 History Updated '{history_filename}': +{appended_count} new entries (Total: {len(existing_history)})")

# -------------------------------------------------------------
# 5. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
def main():
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)

    target_dt = datetime.now()
    target_date_str = target_dt.strftime("%d %b %Y")

    print("🚀 STARTING HIGH-YIELD NEWS PIPELINE...\n")

    # 1. BIHAR NEWS PROCESSING
    print("📍 --- Processing Bihar Current Affairs ---")
    raw_bihar = fetch_raw_bihar_news(target_dt)
    if raw_bihar:
        ai_res_bihar = generate_clean_summary(raw_bihar, target_date_str, is_national=False)
        if ai_res_bihar:
            try:
                parsed_b = json.loads(ai_res_bihar.strip())
                bihar_items = parsed_b.get("latest_news", [])
                
                with open(BIHAR_NEWS_JSON, "w", encoding="utf-8") as f:
                    json.dump({"status": "success", "count": len(bihar_items), "latest_news": bihar_items}, f, ensure_ascii=False, indent=2)
                print(f"✅ Saved '{BIHAR_NEWS_JSON}' ({len(bihar_items)} items)")

                update_news_history_file(BIHAR_HISTORY_JSON, bihar_items)
            except Exception as e:
                print(f"❌ Bihar JSON Parsing Error: {e}")

    # 2. NATIONAL NEWS PROCESSING
    print("\n🇮🇳 --- Processing Pure National Current Affairs ---")
    raw_national = fetch_raw_national_news(target_dt)
    if raw_national:
        ai_res_national = generate_clean_summary(raw_national, target_date_str, is_national=True)
        if ai_res_national:
            try:
                parsed_n = json.loads(ai_res_national.strip())
                national_items = parsed_n.get("latest_news", [])

                with open(NATIONAL_NEWS_JSON, "w", encoding="utf-8") as f:
                    json.dump({"status": "success", "count": len(national_items), "latest_news": national_items}, f, ensure_ascii=False, indent=2)
                print(f"✅ Saved '{NATIONAL_NEWS_JSON}' ({len(national_items)} items)")

                update_news_history_file(NATIONAL_HISTORY_JSON, national_items)
            except Exception as e:
                print(f"❌ National JSON Parsing Error: {e}")

    print("\n🎉 ALL NEWS PIPELINES FINISHED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
