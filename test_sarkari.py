import os
import json
import re
from datetime import datetime
from urllib.parse import quote, urljoin
import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")
BASE_URL = "https://www.indgovtjobs.net/category/central-government-jobs/"
JSON_FILENAME = "sarkarijob.json"
MAX_PAGES = 20  # Kitne pages tak scrape karna hai

# Non-Bihar / Other States Rejection List
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "uppsc", "mppsc", "rpsc", "hpsc", 
    "mpsc", "jpsc", "wbpsc", "punjab", "gujarat", "kerala", "karnataka", 
    "tamil nadu", "andhra", "telangana", "tspsc", "assam", "chhattisgarh", 
    "dsssb", "uttarakhand", "ukpsc"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece"]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

# ⏰ Expired Date Check Function
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

# 🌐 ScrapingAnt Fetcher to Bypass 403 Forbidden
def fetch_via_scrapingant(target_url):
    encoded_url = quote(target_url)
    api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"
    try:
        res = requests.get(api_endpoint, timeout=35)
        if res.status_code == 200:
            return res.text
        else:
            print(f"⚠️ ScrapingAnt returned status: {res.status_code}")
    except Exception as e:
        print(f"⚠️ ScrapingAnt fetch error: {e}")
    return None

# -------------------------------------------------------------
# Main Execution Pipeline
# -------------------------------------------------------------
def run_indgovtjobs_table_scraper():
    job_cards = []
    processed_titles = set()

    for page_num in range(1, MAX_PAGES + 1):
        page_url = BASE_URL if page_num == 1 else f"{BASE_URL}page/{page_num}/"
        print(f"🔄 Bypassing 403 via ScrapingAnt for Page {page_num}: {page_url}")

        html_content = fetch_via_scrapingant(page_url)
        if not html_content:
            print(f"❌ Failed to load page {page_num}")
            break

        print(f"✅ Successfully loaded Page {page_num} HTML (Status 200 OK)")
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Find all HTML Tables directly on the listing page
        tables = soup.find_all('table')
        print(f"📊 Total Tables Found on Page {page_num}: {len(tables)}")

        for table in tables:
            rows = table.find_all('tr')
            
            title = None
            post_url = "https://www.mocktester.online"
            vacancies = None
            qualification = "Refer Official Notification"
            last_date = "Refer Notification"
            start_date = "Online Active"

            for row in rows:
                cells = row.find_all(['td', 'th'])
                if len(cells) >= 2:
                    key_text = clean_text(cells[0].text).lower()
                    val_cell = cells[1]
                    val_text = clean_text(val_cell.text)

                    # Extract Title & Post Link
                    if any(k in key_text for k in ["name of post", "post name", "job title", "recruitment"]):
                        link_tag = val_cell.find('a', href=True) or row.find('a', href=True)
                        title = val_text
                        if link_tag:
                            post_url = urljoin(BASE_URL, link_tag['href'].strip())

                    # Extract Total Vacancies
                    elif any(k in key_text for k in ["total vacancy", "total vacancies", "no. of post", "vacancies", "posts"]):
                        vacancies = val_text

                    # Extract Qualification
                    elif any(k in key_text for k in ["qualification", "educational", "eligibility"]):
                        qualification = val_text

                    # Extract Closing / Last Date
                    elif any(k in key_text for k in ["closing date", "last date", "end date"]):
                        date_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val_text)
                        last_date = date_match.group(0) if date_match else val_text

            # If no direct title in key-value, check preceding header tag
            if not title:
                prev_header = table.find_previous(['h2', 'h3', 'h1'])
                if prev_header:
                    title = clean_text(prev_header.text)
                    header_link = prev_header.find('a', href=True)
                    if header_link:
                        post_url = urljoin(BASE_URL, header_link['href'].strip())

            # Clean Title String
            if title:
                clean_title = re.sub(r'IndGovtjobs.*$', '', title, flags=re.IGNORECASE).strip()
                clean_title = re.sub(r'Read\s*More$', '', clean_title, flags=re.IGNORECASE).strip()

                if len(clean_title) > 10 and clean_title not in processed_titles:
                    if is_hard_rejected(clean_title):
                        print(f"🚫 [REJECTED OTHER STATE]: {clean_title}")
                        continue

                    # Check Date Expiry
                    if is_date_expired(last_date):
                        print(f"⏰ [EXPIRED SKIPPED]: {clean_title} (Last Date: {last_date})")
                        continue

                    processed_titles.add(clean_title)

                    # Vacancy fallback if missing
                    if not vacancies:
                        v_match = re.search(r'(\d+)\s*(?:Vacancies|Posts|Post)', clean_title, re.IGNORECASE)
                        vacancies = f"{v_match.group(1)} Posts" if v_match else "Various Posts"

                    job_type = "Bihar Govt Job" if any(b in clean_title.lower() for b in BIHAR_KEYWORDS) else "Central Govt Job"

                    job_card = {
                        "id": f"job_{len(job_cards)+1:02d}",
                        "title": clean_title,
                        "organization": "Central / Bihar Govt Department",
                        "job_type": job_type,
                        "post_name": clean_title,
                        "total_vacancies": vacancies,
                        "qualification": qualification,
                        "start_date": start_date,
                        "last_date": last_date,
                        "apply_url": "https://www.mocktester.online"
                    }

                    job_cards.append(job_card)
                    print(f"✅ Added [{len(job_cards)}]: {clean_title}")
                    print(f"   Vacancies: {job_card['total_vacancies']} | Last Date: {job_card['last_date']}\n")

                    if len(job_cards) >= 20:
                        break

        if len(job_cards) >= 20:
            break

    output_data = {
        "latest_jobs": job_cards
    }

    with open(JSON_FILENAME, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"🎉 Complete! Saved {len(job_cards)} active jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_indgovtjobs_table_scraper()
