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

def clean_html_text(text):
    """HTML tags ko clean text mein convert karta hai"""
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def remove_markdown_stars(data):
    """JSON ke andar se ** aur markdown symbols ko completely clean karta hai"""
    if isinstance(data, dict):
        return {k: remove_markdown_stars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [remove_markdown_stars(item) for item in data]
    elif isinstance(data, str):
        return data.replace("**", "").replace("##", "").strip()
    return data

# -------------------------------------------------------------
# 2. MULTI-SOURCE HYBRID JOB SCRAPER
# -------------------------------------------------------------
def fetch_raw_jobs():
    """Scrapes raw job updates from FreeJobAlert, SarkariResult & BiharJobPortal"""
    job_records = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    # SOURCE A: FreeJobAlert Multi-Feeds (State, SSC, Railway, Banking, All-India)
    fja_feeds = [
        "https://www.freejobalert.com/feed/",
        "https://www.freejobalert.com/state-government-jobs/feed/",
        "https://www.freejobalert.com/ssc-job-notifications/feed/",
        "https://www.freejobalert.com/railway-jobs/feed/",
        "https://www.freejobalert.com/bank-jobs/feed/"
    ]
    for feed_url in fja_feeds:
        try:
            res = requests.get(feed_url, headers=headers, timeout=12, verify=False)
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                for item in soup.find_all('item')[:25]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                    content = clean_html_text(content_node.text) if content_node is not None else ""
                    if title:
                        job_records.append(f"[FreeJobAlert Feed] Title: {title} | Content: {content[:1500]}")
            print(f"✅ FreeJobAlert Feed Parsed: {feed_url}")
        except Exception as e:
            print(f"⚠️ Error FJA Feed ({feed_url}): {e}")

    # SOURCE B: Sarkari Result Live Updates
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            boxes = soup.find_all('div', id=re.compile(r'box|post'))
            for box in boxes:
                for link in box.find_all('a')[:25]:
                    t = link.text.strip()
                    if t and len(t) > 6:
                        job_records.append(f"[SarkariResult Live Box] Title: {t}")
            print("✅ SarkariResult Live Posts Scraped!")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    # SOURCE C: Bihar Job Portal Updates
    try:
        bjp_url = "https://biharjobportal.com/"
        res = requests.get(bjp_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            posts = [a.text.strip() for a in soup.find_all('a') if len(a.text.strip()) > 10][:25]
            for p in posts:
                job_records.append(f"[BiharJobPortal Post] Title: {p}")
            print("✅ BiharJobPortal Posts Scraped!")
    except Exception as e:
        print(f"⚠️ Error BiharJobPortal Scraping: {e}")

    return "\n".join(job_records)

# -------------------------------------------------------------
# 3. GROQ AI EXECUTOR
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


def generate_job_summary(raw_text):
    today_str = datetime.now().strftime("%d %b %Y")
    truncated_raw = raw_text[:14000]

    prompt = f"""
    You are an expert Government Recruitment Portal Data Editor.
    Below is raw text scraped from FreeJobAlert, SarkariResult, and BiharJobPortal:

    RAW TEXT:
    {truncated_raw}

    HIGH QUANTITY & COMPLETENESS INSTRUCTIONS:
    1. EXTRACT ALL VALID JOBS: Generate AT LEAST 15 to 25 job entries in the 'latest_jobs' list. Do not stop early.
    2. ALLOWED JURISDICTIONS ONLY:
       - Bihar Govt Jobs: BPSC, BSSC, CSBC, BPSSC, Bihar Teacher, Patna High Court, Civil Court, Beltron, Health Dept.
       - Central Govt Jobs: SSC (CGL/CHSL/MTS/GD), Railways (RRB NTPC/Group D/ALP), Banking (IBPS/SBI/RBI), UPSC, Defence.
    3. STRICT REJECTION OF OTHER STATES: REJECT any job belonging to UP, MP, Rajasthan, Haryana, Delhi DSSSB, Maharashtra, etc.
    4. NO MARKDOWN SYMBOLS: DO NOT USE ANY ASTERISKS (**), BOLD SYMBOLS, OR MARKDOWN IN ANY TEXT FIELD. Keep text strictly plain.
    5. FIELD COMPLETENESS:
       - Provide detailed Educational Qualification.
       - Provide category-wise Application Fee (e.g. "General/OBC: ₹600 | SC/ST/Female: ₹150"). If exact fee is not in text, write "As per Official Notification".
       - Provide Age Limit with relaxation.
    6. Set "apply_url" to "https://www.mocktester.online" for ALL items.

    JSON SCHEMA OUTPUT (Return EXACTLY this structure):
    {{
      "latest_jobs": [
        {{
          "id": "job_01",
          "title": "Full Official Recruitment Title 2026",
          "organization": "Recruitment Body (e.g., BPSC / BSSC / SSC / RRB / IBPS)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Specific Post Name",
          "total_vacancies": "Posts Count e.g. 1,957 Posts or Various Posts",
          "qualification": "Full Detailed Educational Qualification Criteria",
          "age_limit": "Min & Max Age Criteria with Relaxation",
          "application_fee": "Detailed Fee Breakdown e.g. General: ₹600 | SC/ST: ₹150",
          "start_date": "Exact Start Date e.g. 28 Aug 2026 or Online Active",
          "last_date": "Exact Last Date e.g. 30 Sep 2026",
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
          "exam_date": "Exam Date / CBT Schedule",
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
# 4. PYTHON POST-PROCESSING SMART FILTER
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
    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "")
        org = job.get("organization", "")

        if is_other_state(title, org):
            print(f"❌ Dropped job (Other state): {title}")
            continue

        if not title or len(title) < 5:
            print(f"❌ Dropped job (Invalid title): {title}")
            continue

        clean_latest_jobs.append(job)

    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")
        if not is_other_state(title, org) and title:
            clean_admit_cards.append(card)

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
# 5. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    print("🔄 Starting Bihar & Central Jobs Scraper Pipeline...\n")

    raw_jobs = fetch_raw_jobs()
    if raw_jobs:
        ai_jobs = generate_job_summary(raw_jobs)
        if ai_jobs:
            try:
                parsed_jobs = json.loads(ai_jobs.strip())
                parsed_jobs = filter_valid_jobs(parsed_jobs)
                parsed_jobs = remove_markdown_stars(parsed_jobs) # Automatically clean all ** stars
                
                has_data = (
                    len(parsed_jobs.get("latest_jobs", [])) > 0 or
                    len(parsed_jobs.get("admit_cards", [])) > 0 or
                    len(parsed_jobs.get("results", [])) > 0
                )
                if has_data:
                    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_jobs, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_jobs.json successfully updated! Jobs: {len(parsed_jobs.get('latest_jobs', []))} | "
                          f"Admit Cards: {len(parsed_jobs.get('admit_cards', []))} | "
                          f"Results: {len(parsed_jobs.get('results', []))}")
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 valid job notifications found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Jobs Pipeline Execution Finished Successfully!")
