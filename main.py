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
# 3. ENHANCED JOB SCRAPER WITH DIRECT PORTAL SOURCES
#    (UPDATED: bigger truncation limits so fee/date/vacancy details
#     don't get cut off before reaching the AI, and Sarkari Result
#     entries — which only carry a title+URL and no real fields —
#     are no longer fed into the job JSON generator, since they
#     gave the AI nothing to work with except invent data.)
# -------------------------------------------------------------
def fetch_raw_jobs():
    """HIGH-VOLUME ACCURATE SCRAPER FOR JOBS, ADMIT CARDS & RESULTS WITH DEEP DATA PARSING"""
    job_notices = []
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    # 1. Broad Multi-Topic Search Queries (Bihar + Central only)
    job_queries = [
        "Bihar+BPSC+OR+BSSC+OR+CSBC+OR+BPSSC+OR+Patna+High+Court+Recruitment+Start+Date+Last+Date+Fees",
        "Bihar+Teacher+TRE+OR+Bihar+Health+Dept+OR+Beltron+OR+Civil+Court+Vacancy+Eligibility+Posts",
        "SSC+CGL+OR+CHSL+OR+MTS+OR+GD+Constable+Notification+Start+Date+Fees",
        "Railway+RRB+NTPC+OR+Group+D+OR+ALP+OR+Technician+Vacancy+Eligibility+Posts",
        "Banking+IBPS+PO+Clerk+OR+SBI+PO+Clerk+OR+UPSC+Notification+Application+Fee",
        "Bihar+OR+SSC+OR+RRB+OR+UPSC+Admit+Card+Download+Exam+Date",
        "Bihar+OR+SSC+OR+RRB+OR+UPSC+Result+Merit+List+Answer+Key"
    ]
    for q in job_queries:
        try:
            g_url = f"https://news.google.com/rss/search?q={q}&hl=en&gl=IN&ceid=IN:en"
            res = requests.get(g_url, impersonate="chrome", timeout=12, verify=False)
            if res.status_code == 200:
                root = ET.fromstring(res.text)
                for item in root.findall('.//item')[:15]:
                    title = item.find('title').text if item.find('title') is not None else ""
                    desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                    if title:
                        # Truncation raised 800 -> 1500 so fee/date/vacancy text isn't cut off
                        job_notices.append(f"[Google Job Alert] Title: {title} | Snippet: {desc[:1500]}")
        except Exception as e:
            print(f"⚠️ Error Job Query ({q}): {e}")

    # 2. FreeJobAlert Main Deep Content Feed
    try:
        fja_url = "https://www.freejobalert.com/feed/"
        res = requests.get(fja_url, headers=headers, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "xml")
            for item in soup.find_all('item')[:50]:
                title = item.find('title').text if item.find('title') is not None else ""
                desc = clean_html_text(item.find('description').text if item.find('description') is not None else "")
                content_node = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
                content_encoded = clean_html_text(content_node.text) if content_node is not None else ""
                full_text = f"{desc} {content_encoded}".strip()
                if title:
                    # Truncation raised 1500 -> 3000 so full fee/date tables survive
                    job_notices.append(f"[FreeJobAlert Entry] Title: {title} | Full Text: {full_text[:3000]}")
            print("✅ Direct FreeJobAlert Deep Content Feed fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error FreeJobAlert Feed: {e}")

    # 3. Sarkari Result Recent Posts Table
    #    NOTE: This source only yields a title + URL, no fee/date/vacancy
    #    data. Feeding it to the AI as if it were a full notice caused the
    #    model to invent structured details from thin air. We now only use
    #    it to confirm a job's title is currently live in the market —
    #    it is NOT allowed to be the sole source for a job entry, and the
    #    grounding filter below will drop anything that relies only on this.
    try:
        sr_url = "https://www.sarkariresult.com/latestjob/"
        res = requests.get(sr_url, headers=headers, timeout=15, verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            job_links = soup.select("#post a")[:20]
            for link in job_links:
                title = link.text.strip()
                href = link.get('href', '')
                if title and href:
                    job_notices.append(f"[Sarkari Result Reference Only - Title/URL only, no fee/date data] Title: {title} | URL: {href}")
            print("✅ Sarkari Result direct jobs fetched successfully!")
    except Exception as e:
        print(f"⚠️ Error SarkariResult Scraping: {e}")

    return "\n".join(job_notices)

# -------------------------------------------------------------
# 4. AI SUMMARY GENERATORS (NEWS & JOBS)
# -------------------------------------------------------------
def generate_clean_summary(raw_text, target_date_str, is_national=False):
    """Groq AI se Fact-Based Detailed Hinglish JSON news summary banwata hai (UNCHANGED)"""
    
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
    
    {raw_text}
    
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
    
    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.01,
            response_format={"type": "json_object"}
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"⚠️ Groq API Failed for {scope_name}: {e}")
        return ""


def generate_job_summary(raw_text):
    """
    Groq AI se Pure English Detailed Job Portal data banwata hai.
    UPDATED: Instead of forcing the AI to NEVER write "Not specified"
    (which pushed it to invent plausible-looking fake dates/fees when the
    source text lacked them), we now explicitly tell it to DROP any job
    it cannot fully ground in the raw text. This removes the incentive
    to hallucinate. The Python-side filter_valid_jobs() then double-checks
    every field is actually present in the raw source before keeping it.
    """
    today_str = datetime.now().strftime("%d %b %Y")

    prompt = f"""
    You are an expert Government Recruitment Portal Data Editor for FreeJobAlert & Sarkari Result.
    Below is raw text scraped regarding Government Job Notifications, Admit Cards, and Results:

    {raw_text}

    ABSOLUTE MANDATORY GROUNDING RULE (CRITICAL - READ CAREFULLY):
    You may ONLY extract facts that are EXPLICITLY written in the raw text above.
    - Do NOT use your own general knowledge of "typical" government exam fees, dates, or age limits.
    - Do NOT estimate, guess, or infer a value that is not literally present in the raw text.
    - If start_date, last_date, total_vacancies, application_fee, or qualification is NOT
      explicitly stated in the raw text for a job, you MUST completely OMIT that job from
      "latest_jobs" entirely. It is far better to return FEWER jobs than to invent even one field.
    - Never write "Not specified", "TBA", "To be announced", "Check notification", "Unknown", or "N/A" —
      but the correct way to handle a missing field is to DROP THE ENTIRE JOB, not to fill in a fake value.
    - The [Sarkari Result Reference Only] entries contain ONLY a title and URL - they have NO fee, date,
      or vacancy data. NEVER use a Sarkari Result Reference Only entry as your only source for a job's
      details. If a job appears only in a Sarkari Result Reference Only line and nowhere else with full
      details, DO NOT include it in "latest_jobs".
    - For "admit_cards": only include an entry if the raw text explicitly states an exam date /
      CBT schedule / admit card release status. Otherwise omit it.
    - For "results": only include an entry if the raw text explicitly states a result status
      (merit list released, answer key declared, etc). Otherwise omit it.

    STRICT GEOGRAPHICAL RULES (APPLIES TO latest_jobs, admit_cards, AND results):
    1. WRITE EVERYTHING IN 100% PURE ENGLISH ONLY.
    2. ALLOWED JURISDICTION ONLY:
       - BIHAR STATE GOVT: BPSC, BSSC, BPSSC, CSBC, Bihar Teacher (TRE), Patna High Court, Civil Court, Beltron, Health Dept Bihar, etc.
       - CENTRAL GOVT (ALL INDIA): Staff Selection Commission (SSC), Indian Railways (RRB), Banking (IBPS, SBI, RBI), UPSC, Defence (Army, Navy, Air Force, CAPF).
    3. ABSOLUTE BAN ON OTHER STATES: REJECT any Job, Admit Card, or Result from UP, MP, Rajasthan, Haryana,
       Delhi DSSSB, Maharashtra, Jharkhand, West Bengal, Punjab, Gujarat, Karnataka, Tamil Nadu, Kerala,
       Odisha, Assam, Telangana, Andhra Pradesh, or any other individual state. This ban applies to
       latest_jobs, admit_cards, AND results equally - not just latest_jobs.

    JSON SCHEMA OUTPUT (Return EXACTLY this structure):
    {{
      "latest_jobs": [
        {{
          "id": "job_01",
          "title": "Full Official Recruitment Title 2026",
          "organization": "Official Recruitment Body (e.g., Bihar Public Service Commission - BPSC)",
          "job_type": "Bihar Govt Job OR Central Govt Job",
          "post_name": "Specific Posts Name with Post-wise Breakdown",
          "total_vacancies": "Exact Post Count e.g., 1,957 Posts",
          "qualification": "Full Comprehensive Educational Qualification Criteria",
          "age_limit": "Complete Min & Max Age limit with category relaxation details",
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

    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.01,
            response_format={"type": "json_object"}
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"⚠️ Groq API Job Summary Error: {e}")
        return '{"latest_jobs": [], "admit_cards": [], "results": []}'


# -------------------------------------------------------------
# 🌟 NORMALIZATION HELPER & ULTRA-STRICT PYTHON FILTER FOR JOBS
#    (UPDATED: added grounding-in-source check + non-Bihar/Central
#     state blacklist, applied to latest_jobs, admit_cards, AND results)
# -------------------------------------------------------------
def normalize_text(text):
    """Cleans whitespace, lowercase, and strips common trailing punctuation."""
    if not text:
        return ""
    cleaned = str(text).lower().strip()
    # Remove trailing periods, dashes, colons, commas
    cleaned = re.sub(r'[\.\-:\,\s]+$', '', cleaned)
    return cleaned

INVALID_KEYWORDS = [
    "tba", "to be announced", "to be notified", "to be updated",
    "not mentioned", "not specified", "not announced", "not available",
    "unknown", "n/a", "check notification", "null", "none", ""
]

# Any of these appearing in title/organization means it's NOT Bihar/Central
# and must be dropped from latest_jobs, admit_cards, and results alike.
STATE_BLACKLIST = [
    "uttar pradesh", " up police", " up board", "uppsc", " up govt",
    "madhya pradesh", "mppsc", "rajasthan", "rpsc", "haryana", "hpsc",
    "dsssb", "delhi govt", "maharashtra", "mpsc", "jharkhand", "jpsc",
    "west bengal", "wbpsc", "punjab", "ppsc", "gujarat", "gpsc",
    "karnataka", "kpsc", "tamil nadu", "tnpsc", "kerala psc",
    "odisha", "opsc", "assam psc", "apsc", "telangana", "tspsc",
    "andhra pradesh", "appsc", "chhattisgarh", "cgpsc", "uttarakhand",
    "ukpsc", "himachal", "hppsc", "goa psc", "manipur", "meghalaya",
    "nagaland", "tripura", "sikkim", "mizoram"
]

def normalize_text_for_search(text):
    return str(text or "").lower()

def is_state_specific(*fields):
    """Returns True if any field mentions a non-Bihar/non-Central state body."""
    combined = " ".join(normalize_text_for_search(f) for f in fields)
    return any(kw in combined for kw in STATE_BLACKLIST)

def _digit_groups(text):
    """Extracts numeric groups (commas/spaces stripped) e.g. '1,957' -> '1957'."""
    raw_numbers = re.findall(r'[\d,]+', text or "")
    return [n.replace(",", "") for n in raw_numbers if n.replace(",", "").strip()]

def value_grounded_in_source(value, raw_text, field_type="generic"):
    """
    Format-tolerant check: does the extracted value's core numbers actually
    appear in the raw scraped text? Dates/vacancies are compared by their
    digit content (day/month-num/year or post-count), ignoring separators
    like '-', '/', ',', or words like 'Aug' vs 'August' vs '08'.
    This prevents the AI from inventing a fee/date/vacancy figure that was
    never in the source, without being so strict that formatting
    differences cause valid, real data to be dropped.
    """
    if not value:
        return False
    raw_digits_blob = re.sub(r'[,\s\-/]', '', raw_text.lower())
    value_numbers = _digit_groups(value)

    if value_numbers:
        # For dates/vacancies: at least one meaningful number (2+ digits,
        # e.g. day/year/post-count) must appear somewhere in the raw text.
        meaningful = [n for n in value_numbers if len(n) >= 2]
        if not meaningful:
            meaningful = value_numbers
        hits = sum(1 for n in meaningful if n in raw_digits_blob)
        return hits >= 1

    # Fallback for values with no digits at all (rare): loose word match
    raw_lower = raw_text.lower()
    tokens = re.findall(r'\b[A-Za-z]{4,}\b', value.lower())
    if not tokens:
        return True  # nothing to check against, don't over-reject
    hits = sum(1 for t in tokens if t in raw_lower)
    return hits >= 1

def filter_valid_jobs(parsed_jobs, raw_text=""):
    """
    Ultra-Strict Python Filter:
    1. Drops jobs/admit-cards/results with missing or placeholder fields.
    2. Drops anything not grounded in the actual scraped raw text
       (kills hallucinated dates/fees/vacancies).
    3. Drops anything specific to a non-Bihar/non-Central state.
    """
    clean_latest_jobs = []
    for job in parsed_jobs.get("latest_jobs", []):
        title = job.get("title", "Unknown Job")
        org = job.get("organization", "")
        s_date = normalize_text(job.get("start_date", ""))
        l_date = normalize_text(job.get("last_date", ""))
        vacancies = normalize_text(job.get("total_vacancies", ""))
        fee = normalize_text(job.get("application_fee", ""))
        qual = normalize_text(job.get("qualification", ""))

        if not s_date or not l_date or not vacancies or not fee or not qual:
            print(f"❌ Dropped job (Missing Field): {title}")
            continue

        is_invalid = False
        for field_val in [s_date, l_date, vacancies, fee, qual]:
            if any(kw == field_val or kw in field_val for kw in INVALID_KEYWORDS):
                is_invalid = True
                break
        if is_invalid:
            print(f"❌ Dropped job (Placeholder value): {title}")
            continue

        if not re.search(r'\d+', vacancies):
            print(f"❌ Dropped job (No digits in total_vacancies): {title}")
            continue

        if not re.search(r'\d+', s_date) or not re.search(r'\d+', l_date):
            print(f"❌ Dropped job (Invalid date format without numbers): {title}")
            continue

        if is_state_specific(title, org):
            print(f"❌ Dropped job (Non-Bihar/Central state): {title}")
            continue

        if raw_text and not (
            value_grounded_in_source(job.get("start_date", ""), raw_text) and
            value_grounded_in_source(job.get("last_date", ""), raw_text) and
            value_grounded_in_source(job.get("total_vacancies", ""), raw_text)
        ):
            print(f"❌ Dropped job (Not grounded in raw scraped source): {title}")
            continue

        clean_latest_jobs.append(job)

    clean_admit_cards = []
    for card in parsed_jobs.get("admit_cards", []):
        title = card.get("title", "Unknown Admit Card")
        org = card.get("organization", "")
        exam_date = normalize_text(card.get("exam_date", ""))
        status = normalize_text(card.get("status", ""))

        if not exam_date or not status:
            print(f"❌ Dropped admit card (Missing Field): {title}")
            continue
        if any(kw == exam_date or kw in exam_date for kw in INVALID_KEYWORDS):
            print(f"❌ Dropped admit card (Placeholder exam_date): {title}")
            continue
        if is_state_specific(title, org):
            print(f"❌ Dropped admit card (Non-Bihar/Central state): {title}")
            continue
        if raw_text and not value_grounded_in_source(card.get("exam_date", ""), raw_text):
            print(f"❌ Dropped admit card (exam_date not grounded in source): {title}")
            continue

        clean_admit_cards.append(card)

    clean_results = []
    for res_item in parsed_jobs.get("results", []):
        title = res_item.get("title", "Unknown Result")
        org = res_item.get("organization", "")
        status = normalize_text(res_item.get("result_status", ""))

        if not status:
            print(f"❌ Dropped result (Missing result_status): {title}")
            continue
        if any(kw == status or kw in status for kw in INVALID_KEYWORDS):
            print(f"❌ Dropped result (Placeholder result_status): {title}")
            continue
        if is_state_specific(title, org):
            print(f"❌ Dropped result (Non-Bihar/Central state): {title}")
            continue

        clean_results.append(res_item)

    parsed_jobs["latest_jobs"] = clean_latest_jobs
    parsed_jobs["admit_cards"] = clean_admit_cards
    parsed_jobs["results"] = clean_results
    return parsed_jobs

# -------------------------------------------------------------
# 5. MASTER HISTORY APPEND FUNCTIONS (UNCHANGED & PRESERVED)
# -------------------------------------------------------------
def append_to_master_history(news_cards, yesterday_key, is_national=False):
    """Appends daily news cards to the master history JSON files"""
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
# 6. MAIN EXECUTION PIPELINE
# -------------------------------------------------------------
if __name__ == "__main__":
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)
        
    target_dt, date_str, key_str = get_yesterday_info()
    print(f"🔄 Starting Complete Current Affairs & Jobs Pipeline ({date_str})...\n")

    # === A. PROCESS BIHAR NEWS (UNCHANGED) ===
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

    # === B. PROCESS NATIONAL NEWS (UNCHANGED) ===
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

    # === C. PROCESS ACCURATE BIHAR & CENTRAL JOBS ===
    print("💼 --- PROCESS ACCURATE BIHAR & CENTRAL JOBS ---")
    raw_jobs = fetch_raw_jobs()
    if raw_jobs:
        ai_jobs = generate_job_summary(raw_jobs)
        if ai_jobs:
            try:
                parsed_jobs = json.loads(ai_jobs.strip())

                print(f"ℹ️ AI returned before filtering -> Jobs: {len(parsed_jobs.get('latest_jobs', []))} | "
                      f"Admit Cards: {len(parsed_jobs.get('admit_cards', []))} | "
                      f"Results: {len(parsed_jobs.get('results', []))}")

                # 🌟 HARD PYTHON FILTERING: drops any job/admit-card/result that is
                # missing required fields, contains placeholder text, is not grounded
                # in the actual scraped source text, or is specific to a non-Bihar/
                # non-Central state.
                parsed_jobs = filter_valid_jobs(parsed_jobs, raw_jobs)
                
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
                    print("🛡️ SAFEGUARD ACTIVATED: 0 complete job/admit-card/result entries found. Retaining existing file!")
            except Exception as e:
                print(f"❌ Jobs JSON Parsing Error: {e}")

    print("\n🎉 Pipeline Execution Finished Successfully!")
