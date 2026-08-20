import os
import re
import json
import html
import hashlib
import feedparser
import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs, unquote
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION
# ============================================================

TARGET_FILE = "rawnews.json"
IST = timezone(timedelta(hours=5, minutes=30))
TIMEOUT = 15

MIN_WORDS_PER_ARTICLE = 150
MAX_WORDS_PER_ARTICLE = 500

SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "").strip()

BIHAR_FEEDS = [
    {
        "category": "Schemes, Policy, Budget & Indexes",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/11872670836562053243"
    },
    {
        "category": "Appointments, Awards, Sports & Culture",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/12169416279183737117"
    },
    {
        "category": "Infrastructure, Energy, Agriculture & Environment",
        "url": "https://www.google.com/alerts/feeds/18398184577640792063/13882357121219546323"
    }
]

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
}

# ============================================================
# DEBUGGING HELPERS
# ============================================================

def now_ist():
    return datetime.now(IST)


def debug(msg):
    print(f"🔍 {msg}")


def warn(msg):
    print(f"⚠️ {msg}")


def success(msg):
    print(f"✅ {msg}")


# ============================================================
# COMPREHENSIVE JUNK & IRRELEVANT KEYWORDS FILTER
# ============================================================

BANNED_TOPICS_REGEX = re.compile(
    r'('
    # 1. Editorials, Opinion Pieces, Columns & Media Self-Promotions
    r'\beditorial\b|\bopinion\b|\bop-ed\b|\bcolumn\b|\bviewpoint\b|\bcommentary\b|\banalysis\b|\bread more\b|\bexclusive interview\b|'
    r'संपादकीय|विचार|कॉलम|दृष्टिकोण|समीक्षा|'

    # 2. Coaching Institutes, Commercial Courses, Fake Rumors & Exam Speculations
    r'\bcoaching\b|\badmission open\b|\bbatch starts\b|\btest series\b|\bmock test series\b|\banswer key released soon\b|'
    r'\bexpected cut-?off\b|\bhow to check\b|\bstep-by-step guide\b|\bdirect link here\b|\bhall ticket download link\b|'
    r'कोचिंग|एडमिशन शुरू|नया बैच|टेस्ट सीरीज|कटऑफ कितना जाएगा|ऐसे करें चेक|डायरेक्ट लिंक|एडमिट कार्ड कब आएगा|'

    # 3. Routine Traffic, Route Diversions & Road Jams
    r'\btraffic jam\b|\broute diverted\b|\bdiversion\b|\bchakka jam\b|\broad blocked\b|\bheavy traffic\b|\bvehicle movement\b|'
    r'ट्रैफिक जाम|रूट डायवर्ट|वाहनों की कतार|सड़क जाम|जाम की समस्या|'

    # 4. Corporate Commercial Deals, Private Orders, Real Estate & Stock Market
    r'\bsecures?\s+order\b|\bbagged\s+order\b|\bsecures?\s+contract\b|\bwon\s+bid\b|\bquarterly\s+results?\b|\bshares?\s+(jump|surge|tank|fall|rise)\b|'
    r'\brooftop\s+solar\s+order\b|\bmarket\s+cap\b|\bipo\b|\bq[1-4]\s+results?\b|\bpat\s+up\b|\bnet\s+profit\b|\bflat for sale\b|\bplot for sale\b|'
    r'ऑर्डर मिला|टेंडर|शेयर बाजार|मुनाफा|कारोबार|कंपनी को मिला|प्लॉट बिकाऊ|'

    # 5. Crime, Legal Scandals, Murder, Suicide, Theft, Liquor Seizure
    r'\bmurder\b|\bkilled\b|\bkilling\b|\brape\b|\bdead\b|\bdeath\b|\bdies\b|\bbody\s+found\b|\barrested?\b|\bloot\b|\brobbery\b|'
    r'\btheft\b|\bkidnap\b|\bextortion\b|\bbribe\b|\bbribery\b|\bfraud\b|\bscam\b|\bshootout\b|\bfiring\b|\bencounter\b|\bsmuggling\b|'
    r'\billicit\b|\bliquor\b|\bspurious\b|\bcyber\s+crime\b|\bgangster\b|\bcriminal\b|\bsuicide\b|'
    r'हत्या|मर्डर|बलात्कार|मौत|शव|लाश|गिरफ्तार|हिरासत|गोलीबारी|गोली मारी|लूट|चोरी|डकैती|अपहरण|फिरौती|धोखाधड़ी|घूस|रिश्वत|मुठभेड़|तस्करी|शराब बरामद|जब्त|छापेमारी|दबोचा|बदमाश|अपराधी|आत्महत्या|'

    # 6. Accidents, Disasters & Vehicle Crashes
    r'\baccident\b|\bcrash\b|\bcollision\b|\bderail\b|\bderailment\b|\bdrowned\b|\bdrowning\b|\bfire\s+broke\b|\bcylinder\s+blast\b|\bexplosion\b|\bblast\b|\bboat\s+capsize\b|\bstampede\b|'
    r'दुर्घटना|सड़क हादसा|टक्कर|ट्रक|बस हादसा|ट्रेन हादसा|डूबने|डूबकर|आग लगी|सिलेंडर ब्लास्ट|धमाका|विस्फोट|नाव पलटी|भगदड़|'

    # 7. Local Political Rallies, Clashes, Strikes, Statements & Bayanbazi
    r'\blathi-?charge\b|\bprotest\b|\bprotesters\b|\bstrike\b|\bhunger\s+strike\b|\bdharna\b|\bclash\b|\bclashes\b|\bstone\s+pelting\b|\bviolence\b|'
    r'\braj\s+bhavan\s+march\b|\bcalls?\s+out\b|\bhits?\s+out\b|\bslams\b|\battacked state govt\b|\bpress conference\b|'
    r'लाठीचार्ज|प्रदर्शन|धरना|हड़ताल|भूख हड़ताल|बवाल|हंगामा|पथराव|हिंसा|झड़प|राजभवन मार्च|घेराव|निशाना साधा|पलटवार|तंज कसा|'

    # 8. Astrology, Horoscopes, Weather Bulletins, Lottery, Gold Rates & Viral Media
    r'\bhoroscope\b|\brashifal\b|\blottery\b|\bviral\s+video\b|\breels?\b|\bweather\s+today\b|\brain\s+batters\b|\bheavy\s+rain\b|\bgold rate today\b|\bsilver price\b|'
    r'राशिफल|लॉटरी|वायरल वीडियो|मौसम का हाल|भारी बारिश|सोने का भाव|चांदी की कीमत'
    r')',
    re.IGNORECASE | re.UNICODE
)


def is_unwanted_news(title, text=""):
    combined = f"{title} {text}"
    match = BANNED_TOPICS_REGEX.search(combined)
    if match:
        return True, match.group(0)
    return False, ""


# ============================================================
# DEEP WEB PAGE DATE DETECTION ENGINE
# ============================================================

DATE_FORMATS = [
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S.%f%z",
    "%Y-%m-%d %H:%M:%S",
    "%a, %d %b %Y %H:%M:%S %z",
    "%a, %d %b %Y %H:%M:%S GMT",
    "%d-%b-%Y", "%d-%B-%Y", "%d/%m/%Y", "%d-%m-%Y",
    "%Y-%m-%d", "%d %b %Y", "%d %B %Y"
]


def parse_date_string(date_str):
    if not date_str:
        return None
    
    clean_str = re.sub(r'\b(IST|GMT|UTC)\b', '', str(date_str), flags=re.I).strip()
    
    for fmt in DATE_FORMATS:
        try:
            d = datetime.strptime(clean_str, fmt)
            if d.tzinfo is None:
                d = d.replace(tzinfo=IST)
            return d.astimezone(IST)
        except Exception:
            continue
            
    # Fallback Regex Search inside string
    m = re.search(r'\b(\d{4}-\d{2}-\d{2}|\d{1,2}[-/]\d{1,2}[-/]\d{4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\b', clean_str)
    if m:
        raw_m = m.group(0)
        for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%d %b %Y", "%d %B %Y"]:
            try:
                d = datetime.strptime(raw_m, fmt)
                return d.replace(tzinfo=IST)
            except Exception:
                continue
    return None


def extract_published_date_from_soup(soup):
    # 1. JSON-LD Structured Data (Most accurate)
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objs = data if isinstance(data, list) else [data]
            for obj in objs:
                if isinstance(obj, dict):
                    pub = obj.get("datePublished") or obj.get("dateModified") or obj.get("uploadDate")
                    if pub:
                        parsed = parse_date_string(pub)
                        if parsed:
                            return parsed
        except Exception:
            pass

    # 2. Meta Tags
    selectors = [
        "meta[property='article:published_time']",
        "meta[property='og:published_time']",
        "meta[name='publish-date']",
        "meta[name='date']",
        "meta[name='DC.date']",
        "meta[itemprop='datePublished']",
        "meta[name='pubdate']",
        "time[datetime]",
        ".publish-date",
        ".date-time",
        ".story-date"
    ]
    for sel in selectors:
        elem = soup.select_one(sel)
        if elem:
            val = elem.get("content") or elem.get("datetime") or elem.get_text(strip=True)
            parsed = parse_date_string(val)
            if parsed:
                return parsed

    return None


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def extract_real_url(google_url):
    try:
        parsed = urlparse(google_url)
        query_params = parse_qs(parsed.query)
        if 'url' in query_params:
            return unquote(query_params['url'][0])
    except Exception as e:
        warn(f"URL extraction failed: {e}")
    return google_url


def clean_text(raw_text):
    if not raw_text:
        return ""
    soup = BeautifulSoup(str(raw_text), "html.parser")
    text = soup.get_text(separator=" ")
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return html.unescape(" ".join(text.split())).strip()


def clean_title(title):
    t = clean_text(title)
    t = re.sub(
        r'\s*[-|–—]\s*(Dainik Bhaskar|Amar Ujala|Prabhat Khabar|Live Hindustan|Jagran|NDTV|News18|PIB|Telangana Today|The Hindu|Times of India)\s*$',
        '',
        t,
        flags=re.I
    )
    return t.strip()


def get_entry_datetime(entry):
    if hasattr(entry, 'published_parsed') and entry.published_parsed:
        utc_dt = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    elif hasattr(entry, 'updated_parsed') and entry.updated_parsed:
        utc_dt = datetime(*entry.updated_parsed[:6], tzinfo=timezone.utc)
        return utc_dt.astimezone(IST)
    return None


# ============================================================
# WEBPAGE HTML FETCHERS (DIRECT + SCRAPINGANT API FALLBACK)
# ============================================================

def scrapingant_fetch(url):
    if not SCRAPINGANT_API_KEY:
        return None

    try:
        debug(f"Triggering ScrapingAnt API for: {url[:50]}...")
        endpoint = "https://api.scrapingant.com/v2/general"
        params = {
            "url": url,
            "x-api-key": SCRAPINGANT_API_KEY,
            "browser": "false",
        }
        r = requests.get(endpoint, params=params, timeout=30)
        if r.status_code == 200:
            try:
                data = r.json()
                if isinstance(data, dict) and "content" in data:
                    return data["content"]
            except Exception:
                pass
            return r.text
        else:
            warn(f"ScrapingAnt API returned HTTP {r.status_code}")
    except Exception as e:
        warn(f"ScrapingAnt Fetch Error: {e}")
    return None


def fetch_raw_html(target_url):
    try:
        resp = requests.get(target_url, headers=HEADERS, timeout=TIMEOUT)
        if resp.status_code == 200 and len(resp.content) > 500:
            return resp.content
        else:
            warn(f"Direct fetch got HTTP {resp.status_code}. Retrying with ScrapingAnt...")
    except Exception as e:
        warn(f"Direct request failed ({e}). Retrying with ScrapingAnt...")

    return scrapingant_fetch(target_url)


def scrape_full_webpage_content_and_date(target_url):
    raw_html = fetch_raw_html(target_url)
    if not raw_html:
        return "", None, 0

    try:
        soup = BeautifulSoup(raw_html, "html.parser")
        
        # Exact Deep Published Date on page
        page_dt = extract_published_date_from_soup(soup)

        for tag in soup(["script", "style", "nav", "footer", "header", "aside", "form", "svg"]):
            tag.decompose()

        target_elem = (
            soup.find("article") or
            soup.find(class_=re.compile(r'(story|article|news|detail|content)', re.I)) or
            soup.find("main")
        )

        if target_elem:
            text = target_elem.get_text(separator=" ")
        else:
            paragraphs = [p.get_text(strip=True) for p in soup.find_all("p") if len(p.get_text(strip=True)) > 25]
            text = " ".join(paragraphs) if paragraphs else soup.get_text(separator=" ")

        cleaned = clean_text(text)
        words = cleaned.split()
        total_words = len(words)

        if total_words >= MIN_WORDS_PER_ARTICLE:
            trimmed = " ".join(words[:MAX_WORDS_PER_ARTICLE])
            return trimmed, page_dt, total_words
        else:
            return "", page_dt, total_words

    except Exception as e:
        warn(f"HTML Parsing Error for {target_url[:40]}: {e}")
        return "", None, 0


# ============================================================
# MAIN EXECUTION
# ============================================================

def process_and_append_bihar_alerts():
    today_date = now_ist().date()
    today_str = now_ist().strftime("%d %b %Y")
    print("\n" + "=" * 80)
    print(f"🚀 STARTING PRECISION BIHAR ALERTS SCRAPER [{today_str}]")
    print("=" * 80)

    raw_data = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": 0,
        "national_raw_count": 0,
        "total_raw_count": 0,
        "bihar_raw_news": [],
        "national_raw_news": [],
        "source_breakdown": {}
    }

    if os.path.exists(TARGET_FILE):
        try:
            with open(TARGET_FILE, "r", encoding="utf-8") as f:
                raw_data = json.load(f)
            debug(f"Loaded existing {TARGET_FILE}")
        except Exception as e:
            warn(f"Could not load {TARGET_FILE}: {e}")

    existing_bihar = raw_data.get("bihar_raw_news", [])
    valid_existing_bihar = [item for item in existing_bihar if today_str in item.get("date", "")]
    
    seen_urls = {item.get("url", "").strip() for item in valid_existing_bihar if item.get("url")}
    seen_titles = {re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', item.get("title", "").lower()) for item in valid_existing_bihar}

    new_bihar_items = []
    dropped_banned = 0
    skipped_old = 0
    failed_scrape = 0
    duplicate_count = 0

    for feed_info in BIHAR_FEEDS:
        cat_name = feed_info["category"]
        feed_url = feed_info["url"]
        print(f"\n📡 Reading Feed: {cat_name}")

        try:
            feed = feedparser.parse(feed_url)
            entries = feed.entries
            debug(f"Found {len(entries)} items in feed.")
        except Exception as e:
            warn(f"Error fetching feed: {e}")
            continue

        for entry in entries:
            raw_title = entry.get("title", "")
            raw_link = entry.get("link", "")
            feed_snippet = entry.get("summary", "") or entry.get("content", [{}])[0].get("value", "")

            c_title = clean_title(raw_title)
            clean_snippet = clean_text(feed_snippet)
            real_url = extract_real_url(raw_link)

            if not c_title or not real_url or len(c_title) < 15:
                debug(f"SKIPPED (Invalid/Empty Title or Link): {raw_title[:40]}")
                continue

            # 1. 📅 FEED LEVEL DATE CHECK
            entry_feed_dt = get_entry_datetime(entry)
            if entry_feed_dt and entry_feed_dt.date() != today_date:
                debug(f"REJECTED FEED DATE (Pub: {entry_feed_dt.strftime('%d %b %Y')}): {c_title[:45]}...")
                skipped_old += 1
                continue

            # 2. 🛑 BANNED TOPIC CHECK (TITLE & SNIPPET)
            is_banned, matched_keyword = is_unwanted_news(c_title, clean_snippet)
            if is_banned:
                warn(f"REJECTED BANNED TOPIC [Matched: '{matched_keyword}']: {c_title[:50]}...")
                dropped_banned += 1
                continue

            # 3. 🧹 DUPLICATE CHECK
            norm_title = re.sub(r'[^a-zA-Z0-9\u0900-\u097f]+', '', c_title.lower())
            if real_url in seen_urls or norm_title in seen_titles:
                debug(f"DUPLICATE SKIPPED: {c_title[:45]}...")
                duplicate_count += 1
                continue

            # 4. 🌐 WEBPAGE SCRAPING + EXACT HTML PUBLISHED DATE VERIFICATION
            content, deep_page_dt, words_found = scrape_full_webpage_content_and_date(real_url)

            if not content or words_found < MIN_WORDS_PER_ARTICLE:
                warn(f"REJECTED TOO SHORT/SCRAPE FAILED ({words_found} words < {MIN_WORDS_PER_ARTICLE}): {c_title[:45]}...")
                failed_scrape += 1
                continue

            # Verify actual article publication date from webpage source
            actual_article_dt = deep_page_dt or entry_feed_dt
            if actual_article_dt and actual_article_dt.date() != today_date:
                warn(f"REJECTED DEEP PAGE DATE (Found: {actual_article_dt.strftime('%d %b %Y')} != Today): {c_title[:45]}...")
                skipped_old += 1
                continue

            # 5. 🛑 BANNED TOPIC CHECK (FULL BODY TEXT)
            is_body_banned, body_keyword = is_unwanted_news("", content[:350])
            if is_body_banned:
                warn(f"REJECTED BANNED TOPIC IN BODY [Matched: '{body_keyword}']: {c_title[:50]}...")
                dropped_banned += 1
                continue

            seen_urls.add(real_url)
            seen_titles.add(norm_title)

            final_dt = actual_article_dt or now_ist()
            formatted_date = final_dt.strftime("%a, %d %b %Y %H:%M:%S IST")

            item = {
                "source": "Bihar Google Alert",
                "title": c_title,
                "url": real_url,
                "date": formatted_date,
                "content": content,
                "content_chars": len(content),
                "content_words": len(content.split()),
                "type": "State News"
            }

            new_bihar_items.append(item)
            success(f"ADDED TO RAWNEWS ({len(content.split())} words): {c_title[:50]}")

    print("\n" + "=" * 80)
    print("📊 EXECUTION BREAKDOWN:")
    print(f"   ✅ Successfully Scraped & Added : {len(new_bihar_items)}")
    print(f"   📅 Skipped (Old Dates)          : {skipped_old}")
    print(f"   🚫 Rejected (Banned/Editorials) : {dropped_banned}")
    print(f"   ⚠️ Rejected (Scrape Failed/<150w): {failed_scrape}")
    print(f"   🧹 Skipped (Duplicates)         : {duplicate_count}")
    print("=" * 80)

    updated_bihar_news = new_bihar_items + valid_existing_bihar
    raw_data["bihar_raw_news"] = updated_bihar_news
    raw_data["bihar_raw_count"] = len(updated_bihar_news)

    national_count = len(raw_data.get("national_raw_news", []))
    raw_data["total_raw_count"] = national_count + len(updated_bihar_news)
    raw_data["generated_at"] = now_ist().strftime("%Y-%m-%d %H:%M:%S")

    source_breakdown = raw_data.get("source_breakdown", {})
    source_breakdown["Bihar Google Alert"] = len(updated_bihar_news)
    raw_data["source_breakdown"] = source_breakdown

    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_data, f, ensure_ascii=False, indent=2)

    success(f"Updated '{TARGET_FILE}'! Today's Bihar Total: {len(updated_bihar_news)} | Grand Total: {raw_data['total_raw_count']}")


if __name__ == "__main__":
    process_and_append_bihar_alerts()
