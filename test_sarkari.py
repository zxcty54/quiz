import os
import json
import re
from datetime import datetime
from bs4 import BeautifulSoup
from groq import Groq
from playwright.sync_api import sync_playwright

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
# Playwright Powered Scraper (Bypasses 403 Forbidden)
# -------------------------------------------------------------
def test_sarkari_result_with_playwright():
    url = "https://www.sarkariresult.com/latestjob/"
    print(f"🧪 [TEST MODE] Scraping SarkariResult via Playwright Browser: {url}\n")

    with sync_playwright() as p:
        # Launch Headless Chromium Engine
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={'width': 1280, 'height': 800}
        )
        page = context.new_page()

        try:
            # Navigate to URL
            response = page.goto(url, timeout=30000, wait_until="domcontentloaded")
            
            if response.status != 200:
                print(f"❌ Failed! Browser Status Code: {response.status}")
                browser.close()
                return

            print(f"✅ Successfully Bypassed Cloudflare! Status Code: {response.status}\n")

            # Extract full rendered page source HTML
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

                # 🚫 1. State/AIIMS Rejection Check
                if is_hard_rejected(full_text):
                    print(f"🚫 [REJECTED STATE/ENTITY]: {full_text}")
                    continue

                # 🚫 2. Date Check from Hyperlink Text
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
            print(f"🚨 Playwright Execution Error: {e}")

        browser.close()

if __name__ == "__main__":
    test_sarkari_result_with_playwright()
