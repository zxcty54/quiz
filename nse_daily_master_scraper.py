import json
import os
import time
import io
import re
import hashlib
from datetime import datetime, timezone, timedelta
from curl_cffi import requests
from pypdf import PdfReader

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

# ============================================================
# CONFIGURATION & CONSTANTS
# ============================================================

BASE_URL = "https://www.nseindia.com"
MASTER_FILE = "nse_corporate_master.json"

ENDPOINTS = {
    "announcements": "https://www.nseindia.com/api/corporate-announcements?index=equities",
    "board_meetings": "https://www.nseindia.com/api/event-calendar?index=equities",
    "financial_results": "https://www.nseindia.com/api/corporates-financial-results?index=equities",
    "shareholding_patterns": "https://www.nseindia.com/api/corporate-share-holdings-master?index=equities"
}

MAX_PDF_DOWNLOADS = 8
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements",
    "Origin": "https://www.nseindia.com",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Dest": "empty"
}

# ============================================================
# DETERMINISTIC REGEX ENGINE (10 TARGET CATEGORIES)
# ============================================================

CATEGORY_PATTERNS = {
    "RESULT": re.compile(
        r'\b(financial result|financial results|audited results|unaudited results|quarterly results|outcome of board meeting.*financial)\b', 
        re.IGNORECASE
    ),
    "ORDER": re.compile(
        r'\b(order win|order received|awarded|contract|bagged|letter of intent|loi|work order|purchase order|new order|commercial agreement)\b', 
        re.IGNORECASE
    ),
    "ACQUISITION": re.compile(
        r'\b(acquisition|amalgamation|merger|takeover|acquires|acquiring|slump sale|joint venture|stake sale|subsidiary acquisition)\b', 
        re.IGNORECASE
    ),
    "FUND_RAISE": re.compile(
        r'\b(fund raising|fund raise|qip|rights issue|preferential issue|preferential allotment|warrants|fpo|qualified institutions placement)\b', 
        re.IGNORECASE
    ),
    "DEBT": re.compile(
        r'\b(debt reduction|ncd|debentures|repayment of debt|prepayment|loan closure|commercial paper|bonds issuance)\b', 
        re.IGNORECASE
    ),
    "CAPACITY_EXPANSION": re.compile(
        r'\b(capacity expansion|new plant|capex|manufacturing facility|greenfield|brownfield|commercial production|expansion project|new unit)\b', 
        re.IGNORECASE
    ),
    "CREDIT_RATING": re.compile(
        r'\b(credit rating|crisil|care|icra|infomerics|brickwork|rating assigned|rating upgrade|rating revised|rating reaffirmed)\b', 
        re.IGNORECASE
    ),
    "BONUS": re.compile(
        r'\b(bonus issue|bonus shares|allotment of bonus|recommendation of bonus|issuance of bonus)\b', 
        re.IGNORECASE
    ),
    "SPLIT": re.compile(
        r'\b(split|sub-division|subdivision|face value.*from.*to|sub-division of shares)\b', 
        re.IGNORECASE
    ),
    "BUYBACK": re.compile(
        r'\b(buyback|buy-back|tender offer|open market buyback|share repurchase)\b', 
        re.IGNORECASE
    )
}

EXCLUDE_JUNK = re.compile(
    r'\b(loss of share|duplicate share|newspaper|clipping|analyst meet|investor meet audio|transcript|trading window closure|closure of trading|general meeting notice|postal ballot notice)\b',
    re.IGNORECASE
)

def classify_event(text_to_check):
    if not text_to_check:
        return None
    if EXCLUDE_JUNK.search(text_to_check):
        return None
    for cat, pattern in CATEGORY_PATTERNS.items():
        if pattern.search(text_to_check):
            return cat
    return None

def generate_hash(identifier):
    clean = re.sub(r'[^a-zA-Z0-9]+', '', str(identifier).lower().strip())
    return hashlib.md5(clean.encode('utf-8')).hexdigest()[:12]

# ============================================================
# PDF EXTRACTION ENGINE
# ============================================================

def extract_pdf_content(session, pdf_url):
    if not pdf_url:
        return ""
    pdf_headers = dict(HEADERS)
    pdf_headers["Host"] = "nsearchives.nseindia.com"
    pdf_headers["Referer"] = "https://www.nseindia.com/"

    try:
        resp = session.get(pdf_url, headers=pdf_headers, timeout=20)
        if resp.status_code != 200 or not resp.content.startswith(b'%PDF'):
            return ""

        pdf_bytes = io.BytesIO(resp.content)
        if pdfplumber:
            try:
                with pdfplumber.open(pdf_bytes) as pdf:
                    pages = [p.extract_text() for p in pdf.pages[:3] if p.extract_text()]
                    text = " ".join(" ".join(pages).split())
                    if text:
                        return text[:2500]
            except Exception:
                pass

        reader = PdfReader(pdf_bytes)
        pages = [p.extract_text() for p in reader.pages[:3] if p.extract_text()]
        text = " ".join(" ".join(pages).split())
        return text[:2500] if text else "[SCANNED_IMAGE_PDF]"
    except Exception:
        return ""

def safe_api_get(session, url, name):
    print(f"📡 Fetching {name}...")
    try:
        resp = session.get(url, headers=HEADERS, timeout=25)
        if resp.status_code == 200:
            data = resp.json()
            items = data if isinstance(data, list) else data.get("data", [])
            print(f"   ✅ Raw {name} count: {len(items)}")
            return items
        print(f"   ⚠️ Status {resp.status_code} for {name}")
        return []
    except Exception as e:
        print(f"   ❌ Error fetching {name}: {e}")
        return []

# ============================================================
# MASTER ORCHESTRATOR & DEDUPLICATION
# ============================================================

def run_nse_daily_master():
    print("=" * 80)
    print("🚀 STARTING NSE DAILY MASTER SCRAPER (PRODUCTION)")
    print("=" * 80)

    # 1. Load Existing State
    master_data = {
        "last_updated": "",
        "corporate_announcements": [],
        "board_meetings": [],
        "financial_results": [],
        "shareholding_patterns": []
    }

    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception:
            pass

    # Deduplication sets
    seen_announcement_hashes = {a.get("hash") for a in master_data["corporate_announcements"] if a.get("hash")}
    seen_meeting_hashes = {m.get("hash") for m in master_data["board_meetings"] if m.get("hash")}
    seen_result_hashes = {r.get("hash") for r in master_data["financial_results"] if r.get("hash")}
    seen_shp_hashes = {s.get("hash") for s in master_data["shareholding_patterns"] if s.get("hash")}

    # 2. Session Handshake
    session = requests.Session(impersonate="chrome124")
    print("🌐 Performing handshake with NSE Homepage...")
    try:
        home_resp = session.get(BASE_URL, headers=HEADERS, timeout=20)
        if home_resp.status_code != 200:
            print(f"❌ Handshake failed (HTTP {home_resp.status_code}). Exiting.")
            return
        print(f"✅ Handshake successful. Active cookies: {len(session.cookies)}")
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return

    time.sleep(2)

    # ------------------------------------------------------------
    # 3. Process Corporate Announcements (Filtered & Deduplicated)
    # ------------------------------------------------------------
    raw_announcements = safe_api_get(session, ENDPOINTS["announcements"], "Announcements")
    time.sleep(1.5)

    new_announcements = []
    pdf_downloads = 0

    for item in raw_announcements:
        symbol = str(item.get("symbol", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        summary = str(item.get("attchmntText", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        # Deterministic Category Filter
        category = classify_event(f"{subject} {summary}")
        if not category:
            continue

        item_hash = generate_hash(f"{symbol}_{subject}_{broadcast_dt}")
        if item_hash in seen_announcement_hashes:
            continue

        pdf_url = ""
        pdf_text = ""
        if attachment_file:
            pdf_url = attachment_file if attachment_file.startswith("http") else f"https://nsearchives.nseindia.com/corporate/{attachment_file}"
            if pdf_downloads < MAX_PDF_DOWNLOADS:
                pdf_text = extract_pdf_content(session, pdf_url)
                pdf_downloads += 1
                time.sleep(1)

        record = {
            "hash": item_hash,
            "category": category,
            "symbol": symbol,
            "company_name": str(item.get("sm_name") or item.get("companyName", "")).strip(),
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary": summary[:350],
            "pdf_link": pdf_url,
            "pdf_extracted_text": pdf_text
        }
        new_announcements.append(record)
        seen_announcement_hashes.add(item_hash)

    # ------------------------------------------------------------
    # 4. Process Board Meetings (Filtered & Deduplicated)
    # ------------------------------------------------------------
    raw_meetings = safe_api_get(session, ENDPOINTS["board_meetings"], "Board Meetings")
    time.sleep(1.5)

    new_meetings = []
    for m in raw_meetings:
        symbol = str(m.get("symbol", "")).strip()
        purpose = str(m.get("purpose", "")).strip()
        details = str(m.get("details", "")).strip()
        meeting_date = str(m.get("meetingDate", "")).strip()

        category = classify_event(f"{purpose} {details}")
        if not category:
            continue

        m_hash = generate_hash(f"{symbol}_{meeting_date}_{purpose}")
        if m_hash in seen_meeting_hashes:
            continue

        new_meetings.append({
            "hash": m_hash,
            "category": category,
            "symbol": symbol,
            "company_name": str(m.get("companyName", "")).strip(),
            "meeting_date": meeting_date,
            "purpose": purpose
        })
        seen_meeting_hashes.add(m_hash)

    # ------------------------------------------------------------
    # 5. Process Financial Results (Deduplicated)
    # ------------------------------------------------------------
    raw_results = safe_api_get(session, ENDPOINTS["financial_results"], "Financial Results")
    time.sleep(1.5)

    new_results = []
    for r in raw_results:
        symbol = str(r.get("symbol", "")).strip()
        period = str(r.get("period", "")).strip()
        res_date = str(r.get("resultDate", "")).strip()

        r_hash = generate_hash(f"{symbol}_{period}_{res_date}")
        if r_hash in seen_result_hashes:
            continue

        new_results.append({
            "hash": r_hash,
            "symbol": symbol,
            "company_name": str(r.get("companyName", "")).strip(),
            "period": period,
            "income": r.get("re venue") or r.get("income", ""),
            "net_profit": r.get("netProfit", ""),
            "eps": r.get("eps", ""),
            "result_date": res_date
        })
        seen_result_hashes.add(r_hash)

    # ------------------------------------------------------------
    # 6. Process Shareholding Patterns (Deduplicated)
    # ------------------------------------------------------------
    raw_shp = safe_api_get(session, ENDPOINTS["shareholding_patterns"], "Shareholding Patterns")

    new_shp = []
    for s in raw_shp:
        symbol = str(s.get("symbol", "")).strip()
        as_on_date = str(s.get("asOnDate", "")).strip()

        s_hash = generate_hash(f"{symbol}_{as_on_date}")
        if s_hash in seen_shp_hashes:
            continue

        new_shp.append({
            "hash": s_hash,
            "symbol": symbol,
            "company_name": str(s.get("companyName", "")).strip(),
            "as_on_date": as_on_date,
            "promoter_holding": s.get("promoter", ""),
            "public_holding": s.get("public", ""),
            "fii_holding": s.get("fii", ""),
            "dii_holding": s.get("dii", "")
        })
        seen_shp_hashes.add(s_hash)

    # ------------------------------------------------------------
    # 7. Merge & Save Master Archive
    # ------------------------------------------------------------
    master_data["last_updated"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S IST")
    master_data["corporate_announcements"] = new_announcements + master_data["corporate_announcements"]
    master_data["board_meetings"] = new_meetings + master_data["board_meetings"]
    master_data["financial_results"] = new_results + master_data["financial_results"]
    master_data["shareholding_patterns"] = new_shp + master_data["shareholding_patterns"]

    # Retain safe ceiling to prevent unbounded file explosion (last 3,000 items)
    master_data["corporate_announcements"] = master_data["corporate_announcements"][:3000]
    master_data["board_meetings"] = master_data["board_meetings"][:1500]
    master_data["financial_results"] = master_data["financial_results"][:2000]
    master_data["shareholding_patterns"] = master_data["shareholding_patterns"][:2000]

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 DAILY RUN SUMMARY:")
    print(f"   • High-Yield Announcements Added : {len(new_announcements)} (PDFs parsed: {pdf_downloads})")
    print(f"   • Filtered Board Meetings Added  : {len(new_meetings)}")
    print(f"   • Fresh Financial Results Added  : {len(new_results)}")
    print(f"   • Fresh Shareholding Added       : {len(new_shp)}")
    print(f"💾 Master Archive Updated           : '{MASTER_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_nse_daily_master()
