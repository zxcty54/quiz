import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
import pymupdf

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.1-8b-instant", "mixtral-8x7b-32768", "llama-3.3-70b-versatile"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
}

# -------------------------------------------------------------
# 2. ACCURATE ORGANIZATION MAPPING DICTIONARY
# -------------------------------------------------------------
ORG_MAP = {
    # Bihar State Bodies
    "bpsc": "Bihar Public Service Commission (BPSC)",
    "bssc": "Bihar Staff Selection Commission (BSSC)",
    "csbc": "Central Selection Board of Constable (CSBC)",
    "bpssc": "Bihar Police Subordinate Services Commission (BPSSC)",
    "btsc": "Bihar Technical Service Commission (BTSC)",
    "bceceb": "Bihar Combined Entrance Competitive Examination Board (BCECEB)",
    "beltron": "Bihar State Electronics Development Corporation (BELTRON)",
    "vidhan sabha": "Bihar Vidhan Sabha",
    "vidhan parishad": "Bihar Vidhan Parishad",
    "civil court": "Bihar Civil Court",
    "patna high court": "Patna High Court",
    "bihar health": "Bihar State Health Society (SHSB)",
    "bihar teacher": "Bihar School Examination Board (BSEB / TRE)",
    "wcdc": "Women and Child Development Corporation (WCDC Bihar)",
    "anganwadi": "Bihar Social Welfare Dept (Anganwadi)",
    "ration dealer": "Bihar Food & Consumer Protection Dept",
    
    # Central Govt & Human Rights / PSU Bodies
    "nhrc": "National Human Rights Commission (NHRC)",
    "ssc": "Staff Selection Commission (SSC)",
    "rrb": "Railway Recruitment Board (RRB)",
    "railway": "Indian Railways",
    "ibps": "Institute of Banking Personnel Selection (IBPS)",
    "sbi": "State Bank of India (SBI)",
    "rbi": "Reserve Bank of India (RBI)",
    "upsc": "Union Public Service Commission (UPSC)",
    "epfo": "Employees' Provident Fund Organisation (EPFO)",
    "esic": "Employees' State Insurance Corporation (ESIC)",
    "lic": "Life Insurance Corporation of India (LIC)",
    "fci": "Food Corporation of India (FCI)",
    "aiims": "All India Institute of Medical Sciences (AIIMS)",
    "drdo": "Defence Research and Development Organisation (DRDO)",
    "isro": "Indian Space Research Organisation (ISRO)",
    "nta": "National Testing Agency (NTA)",
    "icar": "Indian Council of Agricultural Research (ICAR)",
    "post": "India Post / Department of Posts",
    "coast guard": "Indian Coast Guard",
    "navy": "Indian Navy",
    "army": "Indian Army",
    "air force": "Indian Air Force",
    "bsf": "Border Security Force (BSF)",
    "crpf": "Central Reserve Police Force (CRPF)",
    "cisf": "Central Industrial Security Force (CISF)",
    "itbp": "Indo-Tibetan Border Police (ITBP)"
}

OFFICIAL_SOURCES = [
    {"name": "BPSC Bihar Official", "url": "https://www.bpsc.bih.nic.in/", "org": "Bihar Public Service Commission (BPSC)", "type": "job"},
    {"name": "BSSC Notice Board", "url": "https://bssc.bihar.gov.in/NoticeBoard.adp", "org": "Bihar Staff Selection Commission (BSSC)", "type": "job"},
    {"name": "BPSSC Police Notices", "url": "https://bpssc.bih.nic.in/", "org": "Bihar Police Subordinate Services Commission (BPSSC)", "type": "job"},
    {"name": "CSBC Constable Notices", "url": "https://csbc.bih.nic.in/", "org": "Central Selection Board of Constable (CSBC)", "type": "job"},
    {"name": "UPSC Whats New", "url": "https://upsc.gov.in/whats-new", "org": "Union Public Service Commission (UPSC)", "type": "job"},
    {"name": "IBPS CRP Recruitment", "url": "https://www.ibps.in/", "org": "Institute of Banking Personnel Selection (IBPS)", "type": "job"},
    {"name": "RRB Patna Official", "url": "https://www.rrbpatna.gov.in/", "org": "Railway Recruitment Board (RRB Patna)", "type": "job"}
]

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ORG_MAP.items():
        if re.search(r'\b' + re.escape(key) + r'\b', text_lower):
            return full_name
    return "Central / Bihar Govt Agency"

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def remove_markdown_stars(data):
    if isinstance(data, dict):
        return {k: remove_markdown_stars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [remove_markdown_stars(item) for item in data]
    elif isinstance(data, str):
        return data.replace("**", "").replace("##", "").strip()
    return data

def clean_post_name(title):
    clean = re.sub(r'Recruitment\s*\d{4}', '', title, flags=re.IGNORECASE)
    clean = re.sub(r'(Notification Out|Apply Online|Apply Offline|Walkin for|Walkin|Vacancy\s*\d{4}|Important Notice regarding)', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'for\s*\d+\s*(Posts|Vacancies)', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'-\s*$', '', clean).strip()
    if "-" in clean:
        parts = clean.split("-")
        clean = parts[-1].strip() if len(parts[-1].strip()) > 3 else clean
    return clean[:60].strip()

# -------------------------------------------------------------
# 3. REGEX PARSER (FEES, DATES, AGE, VACANCIES)
# -------------------------------------------------------------
def extract_fields_with_regex(text):
    extracted = {
        "application_fee": None,
        "start_date": None,
        "last_date": None,
        "age_limit": None,
        "total_vacancies": None,
        "qualification": None
    }

    # Fee Patterns
    fee_patterns = [
        r'(?:Application\s*Fee|Exam\s*Fee|Fee\s*Details)[\s\S]{1,250}?(?=\n\s*\n|Important|Age|Qualification|$)',
        r'(?:General\s*/?\s*OBC|UR\s*/?\s*EWS)[^.\n]*[₹\d]+[^.\n]*',
        r'(?:Gen\s*/?\s*OBC\s*:\s*₹?\d+[\s\S]{1,100}?SC\s*/?\s*ST\s*:\s*₹?\d+)'
    ]
    for pattern in fee_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            clean_fee = re.sub(r'\s+', ' ', match.group(0)).strip()
            extracted["application_fee"] = clean_fee[:150]
            break

    if not extracted["application_fee"]:
        if re.search(r'\b(no fee|free of cost|nil|exempted)\b', text, re.IGNORECASE):
            extracted["application_fee"] = "General / OBC / SC / ST: ₹0 (No Fee)"

    # Dates Pattern
    date_matches = re.findall(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b', text, re.IGNORECASE)
    if len(date_matches) >= 2:
        extracted["start_date"] = date_matches[0]
        extracted["last_date"] = date_matches[1]
    elif len(date_matches) == 1:
        extracted["last_date"] = date_matches[0]

    # Age Limit
    age_patterns = [
        r'(\d{2}\s*to\s*\d{2}\s*years)',
        r'(\d{2}\s*-\s*\d{2}\s*years)',
        r'(Minimum\s*Age\s*:\s*\d{2}[\s\S]{1,50}?Maximum\s*Age\s*:\s*\d{2})',
        r'(Min\.?\s*\d{2}\s*Yrs?[\s\S]{1,30}?Max\.?\s*\d{2}\s*Yrs?)'
    ]
    for pattern in age_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            clean_age = re.sub(r'\s+', ' ', match.group(0)).strip()
            extracted["age_limit"] = clean_age
            break

    # Vacancies
    vac_match = re.search(r'\b(\d{1,6})\s*(Posts|Vacancies|Seat|Seats)\b', text, re.IGNORECASE)
    if vac_match:
        extracted["total_vacancies"] = f"{vac_match.group(1)} Posts"

    # Qualification
    qual_match = re.search(r'(?:Educational\s*Qualification|Qualification)\s*:\s*([^.\n]+)', text, re.IGNORECASE)
    if qual_match:
        extracted["qualification"] = qual_match.group(1).strip()[:100]

    return extracted

# -------------------------------------------------------------
# 4. DIRECT PDF DOWNLOADER & PARSER
# -------------------------------------------------------------
def fetch_and_parse_pdf(pdf_url):
    print(f"  📥 [DOWNLOADING OFFICIAL PDF]: {pdf_url}")
    try:
        pdf_res = requests.get(pdf_url, headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
        if pdf_res.status_code == 200 and len(pdf_res.content) > 3000:
            doc = pymupdf.open(stream=pdf_res.content, filetype="pdf")
            pages_count = len(doc)
            pdf_text = ""
            for page_num in range(min(pages_count, 10)):
                pdf_text += doc[page_num].get_text("text") + "\n"
            
            clean_pdf_text = clean_html_text(pdf_text[:12000])
            if len(clean_pdf_text) > 150:
                print(f"  ✅ [PyMuPDF SUCCESS] Extracted {len(clean_pdf_text)} chars from Official PDF!")
                return clean_pdf_text
            else:
                print("  ⚠️ [SCANNED OFFICIAL PDF] Digital text empty.")
    except Exception as pe:
        print(f"  ❌ [PDF FETCH/PARSE ERROR]: {pe}")
    return ""

# -------------------------------------------------------------
# 5. MICRO-PROMPT GROQ AI FALLBACK
# -------------------------------------------------------------
def fill_missing_fields_with_ai(title, raw_snippet, missing_keys):
    if not GROQ_KEY or not missing_keys:
        return {}

    prompt = f"""
    Title: {title}
    Official Text: {raw_snippet[:2500]}

    Extract ONLY missing fields ({', '.join(missing_keys)}) in valid JSON.
    Schema:
    {{
      "application_fee": "Category-wise fee breakdown e.g. Gen/OBC: ₹500 | SC/ST: ₹100 or 'No Fee'",
      "start_date": "Exact start date or 'Online Active'",
      "last_date": "Exact last date e.g. 15 Sep 2026",
      "age_limit": "Min and Max age criteria",
      "qualification": "Exact Educational Qualification",
      "post_name": "Specific Post Name"
    }}
    """

    time.sleep(0.5)
    for model in MODELS:
        try:
            res = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are an official government recruitment parser. Output strictly JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                max_tokens=600,
                timeout=12
            )
            return json.loads(res.choices[0].message.content.strip())
        except Exception:
            pass
    return {}

# -------------------------------------------------------------
# 6. SEPARATE TITLE & INNER REJECTION RULES (PREVENTS FALSE POSITIVES)
# -------------------------------------------------------------
# Title filter: Filters unwanted states, university exams, offline walk-ins from title
TITLE_REJECT_PATTERNS = [
    r'\boffline\b', r'\bapply offline\b', r'\bwalkin\b', r'\bwalk-in\b', r'\bwalk in\b',
    r'\buniversity result\b', r'\bsemester result\b', r'\bba part\b', r'\bbsc result\b', r'\bbcom result\b',
    r'\badmissions?\b', r'\bcounselling schedule\b', r'\bscholarship\b', r'\bpost matric\b', r'\byojna\b',
    r'\buttar pradesh\b', r'\bup police\b', r'\buppsc\b', r'\bmadhya pradesh\b', r'\bmppsc\b',
    r'\brajasthan\b', r'\brpsc\b', r'\bharyana\b', r'\bhpsc\b', r'\bdsssb\b', r'\bmaharashtra\b',
    r'\bmpsc\b', r'\bjharkhand\b', r'\bjpsc\b', r'\bwest bengal\b', r'\bpunjab\b', r'\bgujarat\b',
    r'\btamil nadu\b', r'\btnpsc\b', r'\bandhra pradesh\b', r'\btelangana\b', r'\bkerala\b', r'\bkarnataka\b'
]

# Inner Text filter: ONLY filters explicitly Other State Govt Jobs or Scholarships (NO university/college/offline keywords here!)
INNER_REJECT_PATTERNS = [
    r'\buttar pradesh subordinate\b', r'\bup police recruitment\b', r'\brajasthan public service\b',
    r'\bmadhya pradesh public service\b', r'\bharyana staff selection\b', r'\bdelhi subordinate\b',
    r'\bscholarship scheme\b', r'\bpost matric scholarship\b'
]

def check_title_rejection(title):
    t_lower = title.lower()
    for pattern in TITLE_REJECT_PATTERNS:
        if re.search(pattern, t_lower):
            return pattern
    return None

def check_inner_rejection(text):
    t_lower = text.lower()
    for pattern in INNER_REJECT_PATTERNS:
        if re.search(pattern, t_lower):
            return pattern
    return None

# -------------------------------------------------------------
# 7. OFFICIAL PORTAL SCRAPER ENGINE
# -------------------------------------------------------------
def scrape_official_websites():
    official_items = []
    print("\n=======================================================")
    print("🏛️ [DIRECT OFFICIAL SCRAPER] Crawling Official Portals")
    print("=======================================================")

    for source in OFFICIAL_SOURCES:
        try:
            print(f"🌐 Fetching Official Portal: {source['name']}")
            res = requests.get(source['url'], headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
            if res.status_code != 200:
                continue

            soup = BeautifulSoup(res.content, "html.parser")
            a_tags = soup.find_all('a', href=True)

            count = 0
            for a_tag in a_tags:
                title = a_tag.text.strip()
                href = a_tag['href'].strip()

                if len(title) < 8 or check_title_rejection(title):
                    continue

                full_url = urljoin(source['url'], href)
                if full_url.endswith('.pdf') or any(kw in href.lower() or kw in title.lower() for kw in ["notice", "advt", "recruitment", "career"]):
                    official_items.append({
                        "title": title,
                        "url": full_url,
                        "org": source['org'],
                        "type": source['type']
                    })
                    count += 1
                    if count >= 6:
                        break

            print(f"  ✅ Extracted {count} official notices from {source['name']}")

        except Exception as e:
            print(f"  ⚠️ Official Scrape Warning ({source['name']}): {e}")

    return official_items

# -------------------------------------------------------------
# 8. BACKUP AGGREGATOR SCRAPER (SarkariResult + FreeJobAlert)
# -------------------------------------------------------------
def fetch_backup_rss_and_web():
    backup_items = []
    
    # 1. SarkariResult Direct Homepage
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=HEADERS, timeout=10, verify=False, impersonate="chrome")
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            boxes = soup.find_all('div', id=re.compile(r'box|post')) or soup.find_all('div', class_=re.compile(r'box|post'))
            for box in boxes:
                header = box.find(['h2', 'h3', 'div', 'b'])
                box_title = header.text.strip().lower() if header else ""
                
                item_type = "job"
                if "admit" in box_title or "hall ticket" in box_title:
                    item_type = "admit"
                elif "result" in box_title or "answer key" in box_title:
                    item_type = "result"

                for a_tag in box.find_all('a', href=True)[:12]:
                    title = a_tag.text.strip()
                    href = urljoin(sr_url, a_tag['href'].strip())
                    if title and len(title) > 6 and not check_title_rejection(title):
                        backup_items.append({"title": title, "url": href, "org": detect_organization(title), "type": item_type})
    except Exception as e:
        print(f"⚠️ SarkariResult Backup Scrape Warning: {e}")

    # 2. FreeJobAlert & Bihar Job Portal RSS Feeds
    rss_feeds = [
        ("FreeJobAlert Feed", "https://www.freejobalert.com/feed/"),
        ("Bihar Job Portal Feed", "https://biharjobportal.com/feed/")
    ]
    for label, feed_url in rss_feeds:
        try:
            res = requests.get(feed_url, headers=HEADERS, timeout=10, verify=False, impersonate="chrome")
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                for item in soup.find_all('item')[:12]:
                    title = item.find('title').text.strip() if item.find('title') is not None else ""
                    link = item.find('link').text.strip() if item.find('link') is not None else ""
                    
                    item_type = "job"
                    if "admit card" in title.lower() or "hall ticket" in title.lower():
                        item_type = "admit"
                    elif "result" in title.lower() or "answer key" in title.lower():
                        item_type = "result"

                    if title and not check_title_rejection(title):
                        backup_items.append({"title": title, "url": link, "org": detect_organization(title), "type": item_type})
        except Exception as e:
            print(f"⚠️ RSS Backup Warning ({label}): {e}")

    return backup_items

# -------------------------------------------------------------
# 9. MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
import pymupdf

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.1-8b-instant", "mixtral-8x7b-32768", "llama-3.3-70b-versatile"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
}

# -------------------------------------------------------------
# 2. ACCURATE ORGANIZATION MAPPING DICTIONARY
# -------------------------------------------------------------
ORG_MAP = {
    # Bihar State Bodies
    "bpsc": "Bihar Public Service Commission (BPSC)",
    "bssc": "Bihar Staff Selection Commission (BSSC)",
    "csbc": "Central Selection Board of Constable (CSBC)",
    "bpssc": "Bihar Police Subordinate Services Commission (BPSSC)",
    "btsc": "Bihar Technical Service Commission (BTSC)",
    "bceceb": "Bihar Combined Entrance Competitive Examination Board (BCECEB)",
    "beltron": "Bihar State Electronics Development Corporation (BELTRON)",
    "vidhan sabha": "Bihar Vidhan Sabha",
    "vidhan parishad": "Bihar Vidhan Parishad",
    "civil court": "Bihar Civil Court",
    "patna high court": "Patna High Court",
    "bihar health": "Bihar State Health Society (SHSB)",
    "bihar teacher": "Bihar School Examination Board (BSEB / TRE)",
    "wcdc": "Women and Child Development Corporation (WCDC Bihar)",
    "anganwadi": "Bihar Social Welfare Dept (Anganwadi)",
    "ration dealer": "Bihar Food & Consumer Protection Dept",
    
    # Central Govt & Human Rights / PSU Bodies
    "nhrc": "National Human Rights Commission (NHRC)",
    "ssc": "Staff Selection Commission (SSC)",
    "rrb": "Railway Recruitment Board (RRB)",
    "railway": "Indian Railways",
    "ibps": "Institute of Banking Personnel Selection (IBPS)",
    "sbi": "State Bank of India (SBI)",
    "rbi": "Reserve Bank of India (RBI)",
    "upsc": "Union Public Service Commission (UPSC)",
    "epfo": "Employees' Provident Fund Organisation (EPFO)",
    "esic": "Employees' State Insurance Corporation (ESIC)",
    "lic": "Life Insurance Corporation of India (LIC)",
    "fci": "Food Corporation of India (FCI)",
    "aiims": "All India Institute of Medical Sciences (AIIMS)",
    "drdo": "Defence Research and Development Organisation (DRDO)",
    "isro": "Indian Space Research Organisation (ISRO)",
    "nta": "National Testing Agency (NTA)",
    "icar": "Indian Council of Agricultural Research (ICAR)",
    "post": "India Post / Department of Posts",
    "coast guard": "Indian Coast Guard",
    "navy": "Indian Navy",
    "army": "Indian Army",
    "air force": "Indian Air Force",
    "bsf": "Border Security Force (BSF)",
    "crpf": "Central Reserve Police Force (CRPF)",
    "cisf": "Central Industrial Security Force (CISF)",
    "itbp": "Indo-Tibetan Border Police (ITBP)"
}

OFFICIAL_SOURCES = [
    {"name": "BPSC Bihar Official", "url": "https://www.bpsc.bih.nic.in/", "org": "Bihar Public Service Commission (BPSC)", "type": "job"},
    {"name": "BSSC Notice Board", "url": "https://bssc.bihar.gov.in/NoticeBoard.adp", "org": "Bihar Staff Selection Commission (BSSC)", "type": "job"},
    {"name": "BPSSC Police Notices", "url": "https://bpssc.bih.nic.in/", "org": "Bihar Police Subordinate Services Commission (BPSSC)", "type": "job"},
    {"name": "CSBC Constable Notices", "url": "https://csbc.bih.nic.in/", "org": "Central Selection Board of Constable (CSBC)", "type": "job"},
    {"name": "UPSC Whats New", "url": "https://upsc.gov.in/whats-new", "org": "Union Public Service Commission (UPSC)", "type": "job"},
    {"name": "IBPS CRP Recruitment", "url": "https://www.ibps.in/", "org": "Institute of Banking Personnel Selection (IBPS)", "type": "job"},
    {"name": "RRB Patna Official", "url": "https://www.rrbpatna.gov.in/", "org": "Railway Recruitment Board (RRB Patna)", "type": "job"}
]

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ORG_MAP.items():
        if re.search(r'\b' + re.escape(key) + r'\b', text_lower):
            return full_name
    return "Central / Bihar Govt Agency"

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def remove_markdown_stars(data):
    if isinstance(data, dict):
        return {k: remove_markdown_stars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [remove_markdown_stars(item) for item in data]
    elif isinstance(data, str):
        return data.replace("**", "").replace("##", "").strip()
    return data

def clean_post_name(title):
    clean = re.sub(r'Recruitment\s*\d{4}', '', title, flags=re.IGNORECASE)
    clean = re.sub(r'(Notification Out|Apply Online|Apply Offline|Walkin for|Walkin|Vacancy\s*\d{4}|Important Notice regarding)', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'for\s*\d+\s*(Posts|Vacancies)', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'-\s*$', '', clean).strip()
    if "-" in clean:
        parts = clean.split("-")
        clean = parts[-1].strip() if len(parts[-1].strip()) > 3 else clean
    return clean[:60].strip()

# -------------------------------------------------------------
# 3. REGEX PARSER (FEES, DATES, AGE, VACANCIES)
# -------------------------------------------------------------
def extract_fields_with_regex(text):
    extracted = {
        "application_fee": None,
        "start_date": None,
        "last_date": None,
        "age_limit": None,
        "total_vacancies": None,
        "qualification": None
    }

    # Fee Patterns
    fee_patterns = [
        r'(?:Application\s*Fee|Exam\s*Fee|Fee\s*Details)[\s\S]{1,250}?(?=\n\s*\n|Important|Age|Qualification|$)',
        r'(?:General\s*/?\s*OBC|UR\s*/?\s*EWS)[^.\n]*[₹\d]+[^.\n]*',
        r'(?:Gen\s*/?\s*OBC\s*:\s*₹?\d+[\s\S]{1,100}?SC\s*/?\s*ST\s*:\s*₹?\d+)'
    ]
    for pattern in fee_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            clean_fee = re.sub(r'\s+', ' ', match.group(0)).strip()
            extracted["application_fee"] = clean_fee[:150]
            break

    if not extracted["application_fee"]:
        if re.search(r'\b(no fee|free of cost|nil|exempted)\b', text, re.IGNORECASE):
            extracted["application_fee"] = "General / OBC / SC / ST: ₹0 (No Fee)"

    # Dates Pattern
    date_matches = re.findall(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b', text, re.IGNORECASE)
    if len(date_matches) >= 2:
        extracted["start_date"] = date_matches[0]
        extracted["last_date"] = date_matches[1]
    elif len(date_matches) == 1:
        extracted["last_date"] = date_matches[0]

    # Age Limit
    age_patterns = [
        r'(\d{2}\s*to\s*\d{2}\s*years)',
        r'(\d{2}\s*-\s*\d{2}\s*years)',
        r'(Minimum\s*Age\s*:\s*\d{2}[\s\S]{1,50}?Maximum\s*Age\s*:\s*\d{2})',
        r'(Min\.?\s*\d{2}\s*Yrs?[\s\S]{1,30}?Max\.?\s*\d{2}\s*Yrs?)'
    ]
    for pattern in age_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            clean_age = re.sub(r'\s+', ' ', match.group(0)).strip()
            extracted["age_limit"] = clean_age
            break

    # Vacancies
    vac_match = re.search(r'\b(\d{1,6})\s*(Posts|Vacancies|Seat|Seats)\b', text, re.IGNORECASE)
    if vac_match:
        extracted["total_vacancies"] = f"{vac_match.group(1)} Posts"

    # Qualification
    qual_match = re.search(r'(?:Educational\s*Qualification|Qualification)\s*:\s*([^.\n]+)', text, re.IGNORECASE)
    if qual_match:
        extracted["qualification"] = qual_match.group(1).strip()[:100]

    return extracted

# -------------------------------------------------------------
# 4. DIRECT PDF DOWNLOADER & PARSER
# -------------------------------------------------------------
def fetch_and_parse_pdf(pdf_url):
    print(f"  📥 [DOWNLOADING OFFICIAL PDF]: {pdf_url}")
    try:
        pdf_res = requests.get(pdf_url, headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
        if pdf_res.status_code == 200 and len(pdf_res.content) > 3000:
            doc = pymupdf.open(stream=pdf_res.content, filetype="pdf")
            pages_count = len(doc)
            pdf_text = ""
            for page_num in range(min(pages_count, 10)):
                pdf_text += doc[page_num].get_text("text") + "\n"
            
            clean_pdf_text = clean_html_text(pdf_text[:12000])
            if len(clean_pdf_text) > 150:
                print(f"  ✅ [PyMuPDF SUCCESS] Extracted {len(clean_pdf_text)} chars from Official PDF!")
                return clean_pdf_text
            else:
                print("  ⚠️ [SCANNED OFFICIAL PDF] Digital text empty.")
    except Exception as pe:
        print(f"  ❌ [PDF FETCH/PARSE ERROR]: {pe}")
    return ""

# -------------------------------------------------------------
# 5. MICRO-PROMPT GROQ AI FALLBACK
# -------------------------------------------------------------
def fill_missing_fields_with_ai(title, raw_snippet, missing_keys):
    if not GROQ_KEY or not missing_keys:
        return {}

    prompt = f"""
    Title: {title}
    Official Text: {raw_snippet[:2500]}

    Extract ONLY missing fields ({', '.join(missing_keys)}) in valid JSON.
    Schema:
    {{
      "application_fee": "Category-wise fee breakdown e.g. Gen/OBC: ₹500 | SC/ST: ₹100 or 'No Fee'",
      "start_date": "Exact start date or 'Online Active'",
      "last_date": "Exact last date e.g. 15 Sep 2026",
      "age_limit": "Min and Max age criteria",
      "qualification": "Exact Educational Qualification",
      "post_name": "Specific Post Name"
    }}
    """

    time.sleep(0.5)
    for model in MODELS:
        try:
            res = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are an official government recruitment parser. Output strictly JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                max_tokens=600,
                timeout=12
            )
            return json.loads(res.choices[0].message.content.strip())
        except Exception:
            pass
    return {}

# -------------------------------------------------------------
# 6. SEPARATE TITLE & INNER REJECTION RULES (PREVENTS FALSE POSITIVES)
# -------------------------------------------------------------
# Title filter: Filters unwanted states, university exams, offline walk-ins from title
TITLE_REJECT_PATTERNS = [
    r'\boffline\b', r'\bapply offline\b', r'\bwalkin\b', r'\bwalk-in\b', r'\bwalk in\b',
    r'\buniversity result\b', r'\bsemester result\b', r'\bba part\b', r'\bbsc result\b', r'\bbcom result\b',
    r'\badmissions?\b', r'\bcounselling schedule\b', r'\bscholarship\b', r'\bpost matric\b', r'\byojna\b',
    r'\buttar pradesh\b', r'\bup police\b', r'\buppsc\b', r'\bmadhya pradesh\b', r'\bmppsc\b',
    r'\brajasthan\b', r'\brpsc\b', r'\bharyana\b', r'\bhpsc\b', r'\bdsssb\b', r'\bmaharashtra\b',
    r'\bmpsc\b', r'\bjharkhand\b', r'\bjpsc\b', r'\bwest bengal\b', r'\bpunjab\b', r'\bgujarat\b',
    r'\btamil nadu\b', r'\btnpsc\b', r'\bandhra pradesh\b', r'\btelangana\b', r'\bkerala\b', r'\bkarnataka\b'
]

# Inner Text filter: ONLY filters explicitly Other State Govt Jobs or Scholarships (NO university/college/offline keywords here!)
INNER_REJECT_PATTERNS = [
    r'\buttar pradesh subordinate\b', r'\bup police recruitment\b', r'\brajasthan public service\b',
    r'\bmadhya pradesh public service\b', r'\bharyana staff selection\b', r'\bdelhi subordinate\b',
    r'\bscholarship scheme\b', r'\bpost matric scholarship\b'
]

def check_title_rejection(title):
    t_lower = title.lower()
    for pattern in TITLE_REJECT_PATTERNS:
        if re.search(pattern, t_lower):
            return pattern
    return None

def check_inner_rejection(text):
    t_lower = text.lower()
    for pattern in INNER_REJECT_PATTERNS:
        if re.search(pattern, t_lower):
            return pattern
    return None

# -------------------------------------------------------------
# 7. OFFICIAL PORTAL SCRAPER ENGINE
# -------------------------------------------------------------
def scrape_official_websites():
    official_items = []
    print("\n=======================================================")
    print("🏛️ [DIRECT OFFICIAL SCRAPER] Crawling Official Portals")
    print("=======================================================")

    for source in OFFICIAL_SOURCES:
        try:
            print(f"🌐 Fetching Official Portal: {source['name']}")
            res = requests.get(source['url'], headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
            if res.status_code != 200:
                continue

            soup = BeautifulSoup(res.content, "html.parser")
            a_tags = soup.find_all('a', href=True)

            count = 0
            for a_tag in a_tags:
                title = a_tag.text.strip()
                href = a_tag['href'].strip()

                if len(title) < 8 or check_title_rejection(title):
                    continue

                full_url = urljoin(source['url'], href)
                if full_url.endswith('.pdf') or any(kw in href.lower() or kw in title.lower() for kw in ["notice", "advt", "recruitment", "career"]):
                    official_items.append({
                        "title": title,
                        "url": full_url,
                        "org": source['org'],
                        "type": source['type']
                    })
                    count += 1
                    if count >= 6:
                        break

            print(f"  ✅ Extracted {count} official notices from {source['name']}")

        except Exception as e:
            print(f"  ⚠️ Official Scrape Warning ({source['name']}): {e}")

    return official_items

# -------------------------------------------------------------
# 8. BACKUP AGGREGATOR SCRAPER (SarkariResult + FreeJobAlert)
# -------------------------------------------------------------
def fetch_backup_rss_and_web():
    backup_items = []
    
    # 1. SarkariResult Direct Homepage
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=HEADERS, timeout=10, verify=False, impersonate="chrome")
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            boxes = soup.find_all('div', id=re.compile(r'box|post')) or soup.find_all('div', class_=re.compile(r'box|post'))
            for box in boxes:
                header = box.find(['h2', 'h3', 'div', 'b'])
                box_title = header.text.strip().lower() if header else ""
                
                item_type = "job"
                if "admit" in box_title or "hall ticket" in box_title:
                    item_type = "admit"
                elif "result" in box_title or "answer key" in box_title:
                    item_type = "result"

                for a_tag in box.find_all('a', href=True)[:12]:
                    title = a_tag.text.strip()
                    href = urljoin(sr_url, a_tag['href'].strip())
                    if title and len(title) > 6 and not check_title_rejection(title):
                        backup_items.append({"title": title, "url": href, "org": detect_organization(title), "type": item_type})
    except Exception as e:
        print(f"⚠️ SarkariResult Backup Scrape Warning: {e}")

    # 2. FreeJobAlert & Bihar Job Portal RSS Feeds
    rss_feeds = [
        ("FreeJobAlert Feed", "https://www.freejobalert.com/feed/"),
        ("Bihar Job Portal Feed", "https://biharjobportal.com/feed/")
    ]
    for label, feed_url in rss_feeds:
        try:
            res = requests.get(feed_url, headers=HEADERS, timeout=10, verify=False, impersonate="chrome")
            if res.status_code == 200:
                soup = BeautifulSoup(res.content, "xml")
                for item in soup.find_all('item')[:12]:
                    title = item.find('title').text.strip() if item.find('title') is not None else ""
                    link = item.find('link').text.strip() if item.find('link') is not None else ""
                    
                    item_type = "job"
                    if "admit card" in title.lower() or "hall ticket" in title.lower():
                        item_type = "admit"
                    elif "result" in title.lower() or "answer key" in title.lower():
                        item_type = "result"

                    if title and not check_title_rejection(title):
                        backup_items.append({"title": title, "url": link, "org": detect_organization(title), "type": item_type})
        except Exception as e:
            print(f"⚠️ RSS Backup Warning ({label}): {e}")

    return backup_items

# -------------------------------------------------------------
# 9. MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().
