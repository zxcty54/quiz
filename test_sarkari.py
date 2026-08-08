import os
import json
import re
from datetime import datetime
import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# Setup & Configs
# -------------------------------------------------------------
BASE_URL = "https://www.indgovtjobs.net/category/central-government-jobs/"
JSON_FILENAME = "sarkarijob.json"
MAX_PAGES = 2 

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Referer': 'https://www.indgovtjobs.net/'
}

# Rejection Filter for Non-Bihar / Other States
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "lucknow", "uttar pradesh", "uppsc", 
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc", 
    "maharashtra", "mpsc", "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", 
    "gujarat", "kerala", "karnataka", "tamil nadu", "andhra", "telangana", 
    "tspsc", "assam", "chhattisgarh", "delhi", "dsssb", "uttarakhand", "ukpsc"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece"]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def is_date_expired(last_date_str):
    if not last_date_str or "Refer" in last_date_str:
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

# 1. Title Se Direct Vacancies Extract Karne Wala Logic (e.g. "433 Posts", "2615 Posts")
def extract_vacancies_from_title(title):
    match = re.search(r'[-–—]\s*(\d+)\s*(?:[A-Za-z\s,]+)?\s*Posts', title, re.IGNORECASE)
    if not match:
        match = re.search(r'(\d+)\s*(?:Vacancies|Posts)', title, re.IGNORECASE)
    if match:
        return f"{match.group(1)} Posts"
    return None

# 2. Article Page Par Jaakar Exact Last Date & Qualification Scrape Karne Wala Parser
def parse_inner_article_details(article_url):
    try:
        res = requests.get(article_url, headers=HEADERS, timeout=12)
        if res.status_code != 200:
            return {}

        soup = BeautifulSoup(res.text, 'html.parser')
        page_text = soup.get_text()

        last_date = None
        qualification = "Refer Official Notification"
        vacancies = None

        # Table & Paragraph parsing
        tables = soup.find_all('table')
        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cells = row.find_all(['td', 'th'])
                if len(cells) >= 2:
                    header = clean_text(cells[0].text).lower()
                    val = clean_text(cells[1].text)

                    if any(k in header for k in ["closing date", "last date", "end date"]):
                        date_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val)
                        last_date = date_match.group(0) if date_match else val
                    elif any(k in header for k in ["qualification", "educational", "eligibility"]):
                        qualification = val
                    elif any(k in header for k in ["total vacancy", "no. of post", "vacancies"]):
                        vacancies = val

        # Regex Fallback for Last Date inside page
        if not last_date:
            l_match = re.search(r'(?:Last\s*Date|Closing\s*Date|Apply\s*Last\s*Date)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
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

        start_date = "Online Active"
        s_match = re.search(r'(?:Start\s*Date|Opening\s*Date)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
        if s_match:
            start_date = s_match.group(1)

        return {
            "total_vacancies": vacancies,
            "qualification": qualification,
            "start_date": start_date,
            "last_date": last_date or "Refer Notification"
        }

    except Exception as e:
        print(f"⚠️ Error parsing article {article_url}: {e}")
        return {}

# -------------------------------------------------------------
# Main Execution Pipeline
# -------------------------------------------------------------
def run_indgovtjobs_scraper():
    job_cards = []
    processed_urls = set()

    for page_num in range(1, MAX_PAGES + 1):
        page_url = BASE_URL if page_num == 1 else f"{BASE_URL}page/{page_num}/"
        print(f"🌐 Category Page Fetching [{page_num}/{MAX_PAGES}]: {page_url}")
        
        try:
            res = requests.get(page_url, headers=HEADERS, timeout=15)
            if res.status_code != 200:
                break

            soup = BeautifulSoup(res.text, 'html.parser')
            
            # Post links & Read More links extraction
            links = soup.find_all('a', href=True)

            for link in links:
                title = clean_text(link.text)
                article_url = link['href'].strip()

                # Clean Title if "Read More" or "IndGovtjobs" attached
                clean_title_str = re.sub(r'IndGovtjobs.*$', '', title, flags=re.IGNORECASE).strip()
                clean_title_str = re.sub(r'Read\s*More$', '', clean_title_str, flags=re.IGNORECASE).strip()

                if len(clean_title_str) > 15 and "indgovtjobs.net" in article_url and "/category/" not in article_url and article_url not in processed_urls:
                    if is_hard_rejected(clean_title_str):
                        continue

                    processed_urls.add(article_url)
                    job_type = "Bihar Govt Job" if any(b in clean_title_str.lower() for b in BIHAR_KEYWORDS) else "Central Govt Job"

                    # Title se total vacancies pehle nikaalo
                    title_vacancies = extract_vacancies_from_title(clean_title_str)

                    print(f"🔗 [INSIDE ARTICLE SCRAPE]: {clean_title_str}")
                    inner_details = parse_inner_article_details(article_url)

                    final_vacancies = title_vacancies or inner_details.get("total_vacancies") or "Various Posts"
                    final_last_date = inner_details.get("last_date", "Refer Notification")

                    # Skip Expired Jobs
                    if is_date_expired(final_last_date):
                        print(f"⏰ [EXPIRED SKIPPED]: {clean_title_str} (Last Date: {final_last_date})")
                        continue

                    job_card = {
                        "id": f"job_{len(job_cards)+1:02d}",
                        "title": clean_title_str,
                        "organization": "Central / Bihar Govt Department",
                        "job_type": job_type,
                        "post_name": clean_title_str,
                        "total_vacancies": final_vacancies,
                        "qualification": inner_details.get("qualification", "Refer Official Notification"),
                        "start_date": inner_details.get("start_date", "Online Active"),
                        "last_date": final_last_date,
                        "apply_url": "https://www.mocktester.online"
                    }

                    job_cards.append(job_card)
                    print(f"✅ Added [{len(job_cards)}]: {clean_title_str}")
                    print(f"   Vacancies: {job_card['total_vacancies']} | Last Date: {job_card['last_date']}\n")

                    if len(job_cards) >= 20:
                        break

        except Exception as e:
            print(f"🚨 Page {page_num} error: {e}")

        if len(job_cards) >= 20:
            break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Processed and saved active jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_indgovtjobs_scraper()
