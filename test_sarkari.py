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

# 🟢 Dual Category URLs: Central Govt + State/Bihar Govt Jobs
TARGET_CATEGORIES = [
    "https://www.indgovtjobs.net/category/central-government-jobs/",
    "https://www.indgovtjobs.net/category/state-government-jobs/",
    "https://www.indgovtjobs.net/tag/bihar/"
]

JSON_FILENAME = "sarkarijob.json"
MAX_PAGES_PER_CAT = 2 

# Non-Bihar State Rejection List (UP, MP, Rajasthan, JPSC, WB etc. block honge)
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "uppsc", "mppsc", "rpsc", "hpsc", 
    "mpsc", "jpsc", "wbpsc", "punjab", "gujarat", "kerala", "karnataka", 
    "tamil nadu", "andhra", "telangana", "tspsc", "assam", "chhattisgarh", 
    "dsssb", "uttarakhand", "ukpsc", "maharashtra jobs", "ap jobs", "mh jobs", "tn jobs"
]

# Garbage Utility/Menu Blocklist
GARBAGE_KEYWORDS = [
    "typing test", "pdf editor", "quiz", "image editor", "image/pdf", "tools", 
    "gk quiz", "mcq", "indian government jobs", "about us", "privacy policy", 
    "disclaimer", "contact us", "sitemap", "home", "free pdf", "free typing"
]

# Title must have at least ONE real job indicator
JOB_MUST_KEYWORDS = [
    "recruitment", "vacancy", "vacancies", "posts", "post", "apprentice", 
    "officer", "manager", "assistant", "technician", "engineer", "cadre", "commission", "clerk", "mts"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece", "jeevika"]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

# 🛑 Strict Garbage & Menu Filter
def is_garbage_card(text, url):
    text_lower = text.lower().strip()
    url_lower = url.lower()
    
    if len(text_lower) < 12:
        return True
    if any(g in text_lower for g in GARBAGE_KEYWORDS):
        return True
    if not any(j in text_lower for j in JOB_MUST_KEYWORDS):
        return True
    if any(x in url_lower for x in ["/category/", "/tag/", "/page/", "#", "privacy-policy", "about-us", "contact-us"]):
        return True
    return False

# 🧹 Clean Title
def sanitize_title(raw_title):
    title = raw_title.replace('\n', ' ')
    title = re.sub(r'^(?:Central|State|Bihar)\s*Govt\s*', '', title, flags=re.IGNORECASE)
    title = re.sub(r'IndGovtjobs.*$', '', title, flags=re.IGNORECASE)
    title = re.sub(r'\b\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\b.*$', '', title, flags=re.IGNORECASE)
    title = re.sub(r'Read\s*More.*$', '', title, flags=re.IGNORECASE)
    return re.sub(r'\s+', ' ', title).strip()

# ⏰ Date Expiry Check
def is_date_expired(last_date_str):
    if not last_date_str or "Refer" in last_date_str or "N/A" in last_date_str:
        return False
        
    date_patterns = [
        r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
        r'(\d{1,2})[-/\s]([A-Za-z]{3,9})[-/\s](\d{4})'
    ]
    
    for pattern in date_patterns:
        match = re.search(pattern, last_date_str)
        if match:
            try:
                g1, g2, g3 = match.groups()
                if g2.isdigit():
                    day, month, year = int(g1), int(g2), int(g3)
                else:
                    day, year = int(g1), int(g3)
                    month_names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
                    month = month_names.index(g2.lower()[:3]) + 1
                
                if year < 100:
                    year += 2000
                last_dt = datetime(year, month, day).date()
                if last_dt < datetime.now().date():
                    return True
            except Exception:
                pass
    return False

# 🏛️ Organization Extract
def extract_organization_from_title(title):
    for pattern in [r'^\s*([A-Za-z0-9\s]{2,15})\s+Recruitment', r'^\s*([A-Za-z0-9\s]{2,15})\s+Vacancies']:
        match = re.search(pattern, title, re.IGNORECASE)
        if match:
            org = match.group(1).strip()
            if len(org) > 1 and org.lower() not in ["central", "state", "bihar"]:
                return org
    return "Central / Bihar Govt Department"

# 🌐 Robust HTML Fetcher
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

# 🎯 STEP 2: Inner Article Page Parser
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
                    nums = [n for n in re.findall(r'\b\d+\b', val_text) if int(n) not in [2024, 2025, 2026, 2027]]
                    if nums:
                        vacancies = f"{nums[0]} Posts"

                elif any(k in key_text for k in ["closing date", "last date", "end date"]):
                    d_match = re.search(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})', val_text)
                    last_date = d_match.group(0) if d_match else val_text

                elif any(k in key_text for k in ["opening date", "start date", "application begin"]):
                    d_match = re.search(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})', val_text)
                    if d_match:
                        start_date = d_match.group(0)

                elif any(k in key_text for k in ["qualification", "educational", "eligibility"]):
                    qualification = val_text

    # Vacancy Title Fallback
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
        l_match = re.search(r'(?:Closing\s*Date|Last\s*Date|Apply\s*Last\s*Date)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})', page_text, re.IGNORECASE)
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
# Main Execution Pipeline (Scans Central + State/Bihar Categories)
# -------------------------------------------------------------
def run_indgovtjobs_scraper():
    job_cards = []
    processed_urls = set()

    for base_cat_url in TARGET_CATEGORIES:
        print(f"\n========================================================")
        print(f"🚀 STARTING CATEGORY: {base_cat_url}")
        print(f"========================================================")

        for page_num in range(1, MAX_PAGES_PER_CAT + 1):
            page_url = base_cat_url if page_num == 1 else f"{base_cat_url}page/{page_num}/"
            print(f"🌐 [STEP 1] Fetching Listing Page {page_num}: {page_url}")

            page_html = fetch_page_html(page_url)
            if not page_html:
                print(f"❌ Could not load Page {page_num}")
                break

            soup = BeautifulSoup(page_html, 'html.parser')
            all_links = soup.find_all('a', href=True)
            valid_job_links = []

            for a_tag in all_links:
                raw_href = a_tag['href'].strip()
                full_url = urljoin(base_cat_url, raw_href)
                raw_text = clean_text(a_tag.text)

                if "indgovtjobs.net" in full_url and not is_garbage_card(raw_text, full_url):
                    if full_url not in processed_urls:
                        valid_job_links.append((raw_text, full_url))
                        processed_urls.add(full_url)

            print(f"📑 Found {len(valid_job_links)} clean job links on Page {page_num}")

            for raw_title, article_url in valid_job_links:
                clean_title = sanitize_title(raw_title)

                if is_hard_rejected(clean_title) or is_garbage_card(clean_title, article_url):
                    print(f"🚫 [SKIPPED NON-JOB]: {clean_title}")
                    continue

                # STEP 2: Visit Inner Detail Page & Parse Table
                print(f"🔗 [PARSING INNER PAGE]: {clean_title}")
                inner_data = parse_inner_article_table(article_url, clean_title)

                final_last_date = inner_data.get("last_date", "Refer Notification")

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
                print(f"   Type: {job_type} | Vacancies: {job_card['total_vacancies']} | Last Date: {job_card['last_date']}\n")

                if len(job_cards) >= 25:
                    break

            if len(job_cards) >= 25:
                break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Saved {len(job_cards)} clean active Central + Bihar jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_indgovtjobs_scraper()
