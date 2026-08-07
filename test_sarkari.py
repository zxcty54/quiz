import os
import json
import re
from urllib.parse import quote
import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# Configuration & API Setup
# -------------------------------------------------------------
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")

client = Groq(api_key=GROQ_API_KEY) if GROQ_API_KEY else None

TARGET_URL = "https://www.sarkariresult.com/latestjob/"
JSON_FILENAME = "sarkarijob.json"

OTHER_STATES_REJECT = [
    "aiims", "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav ", 
    "uttar pradesh", " up ", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "maharashtra", "mpsc", 
    "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", "gujarat", 
    "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "ap mahesh", "mahesh bank",
    "telangana", "tspsc", "assam", "chhattisgarh", "delhi", "dsssb"
]

SKIP_NAV_KEYWORDS = [
    "sarkari result", "latest job", "admit card", "admission", "result", 
    "terms and conditions", "contact us", "privacy policy", "disclaimer", 
    "about us", "home", "syllabus", "answer key", "certificate verification"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece", "amin"]

CENTRAL_BOARDS = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"),
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("navy", "Indian Navy"),
    ("army", "Indian Army"),
    ("air force", "Indian Air Force"),
    ("airforce", "Indian Air Force"),
    ("drdo", "Defence Research and Development Organisation (DRDO)"),
    ("isro", "Indian Space Research Organisation (ISRO)"),
    ("india post", "Department of Posts / India Post")
]

def clean_html_text(text):
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

def detect_organization_and_type(title):
    title_lower = title.lower()
    for key in BIHAR_KEYWORDS:
        if key in title_lower:
            return "Bihar Govt Agency / Commission", "Bihar Govt Job"
            
    for key, org_full_name in CENTRAL_BOARDS:
        if key in title_lower:
            return org_full_name, "Central Govt Job"
            
    return "Central / Bihar Govt Agency", "Central Govt Job"

def fetch_page_via_scrapingant(url):
    encoded_url = quote(url)
    api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
    try:
        res = requests.get(api_endpoint, timeout=35)
        if res.status_code == 200:
            return res.text
    except Exception as e:
        print(f"⚠️ ScrapingAnt error for {url}: {e}")
    return None

def extract_inner_details_ai(page_text):
    if not client or not page_text:
        return {}

    prompt = f"""
    Extract the following details strictly from the text in JSON format:
    - start_date: Application Start Date (e.g. "05/08/2026")
    - last_date: Application Last Date (e.g. "28/08/2026")
    - total_vacancies: Total Posts (e.g. "34 Posts")
    - qualification: Required Educational Qualification (e.g. "10th / 12th / Degree / B.Tech")

    Text:
    {page_text[:3500]}
    """

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": "You extract government job details into strict JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.01,
            response_format={"type": "json_object"}
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:
        print(f"⚠️ AI Parsing Warning: {e}")
        return {}

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
        title = clean_html_text(link.text)
        detail_url = link['href'].strip()

        if len(title) > 10 and "sarkariresult.com" in detail_url and detail_url not in processed_urls:
            if is_nav_link(title, detail_url) or is_hard_rejected(title):
                continue

            processed_urls.add(detail_url)
            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', title, flags=re.IGNORECASE).strip()
            organization, job_type = detect_organization_and_type(clean_title)

            print(f"🔍 Extracting [{len(job_cards)+1}]: {clean_title}")
            inner_html = fetch_page_via_scrapingant(detail_url)
            inner_text = clean_html_text(inner_html) if inner_html else ""

            ai_data = extract_inner_details_ai(inner_text)

            job_card = {
                "id": f"job_{len(job_cards)+1:02d}",
                "title": clean_title,
                "organization": organization,
                "job_type": job_type,
                "post_name": clean_title,
                "total_vacancies": ai_data.get("total_vacancies") or "Various Posts",
                "qualification": ai_data.get("qualification") or "Refer Official Notification",
                "start_date": ai_data.get("start_date") or "Online Active",
                "last_date": ai_data.get("last_date") or "Refer Notification",
                "apply_url": "https://www.mocktester.online"
            }
            job_cards.append(job_card)

            if len(job_cards) >= 20:  # Top 20 active Bihar/Central jobs
                break

    output_data = {
        "latest_jobs": job_cards
    }

    # Save directly to sarkarijob.json
    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Data successfully saved to '{JSON_FILENAME}'! Total Jobs: {len(job_cards)}")

if __name__ == "__main__":
    run_sarkari_job_scraper()
