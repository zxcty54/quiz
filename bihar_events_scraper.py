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

# Bihar ke 38 Districts (Boundary separation ke liye)
BIHAR_DISTRICTS = [
    "Araria", "Arwal", "Aurangabad", "Banka", "Begusarai", "Bhagalpur", "Bhojpur",
    "Buxar", "Darbhanga", "East Champaran", "West Champaran", "Gaya", "Gopalganj",
    "Jamui", "Jehanabad", "Kaimur", "Katihar", "Khagaria", "Kishanganj", "Lakhisarai",
    "Madhepura", "Madhubani", "Munger", "Muzaffarpur", "Muzzafarpur", "Nalanda",
    "Nawada", "Patna", "Purnia", "Rohtas", "Saharsa", "Samastipur", "Saran",
    "Sheikhpura", "Sheohar", "Sitamarhi", "Siwan", "Supaul", "Vaishali"
]

DISTRICT_REGEX_PART = "|".join([re.escape(d) for d in BIHAR_DISTRICTS])

# Strict Regex:
# Group 1: Title (starts after previous district, stops at date)
# Group 2: Start Day
# Group 3: Start Month
# Group 4: End Day
# Group 5: End Month
# Group 6: Exact District Name from Bihar List
EVENT_REGEX = re.compile(
    rf'([A-Za-z0-9\s\.\'\-]{{3,80}}?)\s+'
    rf'(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*-\s*'
    rf'(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*,\s*'
    rf'({DISTRICT_REGEX_PART})\b',
    re.IGNORECASE
)

# Filter words (navigation & headers)
JUNK_WORDS = [
    "circuit", "destination", "district", "touch", "see", "taste",
    "stories from bihar", "events calender", "contest", "about us",
    "news", "downloads", "policy", "schemes", "upcoming events"
]

def clean_event_title(raw_title):
    t = raw_title.strip()
    # Agar title ke aage pichle event ka district chipka ho, toh strip karein
    for dist in BIHAR_DISTRICTS:
        pattern = rf'^{re.escape(dist)}\s*'
        t = re.sub(pattern, '', t, flags=re.I).strip()
    return t

def scrape_bihar_events():
    print("=" * 80)
    print(f"🚀 SCRAPING ACCURATE BIHAR EVENTS (DISTRICT-BOUNDED)")
    print(f"🔗 Target: {TARGET_URL}")
    print("=" * 80)

    try:
        resp = requests.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ Network Error: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # Header, footer, scripts decompose karein
    for tag in soup(['header', 'footer', 'nav', 'script', 'style', 'noscript']):
        tag.decompose()

    full_text = " ".join(soup.get_text(separator=" ").split())

    parsed_events = []
    seen_keys = set()

    for m in EVENT_REGEX.finditer(full_text):
        raw_title = m.group(1).strip()
        start_day = int(m.group(2))
        start_mon_str = m.group(3).lower()[:3]
        end_day = int(m.group(4))
        end_mon_str = m.group(5).lower()[:3]
        district = m.group(6).strip()

        start_mon = MONTH_MAP.get(start_mon_str)
        end_mon = MONTH_MAP.get(end_mon_str)
        if not start_mon or not end_mon:
            continue

        clean_title = clean_event_title(raw_title)

        # Basic validations
        if len(clean_title) < 3 or any(junk in clean_title.lower() for junk in JUNK_WORDS):
            continue

        # Reject dummy template: "24th Dec - 24th Dec, Jehanabad"
        if start_day == 24 and start_mon == 12 and end_day == 24 and end_mon == 12 and "jehanabad" in district.lower():
            continue

        # Rolling Year Assignment (2026 vs 2027)
        if start_mon < NOW.month:
            event_year = NOW.year + 1  # 2027
        else:
            event_year = NOW.year      # 2026

        start_dt = datetime(event_year, start_mon, start_day, tzinfo=IST)
        end_dt = datetime(event_year, end_mon, end_day, tzinfo=IST)
        is_upcoming = end_dt >= NOW

        dedup_key = f"{clean_title.lower()}_{start_dt.strftime('%Y-%m-%d')}"
        if dedup_key in seen_keys:
            continue
        seen_keys.add(dedup_key)

        clean_item = {
            "title": clean_title,
            "district": district,
            "year": event_year,
            "date_range": f"{start_day} {start_mon_str.capitalize()} - {end_day} {end_mon_str.capitalize()} {event_year}",
            "start_iso": start_dt.strftime("%Y-%m-%d"),
            "end_iso": end_dt.strftime("%Y-%m-%d"),
            "is_upcoming": is_upcoming,
            "status": "Upcoming" if is_upcoming else "Completed",
            "url": TARGET_URL
        }

        parsed_events.append(clean_item)
        print(f"   ✅ [Clean]: {clean_title} | {clean_item['date_range']} | District: {district}")

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
    print(f"💾 Clean Output Saved: '{OUTPUT_FILE}' (Total: {len(parsed_events)} events)")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_bihar_events()
