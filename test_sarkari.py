import os
import json
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# Test Config & Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

# Full Real Chrome Browser Headers to Bypass 403 Forbidden
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer': 'https://www.google.com/',
    'Sec-Ch-Ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'cross-site',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1'
}

OTHER_STATES_REJECT = [
    "aiims", "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav ", 
    "uttar pradesh", " up ", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "maharashtra", "mpsc", 
    "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", "gujarat", 
    "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "ap mahesh", "mahesh bank",
    "telangana", "tspsc", "assam", "chhattisgarh", "delhi", "dsssb"
]

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def is_date_expired(last_date_str):
    if not last_date_str:
        return False

    date_patterns = [
        r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
        r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'
    ]

    for pattern in date_patterns:
        match = re.search(pattern, last_date_str)
        if match:
            try:
                groups = match.groups()
                if len(groups[0]) == 4:
                    dt = datetime(int(groups[0]), int(groups[1]), int(groups[2]))
                else:
                    year = int(groups[2])
                    if year < 100:
                        year += 2000
                    dt = datetime(year, int(groups[1]), int(groups[0]))

                today = datetime.now()
                if dt.date() < today.date():
                    return True
            except Exception:
                pass

    return False

# -------------------------------------------------------------
# SarkariResult Testing Function
# -------------------------------------------------------------
def test_sarkari_result_scraper():
    url = "https://www.sarkariresult.com/latestjob/"
    print(f"🧪 [TEST MODE] Scraping SarkariResult directly: {url}\n")

    try:
        # Impersonate chrome124 to bypass 403 Cloudflare WAF Block
        res = requests.get(
            url, 
            headers=HEADERS, 
            timeout=20, 
            verify=False, 
            impersonate="chrome124"
        )

        if res.status_code != 200:
            print(f"❌ Failed to reach SarkariResult! Status Code: {res.status_code}")
            return

        print("✅ Successfully Bypassed 403! Status Code 200 OK\n")

        soup = BeautifulSoup(res.content, "html.parser")
        post_div = soup.find('div', id='post') or soup.find('body')
        a_tags = post_div.find_all('a', href=True) if post_div else []

        valid_links = []

        for a in a_tags[:40]:
            href = a['href'].strip()
            full_text = clean_html_text(a.text)

            if len(full_text) < 8 or "sarkariresult.com" not in href:
                continue

            # 1. Check Other State Rejection
            if is_hard_rejected(full_text):
                print(f"🚫 [REJECTED STATE/ENTITY]: {full_text}")
                continue

            # 2. Extract Last Date
            last_date_match = re.search(r'Last\s*Date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', full_text, re.IGNORECASE)
            extracted_last_date = last_date_match.group(1) if last_date_match else None

            # 3. Check Expired Date
            if extracted_last_date and is_date_expired(extracted_last_date):
                print(f"⏰ [EXPIRED SKIPPED]: {full_text} (Last Date: {extracted_last_date})")
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', full_text, flags=re.IGNORECASE).strip()

            valid_links.append({
                "title": clean_title,
                "last_date": extracted_last_date,
                "url": href
            })

        print(f"\n✅ Total Active/Valid SarkariResult Links Found: {len(valid_links)}\n")
        print("--- TOP EXTRACTED ACTIVE LINKS ---")
        for idx, item in enumerate(valid_links[:10], 1):
            print(f"{idx}. Title: {item['title']}")
            print(f"   Last Date: {item['last_date']}")
            print(f"   Blue URL: {item['url']}\n")

    except Exception as e:
        print(f"🚨 Test Error: {e}")

if __name__ == "__main__":
    test_sarkari_result_scraper()
