import requests
from bs4 import BeautifulSoup
import json
import re
from urllib.parse import urljoin
from datetime import datetime, timezone, timedelta

# ============================================================
# CONFIGURATION
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

# Master Regex: Extracts individual event blocks cleanly even if merged
# Group 1: Title
# Group 2: Start Day
# Group 3: Start Month
# Group 4: End Day
# Group 5: End Month
# Group 6: District / Venue
EVENT_REGEX = re.compile(
    r'([A-Za-z0-9\s\.\'\-]{3,70}?)\s+'
    r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})\s*-\s*'
    r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3})\s*,\s*'
    r'([A-Za-z\s]{3,30})',
    re.IGNORECASE
)

# Known Navigation / Site Header words to drop
JUNK_TITLES = [
    "department", "travel", "important links", "contacts", "circuits",
    "destinations", "districts", "maps", "touch", "see", "taste",
    "stories from bihar", "events calender", "contest", "video gallery",
    "about us", "news", "downloads", "critical contacts", "tourism policy",
    "schemes", "view all schemes", "there are no upcoming events"
]

def is_unwanted(title, district):
    t_low = title.lower().strip()
    d_low = district.lower().strip()
    
    # 1. Drop dummy template item
    if "jehanabad" in d_low and "24th dec" in t_low:
        return True
    if t_low.startswith("24th dec") or t_low.endswith("24th dec"):
        return True

    # 2. Drop standard menus
    if any(junk in t_low for junk in JUNK_TITLES):
        return True
        
    return False

def scrape_bihar_events():
    print("=" * 80)
    print(f"🚀 SCRAPING ALL VALID EVENTS FROM BIHAR TOURISM")
    print(f"🔗 URL: {TARGET_URL}")
    print("=" * 80)

    try:
        resp = requests.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ HTTP Error: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # Header, footer aur script ko drop karein
    for tag in soup(['header', 'footer', 'nav', 'script', 'style', 'noscript']):
        tag.decompose()

    # Poore page ka clean linear text nikaal lein
    full_text = " ".join(soup.get_text(separator=" ").split())
    
    parsed_events = []
    seen_dedup = set()

    # Step-by-step regex scan
    matches = EVENT_REGEX.finditer(full_text)

    for m in matches:
        raw_title = m.group(1).strip()
        start_day = int(m.group(2))
        start_mon_str = m.group(3).lower()[:3]
        end_day = int(m.group(4))
        end_mon_str = m.group(5).lower()[:3]
        raw_district = m.group(6).strip()

        start_mon = MONTH_MAP.get(start_mon_str)
        end_mon = MONTH_MAP.get(end_mon_str)

        if not start_mon or not end_mon:
            continue

        # Clean title: agar pichle event ka district iske title ke aage jud gaya ho to hatao
        clean_title = re.sub(r'^[A-Za-z\s]+,\s*', '', raw_title).strip()
        clean_district = raw_district.strip()

        # Check junk / dummy
        if is_unwanted(clean_title, clean_district):
            continue

        # Dummy placeholder drop (24 Dec - 24 Dec Jehanabad)
        if start_day == 24 and start_mon == 12 and end_day == 24 and end_mon == 12 and "jehanabad" in clean_district.lower():
            continue

        # Year Resolution (Rolling Calendar: 2026 or 2027)
        if start_mon < NOW.month:
            event_year = NOW.year + 1  # 2027
        else:
            event_year = NOW.year      # 2026

        start_dt = datetime(event_year, start_mon, start_day, tzinfo=IST)
        end_dt = datetime(event_year, end_mon, end_day, tzinfo=IST)
        is_upcoming = end_dt >= NOW

        dedup_key = f"{clean_title.lower()}_{start_dt.strftime('%Y-%m-%d')}"
        if dedup_key in seen_dedup:
            continue
        seen_dedup.add(dedup_key)

        clean_item = {
            "title": clean_title,
            "district": clean_district,
            "year": event_year,
            "date_range": f"{start_day} {start_mon_str.capitalize()} - {end_day} {end_mon_str.capitalize()} {event_year}",
            "start_iso": start_dt.strftime("%Y-%m-%d"),
            "end_iso": end_dt.strftime("%Y-%m-%d"),
            "is_upcoming": is_upcoming,
            "status": "Upcoming" if is_upcoming else "Completed",
            "url": TARGET_URL
        }

        parsed_events.append(clean_item)
        print(f"   ✅ Found: {clean_title} | {clean_item['date_range']} ({clean_district})")

    # Chronological sort
    parsed_events.sort(key=lambda x: x['start_iso'])

    output_data = {
        "source": TARGET_URL,
        "scraped_at": NOW.strftime("%Y-%m-%d %H:%M:%S"),
        "total_events": len(parsed_events),
        "events": parsed_events
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 Saved {len(parsed_events)} events to '{OUTPUT_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_bihar_events()
