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

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

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
# STEP 1: Main Page Crawl with Detailed Debug Logs
# -------------------------------------------------------------
def fetch_job_list_from_main_page(url):
    candidates = []
    print(f"\n[DEBUG Step 1] 🌐 Connecting to Main URL: {url}")
    
    try:
        start_time = time.time()
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        elapsed = round(time.time() - start_time, 2)
        
        print(f"[DEBUG Step 1] 📡 HTTP Status: {res.status_code} | Time Taken: {elapsed}s | Content Size: {len(res.content)} bytes")

        if res.status_code != 200:
            print(f"[DEBUG Step 1] ❌ FAILED to fetch main page. Status Code is not 200.")
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')
        print(f"[DEBUG Step 1] 📊 Total Tables Found on Page: {len(tables)}")

        total_rows_scanned = 0
        for t_idx, table in enumerate(tables):
            rows = table.find_all('tr')
            total_rows_scanned += len(rows)

            for row in rows:
                cols = row.find_all(['td', 'th'])
                if len(cols) >= 2:
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

                    if not title_text and cols:
                        title_text = cols[0].text.strip()

                    if detail_url and len(title_text) > 5:
                        candidates.append({
                            "title": title_text,
                            "detail_url": detail_url
                        })

        print(f"[DEBUG Step 1] 🔍 Scanned {total_rows_scanned} rows across {len(tables)} tables.")
        print(f"[DEBUG Step 1] ✅ Extracted {len(candidates)} valid 'Get Details' job items.")

    except Exception as e:
        print(f"[DEBUG Step 1] 🚨 EXCEPTION in Main Page Fetch:")
        print(traceback.format_exc())

    return candidates

# -------------------------------------------------------------
# STEP 2: Inner Page Scrape with Detailed Debug Logs
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {
        "text_content": "",
        "pdf_url": None,
        "apply_url": None
    }
    print(f"  [DEBUG Step 2] 🔗 Fetching Inner Detail Page: {detail_url}")
    
    try:
        start_time = time.time()
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        elapsed = round(time.time() - start_time, 2)
        
        print(f"  [DEBUG Step 2] 📡 HTTP Status: {res.status_code} | Time: {elapsed}s")

        if res.status_code != 200:
            print(f"  [DEBUG Step 2] ⚠️ Skip: Received Status Code {res.status_code}")
            return details

        soup = BeautifulSoup(res.content, "html.parser")

        # 1. Parse Links
        all_a_tags = soup.find_all('a', href=True)
        print(f"  [DEBUG Step 2] 🔎 Found {len(all_a_tags)} anchor tags in inner page.")

        for a_tag in all_a_tags:
            href = a_tag['href'].strip()
            text = a_tag.text.strip().lower()
            full_link = urljoin(detail_url, href)

            if href.lower().endswith('.pdf') and not details["pdf_url"]:
                details["pdf_url"] = full_link
                print(f"  [DEBUG Step 2] 📄 Found Direct PDF Link: {full_link}")
            elif any(k in text for k in ["apply online", "apply link", "registration"]) and not details["apply_url"]:
                details["apply_url"] = full_link
                print(f"  [DEBUG Step 2] 🎯 Found Apply Online Link: {full_link}")
            elif any(k in text for k in ["notification", "advt"]) and not details["pdf_url"]:
                details["pdf_url"] = full_link
                print(f"  [DEBUG Step 2] 📋 Found Notification Link: {full_link}")

        # 2. Extract Body Content
        content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        raw_text = content_div.text if content_div else ""
        details["text_content"] = clean_html_text(raw_text)[:8000]
        print(f"  [DEBUG Step 2] 📝 Extracted {len(details['text_content'])} chars of body text.")

    except Exception as e:
        print(f"  [DEBUG Step 2] 🚨 EXCEPTION in Deep Fetch:")
        print(traceback.format_exc())

    return details

# -------------------------------------------------------------
# REGEX & FIELD EXTRACTION WITH DEBUG
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

    print(f"  [DEBUG Regex] Extracted -> Vacancies: {extracted['total_vacancies']} | Dates: {extracted['start_date']} to {extracted['last_date']}")
    return extracted

# -------------------------------------------------------------
# MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    print("=======================================================")
    print("🚀 PIPELINE STARTED WITH VERBOSE DEBUGGING")
    print("=======================================================")

    main_url = "https://www.freejobalert.com/latest-notifications/"
    job_candidates = fetch_job_list_from_main_page(main_url)

    if not job_candidates:
        print("\n[DEBUG Main Pipeline] ❌ ERROR: No candidates fetched from Step 1. Pipeline Stopping.")
        return

    process_limit = min(len(job_candidates), 15) # Process top 15 for quick debug testing
    print(f"\n[DEBUG Main Pipeline] ⚙️ Processing Top {process_limit} Jobs...")

    for idx, job in enumerate(job_candidates[:process_limit]):
        title = job["title"]
        detail_url = job["detail_url"]

        print(f"\n-------------------------------------------------------")
        print(f"[{idx+1}/{process_limit}] 📌 Processing Item: {title}")

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            print(f"  [DEBUG Pipeline] ⏭️ Skipping Duplicate Title.")
            continue
        seen_titles.add(clean_key)

        deep_data = fetch_deep_details(detail_url)
        full_context = title + "\n" + deep_data["text_content"]

        extracted = extract_fields_with_regex(full_context)
        org_name = detect_organization(full_context)
        print(f"  [DEBUG Pipeline] Identified Organization: {org_name}")

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
            print("  [DEBUG Pipeline] 💾 Saved to Admit Cards category.")
        elif "result" in t_lower:
            results.append({
                "id": f"result_{len(results)+1:02d}",
                "title": title,
                "organization": org_name,
                "status": "Result Declared",
                "apply_url": deep_data["apply_url"] or detail_url,
                "date": today_str
            })
            print("  [DEBUG Pipeline] 💾 Saved to Results category.")
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
            print("  [DEBUG Pipeline] 💾 Saved to Latest Jobs category.")

    print("\n=======================================================")
    print("💾 SAVING OUTPUT TO bihar_jobs.json...")
    
    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    try:
        with open("bihar_jobs.json", "w", encoding="utf-8") as f:
            json.dump(final_output, f, ensure_ascii=False, indent=2)
        print("✅ bihar_jobs.json written successfully!")
    except Exception as e:
        print(f"❌ ERROR Writing JSON File: {e}")

    print("\n=======================================================")
    print(f"📊 FINAL DEBUG REPORT")
    print(f"Jobs Saved: {len(latest_jobs)} | Admit Cards: {len(admit_cards)} | Results: {len(results)}")
    print("=======================================================")

if __name__ == "__main__":
    run_job_pipeline()
