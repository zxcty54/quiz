import os
import json
import time
import re
import traceback
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

AI_MODELS_TIERS = [
    "llama-3.1-8b-instant",
    "mixtral-8x7b-32768",
    "llama-3.3-70b-versatile"
]

# Strict Non-Bihar / Other States Rejection Keywords
OTHER_STATES_REJECT = [
    "cuttack", "odisha", "orissa", "uttar pradesh", " up ", "uppsc", 
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc", 
    "maharashtra", "mpsc", "jharkhand", "jpsc", "west bengal", "wbpsc", 
    "punjab", "gujarat", "kerala", "karnataka", "tamil nadu", "andhra"
]

BIHAR_BOARDS = [
    ("bpsc", "Bihar Public Service Commission (BPSC)"),
    ("bssc", "Bihar Staff Selection Commission (BSSC)"),
    ("bpssc", "Bihar Police Subordinate Services Commission (BPSSC)"),
    ("csbc", "Central Selection Board of Constable (CSBC)"),
    ("btsc", "Bihar Technical Service Commission (BTSC)"),
    ("patna high court", "Patna High Court"),
    ("high court patna", "Patna High Court"),
    ("wcdc", "Women and Child Development Corporation (WCDC) Bihar"),
    ("beltron", "Bihar State Electronics Development Corporation (BELTRON)"),
    ("bihar amin", "Bihar Revenue & Land Reforms Dept (Amin)"),
    ("civil court bihar", "Bihar Civil Court")
]

CENTRAL_BOARDS = [
    ("upsc", "Union Public Service Commission (UPSC)"),
    ("ssc", "Staff Selection Commission (SSC)"),
    ("rrb", "Railway Recruitment Board (RRB)"),
    ("ibps", "Institute of Banking Personnel Selection (IBPS)"),
    ("sbi", "State Bank of India (SBI)"),
    ("union bank", "Union Bank of India"),
    ("india post", "India Post / Department of Posts"),
    ("indian army", "Indian Army"),
    ("indian navy", "Indian Navy"),
    ("indian air force", "Indian Air Force")
]

ALL_BOARDS = BIHAR_BOARDS + CENTRAL_BOARDS

def is_other_state_job(text):
    text_lower = text.lower()
    return any(state in text_lower for state in OTHER_STATES_REJECT)

def detect_organization(text):
    text_lower = text.lower()
    for key, full_name in ALL_BOARDS:
        if key in text_lower:
            return full_name
    return "Central / Bihar Govt Agency"

def is_bihar_job(text):
    bihar_keywords = ["bihar", "bpsc", "bssc", "bpssc", "csbc", "btsc", "patna", "wcdc", "beltron"]
    return any(kw in text.lower() for kw in bihar_keywords)

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. Multi-Tier AI Parser (Real Dates & Details)
# -------------------------------------------------------------
def parse_job_data_with_ai(context_text):
    if not client:
        return {}

    prompt = f"""
    Extract recruitment notification details from the text below.
    Return strictly valid JSON without markdown formatting.

    Expected JSON Schema:
    {{
      "start_date": "Exact Application Start Date (e.g., '15/07/2026') or null",
      "last_date": "Exact Application Last Date (e.g., '28/08/2026') or null",
      "age_limit": "Age criteria (e.g., '20 to 28 Years') or null",
      "application_fee": "Fee details (e.g., 'Rs. 850 for Gen/OBC, Rs. 175 for SC/ST') or null",
      "qualification": "Educational requirement or null",
      "total_vacancies": "Total posts count (e.g., '11403 Posts') or null"
    }}

    Text Context:
    {context_text[:3000]}
    """

    for model_name in AI_MODELS_TIERS:
        try:
            res = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": "You extract government job details into strict JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                timeout=10
            )
            parsed_json = json.loads(res.choices[0].message.content)
            print(f"  [AI Success] Extracted using model: {model_name}")
            return parsed_json
        except Exception as e:
            print(f"  [AI Tier Fallback] Model '{model_name}' failed. Trying next tier...")

    return {}

# -------------------------------------------------------------
# 3. Step 1: Main Table Scraper (Scrapes Post Date as Start Date)
# -------------------------------------------------------------
def fetch_main_table_data(url):
    candidates = []
    print(f"\n[STEP 1] 🌐 Scraping Main Page: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=20, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        tables = soup.find_all('table')

        for table in tables:
            rows = table.find_all('tr')
            for row in rows:
                cols = row.find_all(['td', 'th'])
                
                if len(cols) >= 5:
                    col_texts = [clean_html_text(c.text) for c in cols]
                    
                    if "post name" in col_texts[1].lower() or "post date" in col_texts[0].lower():
                        continue

                    # Table Column Structure:
                    # Col 0: Post Date (Scraped as Start Date)
                    # Col 1: Board Name
                    # Col 2: Post Name & Vacancies
                    # Col 3: Qualification
                    # Col 4: Last Date
                    post_date = col_texts[0]
                    raw_board = col_texts[1]
                    raw_post_and_vacancies = col_texts[2]
                    qualification = col_texts[3] if len(col_texts) > 3 else None
                    raw_last_date = col_texts[4] if len(col_texts) > 4 else None

                    title = f"{raw_board} {raw_post_and_vacancies}".strip()

                    # 🚫 REJECT OTHER STATES (Cuttack, Odisha, UP, MP, etc.)
                    if is_other_state_job(title):
                        print(f"  [Rejected Other State]: {title}")
                        continue

                    vac_match = re.search(r'(\d+[\d,]*)\s*(Posts|Vacancies)?', raw_post_and_vacancies, re.IGNORECASE)
                    vacancies = vac_match.group(0) if vac_match else None

                    clean_post = re.sub(r'[\s–-]+\d+\s*(Posts|Vacancies)?.*$', '', raw_post_and_vacancies, flags=re.IGNORECASE).strip()

                    date_match = re.search(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', raw_last_date) if raw_last_date else None
                    extracted_last_date = date_match.group(0) if date_match else None

                    detail_url = None
                    for a in row.find_all('a', href=True):
                        link_text = a.text.strip().lower()
                        href = a['href']
                        if "get details" in link_text or "get detail" in link_text or "articles" in href:
                            detail_url = urljoin(url, href)
                            break

                    org_name = detect_organization(f"{raw_board} {clean_post}")

                    if detail_url and len(title) > 5 and not re.match(r'^\d{2}/\d{2}/\d{4}$', title):
                        candidates.append({
                            "title": f"{raw_board} {clean_post}",
                            "post_name": clean_post,
                            "organization": org_name,
                            "qualification": qualification,
                            "total_vacancies": vacancies,
                            "post_date": post_date, # Scraped real post date
                            "last_date": extracted_last_date,
                            "detail_url": detail_url,
                            "is_bihar": is_bihar_job(title)
                        })

        print(f"[STEP 1] ✅ Extracted {len(candidates)} valid Bihar/Central jobs from table!")

    except Exception as e:
        print(f"[STEP 1] 🚨 Error: {e}")

    return candidates

# -------------------------------------------------------------
# 4. Step 2: Inner Page Scrape (PDF & Inner Context)
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {"text_content": "", "pdf_url": None}
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for table in soup.find_all('table'):
                for row in table.find_all('tr'):
                    a_tag = row.find('a', href=True)
                    if a_tag:
                        href = urljoin(detail_url, a_tag['href'])
                        if ("notification" in row.text.lower() or href.endswith('.pdf')) and not details["pdf_url"]:
                            details["pdf_url"] = href

            content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
            details["text_content"] = clean_html_text(content_div.text if content_div else "")
    except Exception as e:
        print(f"⚠️ Inner page warning: {e}")

    return details

# -------------------------------------------------------------
# 5. Main Execution
# -------------------------------------------------------------
def run_job_pipeline():
    today_str = datetime.now().strftime("%d %b %Y")
    latest_jobs, admit_cards, results, seen_titles = [], [], [], set()

    main_url = "https://www.freejobalert.com/latest-notifications/"
    candidates = fetch_main_table_data(main_url)

    candidates.sort(key=lambda x: x["is_bihar"], reverse=True)

    for idx, cand in enumerate(candidates[:25]):
        title = cand["title"]
        detail_url = cand["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(candidates[:25])}] 🔍 Processing: {title}")

        deep_data = fetch_deep_details(detail_url)
        full_context = f"{title}\nPost Date: {cand['post_date']}\nQualification: {cand['qualification']}\n{deep_data['text_content']}"

        # Call AI Parser
        ai_data = parse_job_data_with_ai(full_context)

        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "title": title,
            "organization": cand["organization"],
            "job_type": "Bihar Govt Job" if cand["is_bihar"] else "Central Govt Job",
            "post_name": cand["post_name"] or None,
            "total_vacancies": ai_data.get("total_vacancies") or cand["total_vacancies"] or None,
            "qualification": ai_data.get("qualification") or cand["qualification"] or None,
            "age_limit": ai_data.get("age_limit") or None,
            "application_fee": ai_data.get("application_fee") or None,
            "start_date": ai_data.get("start_date") or cand["post_date"] or None, # Real scraped date used!
            "last_date": ai_data.get("last_date") or cand["last_date"] or None,
            "apply_url": "https://www.mocktester.online",
            "notification_pdf": deep_data["pdf_url"] or None,
            "date": today_str
        }
        latest_jobs.append(job_card)

    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": admit_cards,
        "results": results
    }

    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Clean bihar_jobs.json generated with {len(latest_jobs)} items!")

if __name__ == "__main__":
    run_job_pipeline()
