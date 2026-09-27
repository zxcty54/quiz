import json
import time
import io
from datetime import datetime, timezone, timedelta
from curl_cffi import requests

# PDF Parsers
try:
    import pdfplumber
except ImportError:
    pdfplumber = None

from pypdf import PdfReader

# ============================================================
# CONFIGURATION
# ============================================================

BASE_URL = "https://www.nseindia.com"
ANNOUNCEMENTS_API = "https://www.nseindia.com/api/corporate-announcements?index=equities"
OUTPUT_FILE = "nse_corporate_announcements.json"

MAX_PDF_DOWNLOADS = 10  # Test ke liye first 10 files
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Sec-Fetch-Site": "same-site",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Dest": "document",
    "Referer": "https://www.nseindia.com/"
}

def extract_text_from_pdf_stream(pdf_bytes, pdf_url):
    """pdfplumber aur pypdf dono use karke maximum text extract karta hai"""
    extracted_text = ""
    num_pages = 0

    # 1. Try pdfplumber (Superior text extraction)
    if pdfplumber:
        try:
            with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
                num_pages = len(pdf.pages)
                pages_to_read = min(4, num_pages)
                chunks = []
                for p_idx in range(pages_to_read):
                    t = pdf.pages[p_idx].extract_text(layout=False)
                    if t:
                        chunks.append(t)
                extracted_text = " ".join(" ".join(chunks).split())
                if extracted_text:
                    print(f"      📄 [pdfplumber] Read {len(extracted_text)} chars from {pages_to_read}/{num_pages} pages.")
                    return extracted_text[:3000]
        except Exception as e:
            print(f"      ⚠️ pdfplumber parsing error: {e}")

    # 2. Fallback to pypdf
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        num_pages = len(reader.pages)
        pages_to_read = min(4, num_pages)
        chunks = []
        for p_idx in range(pages_to_read):
            t = reader.pages[p_idx].extract_text()
            if t:
                chunks.append(t)
        extracted_text = " ".join(" ".join(chunks).split())
        if extracted_text:
            print(f"      📄 [pypdf] Read {len(extracted_text)} chars from {pages_to_read}/{num_pages} pages.")
            return extracted_text[:3000]
    except Exception as e:
        print(f"      ⚠️ pypdf parsing error: {e}")

    # Agar pages the lekin text 0 nikla -> Image / Scanned Document
    if num_pages > 0 and not extracted_text:
        print(f"      📷 PDF has {num_pages} pages but no text characters found (Scanned Image/Photo PDF).")
        return f"[SCANNED_IMAGE_PDF: Document contains {num_pages} scanned image pages]"

    return ""


def download_and_parse_pdf(session, pdf_url):
    if not pdf_url:
        return ""
    
    file_name = pdf_url.split('/')[-1]
    print(f"\n   ⬇️ Downloading PDF: {file_name}")
    print(f"      URL: {pdf_url}")

    pdf_headers = dict(HEADERS)
    pdf_headers["Host"] = "nsearchives.nseindia.com"
    pdf_headers["Referer"] = "https://www.nseindia.com/companies-listing/corporate-filings-announcements"

    try:
        resp = session.get(pdf_url, headers=pdf_headers, timeout=25)
        print(f"      HTTP Status : {resp.status_code}")
        print(f"      Content-Type: {resp.headers.get('content-type', 'unknown')}")
        print(f"      Data Size   : {len(resp.content)} bytes")

        if resp.status_code == 403:
            print("      ❌ 403 Forbidden: nsearchives blocked the request.")
            return "[BLOCKED_403: Subdomain access denied]"

        if resp.status_code != 200:
            print(f"      ❌ Download failed with HTTP {resp.status_code}")
            return f"[DOWNLOAD_FAILED: HTTP {resp.status_code}]"

        # Content validation
        if not resp.content.startswith(b'%PDF'):
            # Kabhi-kabhi error HTML page bhej deta hai
            preview = resp.text[:150].strip()
            print(f"      ⚠️ Response is not a valid PDF! Preview: {preview}")
            return "[INVALID_PDF_FORMAT: Returned HTML/Text instead of PDF binary]"

        # Extraction
        text = extract_text_from_pdf_stream(resp.content, pdf_url)
        return text

    except Exception as e:
        print(f"      ❌ Network/Download Exception: {e}")
        return f"[ERROR: {str(e)}]"


def fetch_nse_announcements():
    print("=" * 80)
    print("🚀 NSE CORPORATE ANNOUNCEMENTS & DEEP PDF DEBUGGER")
    print("=" * 80)

    session = requests.Session(impersonate="chrome124")

    # Step 1: Handshake
    print("🌐 Step 1: Performing Handshake with NSE Homepage...")
    try:
        home_resp = session.get(BASE_URL, headers=HEADERS, timeout=20)
        print(f"   Status: {home_resp.status_code} | Cookies: {len(session.cookies)}")
        if home_resp.status_code != 200:
            print("❌ Handshake returned non-200 status.")
            return
    except Exception as e:
        print(f"❌ Handshake failed: {e}")
        return

    time.sleep(2)

    # Step 2: Fetch Announcements JSON
    print("\n📡 Step 2: Fetching Announcements JSON...")
    api_headers = dict(HEADERS)
    api_headers["Accept"] = "application/json, text/plain, */*"
    api_headers["Referer"] = "https://www.nseindia.com/companies-listing/corporate-filings-announcements"

    try:
        api_resp = session.get(ANNOUNCEMENTS_API, headers=api_headers, timeout=25)
        print(f"   API Status: {api_resp.status_code}")
        api_resp.raise_for_status()
        raw_json = api_resp.json()
    except Exception as e:
        print(f"❌ API Error: {e}")
        return

    items = raw_json if isinstance(raw_json, list) else raw_json.get("data", [])
    print(f"📦 Total announcements received: {len(items)}")

    cleaned_records = []
    pdf_success_count = 0
    attempted_pdf_count = 0

    for item in items:
        symbol = str(item.get("symbol", "")).strip()
        comp_name = str(item.get("sm_name") or item.get("companyName", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        details = str(item.get("attchmntText") or item.get("details", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        pdf_link = ""
        pdf_extracted = ""

        if attachment_file:
            # Full link construction
            if attachment_file.startswith("http"):
                pdf_link = attachment_file
            else:
                pdf_link = f"https://nsearchives.nseindia.com/corporate/{attachment_file}"

        # Scrape PDF text
        if pdf_link and attempted_pdf_count < MAX_PDF_DOWNLOADS:
            attempted_pdf_count += 1
            print(f"\n[{attempted_pdf_count}/{MAX_PDF_DOWNLOADS}] Target: {symbol} - {subject[:45]}")
            pdf_extracted = download_and_parse_pdf(session, pdf_link)
            
            if pdf_extracted and not pdf_extracted.startswith("["):
                pdf_success_count += 1
            
            time.sleep(1.5)  # Safe delay between PDF fetches

        cleaned_records.append({
            "symbol": symbol,
            "company_name": comp_name,
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary_details": details[:400],
            "pdf_link": pdf_link,
            "pdf_extracted_text": pdf_extracted
        })

    output_payload = {
        "source": "NSE India Corporate Announcements",
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_records": len(cleaned_records),
        "pdfs_attempted": attempted_pdf_count,
        "pdfs_successfully_parsed": pdf_success_count,
        "announcements": cleaned_records
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 SCRAPING RUN SUMMARY:")
    print(f"   • Total Announcements    : {len(cleaned_records)}")
    print(f"   • PDFs Download Attempted: {attempted_pdf_count}")
    print(f"   • PDFs Text Extracted    : {pdf_success_count}")
    print(f"   • Saved To File          : '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    fetch_nse_announcements()
