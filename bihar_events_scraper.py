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

BIHAR_DISTRICTS = [
    "Araria", "Arwal", "Aurangabad", "Banka", "Begusarai", "Bhagalpur", "Bhojpur",
    "Buxar", "Darbhanga", "East Champaran", "West Champaran", "Gaya", "Gopalganj",
    "Jamui", "Jehanabad", "Kaimur", "Katihar", "Khagaria", "Kishanganj", "Lakhisarai",
    "Madhepura", "Madhubani", "Munger", "Muzaffarpur", "Muzzafarpur", "Nalanda",
    "Nawada", "Patna", "Purnia", "Rohtas", "Saharsa", "Samastipur", "Saran",
    "Sheikhpura", "Sheohar", "Sitamarhi", "Siwan", "Supaul", "Vaishali"
]

DISTRICT_PATTERN = "|".join([re.escape(d) for d in BIHAR_DISTRICTS])

# Strict Regex: Takes clean Title, Dates, and District
EVENT_PATTERN = re.compile(
    rf'^(.*?)\s*(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*-\s*(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*,\s*({DISTRICT_PATTERN})\s*$',
    re.IGNORECASE
)

DATE_FINDER = re.compile(
    rf'(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*-\s*(\d{{1,2}})(?:st|nd|rd|th)?\s+([A-Za-z]{{3}})\s*,\s*({DISTRICT_PATTERN})',
    re.IGNORECASE
)

def resolve_exact_year(month_num):
    """
    Bihar Tourism annual calendar rules:
    - Months 1, 2, 3 (Jan, Feb, Mar) -> 2027
    - Months 4 to 12 (Apr to Dec)    -> 2026
    March 2027 ke aage website par data hi nahi hai.
    """
    if month_num in [1, 2, 3]:
        return 2027
    else:
        return 2026

def scrape_bihar_events():
    print("=" * 80)
    print(f"🚀 SCRAPING BIHAR TOURISM EVENTS (Apr 2026 - Mar 2027)")
    print(f"🔗 Target: {TARGET_URL}")
    print("=" * 80)

    try:
        resp = requests.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        resp.raise_for_status()
    except Exception as e:
        print(f"❌ Network Error: {e}")
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # Decompose headers, navbars, footers, scripts
    for unwanted in soup(['header', 'footer', 'nav', 'script', 'style', 'noscript']):
        unwanted.decompose()

    parsed_events = []
    seen_unique_events = set()

    # Step 1: DOM Elements se direct block-level cards scan karein
    # Isse alag-alag events aapas mein merge nahi honge
    candidates = soup.find_all(['li', 'div', 'p', 'tr', 'article'])

    for tag in candidates:
        text = " ".join(tag.get_text(separator=" ").split())

        # Skip agar text bohot chhota ya bohot bada (parent page) ho
        if len(text) < 12 or len(text) > 160:
            continue

        # Check if this element matches single event pattern
        m = DATE_FINDER.search(text)
        if not m:
            continue

        # Title date se pehle wala hissa hota hai
        raw_title = text[:m.start()].strip()
        start_day = int(m.group(1))
        start_mon_str = m.group(2).lower()[:3]
        end_day = int(m.group(3))
        end_mon_str = m.group(4).lower()[:3]
        district = m.group(5).strip()

        start_mon = MONTH_MAP.get(start_mon_str)
        end_mon = MONTH_MAP.get(end_mon_str)
        if not start_mon or not end_mon:
            continue

        # Clean title
        clean_title = re.sub(r'^[,\-\s]+|[,\-\s]+$', '', raw_title).strip()

        # Rule 1: Title empty nahi hona chahiye aur usme koi district na chipka ho
        for d in BIHAR_DISTRICTS:
            clean_title = re.sub(rf'^{re.escape(d)}\s*', '', clean_title, flags=re.I).strip()

        if len(clean_title) < 4:
            continue

        # Rule 2: Dummy placeholder drop (24th Dec - 24th Dec, Jehanabad)
        if start_day == 24 and start_mon == 12 and end_day == 24 and end_mon == 12 and "jehanabad" in district.lower():
            continue

        # Rule 3: Exact Year Resolution (Jan-Mar = 2027, Apr-Dec = 2026)
        event_year = resolve_exact_year(start_mon)

        start_dt = datetime(event_year, start_mon, start_day, tzinfo=IST)
        end_dt = datetime(event_year, end_mon, end_day, tzinfo=IST)
        is_upcoming = end_dt >= NOW

        # Unique Key: title + start_date + district
        dedup_key = f"{clean_title.lower()}_{start_dt.strftime('%Y-%m-%d')}_{district.lower()}"
        if dedup_key in seen_unique_events:
            continue
        seen_unique_events.add(dedup_key)

        link_el = tag.find('a', href=True)
        link = urljoin(BASE_URL, link_el['href']) if link_el else TARGET_URL

        clean_event = {
            "title": clean_title,
            "district": district,
            "year": event_year,
            "date_range": f"{start_day} {start_mon_str.capitalize()} - {end_day} {end_mon_str.capitalize()} {event_year}",
            "start_iso": start_dt.strftime("%Y-%m-%d"),
            "end_iso": end_dt.strftime("%Y-%m-%d"),
            "is_upcoming": is_upcoming,
            "status": "Upcoming" if is_upcoming else "Completed",
            "url": link
        }

        parsed_events.append(clean_event)
        print(f"   ✅ [{event_year}] {clean_title} | {clean_event['date_range']} ({district})")

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
    print(f"💾 Clean & Verified Events Saved to: '{OUTPUT_FILE}' (Total: {len(parsed_events)})")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    scrape_bihar_events()
