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
# CONFIGURATION & 3-DAY RETENTION
# ============================================================

BASE_URL = "https://www.nseindia.com"
MASTER_FILE = "nse_corporate_master.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

RETENTION_DAYS = 3
CUTOFF_TIME = NOW - timedelta(days=RETENTION_DAYS)

TO_DATE = NOW.strftime("%d-%m-%Y")
FROM_DATE = CUTOFF_TIME.strftime("%d-%m-%Y")

# Minimum Materiality Floors (Crores)
MIN_REVENUE_FLOOR_CR = 25.0
MIN_PAT_FLOOR_CR = 5.0

ENDPOINTS = {
    "announcements": f"https://www.nseindia.com/api/corporate-announcements?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}",
    "financial_results": "https://www.nseindia.com/api/corporates-financial-results?index=equities&period=Quarterly",
    "shareholding_patterns": f"https://www.nseindia.com/api/corporate-share-holdings-master?index=equities&from_date={FROM_DATE}&to_date={TO_DATE}",
    "pledged_data": "https://www.nseindia.com/api/corporate-pledged-data?index=equities"
}

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
# TARGET CATEGORIES (EXCLUDING FUND_RAISE, RATING, COURT/GIFT)
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
    r'gift|inter-se|family trust|huf|transmission of shares|promoter group transfer|'
    r'regulation 29|regulation 31|sast|'
    r'amalgamation|scheme of amalgamation|scheme of arrangement|wholly owned subsidiary|'
    r'wholly-owned subsidiary|wos|merger of subsidiary|internal restructuring|'
    r'credit rating|rating assigned|rating upgrade|rating revised|care|crisil|icra|infomerics|brickwork|'
    r'fund raising|fund raise|qip|rights issue|preferential issue|preferential allotment|warrants|fpo|'
    r'tax order|assessment order|demand order|penalty|nclt order|court order|show cause notice|adjudication order|'
    r'trading window|closure of trading|prior intimation|schedule of board meeting|intimation of board meeting|'
    r'investor presentation|transcript|audio recording|earnings call|analyst meet|investor meet|clarification|reply to clarification|'
    r'loss of share|duplicate share|newspaper|clipping|scrutinizer|postal ballot|general meeting|annual general meeting|'
    r'e-voting|change in address|change of registered office|appointment of|resignation of|esop|stock option|'
    r'regulation 57|payment of interest|payment of principal|scheduled principal|commercial paper|cp maturity'
    r')\b',
    re.IGNORECASE
)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

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
    if val is None:
        return None
    s = str(val).replace(",", "").replace("%", "").strip()
    try:
        return float(s)
    except ValueError:
        return None

def is_within_retention_window(date_str):
    if not date_str:
        return False
    date_clean = date_str.strip()
    for fmt in ("%d-%b-%Y %H:%M:%S", "%d-%b-%Y", "%Y-%m-%d"):
        try:
            target = date_clean if fmt == "%d-%b-%Y %H:%M:%S" else date_clean.split()[0]
            dt = datetime.strptime(target, fmt).replace(tzinfo=IST)
            return dt >= CUTOFF_TIME
        except Exception:
            pass
    return True

# ============================================================
# FORENSIC PDF TABLE EXTRACTOR (LEVEL 3)
# ============================================================

def parse_forensic_results_pdf(pdf_bytes):
    """Scans Statement of P&L tables for Exceptional Items, Other Income, and Operating Metrics"""
    forensics = {
        "exceptional_items": 0.0,
        "other_income": 0.0,
        "ebitda": None,
        "ebit": None,
        "finance_cost": None,
        "depreciation": None,
        "pbt": None,
        "segment_revenue": {},
        "segment_profit": {},
        "is_one_off_driven": False,
        "notes": ""
    }
    if not pdfplumber:
        return forensics

    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            full_text = " ".join([page.extract_text() or "" for page in pdf.pages[:4]])
            forensics["notes"] = full_text[:2000]

            # 1. Exceptional / Extraordinary Items Scan
            exc_match = re.search(r'Exceptional (?:Items|Gain|Loss)[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if exc_match:
                forensics["exceptional_items"] = clean_num(exc_match.group(1)) or 0.0

            # 2. Other Income Scan
            oth_match = re.search(r'Other Income[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if oth_match:
                forensics["other_income"] = clean_num(oth_match.group(1)) or 0.0

            # 3. PBT, Finance Cost, Depreciation
            pbt_match = re.search(r'Profit Before Tax[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if pbt_match:
                forensics["pbt"] = clean_num(pbt_match.group(1))

            fin_match = re.search(r'Finance Costs?[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if fin_match:
                forensics["finance_cost"] = clean_num(fin_match.group(1))

            dep_match = re.search(r'(?:Depreciation|Amortisation)[^\d]+([\d,\.]+)', full_text, re.IGNORECASE)
            if dep_match:
                forensics["depreciation"] = clean_num(dep_match.group(1))

            # 4. Segment Reporting Scan
            if "segment" in full_text.lower():
                seg_matches = re.findall(r'([A-Za-z\s]{4,25})\s+([\d,\.]+)\s+([\d,\.]+)', full_text)
                for sm in seg_matches[:4]:
                    sec_name = sm[0].strip()
                    if sec_name.lower() not in ["total", "segment", "quarter", "particulars", "unallocated"]:
                        forensics["segment_revenue"][sec_name] = sm[1]
                        forensics["segment_profit"][sec_name] = sm[2]

    except Exception:
        pass

    return forensics

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

        forensics = {}
        if is_result and pdf_bytes:
            forensics = parse_forensic_results_pdf(pdf_bytes)

        return extracted_text, forensics
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
# MASTER ORCHESTRATOR
# ============================================================

def run_nse_hourly_master():
    print("=" * 80)
    print("🚀 ADVANCED FINANCIAL FILTER & CORPORATE MASTER ENGINE")
    print(f"📅 Scan Window: {FROM_DATE} to {TO_DATE}")
    print("=" * 80)

    master_data = {
        "last_updated": "",
        "corporate_announcements": [],
        "financial_results": [],
        "shareholding_patterns": []
    }

    if os.path.exists(MASTER_FILE):
        try:
            with open(MASTER_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    master_data = loaded
                    master_data["corporate_announcements"] = [
                        a for a in master_data.get("corporate_announcements", [])
                        if is_within_retention_window(a.get("broadcast_date"))
                    ]
                    master_data["financial_results"] = [
                        r for r in master_data.get("financial_results", [])
                        if is_within_retention_window(r.get("result_date"))
                    ]
                    master_data["shareholding_patterns"] = [
                        s for s in master_data.get("shareholding_patterns", [])
                        if is_within_retention_window(s.get("as_on_date"))
                    ]
        except Exception:
            pass

    seen_announcement_hashes = {a.get("hash") for a in master_data["corporate_announcements"] if a.get("hash")}
    seen_result_hashes = {r.get("hash") for r in master_data["financial_results"] if r.get("hash")}
    seen_shp_hashes = {s.get("hash") for s in master_data["shareholding_patterns"] if s.get("hash")}

    previous_shp_lookup = {}
    for entry in master_data["shareholding_patterns"]:
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
    # 1. Actionable Announcements (Pre-Filtered via Regex)
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

        if not symbol or not subject or not is_within_retention_window(broadcast_dt):
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
                print(f"   📄 [{pdf_downloads + 1}/{MAX_PDF_DOWNLOADS}] Extracting Actionable PDF: {symbol} | {category}...")
                pdf_text, _ = extract_pdf_data(session, pdf_url, is_result=(category == "RESULT"))
                if pdf_text:
                    pdf_downloads += 1
                time.sleep(1.8)

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
    # 2. Financial Results (4-Level Filter & Pre-Check)
    # ------------------------------------------------------------
    raw_results = safe_api_get(
        session, 
        ENDPOINTS["financial_results"], 
        "Financial Results Table", 
        "https://www.nseindia.com/companies-listing/corporate-filings-financial-results"
    )
    time.sleep(1.5)

    new_results = []
    for r in raw_results:
        symbol = str(r.get("symbol", "")).strip()
        comp_name = str(r.get("companyName") or r.get("sm_name", "")).strip()
        period = str(r.get("period") or r.get("audited", "")).strip()
        res_date = str(r.get("res_dt") or r.get("resultDate") or r.get("broadcastDate", "")).strip()
        
        income = clean_num(r.get("income") or r.get("revenue") or r.get("tot_inc"))
        net_profit = clean_num(r.get("netProfit") or r.get("pro_aft_tax"))
        eps = str(r.get("eps") or r.get("re_eps", "")).strip()
        att_file = str(r.get("attchmntFile", "")).strip()

        # Prior Year / Prior Period Numbers (if available in raw API feed)
        prev_income = clean_num(r.get("re_venue_prev") or r.get("income_prev"))
        prev_net_profit = clean_num(r.get("net_profit_prev") or r.get("pro_aft_tax_prev"))

        if not symbol or not is_within_retention_window(res_date):
            continue
        if income is None or net_profit is None:
            continue

        # ------------------------------------------------------------
        # LEVEL 1: Materiality Floor Check (Exclude Penny / Micro-caps)
        # ------------------------------------------------------------
        if income < MIN_REVENUE_FLOOR_CR or net_profit < MIN_PAT_FLOOR_CR:
            continue

        # ------------------------------------------------------------
        # LEVEL 2: Mathematical Outlier Triggers
        # ------------------------------------------------------------
        is_turnaround = False
        yoy_pat_growth = None
        yoy_revenue_growth = None

        if prev_net_profit is not None:
            if prev_net_profit <= 0 and net_profit >= MIN_PAT_FLOOR_CR:
                is_turnaround = True
            elif prev_net_profit > 0:
                yoy_pat_growth = round(((net_profit - prev_net_profit) / prev_net_profit) * 100, 2)

        if prev_income is not None and prev_income > 0:
            yoy_revenue_growth = round(((income - prev_income) / prev_income) * 100, 2)

        # Trigger Condition: Turnaround OR (PAT Growth >= 100% AND Revenue Growth >= 20%)
        is_high_growth = (yoy_pat_growth is not None and yoy_pat_growth >= 100.0)
        has_healthy_revenue = (yoy_revenue_growth is None or yoy_revenue_growth >= 20.0)

        # Skip normal results
        if not is_turnaround and not (is_high_growth and has_healthy_revenue):
            continue

        r_hash = generate_hash(f"{symbol}_{period}_{res_date}")
        if r_hash in seen_result_hashes:
            continue

        # ------------------------------------------------------------
        # LEVEL 3: Targeted PDF Download & Forensic P&L Extraction
        # ------------------------------------------------------------
        forensics = {}
        pdf_url = ""
        if att_file and pdf_downloads < MAX_PDF_DOWNLOADS:
            pdf_url = att_file if att_file.startswith("http") else f"https://nsearchives.nseindia.com/corporate/{att_file}"
            print(f"   🔍 Forensic Scan on Outlier Result: {symbol} (PAT: ₹{net_profit} Cr)...")
            _, forensics = extract_pdf_data(session, pdf_url, is_result=True)
            pdf_downloads += 1
            time.sleep(1.8)

        # Accounting distortion check
        exceptional = forensics.get("exceptional_items", 0.0)
        is_one_off = (exceptional >= (0.40 * net_profit)) if net_profit > 0 else False

        signal_tag = "LOSS_TO_PROFIT" if is_turnaround else "EXCEPTIONAL_GROWTH"
        if is_one_off:
            signal_tag += "_ONE_OFF_DRIVEN"

        new_results.append({
            "hash": r_hash,
            "symbol": symbol,
            "company_name": comp_name,
            "period": period,
            "signal_tag": signal_tag,
            "revenue": income,
            "pat": net_profit,
            "eps": eps,
            "yoy_pat_growth": yoy_pat_growth,
            "yoy_revenue_growth": yoy_revenue_growth,
            "exceptional_items": exceptional,
            "other_income": forensics.get("other_income", 0.0),
            "pbt": forensics.get("pbt"),
            "finance_cost": forensics.get("finance_cost"),
            "depreciation": forensics.get("depreciation"),
            "segment_revenue": forensics.get("segment_revenue", {}),
            "segment_profit": forensics.get("segment_profit", {}),
            "is_one_off_driven": is_one_off,
            "result_date": res_date,
            "pdf_link": pdf_url
        })
        seen_result_hashes.add(r_hash)
        print(f"   ⭐ [QUALIFIED RESULT]: {symbol} | Tag: {signal_tag} | Revenue: ₹{income} Cr | PAT: ₹{net_profit} Cr")

    # ------------------------------------------------------------
    # 3. Shareholding Patterns & Delta Calculation
    # ------------------------------------------------------------
    raw_shp = safe_api_get(
        session, 
        ENDPOINTS["shareholding_patterns"], 
        "Shareholding Patterns", 
        "https://www.nseindia.com/companies-listing/corporate-filings-shareholding-pattern"
    )
    time.sleep(1.5)

    raw_pledge = safe_api_get(session, ENDPOINTS["pledged_data"], "Pledged Shareholding Feed")
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

        if not symbol or not is_within_retention_window(as_on_date):
            continue
        if promoter_val is None and public_val is None:
            continue

        s_hash = generate_hash(f"{symbol}_{as_on_date}")
        if s_hash in seen_shp_hashes:
            continue

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
    # 4. Save Clean Master File
    # ------------------------------------------------------------
    master_data["last_updated"] = NOW.strftime("%Y-%m-%d %H:%M:%S IST")
    master_data["corporate_announcements"] = new_announcements + master_data["corporate_announcements"]
    master_data["financial_results"] = new_results + master_data["financial_results"]
    master_data["shareholding_patterns"] = new_shp + master_data["shareholding_patterns"]

    master_data["corporate_announcements"] = [
        a for a in master_data["corporate_announcements"] if is_within_retention_window(a.get("broadcast_date"))
    ]
    master_data["financial_results"] = [
        r for r in master_data["financial_results"] if is_within_retention_window(r.get("result_date"))
    ]
    master_data["shareholding_patterns"] = [
        s for s in master_data["shareholding_patterns"] if is_within_retention_window(s.get("as_on_date"))
    ]

    with open(MASTER_FILE, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print("📊 EXTRACTION COMPLETED:")
    print(f"   • Actionable Business Filings : {len(new_announcements)}")
    print(f"   • High-Signal Financial Gems  : {len(new_results)} (Filtered from ~2000 filings)")
    print(f"   • Shareholding Records Added  : {len(new_shp)}")
    print(f"💾 Saved to                      : '{MASTER_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    run_nse_hourly_master()
