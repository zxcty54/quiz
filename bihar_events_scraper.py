import requests
from bs4 import BeautifulSoup
import json
import re
from urllib.parse import urljoin
from datetime import datetime, timezone, timedelta

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

# 1. Navigation Menu Blacklist (Menu aur Footer ko drop karne ke liye)
NAVIGATION_JUNK = [
    "circuit", "destination", "district", "map", "touch", "see", "taste",
    "stories from bihar", "events calender", "contest", "video gallery",
    "about us", "news", "download", "contact", "tourism policy", "scheme",
    "department", "travel", "important links", "there are no upcoming events",
    "tender", "hotel", "gallery", "terms", "privacy"
]

def is_junk(text):
    t = text.lower().strip()
    return any(j in t for j in NAVIGATION_JUNK)

# 2. Main Regex: Matches "<Title> <Date-Range>, <District>"
# Example: "Mandar Mahotsav 14th Jan - 18th Jan, Banka"
EVENT_PATTERN = re.compile(
    r'^(.*?)\s*(\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3}\s*-\s*\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3})\s*,\s*([A-Za-z\s]+)$',
    re.IGNORECASE
)

DATE_PARSER = re.compile(
    r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})\s*-\s*(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})',
    re.IGNORECASE
)

def parse_event_string(raw_text, link):
    text = " ".join(raw_text.split()).strip()
    
    if is_junk(text):
        return None

    # Try full match: Title + Date + District
    match = EVENT_PATTERN.match(text)
    
    if match:
        raw_title = match.group(1).strip()
        raw_date = match.group(2).strip()
        district = match.group(3).strip()
    else:
        # Fallback: Agar district comma ke sath end me ho
        loc_match = re.search(r',\s*([A-Za-z\s]+)$', text)
        if not loc_match:
            return None
        district = loc_match.group(1).strip()

        date_m = DATE_PARSER.search(text)
        if not date_m:
            return None
        raw_date = date_m.group(0).strip()
        raw_title = text[:date_m.start()].strip()

    # Agar title empty reh jaye
    if not raw_title or len(raw_title) < 3:
        raw_title = f"{district} Mahotsav"

    # Date Breakdown
    d_match = DATE_PARSER.search(raw_date)
    if not d_match:
        return None

    start_day = int(d_match.group(1))
    start_mon_str = d_match.group(2).lower()[:3]
    start_mon = MONTH_MAP.get(start_mon_str)

    end_day = int(d_match.group(3))
    end_mon_str = d_match.group(4).lower()[:3]
    end_mon = MONTH_MAP.get(end_mon_str)

    if not start_mon or not end_mon:
        return None

    # Rolling Year Logic:
    # Agar event ka month current month (September) se nikal chuka hai -> 2027
    # Agar event aage aane wala hai (October, November, December) -> 2026
    if start_mon < NOW.month:
        event_year = NOW.year + 1  # 2027
    else:
        event_year = NOW.year      # 2026

    start_dt = datetime(event_year, start_mon, start_day, tzinfo=IST)
    end_dt = datetime(event_year, end_mon, end_day, tzinfo=IST)
    is_upcoming = end_dt >= NOW

    return {
        "title": raw_title,
        "district": district,
        "year": event_year,
        "date_range": f"{start_day} {start_mon_str.capitalize()} - {end_day} {end_mon_str.capitalize()} {event_year}",
        "start_iso": start_dt.strftime("%Y-%m-%d"),
        "end_iso": end_dt.strftime("%Y-%m-%d"),
        "is_upcoming": is_upcoming,
        "status": "Upcoming" if is_upcoming else "Completed",
        "url": link
    }

def scrape_bihar_events():
    print("=" * 80)
    print(f"🚀 SCRAPING & CLEANING BIHAR TOURISM EVENTS")
    print(f"🔗 Source: {TARGET_URL}")
    print("=" * 80)

    try:
        resp = requests.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ Network Error: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # Header, footer, scripts hata dein
    for unwanted in soup(['header', 'footer', 'nav', 'script', 'style']):
        unwanted.decompose()

    parsed_events = []
    seen_keys = set()

    # Har text node aur card check karein
    elements = soup.find_all(['div', 'p', 'li', 'article', 'tr'])

    for el in elements:
        text = el.get_text(separator=" ", strip=True)
        
        # Sirf wahi lines uthao jisme month aur hyphen ho
        if not re.search(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*-\s*\d{1,2}', text, re.I):
            continue

        link_el = el.find('a', href=True)
        link = urljoin(BASE_URL, link_el['href']) if link_el else TARGET_URL

        event = parse_event_string(text, link)
        if event:
            dedup_key = f"{event['title'].lower()}_{event['start_iso']}"
            if dedup_key not in seen_keys:
                seen_keys.add(dedup_key)
                parsed_events.append(event)
                print(f"   ✅ Cleaned: {event['title']} | {event['date_range']} | {event['district']}")

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
    print(f"💾 Total {len(parsed_events)} Clean Events Saved to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_bihar_events()
