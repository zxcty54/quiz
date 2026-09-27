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
# CONFIGURATION & PARAMETERS
# ============================================================

BASE_URL = "https://www.nseindia.com"
MASTER_FILE = "nse_corporate_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

TO_DATE = NOW.strftime("%d-%m-%Y")
FROM_DATE = (NOW - timedelta(days=20)).strftime("%d-%m-%Y")

# Working NSE Endpoints with date filters for rich data
ENDPOINTS = {
    "announcements": f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}",
    "financial_results": f"https://www.nseindia.com/api/corporates-financial-results?index=equities&period=Quarterly",
    "shareholding_patterns": f"https://www.nseindia.com/api/corporate-share-holdings-master?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}"
}

# Rich PDF Downloads limit (Outcome documents)
MAX_PDF_DOWNLOADS = 25

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Origin": "https://www.nseindia.com",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Dest": "empty"
}

# ============================================================
# TARGET CATEGORIES (High Impact Corporate Actions)
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
        resp = session.get(pdf_url, headers=pdf_headers, timeout=22)
        if resp.status_code != 200 or not resp.content.startswith(b'%PDF'):
            return ""

        pdf_bytes = io.BytesIO(resp.content)
        
        # Priority 1: pdfplumber for clean tabular & numeric summary
        if pdfplumber:
            try:
                with pdfplumber.open(pdf_bytes) as pdf:
                    pages = [p.extract_text() for p in pdf.pages[:3] if p.extract_text()]
                    text = " ".join(" ".join(pages).split())
                    if text and len(text) > 40:
                        return text[:3000]
            except Exception:
                pass

        # Priority 2: pypdf fallback
        reader = PdfReader(pdf_bytes)
        pages = [p.extract_text() for p in reader.pages[:3] if p.extract_text()]
        text = " ".join(" ".join(pages).split())
        return text[:3000] if (text and len(text) > 40) else "[SCANNED_IMAGE_PDF: Requires OCR]"
    except Exception:
        return ""

def safe_api_get(session, url, name, custom_referer=None):
    print(f"📡 Fetching {name}...")
    headers = dict(HEADERS)
    headers["Referer"] = custom_referer or "https://www.nseindia.com/"
    try:
        resp = session.get(url, headers=headers, timeout=25)
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
# MASTER ORCHESTRATOR
# ============================================================

def run_nse_daily_master():
    print("=" * 80)
    print("🚀 NSE COMPLETE CORPORATE ACTION INTELLIGENCE (NO HALF DATA)")
    print(f"📅 Scan Window: {FROM_DATE} to {TO_DATE}")
    print("=" * 80)

    # 1. Load Existing State
    master_data = {
        "last_updated": "",
        "corporate_announcements": [],
        "upcoming_board_meetings": [],
        "financial_results": [],
        "shareholding_patterns": []
    }

    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    master_data = loaded
        except Exception:
            pass

    seen_announcement_hashes = {a.get("hash") for a in master_data.get("corporate_announcements", []) if a.get("hash")}
    seen_result_hashes = {r.get("hash") for r in master_data.get("financial_results", []) if r.get("hash")}
    seen_shp_hashes = {s.get("hash") for s in master_data.get("shareholding_patterns", []) if s.get("hash")}

    # 2. Handshake
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
    # 3. Actionable Corporate Announcements (Must Have Details/PDF)
    # ------------------------------------------------------------
    raw_announcements = safe_api_get(
        session, 
        ENDPOINTS["announcements"], 
        "Announcements & Filings", 
        "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
    )
    time.sleep(1.5)

    new_announcements = []
    pdf_downloads = 0

    for item in raw_announcements:
        symbol = str(item.get("symbol", "")).strip()
        subject = str(item.get("desc") or item.get("subject", "")).strip()
        summary = str(item.get("attchmntText", "")).strip()
        broadcast_dt = str(item.get("an_dt") or item.get("broadcastDate", "")).strip()
        attachment_file = str(item.get("attchmntFile", "")).strip()

        if not symbol or not subject:
            continue

        # Category Filter
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
                print(f"   📄 [{pdf_downloads+1}/{MAX_PDF_DOWNLOADS}] Extracting PDF for: {symbol} ({category})...")
                pdf_text = extract_pdf_content(session, pdf_url)
                pdf_downloads += 1
                time.sleep(1)

        # 🛑 ZERO-HALF-DATA GUARD:
        # Agar summary bhi nahi hai aur PDF text bhi nahi hai, toh card kisi kaam ka nahi hai
        if not summary and not pdf_text:
            continue

        record = {
            "hash": item_hash,
            "category": category,
            "symbol": symbol,
            "company_name": str(item.get("sm_name") or item.get("companyName", "")).strip(),
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary": summary[:400],
            "pdf_link": pdf_url,
            "pdf_extracted_text": pdf_text
        }
        new_announcements.append(record)
        seen_announcement_hashes.add(item_hash)

    # ------------------------------------------------------------
    # 4. Financial Results (Structured Table with Figures)
    # ------------------------------------------------------------
    raw_results = safe_api_get(
        session, 
        ENDPOINTS["financial_results"], 
        "Financial Results (Quarterly Data)", 
        "https://www.nseindia.com/companies-listing/corporate-filings-financial-results"
    )
    time.sleep(1.5)

    new_results = []
    for r in raw_results:
        symbol = str(r.get("symbol", "")).strip()
        comp_name = str(r.get("companyName") or r.get("sm_name", "")).strip()
        period = str(r.get("period") or r.get("audited", "")).strip()
        res_date = str(r.get("res_dt") or r.get("resultDate") or r.get("broadcastDate", "")).strip()
        
        income = str(r.get("income") or r.get("revenue") or r.get("tot_inc", "")).strip()
        net_profit = str(r.get("netProfit") or r.get("pro_aft_tax") or r.get("net_profit", "")).strip()
        eps = str(r.get("eps") or r.get("re_eps", "")).strip()

        # Strict Filter: Figures hona zaroori hai
        if not symbol or (not income and not net_profit):
            continue

        r_hash = generate_hash(f"{symbol}_{period}_{res_date}")
        if r_hash in seen_result_hashes:
            continue

        new_results.append({
            "hash": r_hash,
            "symbol": symbol,
            "company_name": comp_name,
            "period": period,
            "revenue_income": income,
            "net_profit": net_profit,
            "eps": eps,
            "result_date": res_date
        })
        seen_result_hashes.add(r_hash)

    # ------------------------------------------------------------
    # 5. Shareholding Patterns (Strict Valid Filings Only)
    # ------------------------------------------------------------
    raw_shp = safe_api_get(
        session, 
        ENDPOINTS["shareholding_patterns"], 
        "Shareholding Patterns", 
        "https://www.nseindia.com/companies-listing/corporate-filings-shareholding-pattern"
    )

    new_shp = []
    for s in raw_shp:
        symbol = str(s.get("symbol", "")).strip()
        comp_name = str(s.get("sm_name") or s.get("companyName", "")).strip()
        as_on_date = str(s.get("sh_dt") or s.get("asOnDate") or s.get("date", "")).strip()
        
        promoter = str(s.get("promoterAndPromoterGroup") or s.get("promoter") or "").strip()
        public_hold = str(s.get("public") or "").strip()
        fii = str(s.get("fii") or "").strip()
        dii = str(s.get("dii") or "").strip()

        # Discard if holding numbers are empty
        if not symbol or as_on_date in ["", "-", "None", "null"]:
            continue
        if promoter in ["", "-", "None", "null"] and public_hold in ["", "-", "None", "null"]:
            continue

        s_hash = generate_hash(f"{symbol}_{as_on_date}")
        if s_hash in seen_shp_hashes:
            continue

        new_shp.append({
            "hash": s_hash,
            "symbol": symbol,
            "company_name": comp_name,
            "as_on_date": as_on_date,
            "promoter_holding": promoter,
            "public_holding": public_hold,
            "fii_holding": fii,
            "dii_holding": dii
        })
        seen_shp_hashes.add(s_hash)

    # ------------------------------------------------------------
    # 6. Merge & Write Clean Data
    # ------------------------------------------------------------
    master_data["last_updated"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    master_data["corporate_announcements"] = new_announcements + master_data.get("corporate_announcements", [])
    master_data["financial_results"] = new_results + master_data.get("financial_results", [])
    master_data["shareholding_patterns"] = new_shp + master_data.get("shareholding_patterns", [])

    # Memory ceilings
    master_data["corporate_announcements"] = master_data["corporate_announcements"][:3000]
    master_data["financial_results"] = master_data["financial_results"][:1500]
    master_data["shareholding_patterns"] = master_data["shareholding_patterns"][:1500]

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 RICH ACTIONABLE DATA HARVESTED:")
    print(f"   • Actionable Filings with Details/PDF : {len(new_announcements)} (PDFs parsed: {pdf_downloads})")
    print(f"   • Verified Financial Results (with ₹) : {len(new_results)}")
    print(f"   • Verified Shareholding Patterns      : {len(new_shp)}")
    print(f"💾 Saved to: '{MASTER_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_nse_daily_master()
