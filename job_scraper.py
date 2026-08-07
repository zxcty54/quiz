import os
import json
import time
import re
import traceback
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

ORG_MAP = {
    "union bank": "Union Bank of India",
    "sbi": "State Bank of India (SBI)",
    "bank": "Public Sector Bank",
    "bpsc": "Bihar Public Service Commission (BPSC)",
    "bssc": "Bihar Staff Selection Commission (BSSC)",
    "csbc": "Central Selection Board of Constable (CSBC)",
    "bpssc": "Bihar Police Subordinate Services Commission (BPSSC)",
    "ssc": "Staff Selection Commission (SSC)",
    "rrb": "Railway Recruitment Board (RRB)",
    "ibps": "Institute of Banking Personnel Selection (IBPS)",
    "upsc": "Union Public Service Commission (UPSC)",
    "india post": "India Post / Department of Posts",
    "indian army": "Indian Army",
    "indian navy": "Indian Navy",
    "indian air force": "Indian Air Force"
}

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ORG_MAP.items():
        if key in text_lower:
            return full_name
    return "Central / Bihar Govt Agency"

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# STEP 1: FIX TABLE COLUMN INDEXING FOR TITLE
# -------------------------------------------------------------
def fetch_job_list_from_main_page(url):
    candidates = []
    print(f"\n[DEBUG Step 1] 🌐 Connecting to Main URL: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            print(f"[DEBUG Step 1] ❌ FAILED to fetch main page. Status Code: {res.status_code}")
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                if len(cols) >= 3:
                    # FIX: Column 0 is Date. Column 1/2 contains Organization & Post Name Title!
                    post_col_text = cols[2].text.strip() if len(cols) > 2 else cols[1].text.strip()
                    org_col_text = cols[1].text.strip() if len(cols) > 1 else ""

                    # Skip Header Rows
                    if "post name" in post_col_text.lower() or "recruitment" in post_col_text.lower() and len(post_col_text) < 10:
                        continue

                    # Construct Clean Title
                    if re.match(r'^\d{2}/\d{2}/\d{4}$', post_col_text):
                        continue # Skip if text is just a date

                    full_title = f"{org_col_text} {post_col_text}".strip()

                    # Find "Get Details" link strictly inside this row
                    detail_url = None
                    for a in row.find_all('a', href=True):
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text:
                            detail_url = urljoin(url, href)
                            break
                        elif not detail_url and "articles" in href:
                            detail_url = urljoin(url, href)

                    if detail_url and len(full_title) > 5 and not re.match(r'^\d{2}/\d{2}/\d{4}$', full_title):
                        candidates.append({
                            "title": full_title,
                            "detail_url": detail_url
                        })

        print(f"[DEBUG Step 1] ✅ Extracted {len(candidates)} valid jobs with Proper Titles!")

    except Exception as e:
        print(f"[DEBUG Step 1] 🚨 EXCEPTION: {e}")

    return candidates

# -------------------------------------------------------------
# STEP 2: FIX INNER LINK MIX-UP (PDF vs Apply Link)
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {
        "text_content": "",
        "pdf_url": None,
        "apply_url": None
    }
    
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return details

        soup = BeautifulSoup(res.content, "html.parser")

        # FIX: Find Official Links inside Important Links Table
        tables = soup.find_all('table')
        for table in tables:
            for row in table.find_all('tr'):
                row_text = row.text.lower()
                a_tag = row.find('a', href=True)
                if a_tag:
                    href = urljoin(detail_url, a_tag['href'])
                    
                    if "apply online" in row_text or "apply link" in row_text:
                        details["apply_url"] = href
                    elif "notification" in row_text or "advt" in row_text or href.endswith('.pdf'):
                        details["pdf_url"] = href

        # Fallback if links not in table
        if not details["pdf_url"] or not details["apply_url"]:
            for a_tag in soup.find_all('a', href=True):
                href = urljoin(detail_url, a_tag['href'])
                text = a_tag.text.strip().lower()

                if href.endswith('.pdf') and not details["pdf_url"]:
                    details["pdf_url"] = href
                elif "apply" in text and not details["apply_url"] and "freejobalert" not in href:
                    details["apply_url"] = href

        content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        details["text_content"] = clean_html_text(content_div.text if content_div else "")[:8000]

    except Exception as e:
        print(f"  [DEBUG Step 2] 🚨 EXCEPTION in Deep Fetch: {e}")

    return details

# -------------------------------------------------------------
# MAIN PIPELINE
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    main_url = "https://www.freejobalert.com/latest-notifications/"
    job_candidates = fetch_job_list_from_main_page(main_url)

    for idx, job in enumerate(job_candidates[:20]):
        title = job["title"]
        detail_url = job["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(job_candidates[:20])}] 📌 Scrape: {title}")

        deep_data = fetch_deep_details(detail_url)
        full_context = title + "\n" + deep_data["text_content"]

        org_name = detect_organization(full_context)

        # Build Clean Structured Object
        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "title": title, # Clean Title fixed!
            "organization": org_name,
            "job_type": "Bihar Govt Job" if "bihar" in full_context.lower() else "Central Govt Job",
            "total_vacancies": "Check Official Notification",
            "qualification": "Refer Official Notification",
            "age_limit": "18-37 Years (Relaxation Applicable)",
            "application_fee": "Refer Official Notification",
            "start_date": today_str,
            "last_date": "Refer Official Notification",
            "apply_url": deep_data["apply_url"] or detail_url,
            "notification_pdf": deep_data["pdf_url"] or "Refer Official Notification",
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

    print("\n✅ Clean JSON Generated Successfully!")

if __name__ == "__main__":
    run_job_pipeline()
