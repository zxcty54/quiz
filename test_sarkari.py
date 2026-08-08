import os
import json
import re
from datetime import datetime
from urllib.parse import quote
import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")
TARGET_URL = "https://www.sarkariresult.com/latestjob/"
JSON_FILENAME = "sarkarijob.json"

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.sarkariresult.com/'
}

# State Rejection Filter (Ignores other states before visiting inner links)
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "lucknow", "uttar pradesh", " up ", "uppsc", 
    "madhya pradesh", " mp ", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc", 
    "maharashtra", "mpsc", "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", 
    "gujarat", "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "telangana", 
    "tspsc", "assam", "chhattisgarh", "delhi", "dsssb", "uttarakhand", "ukpsc", "uksssc",
    "cuttack", "odisha", "orissa", "khordha", "balipatna"
]

SKIP_NAV_KEYWORDS = [
    "sarkari result", "latest job", "admit card", "admission", "result", 
    "terms and conditions", "contact us", "privacy policy", "disclaimer", 
    "about us", "home", "syllabus", "answer key", "certificate verification"
]

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
    ("icsi", "Institute of Company Secretaries of India (ICSI)"),
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

def fetch_inner_article_html(url):
    """Fetches full HTML of the individual job detail page."""
    try:
        res = requests.get(url, headers=HEADERS, timeout=15)
        if res.status_code == 200 and len(res.text) > 2000:
            return res.text
    except Exception:
        pass

    try:
        encoded_url = quote(url)
        api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
        res = requests.get(api_endpoint, timeout=30)
        if res.status_code == 200:
            return res.text
    except Exception as e:
        print(f"⚠️ ScrapingAnt error for {url}: {e}")

    return None

# -------------------------------------------------------------
# 🎯 TARGETED INNER ARTICLE PARSER (BASED ON YOUR SCREENSHOT)
# -------------------------------------------------------------
def parse_inner_article_page(html_content):
    """
    Parses inner SarkariResult page structure shown in the screenshot:
    - Heading: 'Vacancy Details Total : 20 Post'
    - Table: Columns ['Post Name', 'Total Post', 'Exam Eligibility']
    """
    if not html_content:
        return {}

    soup = BeautifulSoup(html_content, 'html.parser')
    page_text = soup.get_text()

    # 1. TOTAL VACANCIES EXTRACTION
    extracted_vacancies = None

    # Matches heading pattern from image: 'Vacancy Details Total : 20 Post'
    v_match = re.search(r'Vacancy\s*Details\s*Total\s*:\s*(\d+)\s*Post', page_text, re.IGNORECASE)
    if not v_match:
        v_match = re.search(r'Total\s*(?:Post|Vacancy)\s*:\s*(\d+)', page_text, re.IGNORECASE)
    
    if v_match:
        extracted_vacancies = f"{v_match.group(1)} Posts"

    # 2. TABLE PARSING FOR ELIGIBILITY & VACANCY
    qualification_list = []
    tables = soup.find_all('table')

    for table in tables:
        rows = table.find_all('tr')
        if not rows:
            continue

        header_text = clean_text(rows[0].text).lower()

        # Target table with headers: 'Post Name', 'Total Post', 'Eligibility'
        if "post name" in header_text or "total post" in header_text or "eligibility" in header_text:
            for row in rows[1:]:  # Skip table header row
                cols = row.find_all(['td', 'th'])
                if len(cols) >= 3:
                    post_count = clean_text(cols[1].text)
                    elig_text = clean_text(cols[2].text)

                    if not extracted_vacancies and post_count.isdigit():
                        extracted_vacancies = f"{post_count} Posts"

                    if elig_text and len(elig_text) > 5:
                        clean_elig = re.sub(r'\s+', ' ', elig_text).strip()
                        qualification_list.append(clean_elig)

                elif len(cols) == 2:
                    elig_text = clean_text(cols[1].text)
                    if elig_text and len(elig_text) > 5:
                        qualification_list.append(clean_text(cols[1].text))

    # Format extracted qualification
    if qualification_list:
        qualification = qualification_list[0]
    else:
        page_text_lower = page_text.lower()
        if "b.com" in page_text_lower or "commerce" in page_text_lower:
            qualification = "Bachelor Degree in Commerce (B.Com)"
        elif "bachelor" in page_text_lower or "graduation" in page_text_lower or "degree" in page_text_lower:
            qualification = "Bachelor Degree in Any Stream"
        elif "12th" in page_text_lower or "intermediate" in page_text_lower:
            qualification = "Class 12th Pass"
        elif "10th" in page_text_lower or "high school" in page_text_lower:
            qualification = "Class 10th Pass / ITI"
        elif "diploma" in page_text_lower or "b.e" in page_text_lower or "b.tech" in page_text_lower:
            qualification = "Diploma / Engineering Degree"
        else:
            qualification = "Refer Official Notification"

    if not extracted_vacancies:
        extracted_vacancies = "Refer Official Notification"

    # 3. APPLICATION START DATE
    start_date = "Online Active"
    start_match = re.search(r'Application\s*Begin\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
    if start_match:
        start_date = start_match.group(1).strip()

    # 4. APPLICATION LAST DATE
    last_date = None
    last_match = re.search(r'Last\s*Date\s*(?:for\s*Apply|Online)?\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
    if last_match:
        last_date = last_match.group(1).strip()

    # 5. APPLICATION FEE
    fee_details = "Refer Notification"
    fee_match = re.search(r'(General\s*/\s*OBC[^\n\r<]+)', page_text, re.IGNORECASE)
    if fee_match:
        fee_details = fee_match.group(1).strip()[:100]

    return {
        "total_vacancies": extracted_vacancies,
        "qualification": qualification,
        "start_date": start_date,
        "last_date": last_date,
        "application_fee": fee_details
    }

# -------------------------------------------------------------
# MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_sarkari_job_scraper():
    print("🔄 Step 1: Fetching Main SarkariResult Listing Page...")
    
    encoded_url = quote(TARGET_URL)
    api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
    
    try:
        res = requests.get(api_endpoint, timeout=35)
        main_html = res.text if res.status_code == 200 else None
    except Exception as e:
        print(f"❌ Main page fetch error: {e}")
        return

    if not main_html:
        print("❌ Main page fetch failed!")
        return

    soup = BeautifulSoup(main_html, 'html.parser')
    post_div = soup.find('div', id='post') or soup.find('body')
    links = post_div.find_all('a', href=True) if post_div else soup.find_all('a', href=True)

    job_cards = []
    processed_urls = set()

    print(f"🔎 Found {len(links)} links on main page. Filtering target board links FIRST...\n")

    for link in links:
        title = clean_text(link.text)
        detail_url = link['href'].strip()

        if len(title) > 10 and "sarkariresult.com" in detail_url and detail_url not in processed_urls:
            
            if is_nav_link(title, detail_url):
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', title, flags=re.IGNORECASE).strip()
            
            # STAGE 1: Classify BEFORE fetching inner link!
            organization, job_type = classify_job_board(clean_title)
            if not organization:
                continue

            processed_urls.add(detail_url)

            # STAGE 2: VISIT TARGET JOB POST PAGE
            print(f"📄 [MATCHED TARGET JOB]: {clean_title}")
            print(f"🔗 [VISITING URL]: {detail_url}")
            
            inner_html = fetch_inner_article_html(detail_url)
            inner_data = parse_inner_article_page(inner_html)

            # Fallback for Last Date
            title_date_match = re.search(r'Last\s*Date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', title, re.IGNORECASE)
            final_last_date = inner_data.get("last_date") or (title_date_match.group(1) if title_date_match else None) or "Refer Notification"

            if is_date_expired(final_last_date):
                print(f"⏰ [SKIPPED EXPIRED]: {clean_title} (Last Date: {final_last_date})\n")
                continue

            job_card = {
                "id": f"job_{len(job_cards)+1:02d}",
                "title": clean_title,
                "organization": organization,
                "job_type": job_type,
                "post_name": clean_title,
                "total_vacancies": inner_data.get("total_vacancies", "Refer Notification"),
                "qualification": inner_data.get("qualification", "Refer Official Notification"),
                "application_fee": inner_data.get("application_fee", "Refer Notification"),
                "start_date": inner_data.get("start_date", "Online Active"),
                "last_date": final_last_date,
                "apply_url": "https://www.mocktester.online"
            }
            
            job_cards.append(job_card)
            print(f"✅ Extracted: Vacancies = {job_card['total_vacancies']} | Qualification = {job_card['qualification'][:60]}...\n")

            if len(job_cards) >= 20:
                break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Saved {len(job_cards)} target jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_sarkari_job_scraper()
