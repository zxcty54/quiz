import os
import json
import time
import re
from datetime import datetime
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq
import pymupdf  # PyMuPDF

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.1-8b-instant", "mixtral-8x7b-32768", "llama-3.3-70b-versatile"]

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

# -------------------------------------------------------------
# 2. ORGANIZATION MAPPING DICTIONARY
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
    
    # Central Govt & PSU Bodies
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

    # Age Limit Pattern
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

    # Vacancies Pattern
    vac_match = re.search(r'\b(\d{2,6})\s*(Posts|Vacancies|Seat|Seats)\b', text, re.IGNORECASE)
    if vac_match:
        extracted["total_vacancies"] = f"{vac_match.group(1)} Posts"

    return extracted

# -------------------------------------------------------------
# 4. DEEP SCRAPER WITH PDF CRAWLER
# -------------------------------------------------------------
def fetch_deep_page_and_pdf(url):
    print(f"  🌐 [FETCH] Requesting URL: {url}")
    try:
        res = requests.get(url, headers=HEADERS, timeout=12, verify=False, allow_redirects=True)
        if res.status_code != 200:
            return ""

        soup = BeautifulSoup(res.content, "html.parser")
        for tag in soup.find_all(['script', 'style', 'nav', 'footer', 'header', 'aside']):
            tag.decompose()

        pdf_candidates = []
        all_links = soup.find_all('a', href=True)

        for a_tag in all_links:
            href = a_tag['href'].strip()
            text_label = a_tag.text.strip().lower()
            if href.endswith('.pdf') or "notification" in text_label or "advertisement" in text_label or "click here" in text_label:
                full_pdf_url = requests.compat.urljoin(url, href)
                pdf_candidates.append(full_pdf_url)

        best_pdf_bytes = None
        best_pdf_size = 0
        winning_url = ""

        for idx, c_url in enumerate(pdf_candidates[:4]):
            try:
                c_res = requests.get(c_url, headers=HEADERS, timeout=8, verify=False)
                c_len = len(c_res.content)
                if c_res.status_code == 200 and c_len > best_pdf_size:
                    best_pdf_size = c_len
                    best_pdf_bytes = c_res.content
                    winning_url = c_url
            except Exception:
                pass

        if best_pdf_bytes and best_pdf_size > 5000:
            try:
                print(f"  ⚡ [PyMuPDF] Parsing Main Selected PDF: ({best_pdf_size // 1024} KB)")
                doc = pymupdf.open(stream=best_pdf_bytes, filetype="pdf")
                pages_count = len(doc)
                pdf_text = ""
                for page_num in range(min(pages_count, 10)):
                    pdf_text += doc[page_num].get_text("text") + "\n"
                
                clean_extracted = clean_html_text(pdf_text[:12000])
                print(f"  ✅ [PyMuPDF SUCCESS] Extracted {len(clean_extracted)} characters from PDF!")
                return clean_extracted
            except Exception as pe:
                print(f"  ❌ [PyMuPDF ERROR] Stream parse error: {pe}")

        content = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
        html_text = clean_html_text(content.text if content else "")[:8000]
        return html_text

    except Exception as e:
        print(f"  ❌ [FETCH ERROR] Deep Page Error ({url}): {e}")
    return ""

# -------------------------------------------------------------
# 5. MICRO-PROMPT GROQ AI FALLBACK
# -------------------------------------------------------------
def fill_missing_fields_with_ai(title, raw_snippet, missing_keys):
    if not GROQ_KEY or not missing_keys:
        return {}

    prompt = f"""
    Title: {title}
    Context: {raw_snippet[:2000]}

    Extract missing fields ({', '.join(missing_keys)}) for this gov notification in JSON.
    Schema:
    {{
      "application_fee": "Category fee or 'Refer Official Notification'",
      "start_date": "Exact start date or 'Online Active'",
      "last_date": "Exact last date or 'Refer Official Notification'",
      "age_limit": "Min and Max age criteria",
      "qualification": "Exact Educational Qualification",
      "post_name": "Post Name"
    }}
    """

    time.sleep(0.5)
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
                max_tokens=500,
                timeout=15
            )
            return json.loads(res.choices[0].message.content.strip())
        except Exception:
            pass
    return {}

# -------------------------------------------------------------
# 6. HARD REJECTION KEYWORDS
# -------------------------------------------------------------
REJECT_KEYWORDS = [
    r'\buniversity\b', r'\bcollege\b', r'\bsemester\b', r'\bba part\b', r'\bbsc\b', r'\bbcom\b',
    r'\bdegree college\b', r'\bannual exam\b', r'\badmissions?\b', r'\bcounselling\b', r'\ballotment\b',
    r'\bscholarship\b', r'\bpost matric\b', r'\bnsp scholarship\b', r'\byojna\b', r'\bpension\b',
    r'\buttar pradesh\b', r'\bup police\b', r'\buppsc\b', r'\bmadhya pradesh\b', r'\bmppsc\b',
    r'\brajasthan\b', r'\brpsc\b', r'\bharyana\b', r'\bhpsc\b', r'\bdsssb\b', r'\bmaharashtra\b',
    r'\bmpsc\b', r'\bjharkhand\b', r'\bjpsc\b', r'\bwest bengal\b', r'\bpunjab\b', r'\bgujarat\b',
    r'\btamil nadu\b', r'\btnpsc\b', r'\bandhra pradesh\b', r'\btelangana\b', r'\bkerala\b', r'\bkarnataka\b',
    r'\bapprentice\b', r'\bapprenticeship\b', r'\bmbbs\b', r'\bmedical officer\b'
]

def check_rejection_reason(text):
    t_lower = text.lower()
    for pattern in REJECT_KEYWORDS:
        if re.search(pattern, t_lower):
            return pattern
    return None

def clean_post_name(title):
    clean = re.sub(r'(Recruitment|Notification|Online Form|Apply Online|2025|2026)', '', title, flags=re.IGNORECASE)
    return clean.strip()[:50]

# -------------------------------------------------------------
# 7. SARKARI RESULT DIRECT BOX SCRAPER (FALLBACK & PRIMARY)
# -------------------------------------------------------------
def fetch_sarkari_result_boxes():
    items = []
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=HEADERS, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            
            # Find Boxes for Result, Admit Card, Latest Jobs
            boxes = soup.find_all('div', id=re.compile(r'box|post')) or soup.find_all('div', class_=re.compile(r'box|post'))
            for box in boxes:
                header = box.find(['h2', 'h3', 'div', 'b'])
                box_title = header.text.strip().lower() if header else ""
                
                category_type = "job"
                if "admit" in box_title or "hall ticket" in box_title:
                    category_type = "admit"
                elif "result" in box_title or "answer key" in box_title:
                    category_type = "result"

                for a_tag in box.find_all('a', href=True)[:15]:
                    title = a_tag.text.strip()
                    href = a_tag['href'].strip()
                    if title and len(title) > 6:
                        items.append((title, href, category_type))
            print(f"✅ SarkariResult Live Homepage Scraped: Found {len(items)} items.")
    except Exception as e:
        print(f"⚠️ SarkariResult Direct Scrape Warning: {e}")
    return items

# -------------------------------------------------------------
# 8. MAIN PIPELINE EXECUTION
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    
    latest_jobs = []
    admit_cards = []
    results = []
    seen_titles = set()

    # Active Working Sources
    sources = [
        ("Main FreeJobAlert Feed", "https://www.freejobalert.com/feed/", "job"),
        ("Bihar Job Portal", "https://biharjobportal.com/feed/", "job"),
        ("JagranJosh Govt Jobs", "https://www.jagranjosh.com/rss/josh/jobs.xml", "job")
    ]

    # 1. PROCESS RSS FEEDS
    for label, feed_url, default_type in sources:
        print(f"\n=======================================================")
        print(f"📡 [SOURCE START] Fetching RSS Feed: {label}")
        print(f"=======================================================")
        try:
            res = requests.get(feed_url, headers=HEADERS, timeout=12, verify=False)
            print(f"  📡 RSS Response: {res.status_code}")
            if res.status_code != 200:
                continue

            soup = BeautifulSoup(res.content, "xml")
            rss_items = soup.find_all('item')[:15]
            print(f"  📡 Found {len(rss_items)} items in RSS Feed.")

            for idx, item in enumerate(rss_items):
                title = item.find('title').text.strip() if item.find('title') is not None else ""
                link = item.find('link').text.strip() if item.find('link') is not None else ""
                
                if not title or len(title) < 5 or check_rejection_reason(title):
                    continue

                simple_title = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
                if simple_title in seen_titles:
                    continue
                seen_titles.add(simple_title)

                # Determine item type from title
                item_type = default_type
                if "admit card" in title.lower() or "hall ticket" in title.lower():
                    item_type = "admit"
                elif "result" in title.lower() or "answer key" in title.lower() or "merit list" in title.lower():
                    item_type = "result"

                print(f"[{idx+1}/{len(rss_items)}] 🔍 Processing [{item_type.upper()}]: {title}")

                content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                rss_text = clean_html_text(content_node.text) if content_node is not None else ""
                
                raw_snippet = fetch_deep_page_and_pdf(link) if link else ""
                full_text_context = f"{title}\n{raw_snippet}\n{rss_text}"

                if check_rejection_reason(full_text_context):
                    print(f"  ❌ Inner text matched rejection keyword.")
                    continue

                extracted = extract_fields_with_regex(full_text_context)
                missing_keys = [k for k, v in extracted.items() if v is None]

                if missing_keys and GROQ_KEY and item_type == "job":
                    ai_res = fill_missing_fields_with_ai(title, full_text_context, missing_keys)
                    for key in missing_keys:
                        if ai_res.get(key):
                            extracted[key] = ai_res[key]

                org_name = detect_organization(full_text_context)

                if item_type == "job":
                    latest_jobs.append({
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
                        "apply_url": "https://www.mocktester.online",
                        "exam_tag": "🔥 Govt Job Alert",
                        "date": today_str
                    })
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
                        "apply_url": "https://www.mocktester.online",
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
                        "apply_url": "https://www.mocktester.online",
                        "exam_tag": "🏆 Result",
                        "date": today_str
                    })

        except Exception as e:
            print(f"⚠️ Source Error ({label}): {e}")

    # 2. PROCESS SARKARI RESULT HOMEPAGE DIRECT SCRAPE (FALLBACK / ENRICHMENT)
    print(f"\n=======================================================")
    print(f"🌐 [SOURCE START] Scraping SarkariResult Direct Homepage")
    print(f"=======================================================")
    sr_items = fetch_sarkari_result_boxes()
    for title, link, item_type in sr_items:
        if check_rejection_reason(title):
            continue

        simple_title = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if simple_title in seen_titles:
            continue
        seen_titles.add(simple_title)

        org_name = detect_organization(title)
        
        if item_type == "job":
            latest_jobs.append({
                "id": f"job_{len(latest_jobs)+1:02d}",
                "title": title,
                "organization": org_name,
                "job_type": "Bihar Govt Job" if "bihar" in title.lower() or "bpsc" in title.lower() else "Central Govt Job",
                "post_name": clean_post_name(title),
                "total_vacancies": "Check Official Notification",
                "qualification": "Refer Official Notification",
                "age_limit": "18-37 Years (Relaxation Applicable)",
                "application_fee": "Refer Official Notification",
                "start_date": "Online Active",
                "last_date": "Refer Official Notification",
                "apply_url": "https://www.mocktester.online",
                "exam_tag": "🔥 Govt Job Alert",
                "date": today_str
            })
        elif item_type == "admit":
            admit_cards.append({
                "id": f"admit_{len(admit_cards)+1:02d}",
                "title": title,
                "organization": org_name,
                "job_type": "Bihar Govt Job" if "bihar" in title.lower() else "Central Govt Job",
                "post_name": clean_post_name(title),
                "total_vacancies": "As per Rules",
                "exam_date": "As Scheduled",
                "status": "Admit Card Released / Active",
                "apply_url": "https://www.mocktester.online",
                "exam_tag": "🎫 Hall Ticket",
                "date": today_str
            })
        elif item_type == "result":
            results.append({
                "id": f"result_{len(results)+1:02d}",
                "title": title,
                "organization": org_name,
                "job_type": "Bihar Govt Job" if "bihar" in title.lower() else "Central Govt Job",
                "post_name": clean_post_name(title),
                "total_vacancies": "As per Rules",
                "result_status": "Merit List / Result Released",
                "apply_url": "https://www.mocktester.online",
                "exam_tag": "🏆 Result",
                "date": today_str
            })

    # Build Final Output
    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    final_output = remove_markdown_stars(final_output)

    print(f"\n=======================================================")
    print(f"📊 SUMMARY REPORT:")
    print(f"👉 Total Latest Jobs: {len(latest_jobs)}")
    print(f"👉 Total Admit Cards: {len(admit_cards)}")
    print(f"👉 Total Results: {len(results)}")
    print(f"=======================================================")

    if latest_jobs or admit_cards or results:
        with open("bihar_jobs.json", "w", encoding="utf-8") as f:
            json.dump(final_output, f, ensure_ascii=False, indent=2)
        print("✅ bihar_jobs.json successfully updated!")
    else:
        print("🛡️ SAFEGUARD: No valid items found. Retaining existing file.")

if __name__ == "__main__":
    run_job_pipeline()
