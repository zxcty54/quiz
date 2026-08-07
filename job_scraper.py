import os
import re
import json
import logging
from datetime import datetime
import requests
from bs4 import BeautifulSoup

# ==========================================
# CONFIGURATION & CONSTANTS
# ==========================================

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# Specific mapping keys to avoid false positives (e.g. generic 'post', 'army', 'navy')
ORG_MAP = {
    "india post": "India Post / Department of Posts",
    "indian army": "Indian Army",
    "indian navy": "Indian Navy",
    "indian air force": "Indian Air Force",
    "bpsc": "Bihar Public Service Commission (BPSC)",
    "bssc": "Bihar Staff Selection Commission (BSSC)",
    "btsc": "Bihar Technical Service Commission (BTSC)",
    "csbc": "Central Selection Board of Constable (CSBC)",
    "bpssc": "Bihar Police Subordinate Services Commission (BPSSC)",
    "ssc": "Staff Selection Commission (SSC)",
    "rrb": "Railway Recruitment Board (RRB)",
    "sbi": "State Bank of India (SBI)",
    "ibps": "Institute of Banking Personnel Selection (IBPS)",
    "upsc": "Union Public Service Commission (UPSC)",
    "nta": "National Testing Agency (NTA)",
    "lic": "Life Insurance Corporation (LIC)"
}

REJECT_TITLE_KEYWORDS = [
    "admit card coming soon", "result declared soon", "syllabus", 
    "answer key", "cut off", "model paper", "previous year paper"
]

REJECT_INNER_KEYWORDS = [
    "fake news", "not official yet", "expected date"
]

# ==========================================
# HELPER FUNCTIONS & PARSERS
# ==========================================

def clean_html_text(text: str) -> str:
    """Removes extra spaces, tabs, and newlines from scraped HTML text."""
    if not text:
        return ""
    return re.sub(r'\s+', ' ', text).strip()

def check_title_rejection(title: str) -> bool:
    """Checks if the title contains invalid or unwanted keywords."""
    title_lower = title.lower()
    for kw in REJECT_TITLE_KEYWORDS:
        if kw in title_lower:
            return True
    return False

def check_inner_rejection(text: str) -> bool:
    """Checks if the internal page text contains rejection keywords."""
    text_lower = text.lower()
    for kw in REJECT_INNER_KEYWORDS:
        if kw in text_lower:
            return True
    return False

def clean_post_name(title: str) -> str:
    """Extracts a cleaner post name from the full notification title."""
    clean = re.sub(r'(?i)(recruitment|online form|apply online|202\d|notice)', '', title)
    return clean.strip()

def fetch_and_parse_pdf(pdf_url: str) -> str:
    """Placeholder function for PDF parsing logic."""
    try:
        # Custom PDF parsing logic (e.g. using pypdf / pdfplumber) can go here
        return "PDF Content Placeholder"
    except Exception as e:
        print(f"Error reading PDF {pdf_url}: {e}")
        return ""

def extract_fields_with_regex(context: str) -> dict:
    """Extracts structured fields like vacancy count, age limit, fees, and dates using regex patterns."""
    context_lower = context.lower()
    
    # 1. Total Vacancies
    vacancies_match = re.search(r'(\d+[\d,]*)\s*(posts|vacancies|seats)', context_lower)
    total_vacancies = vacancies_match.group(1) if vacancies_match else None

    # 2. Qualification
    qual_match = re.search(r'(10th|12th|graduate|diploma|b\.tech|m\.tech|degree|passed)', context_lower)
    qualification = qual_match.group(0).upper() if qual_match else None

    # 3. Age Limit
    age_match = re.search(r'(\d{2}\s*-\s*\d{2}\s*years|\d{2}\s*to\s*\d{2}\s*years)', context_lower)
    age_limit = age_match.group(0) if age_match else None

    # 4. Application Fee
    fee_match = re.search(r'(rs\.?\s*\d+|₹\s*\d+|free|nil)', context_lower)
    application_fee = fee_match.group(0) if fee_match else None

    # 5. Start & Last Date
    start_match = re.search(r'(start date|apply date)\s*:\s*([\d\/\-]+)', context_lower)
    start_date = start_match.group(2) if start_match else None

    last_match = re.search(r'(last date)\s*:\s*([\d\/\-]+)', context_lower)
    last_date = last_match.group(2) if last_match else None

    return {
        "total_vacancies": total_vacancies,
        "qualification": qualification,
        "age_limit": age_limit,
        "application_fee": application_fee,
        "start_date": start_date,
        "last_date": last_date
    }

# ==========================================
# SCRAPING & DATA SOURCES
# ==========================================

def scrape_official_websites() -> list:
    """Scrapes official source sites (Mock implementation)."""
    # Dummy candidates structure for pipeline demonstration
    return [
        {
            "title": "BPSC Assistant Professor Recruitment 2026 Apply Online",
            "url": "https://bpsc.bih.nic.in/example-job",
            "type": "job",
            "org": "Bihar Public Service Commission (BPSC)"
        },
        {
            "title": "India Post GDS Online Form 2026 - 30000 Posts",
            "url": "https://indiapost.gov.in/gds-job",
            "type": "job",
            "org": ORG_MAP.get("india post", "India Post")
        }
    ]

def fetch_backup_rss_and_web() -> list:
    """Fetches candidates from backup RSS feeds and secondary web sources."""
    return [
        {
            "title": "Indian Army Agniveer Rally Admit Card 2026",
            "url": "https://joinindianarmy.nic.in/admit-card",
            "type": "admit",
            "org": ORG_MAP.get("indian army", "Indian Army")
        },
        {
            "title": "SSC CGL 2026 Final Result Declared",
            "url": "https://ssc.gov.in/result",
            "type": "result",
            "org": ORG_MAP.get("ssc", "Staff Selection Commission")
        }
    ]

# ==========================================
# MAIN PIPELINE EXECUTION
# ==========================================

def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")

    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    print("\n=======================================================")
    print("🚀 JOB SCRAPER STARTED")
    print("=======================================================")

    # Step 1: Official sources
    raw_candidates = scrape_official_websites()

    print("\n=======================================================")
    print("🔄 BACKUP SOURCES FETCH")
    print("=======================================================")

    backup_candidates = fetch_backup_rss_and_web()
    raw_candidates.extend(backup_candidates)

    print(f"📊 Total Candidates: {len(raw_candidates)}")

    for idx, candidate in enumerate(raw_candidates):

        title = candidate["title"]
        url = candidate["url"]
        item_type = candidate["type"]
        org_name = candidate["org"]

        if check_title_rejection(title):
            continue

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:40]

        if clean_key in seen_titles:
            continue

        seen_titles.add(clean_key)

        print(f"\n[{idx+1}/{len(raw_candidates)}] 🔍 {title}")

        raw_text = ""

        try:
            if url.lower().endswith(".pdf"):
                raw_text = fetch_and_parse_pdf(url)
            else:
                # Custom requests call
                page = requests.get(
                    url,
                    headers=HEADERS,
                    timeout=10,
                    verify=False
                )

                if page.status_code == 200:
                    soup = BeautifulSoup(page.content, "html.parser")
                    raw_text = clean_html_text(soup.text[:6000])

        except Exception as e:
            print("Fetch error:", e)

        full_context = title + "\n" + raw_text

        if check_inner_rejection(full_context):
            print("❌ Rejected inner text")
            continue

        extracted = extract_fields_with_regex(full_context)

        if item_type == "job":
            latest_jobs.append({
                "id": f"job_{len(latest_jobs)+1:02d}",
                "title": title,
                "organization": org_name,
                "job_type": (
                    "Bihar Govt Job"
                    if "bihar" in full_context.lower()
                    else "Central Govt Job"
                ),
                "post_name": clean_post_name(title),
                "total_vacancies": extracted["total_vacancies"] or "Check Official Notification",
                "qualification": extracted["qualification"] or "Refer Official Notification",
                "age_limit": extracted["age_limit"] or "Refer Official Notification",
                "application_fee": extracted["application_fee"] or "Refer Official Notification",
                "start_date": extracted["start_date"] or "Online Active",
                "last_date": extracted["last_date"] or "Refer Official Notification",
                "apply_url": "https://www.mocktester.online",
                "exam_tag": "🔥 Govt Job Alert",
                "date": today_str
            })

        elif item_type == "admit":
            admit_cards.append({
                "id": f"admit_{len(admit_cards)+1:02d}",
                "title": title,
                "organization": org_name,
                "status": "Admit Card Released",
                "date": today_str
            })

        elif item_type == "result":
            results.append({
                "id": f"result_{len(results)+1:02d}",
                "title": title,
                "organization": org_name,
                "status": "Result Released",
                "date": today_str
            })

    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print("\n=======================================================")
    print("📊 FINAL REPORT")
    print("Jobs:", len(latest_jobs))
    print("Admit:", len(admit_cards))
    print("Results:", len(results))
    print("=======================================================")

if __name__ == "__main__":
    run_job_pipeline()
