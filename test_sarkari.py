import os
import json
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# Googlebot Headers (Bypasses Cloudflare Datacenter IP Block)
# -------------------------------------------------------------
GOOGLEBOT_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'From': 'googlebot(at)googlebot.com',
    'Referer': 'https://www.google.com/'
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
# Googlebot Bypass Scraper
# -------------------------------------------------------------
def test_sarkari_googlebot():
    target_url = "https://www.sarkariresult.com/latestjob/"
    print(f"🧪 [GOOGLEBOT BYPASS TEST] Requesting: {target_url}\n")

    try:
        # Requesting as Googlebot via curl_cffi
        res = requests.get(
            target_url, 
            headers=GOOGLEBOT_HEADERS, 
            timeout=20, 
            verify=False
        )

        if res.status_code != 200:
            print(f"⚠️ Direct Googlebot status {res.status_code}. Trying AllOrigin Public Proxy Wrapper...")
            # Fallback via AllOrigins / Scraper Proxy
            proxy_url = f"https://api.allorigins.win/raw?url={target_url}"
            res = requests.get(proxy_url, headers=GOOGLEBOT_HEADERS, timeout=25, verify=False)

        if res.status_code != 200:
            print(f"❌ Failed to bypass 403! Status Code: {res.status_code}")
            return

        print(f"✅ Successfully Bypassed 403! Status Code: {res.status_code}\n")

        soup = BeautifulSoup(res.content, "html.parser")
        post_div = soup.find('div', id='post') or soup.find('body')
        a_tags = post_div.find_all('a', href=True) if post_div else []

        valid_links = []

        for a in a_tags[:40]:
            href = a['href'].strip()
            full_text = clean_html_text(a.text)

            if len(full_text) < 8 or "sarkariresult.com" not in href:
                continue

            # 🚫 State/AIIMS Rejection Check
            if is_hard_rejected(full_text):
                print(f"🚫 [REJECTED STATE/ENTITY]: {full_text}")
                continue

            # 🚫 Date Check from Hyperlink Text
            last_date_match = re.search(r'Last\s*Date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', full_text, re.IGNORECASE)
            extracted_last_date = last_date_match.group(1) if last_date_match else None

            if extracted_last_date and is_date_expired(extracted_last_date):
                print(f"⏰ [EXPIRED SKIPPED]: {full_text} (Last Date: {extracted_last_date})")
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', full_text, flags=re.IGNORECASE).strip()

            valid_links.append({
                "title": clean_title,
                "last_date": extracted_last_date,
                "url": href
            })

        print(f"\n✅ Total Active/Valid Bihar & Central Jobs Found: {len(valid_links)}\n")
        print("--- TOP EXTRACTED ACTIVE LINKS ---")
        for idx, item in enumerate(valid_links[:10], 1):
            print(f"{idx}. Title: {item['title']}")
            print(f"   Last Date: {item['last_date']}")
            print(f"   Blue URL: {item['url']}\n")

    except Exception as e:
        print(f"🚨 Execution Error: {e}")

if __name__ == "__main__":
    test_sarkari_googlebot()
