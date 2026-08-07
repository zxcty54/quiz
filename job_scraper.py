import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin  # Fixed: Proper urljoin import to prevent curl_cffi crash
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
import fitz  # PyMuPDF

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

# -------------------------------------------------------------
# 2. ORGANIZATION MAPPING DICTIONARY (Fixed Exact Matching)
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
    
    # Central Govt & PSU Bodies (Fixed generic words to full phrases)
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
    "india post": "India Post / Department of Posts",
    "indian coast guard": "Indian Coast Guard",
    "indian navy": "Indian Navy",
    "indian army": "Indian Army",
    "indian air force": "Indian Air Force",
    "bsf": "Border Security Force (BSF)",
    "crpf": "Central Reserve Police Force (CRPF)",
    "cisf": "Central Industrial Security Force (CISF)",
    "itbp": "Indo-Tibetan Border Police (ITBP)"
}

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ORG_MAP.items():
        if key in text_lower:
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

# -------------------------------------------------------------
# 3. ROBUST MULTI-PATTERN REGEX PARSER
# -------------------------------------------------------------
def extract_fields_with_regex(text):
    extracted = {
        "application_fee": None,
        "start_date": None,
        "last_date": None,
        "age_limit": None,
        "total_vacancies": None
    }

    # 1. Application Fee
    fee_patterns = [
        r'(?:Application\s*Fee|Exam\s*Fee|Fee\s*Details)[\s\S]{1,200}?(?=\n\s*\n|Important|Age|Qualification|$)',
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

    # 2. Dates
    date_matches = re.findall(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b', text, re.IGNORECASE)
    if len(date_matches) >= 2:
        extracted["start_date"] = date_matches[0]
        extracted["last_date"] = date_matches[1]
    elif len(date_matches) == 1:
        extracted["last_date"] = date_matches[0]

    # 3. Age Limit
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

    # 4. Total Vacancies
    vac_match = re.search(r'\b(\d{2,6})\s*(Posts|Vacancies|Seat|Seats)\b', text, re.IGNORECASE)
    if vac_match:
        extracted["total_vacancies"] = f"{vac_match.group(1)} Posts"

    return extracted

# -------------------------------------------------------------
# 4. REAL PDF LINK CRAWLER & DEEP PARSER
# -------------------------------------------------------------
def fetch_deep_page_and_pdf(url):
    try:
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return ""

        # Case A: Direct PDF URL
        if url.endswith('.pdf') or 'application/pdf' in res.headers.get('Content-Type', ''):
            doc = fitz.open(stream=res.content, filetype="pdf")
            text = ""
            for page_num in range(min(len(doc), 10)):
                text += doc[page_num].get_text("text") + "\n"
            return clean_html_text(text[:12000])

        # Case B: Article Page -> Find embedded official PDF Link
        soup = BeautifulSoup(res.content, "html.parser")
        for tag in soup.find_all(['script', 'style', 'nav', 'footer', 'header', 'aside']):
            tag.decompose()

        pdf_link = None
        for a_tag in soup.find_all('a', href=True):
            href = a_tag['href']
            text_a = a_tag.text.lower()
            if href.endswith('.pdf') or "notification" in text_a or "advertisement" in text_a:
                pdf_link = href
                if not pdf_link.startswith('http'):
                    pdf_link = urljoin(url, pdf_link)  # FIXED HERE!
                break

        if pdf_link and pdf_link != url:
            try:
                pdf_res = requests.get(pdf_link, headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
                if pdf_res.status_code == 200 and len(pdf_res.content) > 5000:
                    doc = fitz.open(stream=pdf_res.content, filetype="pdf")
                    text = ""
                    for page_num in range(min(len(doc), 10)):
                        text += doc[page_num].get_text("text") + "\n"
                    print(f"📄 Successfully Parsed Official PDF ({pdf_link})!")
                    return clean_html_text(text[:12000])
            except Exception as e:
                print(f"⚠️ Embedded PDF fetch error: {e}")

        content = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        return clean_html_text(content.text if content else "")[:8000]

    except Exception as e:
        print(f"⚠️ Page/PDF fetch failed ({url}): {e}")
    return ""

# -------------------------------------------------------------
# 5. MICRO-PROMPT GROQ AI FALLBACK
# -------------------------------------------------------------
def fill_missing_fields_with_ai(title, raw_snippet, missing_keys):
    if not GROQ_KEY or not missing_keys:
        return {}

    prompt = f"""
    Item Title: {title}
    Notification Context: {raw_snippet[:2000]}

    Extract ONLY the missing fields ({', '.join(missing_keys)}) for this notification.
    
    JSON Output Schema:
    {{
      "application_fee": "Category-wise fee breakdown or 'Refer Official Notification'",
      "start_date": "Exact start date or 'Online Active'",
      "last_date": "Exact last date or 'Refer Official Notification'",
      "age_limit": "Min and Max age criteria",
      "qualification": "Exact Educational Qualification",
      "post_name": "Specific Post Name"
    }}
    """

    for model in MODELS:
        try:
            res = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": "You are a recruitment data extractor. Output strictly JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                max_tokens=600,
                timeout=15
            )
            return json.loads(res.choices[0].message.content.strip())
        except Exception as e:
            print(f"⚠️ Micro-LLM Call Failed ({model}): {e}")
    return {}

# -------------------------------------------------------------
# 6. HARD REJECTION KEYWORDS
# -------------------------------------------------------------
REJECT_KEYWORDS = [
    "university", "college", "semester", "ba part", "bsc ", "bcom", "ma ", "msc ",
    "degree college", "annual exam", "admissions", "counselling", "allotment", "entrance test",
    "scholarship", "post matric", "nsp scholarship", "yojna", "scheme", "pension",
    "uttar pradesh", " up police", " up board", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "dsssb", "maharashtra", "jharkhand", "jpsc",
    "west bengal", "punjab", "gujarat", "tamil nadu", "kerala", "karnataka", "odisha",
    "apprentice", "apprenticeship"
]

def is_rejected(text):
    t_lower = text.lower()
    return any(keyword in t_lower for keyword in REJECT_KEYWORDS)

def clean_post_name(title):
    clean = re.sub(r'(?i)(Recruitment|Notification|Online Form|Apply Online|202\d)', '', title)
    return clean.strip()[:50]

# -------------------------------------------------------------
# 7. MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []

    sources = [
        ("SSC Central", "https://www.freejobalert.com/ssc-job-notifications/feed/", "job"),
        ("Railway Central", "https://www.freejobalert.com/railway-jobs/feed/", "job"),
        ("Bank Central", "https://www.freejobalert.com/bank-jobs/feed/", "job"),
        ("UPSC Central", "https://www.freejobalert.com/upsc-job-notifications/feed/", "job"),
        ("Bihar Govt", "https://www.freejobalert.com/state-government-jobs/feed/", "job"),
        ("Admit Cards", "https://www.freejobalert.com/admit-card/feed/", "admit"),
        ("Results", "https://www.freejobalert.com/exam-result/feed/", "result")
    ]

    seen_titles = set()

    for label, feed_url, item_type in sources:
        try:
            res = requests.get(feed_url, headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
            if res.status_code != 200:
                continue

            # Parse RSS feed safely with html.parser / xml
            soup = BeautifulSoup(res.content, "html.parser")
            items = soup.find_all('item')[:10]

            for item in items:
                title_tag = item.find('title')
                link_tag = item.find('link')
                
                title = title_tag.text.strip() if title_tag else ""
                link = link_tag.text.strip() if link_tag else ""
                
                if not title or len(title) < 5 or is_rejected(title):
                    continue

                simple_title = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
                if simple_title in seen_titles:
                    continue
                seen_titles.add(simple_title)

                print(f"\n🔍 Processing [{item_type.upper()}]: {title}")

                raw_snippet = fetch_deep_page_and_pdf(link) if link else ""
                full_text_context = f"{title}\n{raw_snippet}"

                if is_rejected(full_text_context):
                    print(f"❌ Inner Filter Blocked: {title}")
                    continue

                # REGEX EXTRACTION
                extracted = extract_fields_with_regex(full_text_context)

                # MICRO-LLM FALLBACK FOR MISSING FIELDS
                missing_keys = [k for k, v in extracted.items() if v is None]
                if missing_keys and GROQ_KEY and item_type == "job":
                    print(f"⚡ Missing fields {missing_keys} -> Calling Micro-LLM...")
                    ai_res = fill_missing_fields_with_ai(title, raw_snippet, missing_keys)
                    for key in missing_keys:
                        if ai_res.get(key):
                            extracted[key] = ai_res[key]

                org_name = detect_organization(full_text_context)

                if item_type == "job":
                    job_card = {
                        "id": f"job_{len(latest_jobs)+1:02d}",
                        "title": title,
                        "organization": org_name,
                        "job_type": "Bihar Govt Job" if "bihar" in full_text_context.lower() or "bpsc" in full_text_context.lower() else "Central Govt Job",
                        "post_name": extracted.get("post_name") or clean_post_name(title),
                        "total_vacancies": extracted.get("total_vacancies") or "Check Official Notification",
                        "qualification": extracted.get("qualification") or "Refer Official Notification",
                        "age_limit": extracted.get("age_limit") or "18-37 Years (Relaxation Applicable)",
                        "application_fee": extracted.get("application_fee") or "Refer Official Notification",
                        "start_date": extracted.get("start_date") or "Online Active",
                        "last_date": extracted.get("last_date") or "Refer Official Notification",
                        "apply_url": link or "https://www.mocktester.online",
                        "exam_tag": "🔥 Govt Job Alert",
                        "date": today_str
                    }
                    latest_jobs.append(job_card)

                elif item_type == "admit":
                    admit_cards.append({
                        "id": f"admit_{len(admit_cards)+1:02d}",
                        "title": title,
                        "organization": org_name,
                        "job_type": "Bihar Govt Job" if "bihar" in full_text_context.lower() else "Central Govt Job",
                        "post_name": clean_post_name(title),
                        "total_vacancies": "As per Rules",
                        "exam_date": extracted.get("start_date") or "As Scheduled",
                        "status": "Admit Card Released / Active",
                        "apply_url": link or "https://www.mocktester.online",
                        "exam_tag": "🎫 Hall Ticket",
                        "date": today_str
                    })

                elif item_type == "result":
                    results.append({
                        "id": f"result_{len(results)+1:02d}",
                        "title": title,
                        "organization": org_name,
                        "job_type": "Bihar Govt Job" if "bihar" in full_text_context.lower() else "Central Govt Job",
                        "post_name": clean_post_name(title),
                        "total_vacancies": "As per Rules",
                        "result_status": "Merit List / Result Released",
                        "apply_url": link or "https://www.mocktester.online",
                        "exam_tag": "🏆 Result",
                        "date": today_str
                    })

        except Exception as e:
            print(f"⚠️ Source Error ({label}): {e}")

    final_output = remove_markdown_stars({
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    })

    if latest_jobs or admit_cards or results:
        with open("bihar_jobs.json", "w", encoding="utf-8") as f:
            json.dump(final_output, f, ensure_ascii=False, indent=2)
        print(f"\n✅ bihar_jobs.json successfully generated!\n"
              f"👉 Jobs: {len(latest_jobs)}\n"
              f"👉 Admit Cards: {len(admit_cards)}\n"
              f"👉 Results: {len(results)}")
    else:
        print("\n🛡️ SAFEGUARD: No valid items found. Retaining existing file.")

if __name__ == "__main__":
    run_job_pipeline()
