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

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

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
# 1b. GENERIC INNER-PAGE FULL-TEXT EXTRACTOR
# -------------------------------------------------------------
CONTENT_SELECTORS = [
    ("div", {"class": "entry-content"}),
    ("div", {"class": "td-post-content"}),
    ("div", {"class": "post-content"}),
    ("div", {"class": "article-content"}),
    ("div", {"class": "content-area"}),
    ("div", {"id": "post"}),
    ("div", {"id": "content"}),
    ("article", {}),
]

def fetch_inner_page_text(url, char_limit=3500, timeout=8):
    try:
        res = requests.get(url, headers=HEADERS, timeout=timeout, verify=False)
        if res.status_code != 200:
            return ""
        soup = BeautifulSoup(res.content, "html.parser")

        for tag in soup.find_all(['script', 'style', 'nav', 'footer', 'header', 'aside']):
            tag.decompose()

        for tag_name, attrs in CONTENT_SELECTORS:
            node = soup.find(tag_name, attrs=attrs) if attrs else soup.find(tag_name)
            if node:
                text = clean_html_text(str(node))
                if len(text) > 200:
                    return text[:char_limit]

        candidates = soup.find_all('div')
        if candidates:
            best = max(candidates, key=lambda d: len(d.get_text(strip=True)))
            text = clean_html_text(str(best))
            if len(text) > 200:
                return text[:char_limit]

        return clean_html_text(soup.get_text())[:char_limit]
    except Exception as e:
        print(f"⚠️ Inner page fetch failed ({url}): {e}")
        return ""

# -------------------------------------------------------------
# 2. STEP 1 & 2: MULTI-SOURCE & DEEP INNER PAGE SCRAPER
# -------------------------------------------------------------
def fetch_raw_jobs():
    job_records = []

    fja_feeds = [
        ("Central SSC Jobs", "https://www.freejobalert.com/ssc-job-notifications/feed/"),
        ("Central Railway Jobs", "https://www.freejobalert.com/railway-jobs/feed/"),
        ("Central Bank Jobs", "https://www.freejobalert.com/bank-jobs/feed/"),
        ("Central UPSC Jobs", "https://www.freejobalert.com/upsc-job-notifications/feed/"),
        ("Bihar State Govt Jobs", "https://www.freejobalert.com/state-government-jobs/feed/"),
        ("Admit Cards Feed", "https://www.freejobalert.com/admit-card/feed/"),
        ("Results Feed", "https://www.freejobalert.com/exam-result/feed/")
    ]

    MAX_INNER_FETCHES_PER_FEED = 10
    for category_name, feed_url in fja_feeds:
        try:
            res = requests.get(feed_url, headers=HEADERS, timeout=12, verify=False)
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                items = soup.find_all('item')[:15]
                fetched = 0
                for item in items:
                    title = item.find('title').text if item.find('title') is not None else ""
                    link_node = item.find('link')
                    link = link_node.text.strip() if link_node is not None else ""

                    content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                    rss_summary = clean_html_text(content_node.text) if content_node is not None else ""

                    if not title:
                        continue

                    full_text = rss_summary
                    if link and fetched < MAX_INNER_FETCHES_PER_FEED:
                        inner_text = fetch_inner_page_text(link, char_limit=3500)
                        if inner_text and len(inner_text) > len(rss_summary):
                            full_text = inner_text
                        fetched += 1
                        time.sleep(0.25)

                    job_records.append(
                        f"[{category_name}] Title: {title} | Source URL: {link} | Full Content: {full_text[:3500]}"
                    )
                print(f"✅ {category_name} Feed Scraped (deep inner-page: {fetched} pages)!")
        except Exception as e:
            print(f"⚠️ Error Feed ({category_name}): {e}")

    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=HEADERS, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")

            boxes = soup.find_all('div', id=re.compile(r'box|post')) or soup.find_all('div', class_=re.compile(r'box|post'))
            inner_fetch_count = 0
            for box in boxes:
                header = box.find(['h2', 'h3', 'div', 'b'])
                box_type = header.text.strip() if header else "General"

                for link in box.find_all('a', href=True)[:10]:
                    t = link.text.strip()
                    href = link['href']
                    if not t or len(t) <= 6:
                        continue

                    if "sarkariresult.com" in href and inner_fetch_count < 40:
                        inner_text = fetch_inner_page_text(href, char_limit=3000)
                        inner_fetch_count += 1
                        if inner_text:
                            job_records.append(
                                f"[SarkariResult Inner Page - {box_type}] Title: {t} | Page Text: {inner_text}"
                            )
                        else:
                            job_records.append(f"[SarkariResult Table - {box_type}] {t} | URL: {href}")
                        time.sleep(0.25)
                    else:
                        job_records.append(f"[SarkariResult Table - {box_type}] {t} | URL: {href}")

            print(f"✅ SarkariResult Deep Pages Scraped Successfully! ({inner_fetch_count} inner pages fetched)")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    return "\n".join(job_records)

# -------------------------------------------------------------
# 3. STEP 3: GROQ AI STRUCTURING & STRICT EXTRACTION
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
            finish_reason = response.choices[0].finish_reason
            if finish_reason == "length":
                print(f"⚠️ Model [{model_name}] response was CUT OFF (hit max_tokens). Trying next model...")
                continue
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] rate-limited/failed/timed-out: {e}. Trying fallback...")
            time.sleep(2)

    print("❌ All Groq models failed for this call.")
    return ""


def generate_job_summary(raw_text):
    today_str = datetime.now().strftime("%d %b %Y")
    truncated_raw = raw_text[:20000]

    prompt = f"""
    You are an expert Government Recruitment Data Editor for FreeJobAlert & SarkariResult.
    Below is raw text scraped from government job portals. Extract ONLY Govt Job Notifications, Govt Competitive Exam Admit Cards, and Govt Exam Results.

    RAW TEXT:
    {truncated_raw}

    STRICT REJECTION RULES (CRITICAL):
    1. STRICTLY REJECT ALL UNIVERSITY / COLLEGE EXAMS & ADMISSIONS:
       - REJECT any BA, BSc, BCom, MA, MSc, Semester Exams, University Merit Lists, University Results, College Admissions, Counselling Schedules.
       - ONLY include Competitive Exam Results (e.g. BPSC Result, SSC CGL Result, Railway NTPC Result, IBPS PO Result).
    2. STRICTLY REJECT SCHOLARSHIPS & YOJNAS:
       - REJECT Scholarship, Post Matric, NSP, Yojna, Scheme, Pension, Allowance.
    3. STRICTLY REJECT OTHER STATES:
       - INCLUDE ONLY: Bihar Govt Jobs/Exams AND Central Govt Jobs/Exams (SSC, Railways, IBPS/SBI, UPSC, Defence).
       - REJECT: UP, MP, Rajasthan, Haryana, Delhi Govt, Maharashtra, Tamil Nadu, AP, Telangana, Karnataka, Kerala, Gujarat, WB, Odisha, etc.
    4. REJECT APPRENTICE & MBBS DOCTOR POSTS:
       - REJECT Trade Apprentice, Graduate Apprentice, MBBS, Medical Officer, Dental Officer posts.

    DATA EXTRACTION RULES:
    - Populate all 3 arrays: 'latest_jobs', 'admit_cards', and 'results'.
    - Read the Application Fee tables and extract Category-wise fee breakdown (e.g. "General / OBC: ₹500 | SC / ST: ₹250").
    - If fee or qualification is not in the text, write "Refer Official Notification" instead of "Various".
    - Do NOT use markdown asterisks (**).
    - Set "apply_url" to "https://www.mocktester.online" for ALL items.

    JSON SCHEMA OUTPUT:
    {{
      "latest_jobs": [
        {{
          "id": "job_01",
          "title": "Full Official Recruitment Title 2026",
          "organization": "Recruitment Body (e.g. BPSC / BSSC / SSC / RRB / IBPS)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Specific Post Name",
          "total_vacancies": "Posts Count e.g. 1,957 Posts",
          "qualification": "Exact Educational Qualification Criteria",
          "age_limit": "Min & Max Age Criteria with Relaxation",
          "application_fee": "Category-Wise Application Fee Breakdown",
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
          "title": "Official Competitive Exam Admit Card Title 2026",
          "organization": "Recruitment Body Name (e.g. SSC / RRB / BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts or As per Rules",
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
          "title": "Official Competitive Exam Result Title 2026",
          "organization": "Recruitment Body Name (e.g. SSC / RRB / BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Total Posts or As per Rules",
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
# 4. STEP 4: PYTHON HARD FILTER & DEDUPLICATION
# -------------------------------------------------------------
REJECT_KEYWORDS = [
    # University, College & Academic Results (STRICTLY BLOCKED)
    "university", "college", "semester", "ba Part", "bsc ", "bcom", "ma ", "msc ", 
    "degree college", "annual exam", "admissions", "counselling", "allotment", "entrance test",

    # Non-Job Items (Scholarships, Yojnas)
    "scholarship", "post matric", "nsp scholarship", "yojna", "scheme", "pension",

    # Other States
    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "maharashtra", "mpsc", "madc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc",
    "tamil nadu", "tnpsc", "tancet", "andhra pradesh", "appsc", "narasapuram",
    "telangana", "tspsc", "kerala", "kpsc", "karnataka", "odisha", "opsc",

    # Apprentice & Doctors
    "apprentice", "apprenticeship", "mbbs", "medical officer", "specialist medical officer"
]

def is_invalid_item(title, org, post_name="", qualification=""):
    combined = f"{title} {org} {post_name} {qualification}".lower()
    return any(bad_word.lower() in combined for bad_word in REJECT_KEYWORDS)

def is_vacancy_less_than_50(vacancies_str):
    if not vacancies_str or "various" in vacancies_str.lower():
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

    # 1. Filter Jobs
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

        if is_invalid_item(title, org, post_name, qual):
            print(f"❌ Dropped (University/Scholarship/Other State): {title}")
            continue

        if is_vacancy_less_than_50(vacancies):
            print(f"❌ Dropped (Vacancies < 50): {title} ({vacancies})")
            continue

        seen_titles.add(simple_t)
        clean_latest_jobs.append(job)

    # 2. Filter Admit Cards (Check title and org ONLY so it doesn't drop empty qualification items)
    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_item(title, org):
            print(f"❌ Dropped Admit Card (University/Other State): {title}")
            continue

        seen_titles.add(simple_t)
        clean_admit_cards.append(card)

    # 3. Filter Results (Check title and org ONLY so it doesn't drop valid competitive results)
    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "")
        org = res_item.get("organization", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_item(title, org):
            print(f"❌ Dropped Result (University/Other State): {title}")
            continue

        seen_titles.add(simple_t)
        clean_results.append(res_item)

    parsed_jobs["latest_jobs"] = clean_latest_jobs
    parsed_jobs["admit_cards"] = clean_admit_cards
    parsed_jobs["results"] = clean_results
    return parsed_jobs

# -------------------------------------------------------------
# 5. STEP 5: MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)

    print("🔄 Starting Bihar & Central Jobs Scraper Pipeline...\n")

    raw_jobs = fetch_raw_jobs()
    print(f"\nℹ️ Total raw characters scraped (incl. inner pages): {len(raw_jobs)}\n")

    if raw_jobs:
        ai_jobs = generate_job_summary(raw_jobs)
        if ai_jobs:
            try:
                parsed_jobs = json.loads(ai_jobs.strip())

                print(f"ℹ️ AI returned before filtering -> Jobs: {len(parsed_jobs.get('latest_jobs', []))} | "
                      f"Admit Cards: {len(parsed_jobs.get('admit_cards', []))} | "
                      f"Results: {len(parsed_jobs.get('results', []))}")

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
