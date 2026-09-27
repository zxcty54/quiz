import json
import time
import io
from datetime import datetime, timezone, timedelta
from curl_cffi import requests
from pypdf import PdfReader

# ============================================================
# CONFIGURATION
# ============================================================

BASE_URL = "https://www.nseindia.com"
ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements?index=equities"
OUTPUT_FILE = "nse_corporate_announcements.json"

# Kitni recent announcements ki PDF extract karni hai (per run)
MAX_PDF_DOWNLOADS = 15  # GitHub Actions execution time aur rate-limits ke liye safe limit

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

def extract_text_from_pdf(session, pdf_url):
    """PDF ko download karke clean text extract karta hai"""
    if not pdf_url:
        return ""
    try:
        # NSE archives referer ke sath access hote hain
        pdf_headers = dict(HEADERS)
        pdf_headers["Referer"] = "https://www.nseindia.com/"
        
        resp = session.get(pdf_url, headers=pdf_headers, timeout=25)
        if resp.status_code != 200:
            return ""

        # In-memory stream parse
        pdf_file = io.BytesIO(resp.content)
        reader = PdfReader(pdf_file)
        
        extracted_pages = []
        # Pehle 3-4 pages me hi core executive summary / resolution hota hai
        for page_idx in range(min(4, len(reader.pages))):
            text = reader.pages[page_idx].extract_text()
            if text:
                extracted_pages.append(text)

        full_extracted = " ".join(" ".join(extracted_pages).split())
        return full_extracted[:2500]  # First 2500 chars (core factual data)

    except Exception as e:
        print(f"      ⚠️ Failed to read PDF ({pdf_url.split('/')[-1]}): {e}")
        return ""


def fetch_nse_announcements_with_pdf():
    print("=" * 80)
    print("🚀 NSE CORPORATE ANNOUNCEMENTS & PDF SCRAPER")
    print("=" * 80)

    session = requests.Session(impersonate="chrome124")

    # Step 1: Warm-up Handshake (Acquire cookies)
    print("🌐 Step 1: Handshake with NSE Homepage...")
    try:
        home_resp = session.get(BASE_URL, headers=HEADERS, timeout=20)
        if home_resp.status_code != 200:
            print(f"⚠️ Homepage status: {home_resp.status_code}")
        else:
            print(f"✅ Handshake success! Cookies: {len(session.cookies)}")
    except Exception as e:
        print(f"❌ Handshake failed: {e}")
        return

    time.sleep(2)

    # Step 2: Fetch Announcements JSON
    print(f"📡 Step 2: Fetching live filings...")
    try:
        api_resp = session.get(ANNOUNCEMENTS_API, headers=HEADERS, timeout=25)
        if api_resp.status_code == 403:
            print("❌ 403 Forbidden: IP flagged.")
            return
        api_resp.raise_for_status()
        raw_json = api_resp.json()
    except Exception as e:
        print(f"❌ Error fetching JSON: {e}")
        return

    items = raw_json if isinstance(raw_json, list) else raw_json.get("data", [])
    print(f"📦 Total raw announcements received: {len(items)}")

    # Step 3: Process items & scrape attached PDFs
    cleaned_records = []
    pdf_count = 0

    for idx, item in enumerate(items):
        symbol = str(item.get("symbol", "")).strip()
        comp_name = str(item.get("sm_name") or item.get("companyName", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        details = str(item.get("attchmntText") or item.get("details", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        pdf_link = f"https://nsearchives.nseindia.com/corporate/{attachment_file}" if attachment_file else ""
        pdf_text = ""

        # Scrape PDF text for top records
        if pdf_link and pdf_count < MAX_PDF_DOWNLOADS:
            print(f"   📄 [{pdf_count + 1}/{MAX_PDF_DOWNLOADS}] Extracting PDF for: {symbol} - {subject[:40]}...")
            pdf_text = extract_text_from_pdf(session, pdf_link)
            pdf_count += 1
            time.sleep(1) # Pacing between PDF downloads

        cleaned_records.append({
            "symbol": symbol,
            "company_name": comp_name,
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary_details": details[:400],
            "pdf_link": pdf_link,
            "pdf_extracted_text": pdf_text
        })

    output_payload = {
        "source": "NSE India Corporate Announcements",
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_records": len(cleaned_records),
        "pdfs_parsed": pdf_count,
        "announcements": cleaned_records
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Saved to '{OUTPUT_FILE}' | Total: {len(cleaned_records)} records (PDFs parsed: {pdf_count})")
    print("=" * 80)


if __name__ == "__main__":
    fetch_nse_announcements_with_pdf()
