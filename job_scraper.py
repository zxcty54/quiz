import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
import fitz  # PyMuPDF

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

ORG_MAP = {
    "bpsc": "Bihar Public Service Commission (BPSC)",
    "bssc": "Bihar Staff Selection Commission (BSSC)",
    "csbc": "Central Selection Board of Constable (CSBC)",
    "bpssc": "Bihar Police Subordinate Services Commission (BPSSC)",
    "ssc": "Staff Selection Commission (SSC)",
    "rrb": "Railway Recruitment Board (RRB)",
    "ibps": "Institute of Banking Personnel Selection (IBPS)",
    "sbi": "State Bank of India (SBI)",
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
# STEP 1: Main Page Crawl -> Extracts Job Titles & "Get Details" Links
# -------------------------------------------------------------
def fetch_job_list_from_main_page(url):
    candidates = []
    try:
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            print(f"Failed to fetch main page. Status: {res.status_code}")
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        
        # FreeJobAlert ke Notification Tables target karenge
        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                if len(cols) >= 2:
                    # Find 'Get Details' or Title Links
                    a_tags = row.find_all('a', href=True)
                    detail_url = None
                    title_text = ""

                    for a in a_tags:
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text:
                            detail_url = urljoin(url, href)
                        elif len(a.text.strip()) > 10 and not title_text:
                            title_text = a.text.strip()

                    # Fallback title from table text
                    if not title_text:
                        title_text = cols[0].text.strip()

                    if detail_url and len(title_text) > 5:
                        candidates.append({
                            "title": title_text,
                            "detail_url": detail_url
                        })

    except Exception as e:
        print(f"⚠️ Error fetching main job list: {e}")

    return candidates

# -------------------------------------------------------------
# STEP 2: Inner Page Deep Scrape -> PDF, Apply Link & Content
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

        # 1. Parse Links (Apply Online & Notification PDF)
        for a_tag in soup.find_all('a', href=True):
            href = a_tag['href'].strip()
            text = a_tag.text.strip().lower()
            full_link = urljoin(detail_url, href)

            if href.lower().endswith('.pdf') and not details["pdf_url"]:
                details["pdf_url"] = full_link
            elif any(k in text for k in ["apply online", "apply link", "registration"]) and not details["apply_url"]:
                details["apply_url"] = full_link
            elif any(k in text for k in ["notification", "advt"]) and not details["pdf_url"]:
                details["pdf_url"] = full_link

        # 2. Extract Body Content
        content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        details["text_content"] = clean_html_text(content_div.text if content_div else "")[:8000]

    except Exception as e:
        print(f"⚠️ Error in Step 2 Deep Fetch ({detail_url}): {e}")

    return details

# -------------------------------------------------------------
# REGEX & AI EXTRACTION HELPER
# -------------------------------------------------------------
def extract_fields_with_regex(text):
    extracted = {}
    
    # Vacancies
    vac_match = re.search(r'\b(\d{2,6})\s*(Posts|Vacancies|Seat|Seats)\b', text, re.IGNORECASE)
    extracted["total_vacancies"] = f"{vac_match.group(1)} Posts" if vac_match else None

    # Fee
    if re.search(r'\b(no fee|free of cost|nil|exempted)\b', text, re.IGNORECASE):
        extracted["application_fee"] = "General / OBC / SC / ST: ₹0 (No Fee)"
    else:
        fee_match = re.search(r'(?:Fee|Application Fee)[^.\n]*[₹\d]+[^.\n]*', text, re.IGNORECASE)
        extracted["application_fee"] = fee_match.group(0)[:100] if fee_match else None

    # Dates
    dates = re.findall(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b', text, re.IGNORECASE)
    extracted["start_date"] = dates[0] if len(dates) >= 1 else None
    extracted["last_date"] = dates[1] if len(dates) >= 2 else (dates[0] if len(dates) == 1 else None)

    return extracted

# -------------------------------------------------------------
# MAIN PIPELINE
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    print("\n=======================================================")
    print("🚀 2-STEP FREEJOBALERT SCRAPER STARTED")
    print("=======================================================")

    # Step 1: Main Notification Page URL Visit
    main_url = "https://www.freejobalert.com/latest-notifications/"
    print(f"📡 STEP 1: Crawling Main Listing -> {main_url}")
    job_candidates = fetch_job_list_from_main_page(main_url)
    print(f"✅ Found {len(job_candidates)} potential jobs with 'Get Details' links!")

    # Step 2: Loop through each candidate & Fetch Deep Page Details
    for idx, job in enumerate(job_candidates[:30]): # Process top 30 latest jobs
        title = job["title"]
        detail_url = job["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"\n[{idx+1}/{min(len(job_candidates), 30)}] 🔍 STEP 2: Scrape Details -> {title}")
        
        deep_data = fetch_deep_details(detail_url)
        full_context = title + "\n" + deep_data["text_content"]

        extracted = extract_fields_with_regex(full_context)
        org_name = detect_organization(full_context)

        # Categorize item
        t_lower = title.lower()
        if "admit card" in t_lower:
            admit_cards.append({
                "id": f"admit_{len(admit_cards)+1:02d}",
                "title": title,
                "organization": org_name,
                "status": "Admit Card Released",
                "apply_url": deep_data["apply_url"] or detail_url,
                "date": today_str
            })
        elif "result" in t_lower:
            results.append({
                "id": f"result_{len(results)+1:02d}",
                "title": title,
                "organization": org_name,
                "status": "Result Declared",
                "apply_url": deep_data["apply_url"] or detail_url,
                "date": today_str
            })
        else:
            latest_jobs.append({
                "id": f"job_{len(latest_jobs)+1:02d}",
                "title": title,
                "organization": org_name,
                "job_type": "Bihar Govt Job" if "bihar" in full_context.lower() else "Central Govt Job",
                "total_vacancies": extracted.get("total_vacancies") or "Check Official Notification",
                "qualification": "Refer Official Notification",
                "age_limit": "18-37 Years (Relaxation Applicable)",
                "application_fee": extracted.get("application_fee") or "Refer Official Notification",
                "start_date": extracted.get("start_date") or "Online Active",
                "last_date": extracted.get("last_date") or "Refer Official Notification",
                "apply_url": deep_data["apply_url"] or detail_url,
                "notification_pdf": deep_data["pdf_url"] or "Refer Official Notification",
                "date": today_str
            })

    # Save to JSON
    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print("\n=======================================================")
    print(f"📊 FINAL REPORT")
    print(f"Jobs: {len(latest_jobs)} | Admit Cards: {len(admit_cards)} | Results: {len(results)}")
    print("=======================================================")

if __name__ == "__main__":
    run_job_pipeline()
