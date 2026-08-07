import os
import json
import time
import re
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
            return (target_dt - timedelta(days=1)) <= pub_dt <= (target_dt + timedelta(days=1))
    except Exception as e:
        print(f"Date parsing error: {e}")
    return True

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. SCRAPING FUNCTIONS (NEWS - UNCHANGED & PRESERVED)
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    news_titles = []
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
                    if count >= 20: break
            print("✅ Google News Bihar RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Google News Bihar: {e}")

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
                    if count >= 15: break
            print("✅ Prabhat Khabar Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Prabhat Khabar: {e}")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    national_titles = []
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
                        national_titles.append(f"[Google Central] Title: {title.strip()} | Summary: {desc[:200]}")
        except Exception as e:
            print(f"⚠️ Error Google National Query ({q}): {e}")
    print("✅ Google Central Multi-Queries fetched successfully!")

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
# 3. DIRECT FULL-PAGE & FULL-FEED FREEJOBALERT SCRAPER
# -------------------------------------------------------------
def fetch_raw_jobs():
    """Scrapes FULL FreeJobAlert Bihar Page, Full RSS Encoded Feeds & Live Tables"""
    job_notices = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    # Source 1: Direct FreeJobAlert Bihar Government Jobs Full Page Scanning
    try:
        fja_bihar_url = "https://www.freejobalert.com/bihar-government-jobs/"
        res = requests.get(fja_bihar_url, headers=headers, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            # Parse Job Tables directly
            tables = soup.find_all("table")
            for table in tables:
                rows = table.find_all("tr")
                for row in rows[1:30]:  # Scan top rows with full details
                    text = clean_html_text(row.text)
                    if text and len(text) > 15:
                        job_notices.append(f"[FreeJobAlert Bihar Page Table Row] {text}")
            print("✅ Direct FreeJobAlert Bihar Page Scraped Successfully!")
    except Exception as e:
        print(f"⚠️ Error FreeJobAlert Bihar Page: {e}")

    # Source 2: Direct FreeJobAlert State Govt Full RSS Feed (Full Uncut Encoded Content)
    feed_urls = [
        "https://www.freejobalert.com/state-government-jobs/feed/",
        "https://www.freejobalert.com/feed/"
    ]
    for feed_url in feed_urls:
        try:
            res = requests.get(feed_url, headers=headers, timeout=15, verify=False)
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                for item in soup.find_all('item')[:30]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                    content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                    content_encoded = clean_html_text(content_node.text) if content_node is not None else ""
                    
                    full_text = f"{desc} {content_encoded}".strip()
                    if title and ("Bihar" in title or "BPSC" in title or "BSSC" in title or "SSC" in title or "Railway" in title or "RRB" in title or "IBPS" in title or "UPSC" in title or "Bank" in title or "Court" in title or "CSBC" in title):
                        job_notices.append(f"[FreeJobAlert Full Feed Entry] Title: {title} | Full Content: {full_text}")
                print(f"✅ FreeJobAlert Feed Scraped Successfully ({feed_url})!")
        except Exception as e:
            print(f"⚠️ Error FreeJobAlert Feed ({feed_url}): {e}")

    # Source 3: SarkariResult Live Updates
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            boxes = soup.find_all('div', id=re.compile(r'box|post'))
            for box in boxes:
                for link in box.find_all('a')[:20]:
                    title = link.text.strip()
                    if title and len(title) > 8:
                        job_notices.append(f"[SarkariResult Entry] Title: {title}")
            print("✅ SarkariResult Live Updates fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    return "\n".join(job_notices)

# -------------------------------------------------------------
# 4. GROQ AI EXECUTOR
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
    truncated_raw = raw_text[:6000]
    scope_name = "India National Level" if is_national else "Bihar State Level"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"
    
    prompt = f"""
    Summarize exam-relevant current affairs for {scope_name} into JSON format under 'news_cards'.
    Titles and Bullets MUST be in Hinglish. Each card must have exactly 3 factual bullets.
    
    Raw Text: {truncated_raw}
    
    JSON Schema:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Title in Hinglish",
          "category": "Category",
          "bullets": ["Bullet 1", "Bullet 2", "Bullet 3"],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    return call_groq_safe(prompt, system_role="Senior Current Affairs Editor")


def generate_job_summary(raw_text):
    today_str = datetime.now().strftime("%d %b %Y")
    truncated_raw = raw_text[:8000]

    prompt = f"""
    You are an expert Government Recruitment Portal Data Editor for FreeJobAlert & Sarkari Result.
    Extract all Bihar Govt Jobs & Central Govt Jobs (SSC, Railway, Banking, UPSC, Defence) from the scraped raw text into structured JSON.

    RAW TEXT:
    {truncated_raw}

    RULES:
    1. WRITE EVERYTHING IN 100% PURE ENGLISH ONLY.
    2. REJECT ANY OTHER STATE JOBS (REJECT UP, MP, Rajasthan, Haryana, Delhi, Maharashtra, etc.).
    3. INCLUDE BOTH: Newly Announced Jobs AND Currently Active/Live Jobs (where form submission is open).
    4. Extract complete details: start_date, last_date, total_vacancies, qualification, application_fee, age_limit, pay_scale.
    5. If exact fee or vacancies are not explicitly stated in the text, write "As per Official Rules" or "Various Posts" instead of empty string.
    6. Always set "apply_url" to "https://www.mocktester.online".

    JSON SCHEMA OUTPUT:
    {{
      "latest_jobs": [
        {{
          "id": "job_01",
          "title": "Full Official Recruitment Title 2026",
          "organization": "Recruitment Body (e.g., BPSC / BSSC / SSC / RRB)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Posts Count e.g. 1,957 Posts or Various Posts",
          "qualification": "Full Eligibility criteria",
          "age_limit": "Age criteria",
          "pay_scale": "Pay scale or Level",
          "application_fee": "Fee details e.g. General: ₹600 | SC/ST: ₹150 or As per Rules",
          "selection_process": "Selection steps",
          "start_date": "Start Date e.g. 28 Aug 2026 or Online Active",
          "last_date": "Last Date e.g. 30 Sep 2026",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🔥 Govt Job Alert",
          "date": "{today_str}"
        }}
      ],
      "admit_cards": [
        {{
          "id": "admit_01",
          "title": "Official Admit Card Title",
          "organization": "Recruitment Body Name",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts",
          "exam_date": "Exam Date",
          "status": "Admit Card Released",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🎫 Hall Ticket",
          "date": "{today_str}"
        }}
      ],
      "results": [
        {{
          "id": "result_01",
          "title": "Official Result Title",
          "organization": "Recruitment Body Name",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts",
          "result_status": "Merit List / Result Declared",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🏆 Result",
          "date": "{today_str}"
        }}
      ]
    }}
    """
    return call_groq_safe(prompt, system_role="Government Recruitment Data Editor")

# -------------------------------------------------------------
# 5. PYTHON POST-PROCESSING SMART FILTER
# -------------------------------------------------------------
STATE_BLACKLIST = [
    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "delhi govt", "maharashtra", "mpsc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc"
]

def is_other_state(title, org):
    combined = f"{title} {org}".lower()
    return any(state in combined for state in STATE_BLACKLIST)

def filter_valid_jobs(parsed_jobs):
    """Smart Python Filter: Keeps valid Bihar + Central Jobs without over-rejecting"""
    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "")
        org = job.get("organization", "")

        # Rule 1: Other state check
        if is_other_state(title, org):
            print(f"❌ Dropped job (Other state): {title}")
            continue

        # Rule 2: Title must be present
        if not title or len(title) < 5:
            print(f"❌ Dropped job (Invalid title): {title}")
            continue

        clean_latest_jobs.append(job)

    # Filter Admit Cards
    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")
        if not is_other_state(title, org) and title:
            clean_admit_cards.append(card)

    # Filter Results
    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "")
        org = res_item.get("organization", "")
        if not is_other_state(title, org) and title:
            clean_results.append(res_item)

    parsed_jobs["latest_jobs"] = clean_latest_jobs
    parsed_jobs["admit_cards"] = clean_admit_cards
    parsed_jobs["results"] = clean_results
    return parsed_jobs

# -------------------------------------------------------------
# 6. MASTER HISTORY APPEND FUNCTIONS
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
# 7. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Complete Current Affairs & Jobs Pipeline ({date_str})...\n")

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

    print("\n------------------------------------\n")

    # === C. PROCESS BIHAR & CENTRAL JOBS ===
    print("💼 --- PROCESS BIHAR & CENTRAL JOBS ---")
    raw_jobs = fetch_raw_jobs()
    if raw_jobs:
        ai_jobs = generate_job_summary(raw_jobs)
        if ai_jobs:
            try:
                parsed_jobs = json.loads(ai_jobs.strip())
                parsed_jobs = filter_valid_jobs(parsed_jobs)
                
                has_data = (
                    len(parsed_jobs.get("latest_jobs", [])) > 0 or
                    len(parsed_jobs.get("admit_cards", [])) > 0 or
                    len(parsed_jobs.get("results", [])) > 0
                )
                if has_data:
                    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_jobs, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_jobs.json updated! Jobs: {len(parsed_jobs.get('latest_jobs', []))} | "
                          f"Admit Cards: {len(parsed_jobs.get('admit_cards', []))} | "
                          f"Results: {len(parsed_jobs.get('results', []))}")
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 job notifications found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Pipeline Execution Finished Successfully!")
