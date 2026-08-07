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

# 🛑 OTHER STATES STRICT REJECTION LIST (Block UP, MP, Haryana, Jharkhand, etc.)
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

# 🟢 STRICT BIHAR BOARDS WHITELIST
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

# 🟢 STRICT CENTRAL BOARDS WHITELIST
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

def classify_job_board(title):
    title_lower = title.lower()
    
    # 1. First check if it's from another state (Strict Reject)
    if is_hard_rejected(title):
        return None, None
        
    # 2. Check Bihar Whitelist
    for key, full_name in BIHAR_BOARDS:
        if key in title_lower:
            return full_name, "Bihar Govt Job"
            
    # 3. Check Central Whitelist
    for key, full_name in CENTRAL_BOARDS:
        if key in title_lower:
            return full_name, "Central Govt Job"

    # If it's neither Bihar nor Central Whitelisted -> Reject it!
    return None, None

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
            if is_nav_link(title, detail_url):
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', title, flags=re.IGNORECASE).strip()
            
            # Whitelist Classification Check (Reject UP/MP/Other states)
            organization, job_type = classify_job_board(clean_title)
            if not organization:
                print(f"🚫 [REJECTED NON-BIHAR/NON-CENTRAL]: {clean_title}")
                continue

            processed_urls.add(detail_url)

            print(f"🔍 Extracting Valid Job [{len(job_cards)+1}]: {clean_title}")
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

            if len(job_cards) >= 20:
                break

    output_data = {
        "latest_jobs": job_cards
    }

    # Save to sarkarijob.json
    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Data successfully saved to '{JSON_FILENAME}'! Total Valid Bihar/Central Jobs: {len(job_cards)}")

if __name__ == "__main__":
    run_sarkari_job_scraper()
