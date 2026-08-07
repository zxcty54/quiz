import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

# Bihar Specific & Central Govt Boards Mapping
BIHAR_BOARDS = [
    ("bpsc", "Bihar Public Service Commission (BPSC)"),
    ("bssc", "Bihar Staff Selection Commission (BSSC)"),
    ("bpssc", "Bihar Police Subordinate Services Commission (BPSSC)"),
    ("csbc", "Central Selection Board of Constable (CSBC)"),
    ("btsc", "Bihar Technical Service Commission (BTSC)"),
    ("patna high court", "Patna High Court"),
    ("high court patna", "Patna High Court"),
    ("wcdc", "Women and Child Development Corporation (WCDC) Bihar"),
    ("amin", "Bihar Revenue & Land Reforms Dept (Amin)"),
    ("beltron", "Bihar State Electronics Development Corporation (BELTRON)"),
    ("civil court", "Bihar Civil Court")
]

CENTRAL_BOARDS = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"),
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("union bank", "Union Bank of India"),
    ("india post", "India Post / Department of Posts")
]

ALL_BOARDS = BIHAR_BOARDS + CENTRAL_BOARDS

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ALL_BOARDS:
        if key in text_lower:
            return full_name
    return "Central / Bihar Govt Agency"

def is_bihar_job(text):
    text_lower = text.lower()
    bihar_keywords = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "amin", "beltron"]
    return any(kw in text_lower for kw in bihar_keywords)

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def extract_vacancies(text):
    match = re.search(r'(\d+[\d,]*)\s*(Posts|Vacancies|Seat|Seats)?', text, re.IGNORECASE)
    if match:
        return f"{match.group(1)} Posts" if "Post" not in match.group(0) else match.group(0)
    return None

# -------------------------------------------------------------
# STEP 1: Main Table Exact Column Parsing
# -------------------------------------------------------------
def fetch_main_table_data(url):
    candidates = []
    print(f"\n[STEP 1] 🌐 Fetching Main Notifications Page: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=20, verify=False, impersonate="chrome")
        if res.status_code != 200:
            print(f"❌ Status Error: {res.status_code}")
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                
                # Table column verification
                if len(cols) >= 5:
                    col_texts = [clean_html_text(c.text) for c in cols]
                    
                    # Header Row Ignore Logic
                    if "post name" in col_texts[1].lower() or "qualification" in col_texts[2].lower() or "post date" in col_texts[0].lower():
                        continue

                    # Exact Column Mapping
                    # Col 0: Post Date
                    # Col 1: Board / Org Name
                    # Col 2: Post Name & Vacancies
                    # Col 3: Educational Qualification
                    # Col 4: Last Date / Advt No
                    
                    raw_board = col_texts[1]
                    raw_post_and_vacancies = col_texts[2]
                    qualification = col_texts[3] if len(col_texts) > 3 else None
                    last_date = col_texts[4] if len(col_texts) > 4 else None

                    # Extract Vacancy from Col 2 text
                    vacancies = extract_vacancies(raw_post_and_vacancies)
                    
                    # Clean post name (Remove vacancy count text from title)
                    clean_post = re.sub(r'[\s–-]+\d+\s*(Posts|Vacancies|Seats)?.*$', '', raw_post_and_vacancies, flags=re.IGNORECASE).strip()

                    # Find Inner Details Link
                    detail_url = None
                    for a in row.find_all('a', href=True):
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text or "articles" in href:
                            detail_url = urljoin(url, href)
                            break

                    title = f"{raw_board} {clean_post}".strip()
                    org_name = detect_organization(f"{raw_board} {clean_post}")

                    if detail_url and len(title) > 5 and not re.match(r'^\d{2}/\d{2}/\d{4}$', title):
                        candidates.append({
                            "title": title,
                            "post_name": clean_post,
                            "organization": org_name,
                            "qualification": qualification,
                            "total_vacancies": vacancies,
                            "last_date": last_date,
                            "detail_url": detail_url,
                            "is_bihar": is_bihar_job(title + " " + raw_board)
                        })

        print(f"[STEP 1] ✅ Successfully extracted {len(candidates)} jobs from table!")

    except Exception as e:
        print(f"[STEP 1] 🚨 Parsing Exception: {e}")

    return candidates

# -------------------------------------------------------------
# STEP 2: Inner Page Deep Scrape (PDF, Fee, Age Limit)
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {
        "text_content": "",
        "pdf_url": None,
        "application_fee": None,
        "age_limit": None
    }
    
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return details

        soup = BeautifulSoup(res.content, "html.parser")

        # Official PDF Link extraction
        for table in soup.find_all('table'):
            for row in table.find_all('tr'):
                row_text = row.text.lower()
                a_tag = row.find('a', href=True)
                if a_tag:
                    href = urljoin(detail_url, a_tag['href'])
                    if ("notification" in row_text or "advt" in row_text or href.endswith('.pdf')) and not details["pdf_url"]:
                        details["pdf_url"] = href

        content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        raw_text = clean_html_text(content_div.text if content_div else "")

        # Fee Parsing
        fee_match = re.search(r'(?:Application Fee|Exam Fee)[^.\n]*[₹\d]+[^.\n]*', raw_text, re.IGNORECASE)
        if fee_match:
            details["application_fee"] = fee_match.group(0)[:120]
        elif re.search(r'\b(no fee|free of cost|nil)\b', raw_text, re.IGNORECASE):
            details["application_fee"] = "General / OBC / SC / ST: ₹0 (No Fee)"

        # Age Parsing
        age_match = re.search(r'(\d{2}\s*to\s*\d{2}\s*years|\d{2}\s*-\s*\d{2}\s*years)', raw_text, re.IGNORECASE)
        if age_match:
            details["age_limit"] = age_match.group(0)

    except Exception as e:
        print(f"  [STEP 2] ⚠️ Inner page warning: {e}")

    return details

# -------------------------------------------------------------
# MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    main_url = "https://www.freejobalert.com/latest-notifications/"
    candidates = fetch_main_table_data(main_url)

    # Sort candidates so Bihar Jobs come first
    candidates.sort(key=lambda x: x["is_bihar"], reverse=True)

    for idx, cand in enumerate(candidates[:30]):
        title = cand["title"]
        detail_url = cand["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(candidates[:30])}] 🔍 Processing: {title}")

        deep_data = fetch_deep_details(detail_url)

        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "title": title,
            "organization": cand["organization"],
            "job_type": "Bihar Govt Job" if cand["is_bihar"] else "Central Govt Job",
            "post_name": cand["post_name"] or None,
            "total_vacancies": cand["total_vacancies"] or None,
            "qualification": cand["qualification"] or None,
            "age_limit": deep_data["age_limit"] or None,
            "application_fee": deep_data["application_fee"] or None,
            "start_date": today_str,
            "last_date": cand["last_date"] or None,
            "apply_url": "https://www.mocktester.online", # Fixed as per request
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

    print(f"\n✅ Successfully generated bihar_jobs.json with {len(latest_jobs)} items!")

if __name__ == "__main__":
    run_job_pipeline()
