import json
import time
import io
import re
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

MAX_PDF_DOWNLOADS = 10
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

# ============================================================
# FILTER CRITERIA
# ============================================================

# Ye keywords milne par direct skip ho jayega
EXCLUDED_KEYWORDS = [
    "financial results", "quarterly results", "financial result",
    "investor presentation", "press release", "earnings call",
    "qip", "preferential allotment", "warrants", "fund raising",
    "fccb", "debt issue", "ncd", "dividend", "rights issue",
    "loss of share", "duplicate share", "kyc update", "newspaper publication",
    "postal ballot", "agm notice", "egm notice", "scrutinizer",
    "trading window closure", "credit rating"
]

# Sirf ye high-impact events filter honge
TARGET_CATEGORIES = {
    "NEW_ORDER_WIN": [
        "bagged order", "receipt of order", "order win", "awarded order",
        "letter of award", "work order", "purchase order", "contract win",
        "secured order", "commercial agreement", "supply contract"
    ],
    "BUYBACK_BONUS_SPLIT": [
        "buyback", "buy-back", "bonus issue", "bonus shares",
        "stock split", "sub-division of shares", "sub division of equity"
    ],
    "MA_AND_PARTNERSHIP": [
        "acquisition", "merger", "amalgamation", "joint venture",
        "mou signed", "strategic alliance", "stake acquisition"
    ],
    "CAPEX_AND_EXPANSION": [
        "commercial production", "capacity expansion", "new facility",
        "new plant", "plant expansion", "commissioning of"
    ],
    "APPROVALS_AND_PATENTS": [
        "usfda", "patent granted", "eir received", "license granted",
        "regulatory approval", "environmental clearance"
    ],
    "RED_FLAG_ALERTS": [
        "resignation of statutory auditor", "resignation of auditor",
        "resignation of cfo", "search and seizure", "it raid",
        "show cause notice", "forensic audit"
    ]
}


def filter_impact_announcement(subject: str, details: str):
    """Checks subject and details text against negative and positive keywords."""
    combined_text = f"{subject} {details}".lower()

    # 1. Negative Filter
    for bad_word in EXCLUDED_KEYWORDS:
        if bad_word in combined_text:
            return None

    # 2. Positive Filter
    matched_tags = []
    for category, keywords in TARGET_CATEGORIES.items():
        for kw in keywords:
            pattern = rf"\b{re.escape(kw)}\b"
            if re.search(pattern, combined_text):
                matched_tags.append(category)
                break

    return matched_tags if matched_tags else None


# ============================================================
# IN-MEMORY PDF TEXT PARSER
# ============================================================

def extract_text_from_pdf_stream(pdf_bytes, pdf_url):
    """RAM me bina save kiye PDF se text nikalta hai."""
    extracted_text = ""
    num_pages = 0

    # 1. Try pdfplumber
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
            print(f"      ⚠️ pdfplumber error: {e}")

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
        print(f"      ⚠️ pypdf error: {e}")

    if num_pages > 0 and not extracted_text:
        return f"[SCANNED_IMAGE_PDF: Document contains {num_pages} scanned image pages]"

    return ""


def download_and_parse_pdf(session, pdf_url):
    if not pdf_url:
        return ""

    file_name = pdf_url.split('/')[-1]
    print(f"\n   ⬇️ Downloading PDF: {file_name}")

    pdf_headers = dict(HEADERS)
    pdf_headers["Host"] = "nsearchives.nseindia.com"
    pdf_headers["Referer"] = "https://www.nseindia.com/companies-listing/corporate-filings-announcements"

    try:
        resp = session.get(pdf_url, headers=pdf_headers, timeout=25)

        if resp.status_code == 403:
            return "[BLOCKED_403: Subdomain access denied]"

        if resp.status_code != 200:
            return f"[DOWNLOAD_FAILED: HTTP {resp.status_code}]"

        if not resp.content.startswith(b'%PDF'):
            return "[INVALID_PDF_FORMAT: Not a PDF file]"

        return extract_text_from_pdf_stream(resp.content, pdf_url)

    except Exception as e:
        return f"[ERROR: {str(e)}]"


# ============================================================
# MAIN SCRAPER EXECUTION
# ============================================================

def fetch_nse_announcements():
    print("=" * 80)
    print("🚀 NSE CORPORATE ANNOUNCEMENTS - FILTERED HIGH-IMPACT SCRAPER")
    print("=" * 80)

    session = requests.Session(impersonate="chrome124")

    # Step 1: Handshake
    print("🌐 Step 1: Visiting NSE Homepage for handshake...")
    try:
        home_resp = session.get(BASE_URL, headers=HEADERS, timeout=20)
        if home_resp.status_code != 200:
            print(f"❌ Handshake returned status: {home_resp.status_code}")
            return
        print(f"✅ Handshake OK. Cookies captured: {len(session.cookies)}")
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
        api_resp.raise_for_status()
        raw_json = api_resp.json()
    except Exception as e:
        print(f"❌ API Error: {e}")
        return

    items = raw_json if isinstance(raw_json, list) else raw_json.get("data", [])
    print(f"📦 Total raw announcements received: {len(items)}")

    filtered_records = []
    pdf_success_count = 0
    attempted_pdf_count = 0

    for item in items:
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        details = str(item.get("attchmntText") or item.get("details", "")).strip()

        # Filtering check
        categories = filter_impact_announcement(subject, details)
        if not categories:
            continue

        symbol = str(item.get("symbol", "")).strip()
        comp_name = str(item.get("sm_name") or item.get("companyName", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        pdf_link = ""
        pdf_extracted = ""

        if attachment_file:
            if attachment_file.startswith("http"):
                pdf_link = attachment_file
            else:
                clean_path = attachment_file.lstrip("/")
                pdf_link = f"https://nsearchives.nseindia.com/corporate/{clean_path}"

        print(f"\n⚡ Match Found [{', '.join(categories)}]: {symbol} - {subject[:50]}")

        # PDF parsing strictly on matches
        if pdf_link and attempted_pdf_count < MAX_PDF_DOWNLOADS:
            attempted_pdf_count += 1
            print(f"[{attempted_pdf_count}/{MAX_PDF_DOWNLOADS}] Extracting PDF text...")
            pdf_extracted = download_and_parse_pdf(session, pdf_link)

            if pdf_extracted and not pdf_extracted.startswith("["):
                pdf_success_count += 1

            time.sleep(1.5)

        filtered_records.append({
            "symbol": symbol,
            "company_name": comp_name,
            "categories": categories,
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary_details": details[:400],
            "pdf_link": pdf_link,
            "pdf_extracted_text": pdf_extracted
        })

    output_payload = {
        "source": "NSE India Corporate Announcements (Impact Filtered)",
        "scraped_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),
        "total_impact_records": len(filtered_records),
        "pdfs_attempted": attempted_pdf_count,
        "pdfs_successfully_parsed": pdf_success_count,
        "announcements": filtered_records
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 FILTERED RUN SUMMARY:")
    print(f"   • Total Filtered Items Saved : {len(filtered_records)}")
    print(f"   • Impact PDFs Attempted      : {attempted_pdf_count}")
    print(f"   • Impact PDFs Text Extracted : {pdf_success_count}")
    print(f"   • Saved To File              : '{OUTPUT_FILE}'")
    print("=" * 80)


if __name__ == "__main__":
    fetch_nse_announcements()
