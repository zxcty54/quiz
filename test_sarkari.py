import os
import json
import re
from datetime import datetime
from urllib.parse import quote, urljoin
import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# Setup & Configurations
# -------------------------------------------------------------
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")

TARGET_URL = "https://www.sarkariresult.com/latestjob/"
JSON_FILENAME = "sarkarijob.json"

# 🛑 OTHER STATES REJECTION LIST
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "lucknow", "uttar pradesh", " up ", "uppsc", 
    "madhya pradesh", " mp ", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc", 
    "maharashtra", "mpsc", "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", 
    "gujarat", "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "telangana", 
    "tspsc", "assam", "chhattisgarh", "delhi", "dsssb", "uttarakhand", "ukpsc", "uksssc",
    "aiims", "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav "
]

SKIP_NAV_KEYWORDS = [
    "sarkari result", "latest job", "admit card", "admission", "result", 
    "terms and conditions", "contact us", "privacy policy", "disclaimer", 
    "about us", "home", "syllabus", "answer key", "certificate verification"
]

# 🟢 WHITELIST BOARDS
BIHAR_BOARDS = [
    ("bpsc", "Bihar Public Service Commission (BPSC)"),
    ("bssc", "Bihar Staff Selection Commission (BSSC)"),
    ("bpssc", "Bihar Police Subordinate Services Commission (BPSSC)"),
    ("csbc", "Central Selection Board of Constable (CSBC)"),
    ("btsc", "Bihar Technical Service Commission (BTSC)"),
    ("patna high court", "Patna High Court"),
    ("high court patna", "Patna High Court"),
    ("wcdc", "Women and Child Development Corporation Bihar"),
    ("beltron", "BELTRON Bihar"),
    ("bihar amin", "Bihar Revenue Dept (Amin)"),
    ("bihar", "Bihar State Govt Department")
]

CENTRAL_BOARDS = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"),
    ("railway", "Indian Railways"),
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("bank of baroda", "Bank of Baroda"),
    ("union bank", "Union Bank of India"),
    ("pnb", "Punjab National Bank"),
    ("indian army", "Indian Army"),
    ("indian navy", "Indian Navy"),
    ("indian air force", "Indian Air Force"),
    ("indian airforce", "Indian Air Force"),
    ("drdo", "Defence Research and Development Organisation (DRDO)"),
    ("isro", "Indian Space Research Organisation (ISRO)"),
    ("india post", "Department of Posts / India Post"),
    ("post office", "Department of Posts / India Post"),
    ("lic", "Life Insurance Corporation (LIC)"),
    ("epfo", "Employees' Provident Fund Organisation (EPFO)")
]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def is_nav_link(text, url):
    text_lower = text.lower().strip()
    if any(nav in text_lower for nav in SKIP_NAV_KEYWORDS) and len(text_lower) < 30:
        return True
    if url.rstrip('/').endswith(('sarkariresult.com', 'latestjob', 'admitcard', 'admission', 'contactus', 'terms-and-conditions')):
        return True
    return False

def is_date_expired(last_date_str):
    if not last_date_str:
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

def classify_job_board(title):
    title_lower = title.lower()
    if is_hard_rejected(title):
        return None, None
        
    for key, full_name in BIHAR_BOARDS:
        if key in title_lower:
            return full_name, "Bihar Govt Job"
            
    for key, full_name in CENTRAL_BOARDS:
        if key in title_lower:
            return full_name, "Central Govt Job"

    return None, None

def fetch_page_via_scrapingant(url):
    encoded_url = quote(url)
    api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
    try:
        res = requests.get(api_endpoint, timeout=35)
        if res.status_code == 200:
            return res.text
    except Exception as e:
        print(f"⚠️ ScrapingAnt fetch error for {url}: {e}")
    return None

# 🔍 Detail Page Parser (Visits Article Link & Scrapes Exact Vacancy, Dates & Qualification)
def parse_inner_article_page(html_content):
    if not html_content:
        return {}

    soup = BeautifulSoup(html_content, 'html.parser')
    page_text = soup.get_text()

    # 1. Total Vacancies Extraction
    vacancies = "Various Posts"
    vac_match = re.search(r'(Total\s*(?:Post|Vacancy|Vacancies)?\s*:?\s*)(\d+\s*(?:Posts|Vacancies)?)', page_text, re.IGNORECASE)
    if not vac_match:
        vac_match = re.search(r'(\d{2,6})\s*(?:Post|Posts|Vacancies|Vacancy)', page_text, re.IGNORECASE)
    if vac_match:
        vacancies = f"{vac_match.group(2 if len(vac_match.groups())>=2 else 1).strip()} Posts"
        vacancies = re.sub(r'Posts\s*Posts', 'Posts', vacancies, flags=re.IGNORECASE)

    # 2. Application Start Date
    start_date = "Online Active"
    start_match = re.search(r'(Application\s*Begin\s*:?\s*)(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
    if start_match:
        start_date = start_match.group(2).strip()

    # 3. Application Last Date
    last_date = None
    last_match = re.search(r'(Last\s*Date\s*(?:for\s*Apply|Online)?\s*:?\s*)(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
    if last_match:
        last_date = last_match.group(2).strip()

    # 4. Educational Qualification Extraction
    qualification = "Refer Official Notification"
    if "10th" in page_text or "High School" in page_text:
        qualification = "Class 10th Pass / ITI"
    elif "12th" in page_text or "Intermediate" in page_text:
        qualification = "Class 12th Pass"
    elif "Bachelor" in page_text or "Degree" in page_text or "Graduation" in page_text:
        qualification = "Bachelor Degree in Any Stream"
    elif "Diploma" in page_text or "B.E" in page_text or "B.Tech" in page_text:
        qualification = "Diploma / Engineering Degree"

    return {
        "total_vacancies": vacancies,
        "qualification": qualification,
        "start_date": start_date,
        "last_date": last_date
    }

# -------------------------------------------------------------
# Main Execution Pipeline
# -------------------------------------------------------------
def run_sarkari_job_scraper():
    print("🔄 Fetching Main SarkariResult Page via ScrapingAnt...")
    main_html = fetch_page_via_scrapingant(TARGET_URL)
    
    if not main_html:
        print("❌ Main page fetch failed!")
        return

    soup = BeautifulSoup(main_html, 'html.parser')
    post_div = soup.find('div', id='post') or soup.find('body')
    links = post_div.find_all('a', href=True) if post_div else soup.find_all('a', href=True)

    job_cards = []
    processed_urls = set()

    for link in links:
        title = clean_text(link.text)
        detail_url = link['href'].strip()

        if len(title) > 10 and "sarkariresult.com" in detail_url and detail_url not in processed_urls:
            if is_nav_link(title, detail_url):
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', title, flags=re.IGNORECASE).strip()
            
            organization, job_type = classify_job_board(clean_title)
            if not organization:
                continue

            processed_urls.add(detail_url)

            # 🌐 Inside Navigation: Fetch Inner Article Page using detail_url
            print(f"🔗 [INSIDE ARTICLE] Scrape link: {detail_url}")
            inner_html = fetch_page_via_scrapingant(detail_url)
            
            # Extract Inner Article Details
            inner_data = parse_inner_article_page(inner_html)

            # Extract Last Date (Fallback to Title Date if Inner Page fails)
            title_date_match = re.search(r'Last\s*Date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', title, re.IGNORECASE)
            final_last_date = inner_data.get("last_date") or (title_date_match.group(1) if title_date_match else None) or "Refer Notification"

            # ⏰ Expired Check
            if is_date_expired(final_last_date):
                print(f"⏰ [EXPIRED SKIPPED]: {clean_title} (Last Date: {final_last_date})")
                continue

            job_card = {
                "id": f"job_{len(job_cards)+1:02d}",
                "title": clean_title,
                "organization": organization,
                "job_type": job_type,
                "post_name": clean_title,
                "total_vacancies": inner_data.get("total_vacancies", "Various Posts"),
                "qualification": inner_data.get("qualification", "Refer Official Notification"),
                "start_date": inner_data.get("start_date", "Online Active"),
                "last_date": final_last_date,
                "apply_url": "https://www.mocktester.online"
            }
            
            job_cards.append(job_card)
            print(f"✅ Added [{len(job_cards)}]: {clean_title} | Vacancies: {job_card['total_vacancies']} | Last Date: {job_card['last_date']}\n")

            if len(job_cards) >= 20:
                break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Saved {len(job_cards)} active jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_sarkari_job_scraper()
