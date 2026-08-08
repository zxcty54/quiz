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
MAX_PAGES = 10  # Kitne pages tak scan karna hai

# Rejection Lists for Non-Bihar / Other States
OTHER_STATES_REJECT = [
    "upsss", "upsssc", "upeida", "upscidc", "upsrtc", "mpesb", "jssc", "hartron", 
    "skau", "kurukshetra", "banda", "uppsc", "mppsc", "rpsc", "hpsc", 
    "mpsc", "jpsc", "wbpsc", "punjab", "gujarat", "kerala", "karnataka", 
    "tamil nadu", "andhra", "telangana", "tspsc", "assam", "chhattisgarh", 
    "dsssb", "uttarakhand", "ukpsc"
]

BIHAR_KEYWORDS = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron", "bcece"]

SKIP_URL_PATTERNS = [
    "/category/", "/tag/", "/page/", "/about-us", "/privacy-policy", 
    "/contact-us", "/disclaimer", "/sitemap", "/terms", "indgovtjobs.net/$"
]

def clean_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

# ⏰ Date Expiry Check Function
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

# 🌐 Robust HTML Fetcher (curl_cffi -> ScrapingAnt Fallback)
def fetch_page_html(target_url):
    # Method 1: Direct curl_cffi Chrome Impersonation
    if cffi_requests:
        try:
            res = cffi_requests.get(target_url, impersonate="chrome120", timeout=12)
            if res.status_code == 200 and len(res.text) > 2000:
                return res.text
        except Exception:
            pass

    # Method 2: ScrapingAnt API Proxy Fallback
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
        print(f"⚠️ ScrapingAnt API error: {e}")

    return None

# 🎯 STEP 2: Inner Article Page HTML Table Parser
def parse_inner_article_table(article_url):
    html = fetch_page_html(article_url)
    if not html:
        return {}

    soup = BeautifulSoup(html, 'html.parser')
    page_text = soup.get_text()

    organization = "Central / Bihar Govt Department"
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
                    num_match = re.search(r'(\d+)', val_text)
                    vacancies = f"{num_match.group(1)} Posts" if num_match else val_text

                elif any(k in key_text for k in ["closing date", "last date", "end date"]):
                    d_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val_text)
                    last_date = d_match.group(0) if d_match else val_text

                elif any(k in key_text for k in ["opening date", "start date", "application begin"]):
                    d_match = re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', val_text)
                    if d_match:
                        start_date = d_match.group(0)

                elif any(k in key_text for k in ["qualification", "educational", "eligibility"]):
                    qualification = val_text

    # Regex Fallbacks if Table incomplete
    if not last_date:
        l_match = re.search(r'(?:Closing\s*Date|Last\s*Date)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', page_text, re.IGNORECASE)
        if l_match:
            last_date = l_match.group(1)

    if not vacancies:
        v_match = re.search(r'(\d+)\s*(?:Vacancies|Posts|Post)', page_text, re.IGNORECASE)
        if v_match:
            vacancies = f"{v_match.group(1)} Posts"
        else:
            vacancies = "Various Posts" if "various" in page_text.lower() else "Refer Official Notification"

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
            print(f"❌ Could not load Category Page {page_num}")
            break

        soup = BeautifulSoup(page_html, 'html.parser')
        
        # Extract ALL links from page and filter job post URLs
        all_a_tags = soup.find_all('a', href=True)
        valid_job_links = []

        for a in all_a_tags:
            href = a['href'].strip()
            full_url = urljoin(BASE_URL, href)
            text = clean_text(a.text)

            # Link Filter Criteria
            if len(text) > 12 and "indgovtjobs.net" in full_url:
                if not any(pattern in full_url for pattern in SKIP_URL_PATTERNS):
                    if full_url not in processed_urls:
                        valid_job_links.append((text, full_url))

        print(f"📑 Found {len(valid_job_links)} valid job post links on Page {page_num}")

        for raw_title, article_url in valid_job_links:
            clean_title = re.sub(r'IndGovtjobs.*$', '', raw_title, flags=re.IGNORECASE).strip()
            clean_title = re.sub(r'Read\s*More$', '', clean_title, flags=re.IGNORECASE).strip()

            if is_hard_rejected(clean_title):
                print(f"🚫 [REJECTED OTHER STATE]: {clean_title}")
                continue

            processed_urls.add(article_url)

            # Step 2: Visit Inner Detail Page & Parse HTML Table
            print(f"🔗 [STEP 2: INNER PARSE]: {clean_title}")
            inner_data = parse_inner_article_table(article_url)

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

    print(f"🎉 Success! Processed and saved {len(job_cards)} active jobs into '{JSON_FILENAME}'.")

if __name__ == "__main__":
    run_indgovtjobs_scraper()
