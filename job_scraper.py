import os
import json
import time
import re
from datetime import datetime
from urllib.parse import urljoin
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# 1. API Client & Configuration Setup
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

OTHER_STATES_REJECT = [
    "aiims", "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav ", 
    "uttar pradesh", " up ", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "maharashtra", "mpsc", 
    "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", "gujarat", 
    "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "ap mahesh", "mahesh bank",
    "telangana", "tspsc", "assam", "chhattisgarh", "delhi", "dsssb"
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

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def parse_vacancy_count(vac_str):
    if not vac_str:
        return None
    match = re.search(r'\b(\d+)\b', str(vac_str))
    return int(match.group(1)) if match else None

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

def is_date_expired(last_date_str):
    if not last_date_str:
        return False

    date_patterns = [
        r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
        r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'
    ]

    for pattern in date_patterns:
        match = re.search(pattern, last_date_str)
        if match:
            try:
                groups = match.groups()
                if len(groups[0]) == 4:
                    dt = datetime(int(groups[0]), int(groups[1]), int(groups[2]))
                else:
                    year = int(groups[2])
                    if year < 100:
                        year += 2000
                    dt = datetime(year, int(groups[1]), int(groups[0]))

                today = datetime.now()
                if dt.date() < today.date():
                    return True
            except Exception:
                pass

    return False

# -------------------------------------------------------------
# 2. Multi-Tier AI Parser
# -------------------------------------------------------------
def parse_job_data_with_ai(context_text):
    if not client:
        return {}

    prompt = f"""
    Extract recruitment notification details from the text below.
    Return strictly valid JSON without markdown formatting.

    Expected JSON Schema:
    {{
      "start_date": "Exact Start Date or null",
      "last_date": "Exact Last Date or null",
      "qualification": "Educational requirement or null",
      "total_vacancies": "Total posts count string or null"
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
            print(f"  [AI Success] Model: {model_name}")
            return parsed_json
        except Exception as e:
            print(f"  [AI Tier Fallback] Model '{model_name}' failed. Trying next tier...")

    return {}

# -------------------------------------------------------------
# 3. PRIMARY SOURCE: FreeJobAlert Scraper
# -------------------------------------------------------------
def fetch_main_table_data(url):
    candidates = []
    print(f"\n[PRIMARY SOURCE] 🌐 Scraping FreeJobAlert: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
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

                    post_date = col_texts[0]
                    raw_board = col_texts[1]
                    raw_post_and_vacancies = col_texts[2]
                    qualification = col_texts[3] if len(col_texts) > 3 else None
                    raw_last_date = col_texts[5] if len(col_texts) >= 6 else (col_texts[4] if len(col_texts) == 5 else None)

                    title = f"{raw_board} {raw_post_and_vacancies}".strip()
                    
                    if is_hard_rejected(title):
                        continue

                    if is_date_expired(raw_last_date):
                        print(f"  [Expired Skip]: {title} (Last Date: {raw_last_date})")
                        continue

                    vac_match = re.search(r'(\d+[\d,]*)\s*(Posts|Vacancies)?', raw_post_and_vacancies, re.IGNORECASE)
                    vacancies_str = vac_match.group(0) if vac_match else None
                    vac_num = parse_vacancy_count(vacancies_str)

                    if vac_num is not None and vac_num < 30:
                        continue

                    clean_post = re.sub(r'[\s–-]+\d+\s*(Posts|Vacancies)?.*$', '', raw_post_and_vacancies, flags=re.IGNORECASE).strip()

                    table_last_date = None
                    if raw_last_date and raw_last_date != "-":
                        date_match = re.search(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b', raw_last_date)
                        table_last_date = date_match.group(0) if date_match else raw_last_date.strip()

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
                            "total_vacancies": vacancies_str,
                            "start_date": post_date,
                            "last_date": table_last_date,
                            "detail_url": detail_url,
                            "is_bihar": is_bihar_job(title),
                            "source": "FreeJobAlert"  # 👈 Source Tag
                        })

        print(f"[PRIMARY SOURCE] ✅ Extracted {len(candidates)} active jobs from FreeJobAlert!")

    except Exception as e:
        print(f"[PRIMARY SOURCE] 🚨 Error: {e}")

    return candidates

# -------------------------------------------------------------
# 4. SECONDARY SOURCE: SarkariResult Pre-Filter Scraper
# -------------------------------------------------------------
def fetch_sarkari_result_links(url):
    candidates = []
    print(f"\n[SECONDARY SOURCE] 🌐 Filtering Active Links from SarkariResult: {url}")
    
    try:
        res = requests.get(url, headers=HEADERS, timeout=15, verify=False, impersonate="chrome")
        if res.status_code != 200:
            return candidates

        soup = BeautifulSoup(res.content, "html.parser")
        post_div = soup.find('div', id='post') or soup.find('body')
        a_tags = post_div.find_all('a', href=True) if post_div else []

        for a in a_tags[:40]:
            href = a['href'].strip()
            full_text = clean_html_text(a.text)

            if len(full_text) < 8 or "sarkariresult.com" not in href:
                continue

            if is_hard_rejected(full_text):
                print(f"  [Pre-Filter Rejected State]: {full_text}")
                continue

            last_date_match = re.search(r'Last\s*Date\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', full_text, re.IGNORECASE)
            extracted_last_date = last_date_match.group(1) if last_date_match else None

            if extracted_last_date and is_date_expired(extracted_last_date):
                print(f"  [Pre-Filter Expired Skip]: {full_text}")
                continue

            clean_title = re.sub(r'Last\s*Date\s*:?.*$', '', full_text, flags=re.IGNORECASE).strip()

            candidates.append({
                "title": clean_title,
                "last_date": extracted_last_date,
                "detail_url": href,
                "is_bihar": is_bihar_job(clean_title),
                "source": "SarkariResult"  # 👈 Source Tag
            })

        print(f"[SECONDARY SOURCE] ✅ Found {len(candidates)} Active Bihar/Central Links!")

    except Exception as e:
        print(f"[SECONDARY SOURCE] 🚨 Error: {e}")

    return candidates

# -------------------------------------------------------------
# 5. Inner Detail Scraper
# -------------------------------------------------------------
def fetch_deep_details(detail_url):
    details = {"text_content": ""}
    try:
        res = requests.get(detail_url, headers=HEADERS, timeout=12, verify=False, impersonate="chrome")
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            content_div = soup.find('div', id=re.compile(r'post|content|entry')) or soup.find('body')
            details["text_content"] = clean_html_text(content_div.text if content_div else "")
    except Exception as e:
        print(f"⚠️ Inner page fetch failed ({detail_url}): {e}")

    return details

# -------------------------------------------------------------
# 6. Main Pipeline Runner
# -------------------------------------------------------------
def run_job_pipeline():
    latest_jobs, seen_titles = [], set()

    primary_url = "https://www.freejobalert.com/latest-notifications/"
    candidates = fetch_main_table_data(primary_url)

    if not candidates:
        print("\n⚠️ Primary source failed or empty. Triggering SarkariResult Active Links...")
        secondary_url = "https://www.sarkariresult.com/latestjob/"
        candidates = fetch_sarkari_result_links(secondary_url)

    candidates.sort(key=lambda x: x.get("is_bihar", False), reverse=True)

    for idx, cand in enumerate(candidates[:25]):
        title = cand["title"]
        detail_url = cand["detail_url"]

        clean_key = re.sub(r'[^a-zA-Z0-9]', '', title.lower())[:30]
        if clean_key in seen_titles:
            continue
        seen_titles.add(clean_key)

        print(f"[{idx+1}/{len(candidates[:25])}] 🔗 [{cand.get('source')}] Opening: {title}")

        deep_data = fetch_deep_details(detail_url)
        full_context = f"Title: {title}\nQualification: {cand.get('qualification')}\n{deep_data['text_content']}"

        if is_hard_rejected(full_context):
            print(f"  [Inner Rejected State/Entity]: {title}")
            continue

        ai_data = parse_job_data_with_ai(full_context)

        final_vac_str = ai_data.get("total_vacancies") or cand.get("total_vacancies")
        final_vac_num = parse_vacancy_count(final_vac_str)
        if final_vac_num is not None and final_vac_num < 30:
            print(f"  [Rejected Low Vacancy ({final_vac_num} < 30)]: {title}")
            continue

        job_card = {
            "id": f"job_{len(latest_jobs)+1:02d}",
            "source": cand.get("source"),  # 👈 Added "source" field in final JSON
            "title": title,
            "organization": cand.get("organization") or detect_organization(title),
            "job_type": "Bihar Govt Job" if cand.get("is_bihar") else "Central Govt Job",
            "post_name": cand.get("post_name") or title[:50],
            "total_vacancies": final_vac_str or None,
            "qualification": ai_data.get("qualification") or cand.get("qualification") or None,
            "start_date": cand.get("start_date") or ai_data.get("start_date") or None,
            "last_date": cand.get("last_date") or ai_data.get("last_date") or None,
            "apply_url": "https://www.mocktester.online"
        }
        latest_jobs.append(job_card)

    final_output = {
        "latest_jobs": latest_jobs,
        "admit_cards": [],
        "results": []
    }

    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
        json.dump(final_output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ bihar_jobs.json generated! Total Valid Active Jobs: {len(latest_jobs)}")

if __name__ == "__main__":
    run_job_pipeline()
