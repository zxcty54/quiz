import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# 1. API Client & Configuration Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

AI_MODELS_TIERS = [
    "llama-3.1-8b-instant",     # Tier 1: Fast & Token Economical
    "mixtral-8x7b-32768",       # Tier 2: Mid-range MoE
    "llama-3.3-70b-versatile"   # Tier 3: Final Heavy Duty Fallback
]

# Strict Rejection List (AIIMS + Other States + Non-Bihar District Banks)
HARD_REJECT_KEYWORDS = [
    # AIIMS Rejection
    "aiims", 

    # Non-Bihar States / District Banks / Local Entities
    "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav ", 
    "uttar pradesh", " up ", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "maharashtra", "mpsc", 
    "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", "gujarat", 
    "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "ap mahesh", "mahesh bank",
    "telangana", "tspsc", "assam", "chhattisgarh"
]

BIHAR_BOARDS = [
    ("bpsc", "Bihar Public Service Commission (BPSC)"),
    ("bssc", "Bihar Staff Selection Commission (BSSC)"),
    ("bpssc", "Bihar Police Subordinate Services Commission (BPSSC)"),
    ("csbc", "Central Selection Board of Constable (CSBC)"),
    ("btsc", "Bihar Technical Service Commission (BTSC)"),
    ("patna high court", "Patna High Court"),
    ("high court patna", "Patna High Court"),
    ("wcdc", "Women and Child Development Corporation (WCDC) Bihar"),
    ("beltron", "Bihar State Electronics Development Corporation (BELTRON)"),
    ("bihar amin", "Bihar Revenue & Land Reforms Dept (Amin)"),
    ("civil court bihar", "Bihar Civil Court")
]

CENTRAL_BOARDS = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"),
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("union bank", "Union Bank of India"),
    ("india post", "India Post / Department of Posts"),
    ("indian army", "Indian Army"),
    ("indian navy", "Indian Navy"),
    ("indian air force", "Indian Air Force")
]

ALL_BOARDS = BIHAR_BOARDS + CENTRAL_BOARDS

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in HARD_REJECT_KEYWORDS)

def parse_vacancy_count(vac_str):
    """Extracts numeric integer count from vacancy string."""
    if not vac_str:
        return None
    match = re.search(r'\b(\d+)\b', str(vac_str))
    return int(match.group(1)) if match else None

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ALL_BOARDS:
        if key in text_lower:
            return full_name
    return "Central / Bihar Govt Agency"

def is_bihar_job(text):
    bihar_keywords = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron"]
    return any(kw in text.lower() for kw in bihar_keywords)

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. Multi-Tier AI Parser (Token-Saving Fallback Hierarchy)
# -------------------------------------------------------------
def parse_job_data_with_ai(context_text):
    if not client:
        return {}

    prompt = f"""
    Extract recruitment notification details from the text below.
    Return strictly valid JSON without markdown formatting.

    Expected JSON Schema:
    {{
      "start_date": "Exact Start Date or null",
      "last_date": "Exact Last Date or null",
      "age_limit": "Age criteria or null",
      "application_fee": "Fee details or null",
      "qualification": "Educational requirement or null",
      "total_vacancies": "Total posts count or null"
    }}

    Text Context:
    {context_text[:3000]}
    """

    for model_name in AI_MODELS_TIERS:
        try:
            res = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": "You extract government job details into strict JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                timeout=10
            )
            parsed_json = json.loads(res.choices[0].message.content)
            print(f"  [AI Success] Extracted using model: {model_name}")
            return parsed_json
        except Exception as e:
            print(f"  [AI Tier Fallback] Model '{model_name}' failed. Trying next tier...")

    return {}

# -------------------------------------------------------------
# 3. Step 1: Accurate 7-Column Table Scraper
# -------------------------------------------------------------
def fetch_main_table_data(url):
    candidates = []
    print(f"\n[STEP 1] 🌐 Scraping Main Page: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=20, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                
                # FreeJobAlert main tables have 6 to 7 columns
                if len(cols) >= 5:
                    col_texts = [clean_html_text(c.text) for c in cols]
                    
                    # Header Row Ignore Logic
                    if "post name" in col_texts[1].lower() or "post date" in col_texts[0].lower():
                        continue

                    # Dynamic Column Indexing based on Table Layout (Captured from Capture.PNG)
                    # Col 0: Post Date (Start Date)
                    # Col 1: Recruitment Board
                    # Col 2: Exam / Post Name
                    # Col 3: Qualification
                    # Col 4: Advt No (Skipped)
                    # Col 5: Last Date (Real Last Date)
                    post_date = col_texts[0]
                    raw_board = col_texts[1]
                    raw_post_and_vacancies = col_texts[2]
                    qualification = col_texts[3] if len(col_texts) > 3 else None
                    
                    # Handle Column Indexing for Last Date
                    raw_last_date = None
                    if len(col_texts) >= 6:
                        raw_last_date = col_texts[5] # Col 5 is actual Last Date when Advt No column exists
                    elif len(col_texts) == 5:
                        raw_last_date = col_texts[4]

                    title = f"{raw_board} {raw_post_and_vacancies}".strip()

                    # 🚫 FILTER 1: REJECT AIIMS, OTHER STATES & LOCAL DISTRICT BANKS
                    if is_hard_rejected(title):
                        print(f"  [Rejected AIIMS/Other State/Bank]: {title}")
                        continue

                    # Vacancy Extraction & Cleaning
                    vac_match = re.search(r'(\d+[\d,]*)\s*(Posts|Vacancies)?', raw_post_and_vacancies, re.IGNORECASE)
                    vacancies_str = vac_match.group(0) if vac_match else None
                    vac_num = parse_vacancy_count(vacancies_str)

                    # 🚫 FILTER 2: REJECT IF VACANCIES ARE LESS THAN 30
                    if vac_num is not None and vac_num < 30:
                        print(f"  [Rejected Low Vacancy ({vac_num} < 30)]: {title}")
                        continue

                    clean_post = re.sub(r'[\s–-]+\d+\s*(Posts|Vacancies)?.*$', '', raw_post_and_vacancies, flags=re.IGNORECASE).strip()

                    # Clean Date string from raw_last_date
                    table_last_date = None
                    if raw_last_date and raw_last_date != "-":
                        date_match = re.search(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', raw_last_date)
                        table_last_date = date_match.group(0) if date_match else raw_last_date.strip()

                    # Find "Get Details" URL
                    detail_url = None
                    for a in row.find_all('a', href=True):
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text or "articles" in href:
                            detail_url = urljoin(url, href)
                            break

                    org_name = detect_organization(f"{raw_board} {clean_post}")

                    if detail_url and len(title) > 5 and not re.match(r'^\d{2}/\d{2}/\d{4}$', title):
                        candidates.append({
                            "title": f"{raw_board} {clean_post}",
                            "post_name": clean_post,
                            "organization": org_name,
                            "qualification": qualification,
                            "total_vacancies": vacancies_str,
                            "start_date": post_date,        # Col 0 Real Start Date
                            "last_date": table_last_date,   # Col 5 Real Last Date
                            "detail_url": detail_url,
                            "is_bihar": is_bihar_job(title)
                        })

        print(f"[STEP 1] ✅ Extracted {len(candidates)} valid jobs (Filtered <30 posts & AIIMS)!")

    except Exception as e:
        print(f"[STEP 1] 🚨 Error: {e}")

    return candidates

# -------------------------------------------------------------
# 4. Step 2: Inner Page Deep Scrape (PDF Extraction)
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {"text_content": "", "pdf_url": None}
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for table in soup.find_all('table'):
                for row in table.find_all('tr'):
                    a_tag = row.find('a', href=True)
                    if a_tag:
                        href = urljoin(detail_url, a_tag['href'])
                        if ("notification" in row.text.lower() or href.endswith('.pdf')) and not details["pdf_url"]:
                            details["pdf_url"] = href

            content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
            details["text_content"] = clean_html_text(content_div.text if content_div else "")
    except Exception as e:
        print(f"⚠️ Inner page warning: {e}")

    return details

# -------------------------------------------------------------
# 5. Main Execution Pipeline
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    latest_jobs, admit_cards, results, seen_titles = [], [], [], set()

    main_url = "https://www.freejobalert.com/latest-notifications/"
    candidates = fetch_main_table_data(main_url)

    # Prioritize Bihar Jobs to top
    candidates.sort(key=lambda x: x["is_bihar"], reverse=True)

    for idx, cand in enumerate(candidates[:25]):
        title = cand["title"]
        detail_url = cand["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(candidates[:25])}] 🔍 Processing: {title}")

        deep_data = fetch_deep_details(detail_url)
        full_context = f"{title}\nStart Date: {cand['start_date']}\nLast Date: {cand['last_date']}\nQualification: {cand['qualification']}\n{deep_data['text_content']}"

        # Deep Content Rejection Check (AIIMS/State checks)
        if is_hard_rejected(full_context):
            print(f"  [Inner Rejected AIIMS/State]: {title}")
            continue

        ai_data = parse_job_data_with_ai(full_context)

        # Final Post-AI Vacancy Verification (< 30)
        final_vac_str = ai_data.get("total_vacancies") or cand["total_vacancies"]
        final_vac_num = parse_vacancy_count(final_vac_str)
        if final_vac_num is not None and final_vac_num < 30:
            print(f"  [Rejected Low Vacancy ({final_vac_num} < 30)]: {title}")
            continue

        # Final Dates Selection (Main Table HTML Priority)
        final_start_date = cand["start_date"] or ai_data.get("start_date") or None
        final_last_date = cand["last_date"] or ai_data.get("last_date") or None

        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "title": title,
            "organization": cand["organization"],
            "job_type": "Bihar Govt Job" if cand["is_bihar"] else "Central Govt Job",
            "post_name": cand["post_name"] or None,
            "total_vacancies": final_vac_str or None,
            "qualification": ai_data.get("qualification") or cand["qualification"] or None,
            "age_limit": ai_data.get("age_limit") or None,
            "application_fee": ai_data.get("application_fee") or None,
            "start_date": final_start_date, # Real Start Date (Col 0)
            "last_date": final_last_date,   # Real Last Date (Col 5)
            "apply_url": "https://www.mocktester.online",
            "notification_pdf": deep_data["pdf_url"] or None,
            "date": today_str
        }
        latest_jobs.append(job_card)

    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Perfect bihar_jobs.json generated! Total Jobs: {len(latest_jobs)}")

if __name__ == "__main__":
    run_job_pipeline()
