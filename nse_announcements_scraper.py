import json
import time
from datetime import datetime, timezone, timedelta
from curl_cffi import requests

# ============================================================
# CONFIGURATION
# ============================================================

BASE_URL = "https://www.nseindia.com"
ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements?index=equities"
OUTPUT_FILE = "nse_corporate_announcements.json"

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements",
    "Origin": "https://www.nseindia.com",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Dest": "empty",
}

def fetch_nse_corporate_announcements():
    print("=" * 80)
    print("🚀 RUNNING NSE SCRAPER VIA CHROME IMPERSONATION (GitHub Actions Ready)")
    print("=" * 80)

    # impersonate="chrome124" Akamai bot-defense ko bypass karta hai
    session = requests.Session(impersonate="chrome124")

    # Step 1: Warm-up Handshake (Acquire fresh session cookies)
    print("🌐 Step 1: Visiting NSE Homepage for handshake...")
    try:
        home_resp = session.get(BASE_URL, headers=HEADERS, timeout=20)
        if home_resp.status_code != 200:
            print(f"⚠️ Homepage warning status: {home_resp.status_code}")
        else:
            print(f"✅ Session handshake complete. Cookies captured: {len(session.cookies)}")
    except Exception as e:
        print(f"❌ Handshake failed: {e}")
        return

    # Natural delay to respect NSE rate-limit
    time.sleep(3)

    # Step 2: Fetch JSON Announcements Data
    print(f"📡 Step 2: Fetching live filings from: {ANNOUNCEMENTS_API}")
    try:
        api_resp = session.get(ANNOUNCEMENTS_API, headers=HEADERS, timeout=25)
        
        if api_resp.status_code == 403:
            print("❌ 403 Forbidden: IP flagged by Akamai.")
            return
            
        api_resp.raise_for_status()
        raw_json = api_resp.json()
    except Exception as e:
        print(f"❌ Error fetching announcements: {e}")
        return

    # Step 3: Parse and Structure the Data
    items = raw_json if isinstance(raw_json, list) else raw_json.get("data", [])
    print(f"📦 Total raw announcements received: {len(items)}")

    cleaned_records = []
    for item in items:
        symbol = str(item.get("symbol", "")).strip()
        comp_name = str(item.get("sm_name") or item.get("companyName", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        details = str(item.get("attchmntText") or item.get("details", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        pdf_link = f"https://nsearchives.nseindia.com/corporate/{attachment_file}" if attachment_file else ""

        cleaned_records.append({
            "symbol": symbol,
            "company_name": comp_name,
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "details": details[:600],
            "pdf_link": pdf_link
        })

    output_payload = {
        "source": "NSE India Corporate Announcements",
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_records": len(cleaned_records),
        "announcements": cleaned_records
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Output saved to '{OUTPUT_FILE}' (Total: {len(cleaned_records)} announcements)")
    print("=" * 80)

if __name__ == "__main__":
    fetch_nse_corporate_announcements()
