import os
import json
import time
import re
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET
from curl_cffi import requests
from bs4 import BeautifulSoup
from groq import Groq

# -------------------------------------------------------------
# 1. API Client Setup (Groq API)
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None

MODELS = ["llama-3.1-8b-instant", "mixtral-8x7b-32768", "llama-3.3-70b-versatile"]

def get_yesterday_info():
    """Subah 6 AM run hone par kal ki date aur formatted strings generate karta hai"""
    yesterday_dt = datetime.now() - timedelta(days=1)
    date_str = yesterday_dt.strftime("%d %b %Y")   # e.g., '06 Aug 2026'
    key_str = yesterday_dt.strftime("%Y-%m-%d")    # e.g., '2026-08-06'
    return yesterday_dt, date_str, key_str

def is_yesterday_news(pub_date_str, target_dt):
    """Check karta hai ki RSS item ki publish date recent 24-48 hours ki hai ya nahi"""
    if not pub_date_str:
        return True
    try:
        pub_tuple = email.utils.parsedate_tz(pub_date_str)
        if pub_tuple:
            pub_dt = datetime.fromtimestamp(email.utils.mktime_tz(pub_tuple))
            return (target_dt - timedelta(days=1)) <= pub_dt <= (target_dt + timedelta(days=1))
    except Exception as e:
        print(f"Date parsing error: {e}")
    return True

def clean_html_text(text):
    """HTML tags ko clean text me convert karta hai"""
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

# -------------------------------------------------------------
# 2. SCRAPING FUNCTIONS (NEWS - UNCHANGED & PRESERVED)
# -------------------------------------------------------------
def fetch_raw_bihar_news(target_dt):
    """Multiple Official & Media sources se Bihar Current Affairs raw text scrape karta hai"""
    news_titles = []
    
    # Source A: GOOGLE NEWS RSS
    try:
        google_url = "https://news.google.com/rss/search?q=Bihar+Government+Schemes+OR+Infrastructure+OR+Economy+OR+Agriculture&hl=hi&gl=IN&ceid=IN:hi"
        res = requests.get(google_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Google News] {title}")
                    count += 1
                    if count >= 20:
                        break
            print("✅ Google News Bihar RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Google News Bihar: {e}")

    # Source B: CMO BIHAR
    try:
        cmo_url = "https://cm.bihar.gov.in/users/preessrelease.aspx"
        res = requests.get(cmo_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            for row in soup.find_all('tr')[:15]:
                cols = row.find_all('td')
                if len(cols) >= 2:
                    title = cols[1].text.strip()
                    if title and len(title) > 10:
                        news_titles.append(f"[CMO Bihar] {title}")
            print("✅ CMO Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching CMO Bihar: {e}")

    # Source C: IPRD BIHAR
    try:
        iprd_url = "https://state.bihar.gov.in/prdbihar/CitizenHome.html"
        res = requests.get(iprd_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            count = 0
            for link in soup.find_all('a'):
                title = link.text.strip()
                if title and len(title) > 15:
                    news_titles.append(f"[IPRD Bihar] {title}")
                    count += 1
                    if count >= 12:
                        break
            print("✅ IPRD Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching IPRD Bihar: {e}")

    # Source D: PRABHAT KHABAR BIHAR
    try:
        pk_url = "https://www.prabhatkhabar.com/state/bihar/feed"
        res = requests.get(pk_url, impersonate="chrome", timeout=15, verify=False)
        if res.status_code == 200:
            root = ET.fromstring(res.text)
            count = 0
            for item in root.findall('.//item'):
                title = item.find('title').text if item.find('title') is not None else ""
                pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                if title and is_yesterday_news(pub_date, target_dt):
                    news_titles.append(f"[Prabhat Khabar] {title.strip()}")
                    count += 1
                    if count >= 15:
                        break
            print("✅ Prabhat Khabar Bihar news fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error fetching Prabhat Khabar: {e}")

    return "\n".join(news_titles)


def fetch_raw_national_news(target_dt):
    """HIGH-YIELD MULTI-SOURCE PURE NATIONAL Current Affairs Scraper"""
    national_titles = []
    
    # Source A: PIB India (Central Govt Releases)
    try:
        pib_url = "https://pib.gov.in/RssMain.aspx?Mod=1&Lang=1"
        res = requests.get(pib_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[PIB Central] Title: {title.strip()} | Summary: {desc[:250]}")
            print("✅ PIB Central RSS fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error PIB India: {e}")

    # Source B: Google News - Multi-Topic Central Query
    queries = [
        '%22Union+Cabinet%22+OR+%22Central+Government%22+OR+%22Cabinet+Approves%22',
        'ISRO+OR+DRDO+OR+%22Military+Exercise%22+OR+Missile',
        '%22RBI%22+OR+%22NITI+Aayog%22+OR+%22Union+Budget%22+OR+Index',
        '%22G20%22+OR+%22BRICS%22+OR+%22SCO%22+OR+%22COP29%22+OR+%22Summit%22',
        '%22Ramsar+Site%22+OR+%22Tiger+Reserve%22+OR+%22Sports+World+Cup%22'
    ]
    for q in queries:
        try:
            g_url = f"https://news.google.com/rss/search?q={q}&hl=hi&gl=IN&ceid=IN:hi"
            res = requests.get(g_url, impersonate="chrome", timeout=12, verify=False)
            if res.status_code == 200:
                root = ET.fromstring(res.text)
                for item in root.findall('.//item')[:10]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ""
                    desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                    if title and is_yesterday_news(pub_date, target_dt):
                        national_titles.append(f"[Google Central] Title: {title.strip()} | Summary: {desc[:200]}")
        except Exception as e:
            print(f"⚠️ Error Google National Query ({q}): {e}")
    print("✅ Google Central Multi-Queries fetched successfully!")

    # Source C: AIR News
    try:
        air_url = "https://newsonair.gov.in/feed/"
        res = requests.get(air_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[AIR Central] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ AIR Central News fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error AIR News: {e}")

    # Source D: The Hindu National
    try:
        hindu_url = "https://www.thehindu.com/news/national/feeder/default.rss"
        res = requests.get(hindu_url, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item'):
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                if title:
                    national_titles.append(f"[The Hindu National] Title: {title.strip()} | Summary: {desc[:200]}")
            print("✅ The Hindu National fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error The Hindu: {e}")

    return "\n".join(national_titles)

# -------------------------------------------------------------
# 3. HIGH-YIELD LIVE & UPCOMING JOBS SCRAPER
# -------------------------------------------------------------
def fetch_raw_jobs():
    """Scrapes both Newly Announced AND Currently Live/Active Jobs, Admit Cards & Results"""
    job_notices = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    # 1. Google News Queries (Targeting Both Live Active Applications & Upcoming Jobs)
    job_queries = [
        "Bihar+BPSC+OR+BSSC+OR+CSBC+OR+BPSSC+OR+Patna+High+Court+Apply+Online+Last+Date",
        "SSC+CGL+OR+CHSL+OR+MTS+OR+GD+Constable+Apply+Online+Last+Date+Fees",
        "Railway+RRB+NTPC+OR+Group+D+OR+ALP+OR+Technician+Apply+Online+Eligibility",
        "Banking+IBPS+PO+Clerk+OR+SBI+PO+Clerk+OR+UPSC+Apply+Online+Notification",
        "Bihar+OR+SSC+OR+RRB+OR+IBPS+Admit+Card+Release+Exam+Date",
        "Bihar+OR+SSC+OR+RRB+OR+IBPS+Result+Merit+List+Answer+Key"
    ]
    for q in job_queries:
        try:
            g_url = f"https://news.google.com/rss/search?q={q}&hl=en&gl=IN&ceid=IN:en"
            res = requests.get(g_url, impersonate="chrome", timeout=10, verify=False)
            if res.status_code == 200:
                root = ET.fromstring(res.text)
                for item in root.findall('.//item')[:15]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                    if title:
                        job_notices.append(f"[Google Alert] Title: {title} | Snippet: {desc[:800]}")
        except Exception as e:
            print(f"⚠️ Error Job Query ({q}): {e}")
    print("✅ Google Job Alerts fetched successfully!")

    # 2. FreeJobAlert Main Deep Content Feed
    try:
        fja_url = "https://www.freejobalert.com/feed/"
        res = requests.get(fja_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item')[:45]:
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                content_encoded = clean_html_text(content_node.text) if content_node is not None else ""
                full_text = f"{desc} {content_encoded}".strip()
                if title:
                    job_notices.append(f"[FreeJobAlert Entry] Title: {title} | Details: {full_text[:1200]}")
            print("✅ Direct FreeJobAlert Content Feed fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error FreeJobAlert Feed: {e}")

    # 3. Sarkari Result Direct Latest Box Scraping (Live Market Proof)
    try:
        sr_url = "https://www.sarkariresult.com/"
        res = requests.get(sr_url, headers=headers, timeout=12, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            boxes = soup.find_all('div', id=re.compile(r'box|post'))
            for box in boxes:
                for link in box.find_all('a')[:20]:
                    title = link.text.strip()
                    if title and len(title) > 8:
                        job_notices.append(f"[SarkariResult Entry] Title: {title}")
            print("✅ SarkariResult Live Updates fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    return "\n".join(job_notices)

# -------------------------------------------------------------
# 4. GROQ AI EXECUTOR (WITH MULTI-MODEL FALLBACK)
# -------------------------------------------------------------
def call_groq_safe(prompt, system_role="You are a JSON generator assistant."):
    """Multi-Model Fallback Executor (TPM & TPD Safe)"""
    time.sleep(2)
    
    for model_name in MODELS:
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_role},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"}
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] rate-limited/failed: {e}. Trying fallback...")
            time.sleep(2)
            
    print("❌ All Groq models failed/rate-limited for this call.")
    return ""


def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Fact-Based Detailed Hinglish JSON news summary banwata hai"""
    truncated_raw = raw_text[:6000]
    
    if is_national:
        scope_name = "India National & International Level ONLY"
        tag_name = "🎯 National Special / India Affairs"
        category_instruction = """
        STRICT ALLOWED NATIONAL CATEGORIES (Pick ONLY from these 7 exact names):
        1. "Policies, Acts & Flagship Schemes"
        2. "Science, Defense & ISRO"
        3. "Indices, Reports & Economic Affairs"
        4. "International Relations & Summits"
        5. "Environment, Ramsar Sites & Wildlife"
        6. "Appointments, Awards & Places in News"
        7. "Sports & Joint Military Exercises"
        """
        rejection_rules = """
        STRICT REJECTION RULES (CRITICAL):
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT Jobs, Vacancies, Recruitment, Exam Notices, Admit Cards, University/School Notices, and Results.
        2. REJECT ALL STATE-SPECIFIC LOCAL NEWS: Strictly REJECT news specific to individual states (e.g. Tamil Nadu Budget, UP Govt Schemes, State local politics).
        3. REJECT ALL Politics, Crime, & Accidents: REJECT political rallies, speeches, party disputes, political statements, crime, and local accidents.
        4. ACCEPT ONLY PURE NATIONAL / CENTRAL / INTERNATIONAL EVENTS.
        """
        bullet_rules = """
        EXAMINER FOCUS BULLET RULES (NATIONAL):
        - Bullet 1 (Core Decision/Event): Core decision, Nodal Central Ministry/Org, Location/Venue, or Theme in Hinglish.
        - Bullet 2 (Exact High-Yield Exam Facts): Countries, Missile/Launch Vehicle name, India's Rank, Budget Outlay.
        - Bullet 3 (Context & Strategic Objective): Core objective, strategic importance, or policy framework in Hinglish.
        """
    else:
        scope_name = "Bihar State Level"
        tag_name = "🎯 BPSC Special / Bihar Current Affairs"
        category_instruction = """
        STRICT ALLOWED BIHAR CATEGORIES (Pick ONLY from these 5 exact names):
        1. "Govt Schemes & Policies"
        2. "Infrastructure & Projects"
        3. "Agriculture, Environment & GI Tags"
        4. "Appointments, Awards & Persons in News"
        5. "Bihar Economy, Budget & Reports"
        """
        rejection_rules = """
        STRICT REJECTION & DISCARD RULES (CRITICAL):
        1. REJECT ALL RECRUITMENT & EXAM NEWS: Strictly REJECT any Education, Schools, University, Recruitment, Vacancies, Exam Notices, Admit Cards, and Results.
        2. REJECT ALL routine administrative instructions, CM directives, political speeches, crime, and accidents.
        3. STRICT INFRASTRUCTURE FILTER: ACCEPT ONLY MAJOR MEGA-INFRASTRUCTURE PROJECTS.
        4. EVERY card MUST contain AT LEAST ONE hard fact (Outlay, Specific Act Name, MoU partner).
        """
        bullet_rules = """
        BULLET POINT RULES (IF A CARD QUALIFIES):
        1. WRITE EXACTLY 3 DEEP FACTUAL BULLET POINTS IN HINGLISH.
        2. DO NOT write filler lines like "Yeh BPSC ke liye important hai". Provide REAL factual context.
        """

    prompt = f"""
    You are a Senior Current Affairs Editor for BPSC, SSC, and Civil Services Competitive Exams.
    Below is raw news text scraped for {scope_name}:
    
    {truncated_raw}
    
    {category_instruction}

    {rejection_rules}

    DEDUPLICATION & QUANTITY RULE:
    - MERGE duplicate reports of the same event into ONE single card. No duplicate cards allowed.
    - GENERATE ALL VALID CARDS: Extract ALL unique qualifying news items from the input text (target 8-15 cards).

    LANGUAGE & BULLETS:
    - WRITE ALL TITLES AND BULLETS IN **HINGLISH** (Hindi written in Roman English Script).
    - ALWAYS WRITE EXACTLY 3 BULLET POINTS FOR EVERY CARD.
    {bullet_rules}

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category name from the list above",
          "bullets": [
            "Bullet 1: Detailed factual explanation in Hinglish",
            "Bullet 2: Exact numerical data/budget outlay in Hinglish",
            "Bullet 3: Deep explanation of policy framework in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    
    return call_groq_safe(prompt, system_role="Senior Current Affairs Editor")


def generate_job_summary(raw_text):
    """Groq AI se Pure English Structured JSON Job Portal data banwata hai"""
    today_str = datetime.now().strftime("%d %b %Y")
    truncated_raw = raw_text[:7000]

    prompt = f"""
    You are an expert Government Recruitment Portal Data Editor for FreeJobAlert & Sarkari Result.
    Below is raw text scraped regarding Government Job Notifications, Admit Cards, and Results:

    {truncated_raw}

    JOB SELECTION RULES (CRITICAL):
    1. INCLUDE BOTH:
       - Newly Announced Jobs (Starting soon)
       - Currently LIVE / ACTIVE Jobs (Forms currently open, where last_date is valid or open)
    2. MANDATORY FIELDS FOR "latest_jobs":
       - "start_date": Exact date (e.g., "28 Aug 2026").
       - "last_date": Exact date (e.g., "30 Sep 2026").
       - "total_vacancies": Exact post count (e.g., "1,957 Posts").
       - "qualification": Comprehensive eligibility criteria.
       - "application_fee": Complete category-wise fee breakdown (e.g. "General/OBC: ₹600 | SC/ST/PH: ₹150").
       - NEVER write generic "TBA" or "To be announced".

    STRICT GEOGRAPHICAL RULES (APPLIES TO latest_jobs, admit_cards, AND results):
    1. WRITE EVERYTHING IN 100% PURE ENGLISH ONLY.
    2. ALLOWED JURISDICTION ONLY:
       - BIHAR STATE GOVT: BPSC, BSSC, BPSSC, CSBC, Bihar Teacher (TRE), Patna High Court, Civil Court, Beltron, Health Dept Bihar, etc.
       - CENTRAL GOVT (ALL INDIA): Staff Selection Commission (SSC), Indian Railways (RRB), Banking (IBPS, SBI, RBI), UPSC, Defence (Army, Navy, Air Force, CAPF).
    3. ABSOLUTE BAN ON OTHER STATES: REJECT any Job, Admit Card, or Result from UP, MP, Rajasthan, Haryana, Delhi DSSSB, Maharashtra, Jharkhand, etc.

    LINK MAPPING:
    - Set "apply_url" to "https://www.mocktester.online" for ALL items.

    JSON SCHEMA OUTPUT (Return EXACTLY this structure):
    {{
      "latest_jobs": [
        {{
          "id": "job_01",
          "title": "Full Official Recruitment Title 2026",
          "organization": "Official Recruitment Body (e.g., Bihar Public Service Commission - BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Specific Posts Name",
          "total_vacancies": "Exact Post Count e.g., 1,957 Posts",
          "qualification": "Full Comprehensive Educational Qualification Criteria",
          "age_limit": "Complete Min & Max Age limit with relaxation details",
          "pay_scale": "Pay Scale / Salary Level details",
          "application_fee": "Complete Category-wise Application Fee Breakdown",
          "selection_process": "Detailed Selection Steps (e.g., Written CBT, Physical Test, DV)",
          "start_date": "Exact Application Start Date e.g., 28 Aug 2026",
          "last_date": "Exact Application Last Date e.g., 30 Sep 2026",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🔥 Govt Job Alert",
          "date": "{today_str}"
        }}
      ],
      "admit_cards": [
        {{
          "id": "admit_01",
          "title": "Clean Official Admit Card Title",
          "organization": "Recruitment Body Name (e.g., BSSC / SSC / RRB)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Exact Total Posts",
          "exam_date": "Exact Exam Date / CBT Schedule",
          "status": "Admit Card Released / Hall Ticket Link Active",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🎫 Hall Ticket",
          "date": "{today_str}"
        }}
      ],
      "results": [
        {{
          "id": "result_01",
          "title": "Clean Official Result Title",
          "organization": "Recruitment Body Name (e.g., CSBC / BPSC / SSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Post Name",
          "total_vacancies": "Exact Total Posts",
          "result_status": "Merit List PDF Released / Answer Key Declared",
          "apply_url": "https://www.mocktester.online",
          "exam_tag": "🏆 Result",
          "date": "{today_str}"
        }}
      ]
    }}
    """

    return call_groq_safe(prompt, system_role="Government Recruitment Data Editor")

# -------------------------------------------------------------
# 5. PYTHON POST-PROCESSING SMART FILTER
# -------------------------------------------------------------
STATE_BLACKLIST = [
    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "delhi govt", "maharashtra", "mpsc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc",
    "karnataka", "kpsc", "tamil nadu", "tnpsc", "kerala psc",
    "odisha", "opsc", "assam psc", "apsc", "telangana", "tspsc"
]

INVALID_KEYWORDS = ["tba", "to be announced", "to be notified", "not mentioned", "unknown", "n/a", "check notification", "null", ""]

def is_other_state(title, org):
    combined = f"{title} {org}".lower()
    return any(state in combined for state in STATE_BLACKLIST)

def filter_valid_jobs(parsed_jobs):
    """Smart Python Filter: Validates complete data and drops other states"""
    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "")
        org = job.get("organization", "")
        s_date = str(job.get("start_date", "")).strip().lower()
        l_date = str(job.get("last_date", "")).strip().lower()
        vacancies = str(job.get("total_vacancies", "")).strip().lower()

        # Rule 1: Other state check
        if is_other_state(title, org):
            print(f"❌ Dropped job (Other state): {title}")
            continue

        # Rule 2: Mandatory fields check
        if not s_date or not l_date or not vacancies:
            print(f"❌ Dropped job (Missing mandatory fields): {title}")
            continue

        # Rule 3: TBA / Placeholder check
        if any(kw in s_date for kw in INVALID_KEYWORDS) or \
           any(kw in l_date for kw in INVALID_KEYWORDS) or \
           any(kw in vacancies for kw in INVALID_KEYWORDS):
            print(f"❌ Dropped job (Placeholder value): {title}")
            continue

        clean_latest_jobs.append(job)

    # Filter Admit Cards
    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "")
        org = card.get("organization", "")
        if not is_other_state(title, org) and card.get("exam_date"):
            clean_admit_cards.append(card)

    # Filter Results
    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "")
        org = res_item.get("organization", "")
        if not is_other_state(title, org) and res_item.get("result_status"):
            clean_results.append(res_item)

    parsed_jobs["latest_jobs"] = clean_latest_jobs
    parsed_jobs["admit_cards"] = clean_admit_cards
    parsed_jobs["results"] = clean_results
    return parsed_jobs

# -------------------------------------------------------------
# 6. MASTER HISTORY APPEND FUNCTIONS
# -------------------------------------------------------------
def append_to_master_history(news_cards, yesterday_key, is_national=False):
    master_file = "all_national_news_history.json" if is_national else "all_bihar_news_history.json"
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Master History appended under key '{yesterday_key}' into '{master_file}'!")

# -------------------------------------------------------------
# 7. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Complete Current Affairs & Jobs Pipeline ({date_str})...\n")

    # === A. PROCESS BIHAR NEWS ===
    print("📍 --- PROCESS BIHAR NEWS ---")
    raw_bihar = fetch_raw_bihar_news(target_dt)
    if raw_bihar:
        ai_bihar = generate_clean_summary(raw_bihar, date_str, is_national=False)
        if ai_bihar:
            try:
                parsed_bihar = json.loads(ai_bihar.strip())
                cards = parsed_bihar.get("news_cards", [])
                
                if cards and len(cards) > 0:
                    with open("bihar_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_news.json successfully updated with {len(cards)} new cards!")
                    append_to_master_history(cards, key_str, is_national=False)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 Bihar news cards. Retaining existing file!")
            except Exception as e:
                print(f"❌ Bihar JSON Parsing Error: {e}")

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    print("🇮🇳 --- PROCESS NATIONAL NEWS ---")
    raw_national = fetch_raw_national_news(target_dt)
    if raw_national:
        ai_national = generate_clean_summary(raw_national, date_str, is_national=True)
        if ai_national:
            try:
                parsed_national = json.loads(ai_national.strip())
                cards_nat = parsed_national.get("news_cards", [])
                
                if cards_nat and len(cards_nat) > 0:
                    with open("national_news.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_national, f, ensure_ascii=False, indent=2)
                    print(f"✅ national_news.json successfully updated with {len(cards_nat)} new cards!")
                    append_to_master_history(cards_nat, key_str, is_national=True)
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 National news cards. Retaining existing file!")
            except Exception as e:
                print(f"❌ National JSON Parsing Error: {e}")

    print("\n------------------------------------\n")

    # === C. PROCESS BIHAR & CENTRAL JOBS ===
    print("💼 --- PROCESS BIHAR & CENTRAL JOBS ---")
    raw_jobs = fetch_raw_jobs()
    if raw_jobs:
        ai_jobs = generate_job_summary(raw_jobs)
        if ai_jobs:
            try:
                parsed_jobs = json.loads(ai_jobs.strip())
                
                # Filter Jobs
                parsed_jobs = filter_valid_jobs(parsed_jobs)
                
                has_data = (
                    len(parsed_jobs.get("latest_jobs", [])) > 0 or
                    len(parsed_jobs.get("admit_cards", [])) > 0 or
                    len(parsed_jobs.get("results", [])) > 0
                )
                if has_data:
                    with open("bihar_jobs.json", "w", encoding="utf-8") as f:
                        json.dump(parsed_jobs, f, ensure_ascii=False, indent=2)
                    print(f"✅ bihar_jobs.json updated! Jobs: {len(parsed_jobs.get('latest_jobs', []))} | "
                          f"Admit Cards: {len(parsed_jobs.get('admit_cards', []))} | "
                          f"Results: {len(parsed_jobs.get('results', []))}")
                else:
                    print("🛡️ SAFEGUARD ACTIVATED: 0 job notifications found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Pipeline Execution Finished Successfully!")
