import os
import json
import time
import re
from datetime import datetime
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
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def remove_markdown_stars(data):
    if isinstance(data, dict):
        return {k: remove_markdown_stars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [remove_markdown_stars(item) for item in data]
    elif isinstance(data, str):
        return data.replace("**", "").replace("##", "").strip()
    return data

# -------------------------------------------------------------
# 2. DEEP INNER-PAGE SCRAPER (FETCHES EXACT FEES & QUALIFICATION)
# -------------------------------------------------------------
def fetch_raw_jobs():
    """Fetches full page content from SarkariResult Latest Jobs Page & FreeJobAlert Inner Pages"""
    job_records = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    # 1. SarkariResult Dedicated Latest Jobs Page & Detail Links
    try:
        sr_jobs_url = "https://www.sarkariresult.com/latestjob.php"
        res = requests.get(sr_jobs_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            post_div = soup.find('div', id='post') or soup.find('div', class_='post')
            if post_div:
                job_links = []
                for a in post_div.find_all('a', href=True):
                    href = a['href']
                    txt = a.text.strip()
                    if len(txt) > 8 and "sarkariresult.com" in href:
                        job_links.append((txt, href))
                
                print(f"✅ SarkariResult: Found {len(job_links[:12])} Active Job Links. Fetching inner pages for Fees & Dates...")
                
                # Scrape inner detail pages for top 12 links (where Fee, Age & Dates tables exist)
                for txt, link in job_links[:12]:
                    try:
                        inner_res = requests.get(link, headers=headers, timeout=8, verify=False)
                        if inner_res.status_code == 200:
                            inner_soup = BeautifulSoup(inner_res.content, "html.parser")
                            content_div = inner_soup.find('div', id='post') or inner_soup.find('body')
                            if content_div:
                                page_text = clean_html_text(content_div.text)
                                job_records.append(f"[SarkariResult Full Detail Page] Title: {txt} | Page Content: {page_text[:3000]}")
                        time.sleep(0.5)
                    except Exception as ie:
                        print(f"⚠️ Inner link fetch error ({link}): {ie}")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    # 2. FreeJobAlert Central Feeds (SSC, Railway, Banking, State)
    fja_feeds = [
        "https://www.freejobalert.com/ssc-job-notifications/feed/",
        "https://www.freejobalert.com/railway-jobs/feed/",
        "https://www.freejobalert.com/bank-jobs/feed/",
        "https://www.freejobalert.com/state-government-jobs/feed/"
    ]
    for feed_url in fja_feeds:
        try:
            res = requests.get(feed_url, headers=headers, timeout=12, verify=False)
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                for item in soup.find_all('item')[:15]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                    content = clean_html_text(content_node.text) if content_node is not None else ""
                    if title:
                        job_records.append(f"[FreeJobAlert Central Feed] Title: {title} | Content: {content[:2000]}")
            print(f"✅ FreeJobAlert Feed Parsed: {feed_url}")
        except Exception as e:
            print(f"⚠️ Error FJA Feed ({feed_url}): {e}")

    # 3. Bihar Job Portal Updates
    try:
        bjp_url = "https://biharjobportal.com/"
        res = requests.get(bjp_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            posts = [a.text.strip() for a in soup.find_all('a') if len(a.text.strip()) > 10][:20]
            for p in posts:
                job_records.append(f"[BiharJobPortal Entry] Title: {p}")
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
    truncated_raw = raw_text[:16000]

    prompt = f"""
    You are an expert Government Recruitment Portal Data Editor.
    Extract Bihar State Govt & Central Govt Recruitment Jobs, Admit Cards, and Results from the scraped raw text into structured JSON.

    RAW TEXT (Includes full detail page text with Application Fee tables, Dates, and Qualification tables):
    {truncated_raw}

    STRICT INSTRUCTIONS:
    1. BALANCE BIHAR & CENTRAL JOBS: Ensure a strong mix of both Bihar Govt Jobs (BPSC, BSSC, BPSSC, CSBC, Bihar Teacher, Patna High Court, Beltron) AND Central Govt Jobs (SSC CGL/CHSL/MTS/GD, Railways RRB NTPC/Group D/ALP, Banking IBPS/SBI, UPSC, Defence Agniveer/CAPF, Postal Circle).
    2. REAL APPLICATION FEE EXTRACTION: Read the inner page text carefully and extract the ACTUAL category-wise Application Fee (e.g. "General / OBC / EWS: ₹500 | SC / ST / PH / Female: ₹250"). Do NOT write "As per notification" if numbers or fee details are present in the raw text!
    3. STRICT REJECTION OF OTHER STATES: Reject UP, MP, Rajasthan, Haryana, Delhi Govt, Maharashtra, Tamil Nadu, Andhra Pradesh, Telangana, Karnataka, Kerala, Gujarat, West Bengal, Odisha, Assam, etc.
    4. REJECT NON-JOB NOTICES: Reject College Admissions, Counselling Schedules, Entrance Tests (TANCET, CET, NEET), School/University news.
    5. REJECT APPRENTICE & MBBS DOCTOR POSTS: Do NOT include Trade Apprentice or MBBS/Doctor/Medical Officer posts.
    6. MINIMUM 50 VACANCIES: Only include recruitments with 50+ vacancies or 'Various Posts'.
    7. NO MARKDOWN SYMBOLS: Plain text only, no asterisks (**).
    8. Set "apply_url" to "https://www.mocktester.online" for ALL items.

    JSON SCHEMA OUTPUT:
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
          "application_fee": "Exact Category-Wise Fee Breakdown from text (e.g. General/OBC: ₹500 | SC/ST/Female: ₹125)",
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
          "title": "Official Admit Card Title 2026",
          "organization": "Recruitment Body Name (e.g. SSC / RRB / BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts or Various Posts",
          "exam_date": "Exam Date or CBT Schedule",
          "status": "Admit Card Released",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🎫 Hall Ticket",
          "date": "{today_str}"
        }}
      ],
      "results": [
        {{
          "id": "result_01",
          "title": "Official Result Title 2026",
          "organization": "Recruitment Body Name (e.g. SSC / RRB / BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts or Various Posts",
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
# 4. PYTHON POST-PROCESSING SMART FILTER & DEDUPLICATION
# -------------------------------------------------------------
REJECT_KEYWORDS = [
    # Other States & Specific Boards
    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "maharashtra", "mpsc", "madc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc",
    "tamil nadu", "tnpsc", "tancet", "andhra pradesh", "appsc", "narasapuram",
    "telangana", "tspsc", "kerala", "kpsc", "karnataka", "odisha", "opsc",

    # Non-Job Admissions & Counselling
    "counselling", "allotment", "admission", "entrance test", "seat allotment",

    # Apprentice & Medical Officer Filters
    "apprentice", "apprenticeship", "mbbs", "medical officer", "specialist medical officer"
]

def is_invalid_job(title, org, post_name, qualification):
    combined = f"{title} {org} {post_name} {qualification}".lower()
    return any(bad_word in combined for bad_word in REJECT_KEYWORDS)

def is_vacancy_less_than_50(vacancies_str):
    if not vacancies_str:
        return False
    nums = re.findall(r'\b\d+\b', vacancies_str)
    if nums:
        count = int(nums[0])
        if count < 50:
            return True
    return False

def simplify_title(title):
    clean = re.sub(r'[^a-zA-Z0-9]', '', title.lower())
    return clean[:30]

def filter_valid_jobs(parsed_jobs):
    seen_titles = set()

    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "")
        org = job.get("organization", "")
        post_name = job.get("post_name", "")
        qual = job.get("qualification", "")
        vacancies = job.get("total_vacancies", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            print(f"🔄 Dropped Duplicate Job: {title}")
            continue

        if is_invalid_job(title, org, post_name, qual):
            print(f"❌ Dropped (Keyword/State/Apprentice/Doctor Filter): {title}")
            continue

        if is_vacancy_less_than_50(vacancies):
            print(f"❌ Dropped (Vacancies < 50): {title} ({vacancies})")
            continue

        seen_titles.add(simple_t)
        clean_latest_jobs.append(job)

    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")
        post_name = card.get("post_name", "")
        qual = card.get("qualification", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_job(title, org, post_name, qual):
            continue

        seen_titles.add(simple_t)
        clean_admit_cards.append(card)

    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "")
        org = res_item.get("organization", "")
        post_name = res_item.get("post_name", "")
        qual = res_item.get("qualification", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_job(title, org, post_name, qual):
            continue

        seen_titles.add(simple_t)
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
                parsed_jobs = remove_markdown_stars(parsed_jobs)
                
                has_data = (
                    len(parsed_jobs.get("latest_jobs", [])) > 0 or
                    len(parsed_jobs.get("admit_cards", [])) > 0 or
                    len(parsed_jobs.get("results", [])) > 0
                )
                if has_data:
                    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_jobs, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_jobs.json successfully updated!\n"
                          f"👉 Jobs Count: {len(parsed_jobs.get('latest_jobs', []))}\n"
                          f"👉 Admit Cards Count: {len(parsed_jobs.get('admit_cards', []))}\n"
                          f"👉 Results Count: {len(parsed_jobs.get('results', []))}")
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 valid job notifications found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Jobs Pipeline Execution Finished Successfully!")
