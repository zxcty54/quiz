import os
import json
import re
import time
from datetime import datetime
from bs4 import BeautifulSoup
from groq import Groq
from playwright.sync_api import sync_playwright
from playwright_stealth import stealth_sync

# -------------------------------------------------------------
# Test Config & Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

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
# Stealth-Enabled Playwright Scraper
# -------------------------------------------------------------
def test_sarkari_result_with_stealth():
    # Primary URL with Fallback Mirror
    url = "https://www.sarkariresult.com/latestjob/"
    fallback_url = "https://www.sarkariresult.com/latestjobs.php"
    
    print(f"🧪 [STEALTH TEST] Scraping SarkariResult via Stealth Playwright: {url}\n")

    with sync_playwright() as p:
        # Launch Chromium with anti-detection flags
        browser = p.chromium.launch(
            headless=True,
            args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-blink-features=AutomationControlled',
                '--disable-infobars',
                '--window-position=0,0',
                '--ignore-certificate-errors',
                '--ignore-certificate-errors-spki-list',
                '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
            ]
        )
        
        context = browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            locale="en-US",
            timezone_id="Asia/Kolkata"
        )
        
        page = context.new_page()
        
        # Apply Stealth mode bypass
        stealth_sync(page)

        try:
            # 1. Try Main URL
            print(f"🌐 Navigating to {url}...")
            response = page.goto(url, timeout=35000, wait_until="networkidle")
            
            # If 403 occurs on main URL, try fallback URL
            if response.status == 403:
                print(f"⚠️ Main URL returned 403. Trying fallback mirror: {fallback_url}")
                response = page.goto(fallback_url, timeout=35000, wait_until="networkidle")

            if response.status != 200:
                print(f"❌ Failed! Final Status Code: {response.status}")
                browser.close()
                return

            print(f"✅ Bypassed Cloudflare! Status Code: {response.status}\n")

            # Allow dynamic JS rendering if any
            time.sleep(2)

            content = page.content()
            soup = BeautifulSoup(content, "html.parser")

            post_div = soup.find('div', id='post') or soup.find('body')
            a_tags = post_div.find_all('a', href=True) if post_div else []

            valid_links = []

            for a in a_tags[:40]:
                href = a['href'].strip()
                full_text = clean_html_text(a.text)

                if len(full_text) < 8 or "sarkariresult.com" not in href:
                    continue

                # 🚫 State/AIIMS Rejection
                if is_hard_rejected(full_text):
                    print(f"🚫 [REJECTED STATE/ENTITY]: {full_text}")
                    continue

                # 🚫 Date Expired Check
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
            print(f"🚨 Stealth Playwright Execution Error: {e}")

        browser.close()

if __name__ == "__main__":
    test_sarkari_result_with_stealth()
