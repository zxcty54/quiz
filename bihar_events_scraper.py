import requests
from bs4 import BeautifulSoup
import json
import re
from urllib.parse import urljoin
from datetime import datetime

TARGET_URL = "https://tourism.bihar.gov.in/en/events"
BASE_URL = "https://tourism.bihar.gov.in"
OUTPUT_FILE = "bihar_events_2026_2027.json"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
}

def is_target_year(text):
    """Check karta hai ki text me 2026 ya 2027 mention hai ya nahi."""
    if not text:
        return False
    return bool(re.search(r'\b(2026|2027)\b', text))

def extract_events_from_next_data(soup):
    """
    Agar website Next.js/React framework par bani ho, 
    to __NEXT_DATA__ JSON script tag se direct clean data extract karta hai.
    """
    next_data_script = soup.find("script", id="__NEXT_DATA__")
    events = []
    if not next_data_script:
        return events

    try:
        raw_json = json.loads(next_data_script.string)
        page_props = raw_json.get("props", {}).get("pageProps", {})
        
        # Possible keys jisme events list hoti hai
        candidate_lists = []
        for key in ["events", "eventList", "data", "initialData"]:
            val = page_props.get(key)
            if isinstance(val, list):
                candidate_lists.append(val)

        for lst in candidate_lists:
            for item in lst:
                if isinstance(item, dict):
                    # Combine all string values to check year
                    full_str = " ".join([str(v) for v in item.values()])
                    if is_target_year(full_str):
                        events.append({
                            "title": item.get("title") or item.get("name") or "Event",
                            "date": item.get("date") or item.get("startDate") or "",
                            "end_date": item.get("endDate") or "",
                            "location": item.get("location") or item.get("venue") or "Bihar",
                            "description": item.get("description") or item.get("details") or "",
                            "link": urljoin(BASE_URL, item.get("url") or item.get("slug") or "")
                        })
    except Exception as e:
        print(f"⚠️ Warning: Could not parse __NEXT_DATA__: {e}")

    return events

def extract_events_from_html(soup):
    """
    Standard HTML cards, blocks aur lists se events parse karta hai.
    """
    events = []
    
    # Common container selectors jo tourism portals use karte hain
    event_containers = soup.find_all(
        ['div', 'article', 'li'], 
        class_=re.compile(r'(event|festival|card|calendar)', re.I)
    )

    seen_titles = set()

    for container in event_containers:
        text_content = container.get_text(separator=" ", strip=True)
        
        # Sirf wahi cards filter karo jisme 2026 ya 2027 hai
        if not is_target_year(text_content):
            continue

        # Title extraction
        title_el = container.find(['h2', 'h3', 'h4', 'h5', 'strong', 'a'])
        title = title_el.get_text(strip=True) if title_el else ""
        if not title or len(title) < 3:
            continue

        if title.lower() in seen_titles:
            continue

        # Link extraction
        link_el = container.find('a', href=True)
        link = urljoin(BASE_URL, link_el['href']) if link_el else TARGET_URL

        # Date extraction via regex
        date_match = re.search(
            r'(\b\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s,-]+\b(2026|2027)\b)|(\b(2026|2027)[-/.]\d{1,2}[-/.]\d{1,2}\b)', 
            text_content, 
            re.I
        )
        date_str = date_match.group(0) if date_match else "2026/2027 (See description)"

        # Location extraction (common markers)
        loc_match = re.search(r'(?:Location|Venue|District|Place)\s*[:\-]\s*([A-Za-z\s,]+)', text_content, re.I)
        location = loc_match.group(1).strip() if loc_match else "Bihar"

        # Description / Summary
        desc_el = container.find(['p', 'span'])
        desc = desc_el.get_text(strip=True) if desc_el else text_content[:200]

        events.append({
            "title": title,
            "date": date_str,
            "location": location,
            "description": desc,
            "url": link
        })
        seen_titles.add(title.lower())

    return events

def scrape_bihar_tourism_events():
    print(f"🌐 Fetching URL: {TARGET_URL}")
    try:
        response = requests.get(TARGET_URL, headers=HEADERS, timeout=25, verify=False)
        response.raise_for_status()
    except requests.RequestException as e:
        print(f"❌ Network / HTTP Error: {e}")
        return

    soup = BeautifulSoup(response.text, "html.parser")

    # Step 1: Check if Next.js hydration payload exists
    events = extract_events_from_next_data(soup)

    # Step 2: Fallback to DOM elements if empty
    if not events:
        events = extract_events_from_html(soup)

    print(f"✅ Filtered {len(events)} events for years 2026 & 2027.")

    # Save to JSON
    output_payload = {
        "source": TARGET_URL,
        "scraped_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "filter_years": [2026, 2027],
        "total_events": len(events),
        "events": events
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print(f"💾 File successfully saved to: '{OUTPUT_FILE}'")

if __name__ == "__main__":
    # Disable InsecureRequestWarning agar portal ka SSL intermediate certificate missing ho
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    scrape_bihar_tourism_events()
