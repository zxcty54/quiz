

import os
import json
import re
import time
import html  # Unescape karne ke liye zaroori hai
import urllib3
import feedparser
from datetime import datetime, timezone, timedelta
from curl_cffi import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse, parse_qs

# Suppress SSL warnings in console
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# -------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------
PIB_RSS_URL = "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"
OUTPUT_FILE = "rawnews.json"
IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
}

def clean_text(text):
    if not text:
        return ""
    # HTML entities clean karein
    text = html.unescape(text)
    soup = BeautifulSoup(text, "html.parser")
    # Non-content elements hatao
    for tag in soup(["script", "style", "blockquote", "iframe"]):
        tag.decompose()
    clean_text = soup.get_text(" ", strip=True)
    return " ".join(clean_text.split()).strip()

def convert_pib_url(url):
    """RSS Iframe URL ko Full Article Page URL mein convert karta hai"""
    if not url:
        return ""
    parsed = urlparse(url)
    if "PressReleaseIframePage.aspx" in parsed.path or "PressReleasePage.aspx" in parsed.path:
        qs = parse_qs(parsed.query)
        prid = qs.get("PRID", [""])[0] or qs.get("prid", [""])[0]
        if prid:
            return f"https://www.pib.gov.in/PressReleasePage.aspx?PRID={prid}"
    return url

def fetch_pib_full_article(article_url):
    """Press Release Page se targeted body text extract karta hai"""
    try:
        res = requests.get(article_url, headers=HEADERS, timeout=15, impersonate="chrome", verify=False)
        if res.status_code == 200:
            soup = BeautifulSoup(res.content, "html.parser")
            
            # --- METHOD 1: Sabse Best & Clean (Hidden Field) ---
            hidden_input = soup.find("input", id="ltrDescriptionn")
            if hidden_input and hidden_input.get("value"):
                raw_escaped_html = hidden_input.get("value")
                clean_content = clean_text(raw_escaped_html)
                
                # Check for garbage endings and clean them
                clean_content = re.sub(r'\s*\*{3,}.*$', '', clean_content)  # Remove **** markings
                if len(clean_content) > 150:
                    return clean_content[:15000]

            # --- METHOD 2: Modern Class Container ---
            main_div = soup.find("div", class_="innner-page-main-about-us-content-right-part")
            if main_div:
                # Language strip line delete karein
                for lang_div in main_div.find_all("div", class_="ReleaseLang"):
                    lang_div.decompose()
                
                txt = clean_text(main_div.get_text(" ", strip=True))
                # Remove release metadata (like Release ID, Visitor Counter)
                txt = re.sub(r'\(Release ID:\s*\d+\).*$', '', txt, flags=re.I)
                txt = re.sub(r'इस विज्ञप्ति को इन भाषाओं में पढ़ें.*$', '', txt, flags=re.I)
                txt = re.sub(r'Read this release in.*$', '', txt, flags=re.I)
                
                if len(txt) > 150:
                    return txt[:15000]

            # --- METHOD 3: Fallback (Paragraphs but with clean validation) ---
            paragraphs = soup.find_all("p")
            clean_paragraphs = []
            for p in paragraphs:
                txt = clean_text(p.text)
                # Filter out garbage lines
                if len(txt) > 35 and not any(junk in txt.lower() for junk in ["copyright", "pib Delhi", "posted on", "visitor counter", "release id"]):
                    clean_paragraphs.append(txt)
            
            all_text = " ".join(clean_paragraphs)
            if len(all_text) > 150:
                return all_text[:15000]

    except Exception as e:
        print(f"⚠️ Failed to fetch full PIB article from {article_url}: {e}")
        
    return ""

def process_pib_rss():
    print(f"📡 Fetching PIB RSS Feed: {PIB_RSS_URL}")
    
    try:
        res = requests.get(PIB_RSS_URL, headers=HEADERS, timeout=20, impersonate="chrome", verify=False)
        if res.status_code != 200:
            print(f"❌ Failed to fetch RSS Feed. HTTP Status: {res.status_code}")
            return
    except Exception as e:
        print(f"❌ Network Error: {e}")
        return

    parsed = feedparser.parse(res.content)
    entries = parsed.entries or []
    print(f"🔍 Found {len(entries)} items in PIB RSS Feed.")

    pib_items = []

    for entry in entries:
        title = clean_text(entry.get("title", ""))
        rss_link = entry.get("link", "").strip()
        pub_date = entry.get("published", "") or entry.get("pubDate", "")

        if not title or not rss_link:
            continue

        full_url = convert_pib_url(rss_link)
        print(f"➡️ Processing: {title[:70]}...")

        # Scraping full body
        full_content = fetch_pib_full_article(full_url)
        
        # Validation
        if not full_content or len(full_content) < 150:
            print(f"⚠️ Skipped (No valid body content scraped): {title[:60]}")
            continue

        pib_items.append({
            "source": "PIB Central",
            "title": title,
            "url": full_url,
            "date": pub_date,
            "content": full_content,
            "content_chars": len(full_content),
            "type": "PIB Cabinet Release"
        })
        time.sleep(0.5) # Gentle rate limiting

    # -------------------------------------------------------------
    # Save or Append to rawnews.json
    # -------------------------------------------------------------
    raw_data = {"national_raw_news": [], "bihar_raw_news": []}
    
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                raw_data = json.load(f)
        except Exception:
            print(f"⚠️ Could not read existing {OUTPUT_FILE}, creating new structure.")

    # Deduplication check using unique URL
    existing_urls = {item.get("url") for item in raw_data.get("national_raw_news", [])}
    added_count = 0

    for item in pib_items:
        if item["url"] not in existing_urls:
            raw_data.setdefault("national_raw_news", []).insert(0, item) # Newest first
            existing_urls.add(item["url"])
            added_count += 1

    # Update metadata counts
    raw_data["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")
    raw_data["national_raw_count"] = len(raw_data.get("national_raw_news", []))
    raw_data["bihar_raw_count"] = len(raw_data.get("bihar_raw_news", []))
    raw_data["total_news"] = raw_data["national_raw_count"] + raw_data["bihar_raw_count"]

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(raw_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Finished! Added {added_count} new PIB releases to '{OUTPUT_FILE}'.")
    print(f"📦 Total National News in JSON: {raw_data['national_raw_count']}")

if __name__ == "__main__":
    process_pib_rss()


