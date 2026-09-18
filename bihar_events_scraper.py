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
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://tourism.bihar.gov.in/"
}

def debug_print(stage, msg):
    print(f"[{stage.upper()}] {msg}")

def check_years(text):
    if not text:
        return False
    return bool(re.search(r'\b(2026|2027)\b', str(text)))

def run_debug_scraper():
    print("=" * 80)
    print(f"🔍 STARTING DEEP DEBUG SCRAPER FOR: {TARGET_URL}")
    print("=" * 80)

    # 1. Network / HTTP Diagnostic
    try:
        session = requests.Session()
        resp = session.get(TARGET_URL, headers=HEADERS, timeout=30, verify=False)
        debug_print("network", f"Status Code: {resp.status_code}")
        debug_print("network", f"Content-Type: {resp.headers.get('content-type')}")
        debug_print("network", f"Raw HTML Length: {len(resp.text)} characters")
        
        if resp.status_code != 200:
            debug_print("error", f"Website returned non-200 response: {resp.status_code}")
            return
    except Exception as e:
        debug_print("network_error", str(e))
        return

    soup = BeautifulSoup(resp.text, "html.parser")

    # 2. Check for Framework Hydration Data (__NEXT_DATA__ or window.__INITIAL_STATE__)
    all_events = []
    
    scripts = soup.find_all("script")
    debug_print("dom", f"Total <script> tags found: {len(scripts)}")

    # Check Next.js
    next_script = soup.find("script", id="__NEXT_DATA__")
    if next_script:
        debug_print("hydration", "Found Next.js __NEXT_DATA__ block! Extracting...")
        try:
            data = json.loads(next_script.string)
            raw_dump = json.dumps(data)
            debug_print("hydration", f"Next.js data size: {len(raw_dump)} chars")
            
            # Auto-search for array of events inside JSON
            def find_event_arrays(obj):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if any(token in k.lower() for token in ["event", "festival", "fair", "calendar"]) and isinstance(v, list):
                            return v
                        res = find_event_arrays(v)
                        if res:
                            return res
                elif isinstance(obj, list):
                    for elem in obj:
                        res = find_event_arrays(elem)
                        if res:
                            return res
                return None

            detected_list = find_event_arrays(data)
            if detected_list:
                debug_print("hydration", f"Extracted {len(detected_list)} items from framework state.")
                for itm in detected_list:
                    if isinstance(itm, dict):
                        all_events.append({
                            "title": itm.get("title") or itm.get("name") or itm.get("heading") or "Event",
                            "date": str(itm.get("date") or itm.get("startDate") or itm.get("eventDate") or ""),
                            "location": str(itm.get("location") or itm.get("venue") or itm.get("place") or "Bihar"),
                            "description": str(itm.get("description") or itm.get("shortDescription") or ""),
                            "url": urljoin(BASE_URL, str(itm.get("url") or itm.get("slug") or ""))
                        })
        except Exception as err:
            debug_print("hydration_error", f"Could not extract Next.js JSON: {err}")
    else:
        debug_print("hydration", "No __NEXT_DATA__ tag found. Analyzing raw scripts...")

    # 3. Check for inline JSON objects inside <script>
    if not all_events:
        for idx, s in enumerate(scripts):
            content = s.string or ""
            if any(term in content for term in ["events", "eventList", "calendarData", "festivals"]):
                debug_print("script_inspect", f"Script #{idx} contains event keywords! Searching JSON matches...")
                matches = re.findall(r'(\[\s*\{.*?\}\s*\])', content, re.DOTALL)
                for m in matches:
                    try:
                        parsed = json.loads(m)
                        if isinstance(parsed, list) and len(parsed) > 0 and isinstance(parsed[0], dict):
                            debug_print("script_inspect", f"Found valid JSON list with {len(parsed)} items in script #{idx}")
                            for item in parsed:
                                all_events.append({
                                    "title": item.get("title") or item.get("name") or "Event",
                                    "date": str(item.get("date") or item.get("startDate") or ""),
                                    "location": str(item.get("location") or item.get("venue") or "Bihar"),
                                    "description": str(item.get("description") or ""),
                                    "url": TARGET_URL
                                })
                    except Exception:
                        pass

    # 4. Fallback: Parse Direct HTML DOM Nodes
    if not all_events:
        debug_print("dom_fallback", "Attempting DOM card parsing...")
        
        # Log all anchor tags with /events/ in URL
        event_links = soup.find_all('a', href=re.compile(r'/event', re.I))
        debug_print("dom_links", f"Found {len(event_links)} anchor links containing '/event' in href.")
        
        # Common Card Containers
        cards = soup.find_all(['div', 'article', 'section', 'li'], class_=re.compile(r'(card|event|item|post|festival)', re.I))
        debug_print("dom_cards", f"Found {len(cards)} elements matching card class patterns.")

        for c in cards:
            title_el = c.find(['h2', 'h3', 'h4', 'h5', 'strong'])
            if not title_el:
                continue
            title = title_el.get_text(strip=True)
            if len(title) < 4:
                continue
            
            raw_text = c.get_text(separator=" ", strip=True)
            link_el = c.find('a', href=True)
            url = urljoin(BASE_URL, link_el['href']) if link_el else TARGET_URL

            all_events.append({
                "title": title,
                "date": raw_text, # Will be filtered later
                "location": "Bihar",
                "description": raw_text[:250],
                "url": url
            })

    # 5. Diagnostic Summary of Found Data
    print("\n" + "-" * 80)
    debug_print("analysis", f"Total Raw Events Detected on Page: {len(all_events)}")
    
    if all_events:
        print("\n🔍 SAMPLE RAW ITEMS EXTRACTED (First 3):")
        for i, ev in enumerate(all_events[:3], 1):
            print(f"   {i}. Title: {ev.get('title')}")
            print(f"      Date Text: {ev.get('date')[:60]}")
    else:
        debug_print("root_cause", "Page does not contain static events HTML or inline JSON.")
        debug_print("root_cause", "The portal likely loads data dynamically via an API endpoint after page mount.")
        
        # Search for potential API endpoints mentioned in JavaScript
        api_matches = set(re.findall(r'["\'](/api/[^"\']+)["\']', resp.text))
        if api_matches:
            print("\n📡 DETECTED API ROUTES IN PAGE SOURCE:")
            for api in api_matches:
                print(f"   • {urljoin(BASE_URL, api)}")
        return

    # 6. Apply Year Filtering (2026 / 2027)
    target_filtered = []
    for ev in all_events:
        combined = f"{ev.get('title', '')} {ev.get('date', '')} {ev.get('description', '')}"
        if check_years(combined):
            target_filtered.append(ev)

    print("-" * 80)
    debug_print("filter", f"Events explicitly matching 2026/2027: {len(target_filtered)}")

    # Decision Output
    final_save_list = target_filtered if target_filtered else all_events
    
    if not target_filtered:
        debug_print("notice", "0 events matched years 2026/2027 directly.")
        debug_print("notice", f"Saving all {len(all_events)} detected active portal events so no data is lost.")

    output_payload = {
        "source": TARGET_URL,
        "scraped_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_scanned": len(all_events),
        "target_years_matched": len(target_filtered),
        "events": final_save_list
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output_payload, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    debug_print("saved", f"Output written to '{OUTPUT_FILE}' ({len(final_save_list)} items).")
    print("=" * 80)

if __name__ == "__main__":
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    run_debug_scraper()
