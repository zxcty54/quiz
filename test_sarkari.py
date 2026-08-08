import os
import json
import re
from datetime import datetime
from urllib.parse import quote, urljoin
from bs4 import BeautifulSoup

try:
    from curl_cffi import requests as cffi_requests
except ImportError:
    cffi_requests = None

import requests

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")
BASE_URL = "https://www.indgovtjobs.net/category/central-government-jobs/"
JSON_FILENAME = "sarkarijob.json"
MAX_PAGES = 10 

# Rejection Lists for non-job links & non-target states
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "uppsc", "mppsc", "rpsc", "hpsc", 
    "mpsc", "jpsc", "wbpsc", "punjab", "gujarat", "kerala", "karnataka", 
    "tamil nadu", "andhra", "telangana", "tspsc", "assam", "chhattisgarh", 
    "dsssb", "uttarakhand", "ukpsc"
]

GARBAGE_TITLE_KEYWORDS = [
    "typing test", "pdf", "editor", "quiz", "tools", "maharashtra jobs", 
    "ap jobs", "mh jobs", "tn jobs", "gk quiz", "mcq", "indian government jobs",
    "indgovtjobs", "about us", "privacy policy", "disclaimer", "contact us"
]

JOB_MUST_KEYWORDS = [
    "recruitment", "vacancy", "posts", "post", "apprentice", "officer", 
    "manager", "assistant", "technician", "engineer", "cadre", "commission"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece"]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def is_garbage_link(text):
    text_lower = text.lower()
    # Reject if contains garbage keywords or doesn't contain a real job keyword
    if any(g in text_lower for g in GARBAGE_TITLE_KEYWORDS):
        return True
    if not any(j in text_lower for j in JOB_MUST_KEYWORDS):
        return True
    return False

# 🧹 Clean Title Function
def sanitize_title(raw_title):
    # Remove newlines
    title = raw_title.replace('\n', ' ')
    # Remove leading category labels
    title = re.sub(r'^(?:Central|State|Bihar)\s*Govt\s*', '', title, flags=re.IGNORECASE)
    # Remove trailing IndGovtjobs & Dates (e.g. IndGovtjobs 7 Aug 2026)
    title = re.sub(r'IndGovtjobs.*$', '', title, flags=re.IGNORECASE)
    title = re.sub(r'\b\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\b.*$', '', title, flags=re.IGNORECASE)
    title = re.sub(r'Read\s*More.*$', '', title, flags=re.IGNORECASE)
    # Strip whitespace
    return re.sub(r'\s+', ' ', title).strip()

# ⏰ Date Expiry Check
def is_date_expired(last_date_str):
    if not last_date_str or "Refer" in last_date_str or "N/A" in last_date_str:
        return False
        
    date_match = re.search(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})', last_date_str)
    if date_match:
        try:
            day, month, year = map(int, date_match.groups())
            if year < 100:
                year += 2000
            last_dt = datetime(year, month, day).date()
            if last_dt < datetime.now().date():
                return True
        except Exception:
            pass
    return False

# 🏛️ Extract Organization Name from Title
def extract_organization_from_title(title):
    org_patterns = [
        (r'^\s*([A-Za-z0-9\s]{2,15})\s+Recruitment', 1),
        (r'^\s*([A-Za-z0-9\s]{2,15})\s+Vacancies', 1),
        (r'^\s*([A-Za-z0-9\s]{2,15})\s+Jobs', 1)
    ]
    for pattern, grp in org_patterns:
        match = re.search(pattern, title, re.IGNORECASE)
        if match:
            org = match.group(grp).strip()
            if len(org) > 1 and org.lower() not in ["central", "state", "bihar"]:
                return org
    return "Central / Bihar Govt Department"

# 🌐 HTML Fetcher (curl_cffi -> ScrapingAnt Fallback)
def fetch_page_html(target_url):
    if cffi_requests:
        try:
            res = cffi_requests.get(target_url, impersonate="chrome120", timeout=12)
            if res.status_code == 200 and len(res.text) > 2000:
                return res.text
        except Exception:
            pass

    encoded_url = quote(target_url)
    api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=false"
    try:
        res = requests.get(api_endpoint, timeout=30)
        if res.status_code == 200 and len(res.text) > 1000:
            return res.text
        else:
            fallback_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
            f_res = requests.get(fallback_endpoint, timeout=40)
            if f_res.status_code == 200:
                return f_res.text
    except Exception as e:
        print(f"⚠️ ScrapingAnt error: {e}")

    return None

# 🎯 Inner Article Table & Text Parser
def parse_inner_article_table(article_url, clean_title):
    html = fetch_page_html(article_url)
    if not html:
        return {}

    soup = BeautifulSoup(html, 'html.parser')
    page_text = soup.get_text()

    organization = extract_organization_from_title(clean_title)
    vacancies = None
    qualification = "Refer Official Notification"
    last_date = None
    start_date = "Online Active"

    # Search for Key-Value Tables inside the post
    tables = soup.find_all('table')
    for table in tables:
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all(['td', 'th'])
            if len(cells) >= 2:
                key_text = clean_text(cells[0].text).lower()
                val_text = clean_text(cells[1].text)

                if any(k in key_text for k in ["organisation", "organization", "recruitment board"]):
                    if val_text and len(val_text) < 60:
                        organization = val_text

                elif any(k in key_text for k in ["total vacancies", "total vacancy", "no. of post", "vacancies"]):
                    # Don't match years (e.g. 2025, 2026, 2027) as vacancies!
                    nums = [n for n in re.findall(r'\b\d+\b', val_text) if int(n) not in [2024, 2025, 2026, 2027]]
                    if nums:
                        vacancies = f"{nums[0]} Posts"

                elif any(k in key_text for k in ["closing date", "last date", "end date"]):
                    d_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val_text)
                    last_date = d_match.group(0) if d_match else val_text

                elif any(k in key_text for k in ["opening date", "start date", "application begin"]):
                    d_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val_text)
                    if d_match:
                        start_date = d_match.group(0)

                elif any(k in key_text for k in ["qualification", "educational", "eligibility"]):
                    qualification = val_text

    # Extract Vacancies from Title if Table missed it
    if not vacancies:
        v_match = re.search(r'[-–—]\s*(\d+)\s*(?:[A-Za-z\s,]+)?\s*Posts', clean_title, re.IGNORECASE)
        if not v_match:
            v_match = re.search(r'(\d+)\s*(?:Vacancies|Posts)', clean_title, re.IGNORECASE)
        if v_match and int(v_match.group(1)) not in [2024, 2025, 2026, 2027]:
            vacancies = f"{v_match.group(1)} Posts"

    if not vacancies:
        vacancies = "Various Posts" if "various" in page_text.lower() else "Refer Official Notification"

    # Regex Fallback for Last Date
    if not last_date:
        l_match = re.search(r'(?:Closing\s*Date|Last\s*Date)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
        if l_match:
            last_date = l_match.group(1)

    # Qualification Fallback
    if qualification == "Refer Official Notification":
        if "10th" in page_text or "Matriculation" in page_text:
            qualification = "Class 10th Pass / ITI"
        elif "12th" in page_text or "Intermediate" in page_text:
            qualification = "Class 12th Pass"
        elif "Bachelor" in page_text or "Degree" in page_text or "Graduation" in page_text:
            qualification = "Bachelor Degree in Any Stream"
        elif "Diploma" in page_text or "B.E" in page_text or "B.Tech" in page_text:
            qualification = "Diploma / Engineering Degree"

    return {
        "organization": organization,
        "total_vacancies": vacancies,
        "qualification": qualification,
        "start_date": start_date,
        "last_date": last_date or "Refer Notification"
    }

# -------------------------------------------------------------
# Main Execution Pipeline
# -------------------------------------------------------------
def run_indgovtjobs_scraper():
    job_cards = []
    processed_urls = set()

    for page_num in range(1, MAX_PAGES + 1):
        page_url = BASE_URL if page_num == 1 else f"{BASE_URL}page/{page_num}/"
        print(f"🌐 [STEP 1] Fetching Listing Page {page_num}: {page_url}")

        page_html = fetch_page_html(page_url)
        if not page_html:
            print(f"❌ Could not load Page {page_num}")
            break

        soup = BeautifulSoup(page_html, 'html.parser')
        
        # Scan links
        all_a_tags = soup.find_all('a', href=True)
        valid_job_links = []

        for a in all_a_tags:
            href = a['href'].strip()
            full_url = urljoin(BASE_URL, href)
            raw_text = clean_text(a.text)

            if len(raw_text) > 10 and "indgovtjobs.net" in full_url:
                if "/category/" not in full_url and "/tag/" not in full_url and "/page/" not in full_url:
                    if not is_garbage_link(raw_text) and full_url not in processed_urls:
                        valid_job_links.append((raw_text, full_url))

        print(f"📑 Found {len(valid_job_links)} clean job links on Page {page_num}")

        for raw_title, article_url in valid_job_links:
            clean_title = sanitize_title(raw_title)

            if is_hard_rejected(clean_title) or is_garbage_link(clean_title):
                print(f"🚫 [SKIPPED NON-JOB]: {clean_title}")
                continue

            processed_urls.add(article_url)

            # Step 2: Visit Inner Detail Page & Parse Table
            print(f"🔗 [PARSING INNER PAGE]: {clean_title}")
            inner_data = parse_inner_article_table(article_url, clean_title)

            final_last_date = inner_data.get("last_date", "Refer Notification")

            # Skip Expired Jobs
            if is_date_expired(final_last_date):
                print(f"⏰ [EXPIRED SKIPPED]: {clean_title} (Last Date: {final_last_date})")
                continue

            job_type = "Bihar Govt Job" if any(b in clean_title.lower() for b in BIHAR_KEYWORDS) else "Central Govt Job"

            job_card = {
                "id": f"job_{len(job_cards)+1:02d}",
                "title": clean_title,
                "organization": inner_data.get("organization", "Central / Bihar Govt Department"),
                "job_type": job_type,
                "post_name": clean_title,
                "total_vacancies": inner_data.get("total_vacancies", "Various Posts"),
                "qualification": inner_data.get("qualification", "Refer Official Notification"),
                "start_date": inner_data.get("start_date", "Online Active"),
                "last_date": final_last_date,
                "apply_url": "https://www.mocktester.online"
            }

            job_cards.append(job_card)
            print(f"✅ Clean Job Added [{len(job_cards)}]: {clean_title}")
            print(f"   Org: {job_card['organization']} | Vacancies: {job_card['total_vacancies']} | Last Date: {job_card['last_date']}\n")

            if len(job_cards) >= 20:
                break

        if len(job_cards) >= 20:
            break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Saved {len(job_cards)} clean active jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_indgovtjobs_scraper()
