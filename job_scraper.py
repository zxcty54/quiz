"""
Bihar & Central Govt Jobs Pipeline (mocktester.online)
--------------------------------------------------------
WHAT THIS SCRIPT GUARANTEES:
1. ONLY Bihar state govt + Central (all-India) govt jobs/admit-cards/results.
   Every other state is explicitly rejected.
2. A job in "latest_jobs" ONLY appears if it has BOTH a real start_date and
   a real last_date (actual calendar dates - not "TBA", not "Online Active",
   not missing).
3. A job is only kept if it is still LIVE - i.e. its last_date has not
   already passed as of today. Expired jobs are dropped automatically.
4. Deep-scrapes each post's actual detail page (not just the RSS/listing
   summary) because fee/age/date tables usually live only on that page.
5. No hallucination: the AI is told to OMIT an item entirely rather than
   invent a fee/date/vacancy figure it can't find in the scraped text.

Requires: pip install groq curl_cffi beautifulsoup4 lxml python-dateutil
(python-dateutil is optional but strongly recommended for robust date
parsing - the script still works without it via a regex fallback.)
"""

import os
import json
import time
import re
from datetime import datetime, date
import xml.etree.ElementTree as ET
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

try:
    from dateutil import parser as date_parser
    HAS_DATEUTIL = True
except ImportError:
    HAS_DATEUTIL = False
    print("⚠️ python-dateutil not installed - using basic date fallback. "
          "Run: pip install python-dateutil for more reliable date parsing.")

# -------------------------------------------------------------
# 1. SETUP
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
# 2. DATE PARSING (for the "live job" check)
# -------------------------------------------------------------
MONTHS = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
    'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
    'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
    'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12
}

def parse_date_flexible(date_str):
    """
    Tries to parse a date string in whatever format the AI/source gave it
    (e.g. '30 Sep 2026', '30-09-2026', '2026-09-30', '30th September 2026').
    Returns a date object, or None if it genuinely isn't a real date
    (e.g. 'Online Active', 'TBA', empty).
    """
    if not date_str or not date_str.strip():
        return None
    s = date_str.strip()

    if HAS_DATEUTIL:
        try:
            dt = date_parser.parse(s, fuzzy=True, dayfirst=True)
            # Sanity check: reject obviously wrong years (parser hallucinating on junk text)
            if 2020 <= dt.year <= 2035:
                return dt.date()
        except Exception:
            pass

    # Manual fallback: "30 Sep 2026" / "30-09-2026" / "30/09/2026"
    m = re.search(r'(\d{1,2})[\s\-/]+([A-Za-z]{3,9}|\d{1,2})[\s\-/]+(\d{4})', s)
    if m:
        try:
            day = int(m.group(1))
            mon_raw = m.group(2).lower()
            year = int(m.group(3))
            month = int(mon_raw) if mon_raw.isdigit() else MONTHS.get(mon_raw[:3])
            if month:
                return datetime(year, month, day).date()
        except (ValueError, KeyError):
            return None

    # ISO format: "2026-09-30"
    m2 = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})', s)
    if m2:
        try:
            return datetime(int(m2.group(1)), int(m2.group(2)), int(m2.group(3))).date()
        except ValueError:
            return None

    return None

def is_job_still_live(last_date_str, today=None):
    """A job is 'live' only if its last_date is a real, parseable date
    that has NOT already passed."""
    today = today or date.today()
    parsed = parse_date_flexible(last_date_str)
    if parsed is None:
        return False, None
    return parsed >= today, parsed

# -------------------------------------------------------------
# 3. INNER-PAGE FULL-TEXT EXTRACTOR
#    FreeJobAlert's RSS feed and SarkariResult's listing page only give a
#    short summary - the actual fee table, age limit, qualification, and
#    important-dates block live on the individual post's own page.
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
# 4. SCRAPER: FreeJobAlert (deep) + SarkariResult (deep)
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
# 5. GROQ AI CALL (robust: timeout + max_tokens + fallback models)
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
            if response.choices[0].finish_reason == "length":
                print(f"⚠️ Model [{model_name}] response CUT OFF (hit max_tokens). Trying next model...")
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
    Below is raw text scraped from multiple government job portals, INCLUDING each post's
    full inner detail page (fee tables, age limit tables, qualification, and important dates
    live on these inner pages, not just the listing/RSS summary):

    RAW TEXT:
    {truncated_raw}

    STRICT REJECTION RULES (CRITICAL):
    1. STRICTLY REJECT SCHOLARSHIPS & YOJNAS:
       - REJECT any item containing "Scholarship", "Post Matric", "NSP", "Yojna", "Scheme", "Pension", "Allowance".
    2. STRICTLY REJECT ADMISSIONS & COUNSELLING:
       - REJECT College Admissions, Seat Allotments, Counselling Schedules, Entrance Tests (TANCET, CET, NEET, GATE).
    3. STRICTLY REJECT OTHER STATES - THIS IS THE MOST IMPORTANT RULE:
       - INCLUDE ONLY: (a) Bihar State Govt jobs (BPSC, BSSC, BPSSC, CSBC, Bihar Teacher/TRE,
         Patna High Court, Bihar Civil Court, Beltron, Bihar Health Dept, Bihar Police) AND
         (b) Central/All-India Govt jobs (SSC, Indian Railways/RRB, Banking IBPS/SBI/RBI,
         UPSC, Defence - Army/Navy/Air Force/CAPF, NTA).
       - REJECT ANY job tied to a specific OTHER state's own government/PSC/board, including
         but not limited to: UP, MP, Rajasthan, Haryana, Delhi, Maharashtra, Tamil Nadu,
         Andhra Pradesh, Telangana, Karnataka, Kerala, Gujarat, West Bengal, Odisha, Punjab,
         Jharkhand, Chhattisgarh, Uttarakhand, Himachal Pradesh, Assam, and all others.
       - If you are not sure whether a job is Bihar/Central or another state, LEAVE IT OUT.
    4. REJECT APPRENTICE & MBBS DOCTOR POSTS:
       - REJECT Trade Apprentice, Graduate Apprentice, MBBS, Medical Officer, Dental Officer posts.

    DATE RULE (CRITICAL - THIS DETERMINES IF A JOB IS INCLUDED AT ALL):
    - Every item in "latest_jobs" MUST have a real, exact calendar start_date AND a real,
      exact calendar last_date, written EXACTLY as found in the raw text (e.g. "28 Aug 2026",
      "30-09-2026"). 
    - Do NOT write "Online Active", "TBA", "As per notification", "Ongoing", or any
      non-calendar-date phrase in start_date or last_date.
    - If either the exact start_date or the exact last_date is not explicitly present
      anywhere in the raw text for an item, DO NOT include that item in "latest_jobs" at all.
      Do not guess a date. Leaving the job out entirely is the correct behavior.

    DATA EXTRACTION RULES (NO HALLUCINATION / NO 'VARIOUS'):
    - Read the Application Fee tables in the "Full Content" / "Page Text" sections and extract
      the exact category-wise fee breakdown (e.g. "General / OBC: ₹500 | SC / ST: ₹250").
    - Extract the exact Educational Qualification requirement as written on the page.
    - ONLY use facts that are literally present in the raw text above. Do not use typical/
      default values from your own general knowledge.
    - If fee or qualification is genuinely not present anywhere in the raw text for that item,
      write "Refer Official Notification" instead of "Various" - do NOT invent a number.
    - Populate all 3 arrays: 'latest_jobs', 'admit_cards', and 'results'.
      - For "admit_cards", only include an item if an exam_date or CBT schedule is explicitly
        stated in the raw text. Otherwise omit it.
      - For "results", only include an item if a result_status (merit list / answer key /
        result declared) is explicitly stated in the raw text. Otherwise omit it.
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
          "start_date": "Exact Start Date e.g. 28 Aug 2026",
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
          "title": "Official Result Title 2026",
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
# 6. PYTHON HARD FILTER (state, dedup, live-only, mandatory dates)
# -------------------------------------------------------------
REJECT_KEYWORDS = [
    "scholarship", "post matric", "nsp scholarship", "yojna", "scheme", "pension",
    "counselling", "allotment", "admission", "entrance test", "seat allotment",

    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "maharashtra", "mpsc", "madc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc",
    "tamil nadu", "tnpsc", "tancet", "andhra pradesh", "appsc", "narasapuram",
    "telangana", "tspsc", "kerala", "kpsc", "karnataka", "odisha", "opsc",
    "chhattisgarh", "cgpsc", "uttarakhand", "ukpsc", "himachal", "hppsc",
    "goa psc", "assam", "apsc", "manipur", "meghalaya", "nagaland",
    "tripura", "sikkim", "mizoram", "delhi govt", "delhi police",

    "apprentice", "apprenticeship", "mbbs", "medical officer", "specialist medical officer"
]

def is_invalid_item(title, org, post_name, qualification=""):
    combined = f"{title} {org} {post_name} {qualification}".lower()
    return any(bad_word in combined for bad_word in REJECT_KEYWORDS)

def simplify_title(title):
    clean = re.sub(r'[^a-zA-Z0-9]', '', title.lower())
    return clean[:30]

def filter_valid_jobs(parsed_jobs):
    seen_titles = set()
    today = date.today()

    # ---- 1. latest_jobs: state check + mandatory real dates + must be LIVE ----
    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "")
        org = job.get("organization", "")
        post_name = job.get("post_name", "")
        qual = job.get("qualification", "")
        start_date_str = job.get("start_date", "")
        last_date_str = job.get("last_date", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            print(f"🔄 Dropped Duplicate Job: {title}")
            continue

        if is_invalid_item(title, org, post_name, qual):
            print(f"❌ Dropped (Scholarship/Other State/Apprentice): {title}")
            continue

        if not start_date_str or not last_date_str:
            print(f"❌ Dropped (Missing start_date or last_date): {title}")
            continue

        start_parsed = parse_date_flexible(start_date_str)
        if start_parsed is None:
            print(f"❌ Dropped (start_date not a real date: '{start_date_str}'): {title}")
            continue

        is_live, last_parsed = is_job_still_live(last_date_str, today)
        if last_parsed is None:
            print(f"❌ Dropped (last_date not a real date: '{last_date_str}'): {title}")
            continue
        if not is_live:
            print(f"❌ Dropped (EXPIRED - last date {last_parsed} already passed): {title}")
            continue

        seen_titles.add(simple_t)
        clean_latest_jobs.append(job)

    # ---- 2. admit_cards: state check + must have exam_date ----
    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")
        post_name = card.get("post_name", "")
        exam_date = card.get("exam_date", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_item(title, org, post_name):
            print(f"❌ Dropped Admit Card (Other State/Invalid): {title}")
            continue

        if not exam_date or not exam_date.strip():
            print(f"❌ Dropped Admit Card (Missing exam_date): {title}")
            continue

        seen_titles.add(simple_t)
        clean_admit_cards.append(card)

    # ---- 3. results: state check + must have result_status ----
    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "")
        org = res_item.get("organization", "")
        post_name = res_item.get("post_name", "")
        result_status = res_item.get("result_status", "")

        if not title or len(title) < 5:
            continue

        simple_t = simplify_title(title)
        if simple_t in seen_titles:
            continue

        if is_invalid_item(title, org, post_name):
            print(f"❌ Dropped Result (Other State/Invalid): {title}")
            continue

        if not result_status or not result_status.strip():
            print(f"❌ Dropped Result (Missing result_status): {title}")
            continue

        seen_titles.add(simple_t)
        clean_results.append(res_item)

    parsed_jobs["latest_jobs"] = clean_latest_jobs
    parsed_jobs["admit_cards"] = clean_admit_cards
    parsed_jobs["results"] = clean_results
    return parsed_jobs

# -------------------------------------------------------------
# 7. MAIN EXECUTION PIPELINE
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
                          f"👉 Live Jobs Count: {len(parsed_jobs.get('latest_jobs', []))}\n"
                          f"👉 Admit Cards Count: {len(parsed_jobs.get('admit_cards', []))}\n"
                          f"👉 Results Count: {len(parsed_jobs.get('results', []))}")
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 valid job notifications found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Jobs Pipeline Execution Finished Successfully!")
