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
# CONFIGURATION
# ============================================================

BASE_URL = "https://www.nseindia.com"
MASTER_FILE = "nse_corporate_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

TO_DATE = NOW.strftime("%d-%m-%Y")
FROM_DATE = (NOW - timedelta(days=15)).strftime("%d-%m-%Y")

ENDPOINTS = {
    "announcements": f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}",
    "financial_results": "https://www.nseindia.com/api/corporates-financial-results?index=equities&period=Quarterly",
    "shareholding_patterns": f"https://www.nseindia.com/api/corporate-share-holdings-master?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}",
    "pledged_data": "https://www.nseindia.com/api/corporate-pledged-data?index=equities"
}

MAX_PDF_DOWNLOADS = 40

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
# TARGET CATEGORIES (EXPANDED TO ALL STRATEGIC ACTIONS)
# ============================================================

CATEGORY_PATTERNS = {
    "ORDER": re.compile(
        r'\b(order win|order received|awarded|contract|bagged|letter of intent|loi|work order|purchase order|new order|commercial agreement)\b', 
        re.IGNORECASE
    ),
    "ACQUISITION": re.compile(
        r'\b(acquisition of.*business|takeover|acquires.*stake|acquiring.*stake|slump sale|purchase of business)\b', 
        re.IGNORECASE
    ),
    "DIVESTMENT": re.compile(
        r'\b(divestment|divestiture|stake sale|sale of subsidiary|sale of division|slump sale of|hive-off|demerger of)\b', 
        re.IGNORECASE
    ),
    "NEW_BUSINESS": re.compile(
        r'\b(new line of business|entry into|diversification into|commencement of new business|venturing into)\b', 
        re.IGNORECASE
    ),
    "NEW_PRODUCT": re.compile(
        r'\b(product launch|launch of new product|commercial launch of|unveiled new|introduced new product|commercialisation of)\b', 
        re.IGNORECASE
    ),
    "JV": re.compile(
        r'\b(joint venture|jv agreement|incorporation of jv|joint venture agreement|jv company)\b', 
        re.IGNORECASE
    ),
    "STRATEGIC_PARTNERSHIP": re.compile(
        r'\b(strategic partnership|strategic tie-up|memorandum of understanding|mou signed|collaboration agreement|teaming agreement)\b', 
        re.IGNORECASE
    ),
    "COMMERCIAL_PRODUCTION": re.compile(
        r'\b(commencement of commercial production|commercial operations|starts commercial production|trial run completed|successful commissioning)\b', 
        re.IGNORECASE
    ),
    "CAPACITY_EXPANSION": re.compile(
        r'\b(capacity expansion|new plant|capex|manufacturing facility|greenfield|brownfield|expansion project|new unit)\b', 
        re.IGNORECASE
    ),
    "RESULT": re.compile(
        r'\b(financial result|financial results|audited results|unaudited results|quarterly results|outcome of board meeting.*financial)\b', 
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
    r'\b('
    # Family gift & Internal reorganizations
    r'gift|inter-se|family trust|huf|transmission of shares|promoter group transfer|'
    r'regulation 29|regulation 31|sast|'
    r'amalgamation|scheme of amalgamation|scheme of arrangement|wholly owned subsidiary|'
    r'wholly-owned subsidiary|wos|merger of subsidiary|internal restructuring|'
    # Blocked Categories
    r'credit rating|rating assigned|rating upgrade|rating revised|care|crisil|icra|infomerics|brickwork|'
    r'fund raising|fund raise|qip|rights issue|preferential issue|preferential allotment|warrants|fpo|'
    # Court / Tax
    r'tax order|assessment order|demand order|penalty|nclt order|court order|show cause notice|adjudication order|'
    # Result Noise
    r'trading window|closure of trading|prior intimation|schedule of board meeting|intimation of board meeting|'
    r'investor presentation|transcript|audio recording|earnings call|analyst meet|investor meet|clarification|reply to clarification|'
    # Routine HR / Admin / Compliance
    r'loss of share|duplicate share|newspaper|clipping|scrutinizer|postal ballot|general meeting|annual general meeting|'
    r'e-voting|change in address|change of registered office|appointment of|resignation of|esop|stock option|'
    r'regulation 57|payment of interest|payment of principal|scheduled principal|commercial paper|cp maturity'
    r')\b',
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

def clean_num(val):
    """Safely converts string holding percentages/numbers to float"""
    if val is None:
        return None
    s = str(val).replace(",", "").replace("%", "").strip()
    try:
        return float(s)
    except ValueError:
        return None

# ============================================================
# DEEP METRICS PDF PARSER (SEBI STATEMENT PARSING)
# ============================================================

def parse_deep_financial_metrics(pdf_bytes):
    """
    Extracts deep SEBI line-items (EBITDA, PBT, Finance Cost, Segments) 
    from Financial Result PDF
    """
    metrics = {
        "revenue": None,
        "ebitda": None,
        "ebit": None,
        "finance_cost": None,
        "depreciation": None,
        "pbt": None,
        "pat": None,
        "eps": None,
        "cash_flow": None,
        "debt": None,
        "segment_revenue": {},
        "segment_profit": {}
    }
    
    if not pdfplumber:
        return metrics

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            full_text = " ".join([page.extract_text() or "" for page in pdf.pages[:5]])
            
            # 1. Regex checks for standard line items
            pbt_match = re.search(r'Profit Before Tax[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if pbt_match:
                metrics["pbt"] = pbt_match.group(1)

            fin_cost = re.search(r'Finance Costs?[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if fin_cost:
                metrics["finance_cost"] = fin_cost.group(1)

            dep_match = re.search(r'(?:Depreciation|Amortisation)[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if dep_match:
                metrics["depreciation"] = dep_match.group(1)

            # 2. Check for Segment Reporting section
            if "segment" in full_text.lower():
                seg_match = re.findall(r'([A-Za-z\s]{4,25})\s+([\d,\.]+)\s+([\d,\.]+)', full_text)
                for sm in seg_match[:4]:
                    sec_name = sm[0].strip()
                    if sec_name.lower() not in ["total", "segment", "quarter", "particulars"]:
                        metrics["segment_revenue"][sec_name] = sm[1]
                        metrics["segment_profit"][sec_name] = sm[2]

            # 3. Cash flow & Debt keyword detection
            cf_match = re.search(r'Net Cash (?:from|generated from) Operating Activities[^\d]+([\d,\.\-]+)', full_text, re.IGNORECASE)
            if cf_match:
                metrics["cash_flow"] = cf_match.group(1)

            debt_match = re.search(r'Total (?:Borrowings|Debt)[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if debt_match:
                metrics["debt"] = debt_match.group(1)

    except Exception:
        pass

    return metrics


def extract_pdf_data(session, pdf_url, is_result=False):
    if not pdf_url:
        return "", {}
    
    pdf_headers = {
        "User-Agent": HEADERS["User-Agent"],
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Host": "nsearchives.nseindia.com",
        "Referer": "https://www.nseindia.com/companies-listing/corporate-filings-announcements"
    }

    try:
        resp = session.get(pdf_url, headers=pdf_headers, timeout=25)
        if resp.status_code != 200 or not resp.content.startswith(b'%PDF'):
            return "", {}

        pdf_bytes = resp.content
        extracted_text = ""

        # Extract text representation
        if pdfplumber:
            try:
                with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
                    pages = [p.extract_text() for p in pdf.pages[:3] if p.extract_text()]
                    extracted_text = " ".join(" ".join(pages).split())[:3000]
            except Exception:
                pass

        if not extracted_text:
            reader = PdfReader(io.BytesIO(pdf_bytes))
            pages = [p.extract_text() for p in reader.pages[:3] if p.extract_text()]
            extracted_text = " ".join(" ".join(pages).split())[:3000]

        # Deep metrics extraction if it's a financial result filing
        deep_metrics = {}
        if is_result and pdf_bytes:
            deep_metrics = parse_deep_financial_metrics(pdf_bytes)

        return extracted_text, deep_metrics

    except Exception:
        return "", {}

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
# MASTER ORCHESTRATOR WITH DELTA CALCULATIONS
# ============================================================

def run_nse_daily_master():
    print("=" * 80)
    print("🚀 ADVANCED NSE CORPORATE ACTIONS & FINANCIAL MASTER")
    print(f"📅 Scan Window: {FROM_DATE} to {TO_DATE}")
    print("=" * 80)

    master_data = {
        "last_updated": "",
        "corporate_announcements": [],
        "financial_results": [],
        "shareholding_patterns": []
    }

    # Load existing state
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

    # Build historical lookup map for Shareholding Changes calculation
    # Format: {symbol: {promoter, fii, dii, pledge}}
    previous_shp_lookup = {}
    for entry in master_data.get("shareholding_patterns", []):
        sym = entry.get("symbol")
        if sym and sym not in previous_shp_lookup:
            previous_shp_lookup[sym] = {
                "promoter": clean_num(entry.get("promoter_holding")),
                "fii": clean_num(entry.get("fii_holding")),
                "dii": clean_num(entry.get("dii_holding")),
                "pledge": clean_num(entry.get("promoter_pledged"))
            }

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
    # 1. Actionable Announcements (All Strategic Actions + PDF)
    # ------------------------------------------------------------
    raw_announcements = safe_api_get(
        session, 
        ENDPOINTS["announcements"], 
        "Corporate Announcements", 
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
                print(f"   📄 [{pdf_downloads + 1}/{MAX_PDF_DOWNLOADS}] Extracting PDF: {symbol} | {category}...")
                pdf_text, _ = extract_pdf_data(session, pdf_url, is_result=(category == "RESULT"))
                if pdf_text:
                    pdf_downloads += 1
                time.sleep(1.8)

        # Zero-Blank PDF Guard
        if not pdf_text:
            continue

        new_announcements.append({
            "hash": item_hash,
            "category": category,
            "symbol": symbol,
            "company_name": str(item.get("sm_name") or item.get("companyName", "")).strip(),
            "subject": subject,
            "broadcast_date": broadcast_dt,
            "summary": summary[:400],
            "pdf_link": pdf_url,
            "pdf_extracted_text": pdf_text
        })
        seen_announcement_hashes.add(item_hash)

    # ------------------------------------------------------------
    # 2. Deep Financial Results (Standard + PDF Breakdown)
    # ------------------------------------------------------------
    raw_results = safe_api_get(
        session, 
        ENDPOINTS["financial_results"], 
        "Financial Results", 
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
        net_profit = str(r.get("netProfit") or r.get("pro_aft_tax", "")).strip()
        eps = str(r.get("eps") or r.get("re_eps", "")).strip()
        att_file = str(r.get("attchmntFile", "")).strip()

        if not symbol or (not income and not net_profit):
            continue

        r_hash = generate_hash(f"{symbol}_{period}_{res_date}")
        if r_hash in seen_result_hashes:
            continue

        # Extract deep metrics from statement if PDF is available
        deep_data = {}
        if att_file and pdf_downloads < MAX_PDF_DOWNLOADS:
            pdf_url = att_file if att_file.startswith("http") else f"https://nsearchives.nseindia.com/corporate/{att_file}"
            _, deep_data = extract_pdf_data(session, pdf_url, is_result=True)
            time.sleep(1.5)

        new_results.append({
            "hash": r_hash,
            "symbol": symbol,
            "company_name": comp_name,
            "period": period,
            "revenue": income,
            "pat": net_profit,
            "eps": eps,
            "pbt": deep_data.get("pbt"),
            "finance_cost": deep_data.get("finance_cost"),
            "depreciation": deep_data.get("depreciation"),
            "cash_flow": deep_data.get("cash_flow"),
            "debt": deep_data.get("debt"),
            "segment_revenue": deep_data.get("segment_revenue", {}),
            "segment_profit": deep_data.get("segment_profit", {}),
            "result_date": res_date
        })
        seen_result_hashes.add(r_hash)

    # ------------------------------------------------------------
    # 3. Shareholding Patterns & Automatic Change Calculation
    # ------------------------------------------------------------
    raw_shp = safe_api_get(
        session, 
        ENDPOINTS["shareholding_patterns"], 
        "Shareholding Patterns", 
        "https://www.nseindia.com/companies-listing/corporate-filings-shareholding-pattern"
    )
    time.sleep(1.5)

    # Fetch Pledged / Encumbrance data
    raw_pledge = safe_api_get(
        session, 
        ENDPOINTS["pledged_data"], 
        "Pledged Shareholding Feed"
    )
    pledge_map = {}
    for p in raw_pledge:
        sym = str(p.get("symbol", "")).strip()
        pledged_pct = clean_num(p.get("promoterPledgedPct") or p.get("pledgedPct"))
        if sym and pledged_pct is not None:
            pledge_map[sym] = pledged_pct

    new_shp = []
    for s in raw_shp:
        symbol = str(s.get("symbol", "")).strip()
        comp_name = str(s.get("sm_name") or s.get("companyName", "")).strip()
        as_on_date = str(s.get("sh_dt") or s.get("asOnDate") or s.get("date", "")).strip()
        
        promoter_val = clean_num(s.get("promoterAndPromoterGroup") or s.get("promoter"))
        public_val = clean_num(s.get("public"))
        fii_val = clean_num(s.get("fii") or s.get("foreignPortfolioInvestors"))
        dii_val = clean_num(s.get("dii") or s.get("domesticInstitutions"))
        current_pledge = pledge_map.get(symbol, 0.0)

        if not symbol or as_on_date in ["", "-", "None", "null"]:
            continue
        if promoter_val is None and public_val is None:
            continue

        s_hash = generate_hash(f"{symbol}_{as_on_date}")
        if s_hash in seen_shp_hashes:
            continue

        # Calculate QoQ Changes (Deltas)
        prev = previous_shp_lookup.get(symbol, {})
        promoter_change = round(promoter_val - prev["promoter"], 2) if (promoter_val is not None and prev.get("promoter") is not None) else None
        fii_change = round(fii_val - prev["fii"], 2) if (fii_val is not None and prev.get("fii") is not None) else None
        dii_change = round(dii_val - prev["dii"], 2) if (dii_val is not None and prev.get("dii") is not None) else None
        pledge_change = round(current_pledge - prev["pledge"], 2) if (current_pledge is not None and prev.get("pledge") is not None) else None

        new_shp.append({
            "hash": s_hash,
            "symbol": symbol,
            "company_name": comp_name,
            "as_on_date": as_on_date,
            "promoter_holding": promoter_val,
            "promoter_change": promoter_change,
            "fii_holding": fii_val,
            "fii_change": fii_change,
            "dii_holding": dii_val,
            "dii_change": dii_change,
            "promoter_pledged": current_pledge,
            "pledge_change": pledge_change,
            "public_holding": public_val
        })
        seen_shp_hashes.add(s_hash)

    # ------------------------------------------------------------
    # 4. Save Master File
    # ------------------------------------------------------------
    master_data["last_updated"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    master_data["corporate_announcements"] = new_announcements + master_data.get("corporate_announcements", [])
    master_data["financial_results"] = new_results + master_data.get("financial_results", [])
    master_data["shareholding_patterns"] = new_shp + master_data.get("shareholding_patterns", [])

    master_data["corporate_announcements"] = master_data["corporate_announcements"][:3000]
    master_data["financial_results"] = master_data["financial_results"][:1500]
    master_data["shareholding_patterns"] = master_data["shareholding_patterns"][:1500]

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 EXTRACTION COMPLETED:")
    print(f"   • Strategic Filings (with PDF)       : {len(new_announcements)}")
    print(f"   • Deep Results (EBITDA/PBT/Segments) : {len(new_results)}")
    print(f"   • Shareholding Records (with Deltas) : {len(new_shp)}")
    print(f"💾 Clean Master Saved to                : '{MASTER_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_nse_daily_master()
