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

# Priority-based ORG MAP (Fixed Tuple Syntax)
ORG_MAP = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("bpsc", "Bihar Public Service Commission (BPSC)"),
    ("bssc", "Bihar Staff Selection Commission (BSSC)"),
    ("csbc", "Central Selection Board of Constable (CSBC)"),
    ("bpssc", "Bihar Police Subordinate Services Commission (BPSSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"), # Syntax fixed here
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("union bank", "Union Bank of India"),
    ("bank", "Public Sector Bank"),
    ("india post", "India Post / Department of Posts"),
    ("indian army", "Indian Army"),
    ("indian navy", "Indian Navy"),
    ("indian air force", "Indian Air Force")
]

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ORG_MAP:
        if key in text_lower:
            return full_name
    return "Central / Bihar Govt Agency"

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# STEP 1: Main Table Direct Field Scraper
# -------------------------------------------------------------
def fetch_main_table_data(url):
    candidates = []
    print(f"\n[STEP 1] 🌐 Scraping Main Page: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=20, verify=False, impersonate="chrome")
        if res.status_code != 200:
            print(f"[STEP 1] ❌ HTTP Error: {res.status_code}")
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                
                if len(cols) >= 5:
                    col_texts = [clean_html_text(c.text) for c in cols]
                    
                    if "post name" in col_texts[1].lower() or "qualification" in col_texts[2].lower():
                        continue

                    exam_board = col_texts[0]
                    post_name = col_texts[1]
                    qualification = col_texts[2] if len(col_texts) > 2 else "Refer Official Notification"
                    vacancies = col_texts[3] if len(col_texts) > 3 else "Check Official Notification"
                    last_date = col_texts[4] if len(col_texts) > 4 else "Refer Official Notification"

                    detail_url = None
                    for a in row.find_all('a', href=True):
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text or "articles" in href:
                            detail_url = urljoin(url, href)
                            break

                    title = f"{exam_board} {post_name}".strip()
                    if detail_url and len(title) > 8 and not re.match(r'^\d{2}/\d{2}/\d{4}$', title):
                        candidates.append({
                            "title": title,
                            "post_name": post_name,
                            "organization": detect_organization(title),
                            "qualification": qualification if qualification else "Refer Official Notification",
                            "total_vacancies": vacancies if vacancies else "Check Official Notification",
                            "last_date": last_date if last_date else "Refer Official Notification",
                            "detail_url": detail_url
                        })

        print(f"[STEP 1] ✅ Successfully extracted {len(candidates)} jobs directly from Table!")

    except Exception as e:
        print(f"[STEP 1] 🚨 Error: {e}")

    return candidates

# -------------------------------------------------------------
# STEP 2: Deep Detail Scraper (Apply URL, PDF, Fee, Age Limit)
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {
        "text_content": "",
        "pdf_url": None,
        "apply_url": None,
        "application_fee": None,
        "age_limit": None
    }
    
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return details

        soup = BeautifulSoup(res.content, "html.parser")

        for table in soup.find_all('table'):
            for row in table.find_all('tr'):
                row_text = row.text.lower()
                a_tag = row.find('a', href=True)
                if a_tag:
                    href = urljoin(detail_url, a_tag['href'])
                    if "apply online" in row_text or "apply link" in row_text:
                        details["apply_url"] = href
                    elif "notification" in row_text or "advt" in row_text or href.endswith('.pdf'):
                        details["pdf_url"] = href

        content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        raw_text = clean_html_text(content_div.text if content_div else "")
        details["text_content"] = raw_text[:8000]

        fee_match = re.search(r'(?:Application Fee|Exam Fee)[^.\n]*[₹\d]+[^.\n]*', raw_text, re.IGNORECASE)
        if fee_match:
            details["application_fee"] = fee_match.group(0)[:120]
        elif re.search(r'\b(no fee|free of cost|nil)\b', raw_text, re.IGNORECASE):
            details["application_fee"] = "General / OBC / SC / ST: ₹0 (No Fee)"

        age_match = re.search(r'(\d{2}\s*to\s*\d{2}\s*years|\d{2}\s*-\s*\d{2}\s*years)', raw_text, re.IGNORECASE)
        if age_match:
            details["age_limit"] = age_match.group(0)

    except Exception as e:
        print(f"  [STEP 2] ⚠️ Inner fetch warning: {e}")

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
    candidates = fetch_main_table_data(main_url)

    for idx, cand in enumerate(candidates[:25]):
        title = cand["title"]
        detail_url = cand["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(candidates[:25])}] 🔍 Deep Scraping: {title}")

        deep_data = fetch_deep_details(detail_url)

        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "title": title,
            "organization": cand.get("organization") or "Central / Bihar Govt Agency",
            "job_type": "Bihar Govt Job" if "bihar" in (title + cand.get("post_name", "")).lower() else "Central Govt Job",
            "post_name": cand.get("post_name") or None,
            "total_vacancies": cand.get("total_vacancies") or None,
            "qualification": cand.get("qualification") or None,
            "age_limit": deep_data.get("age_limit") or None,
            "application_fee": deep_data.get("application_fee") or None,
            "start_date": cand.get("start_date") or today_str,
            "last_date": cand.get("last_date") or None,
            "apply_url": deep_data.get("apply_url") or detail_url,
            "notification_pdf": deep_data.get("pdf_url") or None,
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

    print(f"\n✅ bihar_jobs.json generated successfully with {len(latest_jobs)} verified jobs!")

if __name__ == "__main__":
    run_job_pipeline()
