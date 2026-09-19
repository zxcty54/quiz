import requests
from bs4 import BeautifulSoup
import json
import re
from urllib.parse import urljoin
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION & CONSTANTS
# ============================================================

TARGET_URL = "https://tourism.bihar.gov.in/en/events"
BASE_URL = "https://tourism.bihar.gov.in"
OUTPUT_FILE = "bihar_events_2026_2027.json"

IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://tourism.bihar.gov.in/"
}

MONTH_MAP = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12
}

GENUINE_EVENT_KEYWORDS = [
    "mahotsav", "mela", "festival", "utsav", "fair", "jayanti", "diwas", "samaroh"
]

NAVIGATION_JUNK = [
    "circuit", "destination", "district", "map", "touch", "see", "taste",
    "stories from bihar", "events calender", "contest", "video gallery",
    "about us", "news", "download", "contact", "tourism policy", "scheme",
    "department", "travel", "important links", "there are no upcoming events",
    "tender", "hotel", "gallery", "terms", "privacy", "feedback"
]

# Date detector pattern
DATE_DETECTOR = re.compile(
    r'\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3}\s*-\s*\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3}',
    re.IGNORECASE
)

# Atomic event regex pattern
EVENT_ATOMIC_PATTERN = re.compile(
    r'([A-Za-z0-9\s\'\.\(\)]+?(?:' + '|'.join(GENUINE_EVENT_KEYWORDS) + r')[A-Za-z0-9\s\'\.\(\)]*?)\s+'
    r'(\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3}\s*-\s*\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3})\s*,\s*'
    r'([A-Za-z\s]+)',
    re.IGNORECASE
)

def parse_date_components(date_str):
    m = re.search(
        r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})\s*-\s*(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})',
        date_str,
        re.I
    )
    if not m:
        return None
    
    start_d, start_m_str, end_d, end_m_str = int(m.group(1)), m.group(2).lower()[:3], int(m.group(3)), m.group(4).lower()[:3]
    start_m = MONTH_MAP.get(start_m_str)
    end_m = MONTH_MAP.get(end_m_str)
    
    if not start_m or not end_m:
        return None
        
    return start_d, start_m, start_m_str, end_d, end_m, end_m_str

def scrape_bihar_events():
    print("=" * 80)
    print(f"🚀 SCRAPING ATOMIC BIHAR TOURISM EVENTS (2026-2027)")
    print(f"🔗 Target: {TARGET_URL}")
    print("=" * 80)

    try:
        resp = requests.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ Network Error: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # Remove irrelevant structural sections
    for unwanted in soup(['header', 'footer', 'nav', 'script', 'style', 'noscript']):
        unwanted.decompose()

    parsed_events = []
    seen_dedup_keys = set()

    # Step 1: Find leaf text blocks
    for element in soup.find_all(['li', 'div', 'p', 'article', 'tr']):
        # Ignore if it has block children (prevents parent-container concatenation)
        if element.find(['li', 'div', 'p', 'article']):
            continue

        raw_text = " ".join(element.get_text(separator=" ", strip=True).split())
        
        # Quick skip for short or junk text
        if len(raw_text) < 15 or any(j in raw_text.lower() for j in NAVIGATION_JUNK):
            continue

        # 🛑 RULE 1: Agar ek hi tag ke andar MULTIPLE dates hain, to yeh parent container hai, discard karo!
        date_matches = DATE_DETECTOR.findall(raw_text)
        if len(date_matches) != 1:
            continue

        # 🛑 RULE 2: Atomic Regex extraction
        atomic_match = EVENT_ATOMIC_PATTERN.search(raw_text)
        if not atomic_match:
            continue

        clean_title = atomic_match.group(1).strip()
        raw_date = atomic_match.group(2).strip()
        raw_district = atomic_match.group(3).strip()

        # Clean district (remove trailing noise)
        clean_district = re.split(r'[\r\n\t\|]', raw_district)[0].strip()

        # Reject dummy placeholder
        if "24th dec - 24th dec" in raw_date.lower() and "jehanabad" in clean_district.lower():
            continue

        # Parse date parts
        date_parts = parse_date_components(raw_date)
        if not date_parts:
            continue

        start_day, start_mon, start_mon_str, end_day, end_mon, end_mon_str = date_parts

        # Rolling Year Assignment (2026 / 2027)
        if start_mon < NOW.month:
            event_year = NOW.year + 1  # 2027
        else:
            event_year = NOW.year      # 2026

        start_dt = datetime(event_year, start_mon, start_day, tzinfo=IST)
        end_dt = datetime(event_year, end_mon, end_day, tzinfo=IST)
        is_upcoming = end_dt >= NOW

        dedup_key = f"{clean_title.lower()}_{start_dt.strftime('%Y-%m-%d')}"
        if dedup_key in seen_dedup_keys:
            continue
        seen_dedup_keys.add(dedup_key)

        link_el = element.find('a', href=True)
        link = urljoin(BASE_URL, link_el['href']) if link_el else TARGET_URL

        clean_event = {
            "title": clean_title,
            "district": clean_district,
            "year": event_year,
            "date_range": f"{start_day} {start_mon_str.capitalize()} - {end_day} {end_mon_str.capitalize()} {event_year}",
            "start_iso": start_dt.strftime("%Y-%m-%d"),
            "end_iso": end_dt.strftime("%Y-%m-%d"),
            "is_upcoming": is_upcoming,
            "status": "Upcoming" if is_upcoming else "Completed",
            "url": link
        }

        parsed_events.append(clean_event)
        print(f"   ✅ [Atomic Event]: {clean_title} | {clean_event['date_range']} ({clean_district})")

    # Chronological sort
    parsed_events.sort(key=lambda x: x['start_iso'])

    output_payload = {
        "source": TARGET_URL,
        "scraped_at": NOW.strftime("%Y-%m-%d %H:%M:%S"),
        "total_events": len(parsed_events),
        "events": parsed_events
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 File Saved: '{OUTPUT_FILE}' | Pure Events Count: {len(parsed_events)}")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_bihar_events()
