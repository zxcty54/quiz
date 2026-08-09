
import os
import re
import json
import time
import html
import feedparser
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse, parse_qs

from curl_cffi import requests
from bs4 import BeautifulSoup

# -------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------
PIB_RSS_URL = "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3"
OUTPUT_FILE = "rawnews.json"

IST = timezone(timedelta(hours=5, minutes=30))

MAX_ITEMS = 40              # ek run me max releases
MAX_AGE_HOURS = 48          # 0 kar do to filter off
MIN_CONTENT_CHARS = 250
REQUEST_DELAY = 0.6
PRUNE_DAYS = 7              # JSON me itne din se purani news hata do

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
}


# -------------------------------------------------------------
# HELPERS
# -------------------------------------------------------------
def clean_text(text):
    if not text:
        return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", "")
    return re.sub(r"\s+", " ", text).strip()


def get_rss_lang(url):
    qs = parse_qs(urlparse(url).query)
    for k in ("Lang", "lang"):
        if k in qs:
            return qs[k][0]
    return "1"


PIB_LANG = get_rss_lang(PIB_RSS_URL)


def extract_prid(url):
    qs = parse_qs(urlparse(url).query)
    for k in ("PRID", "prid", "Prid"):
        if k in qs and qs[k][0].strip():
            return qs[k][0].strip()
    m = re.search(r"PRID=(\d+)", url, re.I)
    return m.group(1) if m else ""


def convert_pib_url(url):
    """Iframe URL -> full static PressReleasePage URL"""
    prid = extract_prid(url)
    if prid:
        return f"https://www.pib.gov.in/PressReleasePage.aspx?PRID={prid}&lang={PIB_LANG}"
    return url


def parse_pib_date(text):
    """'Posted On: 09 AUG 2026 7:20PM by PIB Delhi' -> datetime"""
    if not text:
        return None

    t = clean_text(text)
    t = re.sub(r"^(Posted\s*On|प्रविष्टि\s*तिथि)\s*:?\s*", "", t, flags=re.I)
    t = re.sub(r"\bby\s+PIB.*$", "", t, flags=re.I).strip()
    t = t.replace(".", "")

    for fmt in ("%d %b %Y %I:%M%p", "%d %B %Y %I:%M%p",
                "%d %b %Y %H:%M", "%d %b %Y", "%d %B %Y"):
        try:
            return datetime.strptime(t, fmt).replace(tzinfo=IST)
        except ValueError:
            continue

    m = re.search(
        r"(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm]))?", t
    )
    if m:
        d, mon, y, hh, mm, ap = m.groups()
        base = f"{d} {mon} {y}"
        try:
            if hh:
                return datetime.strptime(
                    f"{base} {hh}:{mm}{ap.upper()}", "%d %b %Y %I:%M%p"
                ).replace(tzinfo=IST)
            return datetime.strptime(base, "%d %b %Y").replace(tzinfo=IST)
        except ValueError:
            pass
    return None


def rss_entry_date(entry):
    if getattr(entry, "published_parsed", None):
        return datetime(*entry.published_parsed[:6], tzinfo=timezone.utc).astimezone(IST)
    return parse_pib_date(entry.get("published", ""))


def is_fresh(dt):
    if MAX_AGE_HOURS <= 0 or dt is None:
        return True
    diff = (datetime.now(IST) - dt).total_seconds() / 3600
    return -3 <= diff <= MAX_AGE_HOURS


# -------------------------------------------------------------
# ARTICLE FETCH  (asli fix yahan hai)
# -------------------------------------------------------------
def fetch_pib_article(url):
    out = {"content": "", "date": None, "ministry": "", "title": ""}

    try:
        res = requests.get(url, headers=HEADERS, timeout=20,
                           impersonate="chrome", verify=False)
        if res.status_code != 200:
            print(f"   ⚠️ HTTP {res.status_code}")
            return out
    except Exception as e:
        print(f"   ⚠️ Fetch error: {e}")
        return out

    soup = BeautifulSoup(res.content, "html.parser")

    # 🔥 CRITICAL: hidden duplicate PDF block hatao (warna content 2x hoga)
    for sel in ["#PdfDiv", ".section1", "#accessories", ".ReleaseLang",
                "#RelLink", ".RelTag", ".print-icons"]:
        for tag in soup.select(sel):
            tag.decompose()

    for tag in soup(["script", "style", "noscript", "nav", "footer", "form", "aside"]):
        tag.decompose()

    # Title
    t = soup.find("h2", id="Titleh2")
    if t:
        out["title"] = clean_text(t.get_text())

    # Ministry
    m = soup.find("div", id="MinistryName")
    if m:
        out["ministry"] = clean_text(m.get_text())

    # Date
    d = soup.find("div", id="PrDateTime")
    if d:
        out["date"] = parse_pib_date(d.get_text())

    # ✅ PRIMARY: hidden field with clean article HTML
    hidden = soup.find("input", id="ltrDescriptionn")
    if hidden and hidden.get("value"):
        raw = html.unescape(hidden["value"])
        text = clean_text(BeautifulSoup(raw, "html.parser").get_text(" ", strip=True))
        if len(text) >= MIN_CONTENT_CHARS:
            out["content"] = polish(text)
            return out

    # ✅ FALLBACK 1: main visible container
    box = soup.find("div", class_="innner-page-main-about-us-content-right-part")
    if box:
        for kill_id in ["MinistryName", "Titleh2", "PrDateTime", "ReleaseId", "lblViews"]:
            el = box.find(id=kill_id)
            if el:
                el.decompose()
        paras = [clean_text(p.get_text()) for p in box.find_all(["p", "li"])]
        text = " ".join(p for p in paras if len(p) > 25)
        if len(text) >= MIN_CONTENT_CHARS:
            out["content"] = polish(text)
            return out

    # ✅ FALLBACK 2: all paragraphs (PdfDiv already removed)
    paras = [clean_text(p.get_text()) for p in soup.find_all("p")]
    text = " ".join(p for p in paras if len(p) > 25)
    if len(text) >= MIN_CONTENT_CHARS:
        out["content"] = polish(text)

    return out


def polish(text):
    text = re.sub(r"\*{3,}", " ", text)                       # ***** separators
    text = re.sub(r"\(Release ID:\s*\d+\)", "", text, flags=re.I)
    text = re.sub(r"\(रिलीज़ आईडी:\s*\d+\)", "", text)
    text = re.sub(r"Visitor Counter\s*:\s*\d+", "", text, flags=re.I)
    text = re.sub(r"आगंतुक पटल\s*:\s*\d+", "", text)
    return clean_text(text)[:15000]


# -------------------------------------------------------------
# MAIN
# -------------------------------------------------------------
def process_pib_rss():
    print(f"📡 PIB RSS: {PIB_RSS_URL}")

    try:
        res = requests.get(PIB_RSS_URL, headers=HEADERS, timeout=20,
                           impersonate="chrome", verify=False)
        if res.status_code != 200:
            print(f"❌ RSS HTTP {res.status_code}")
            return
    except Exception as e:
        print(f"❌ RSS error: {e}")
        return

    entries = feedparser.parse(res.content).entries or []
    print(f"🔍 {len(entries)} items found\n")

    items, skipped = [], 0

    for entry in entries[:MAX_ITEMS]:
        rss_title = clean_text(entry.get("title", ""))
        rss_link = (entry.get("link") or "").strip()
        if not rss_title or not rss_link:
            continue

        prid = extract_prid(rss_link)
        url = convert_pib_url(rss_link)

        print(f"➡️  {rss_title[:70]}")
        art = fetch_pib_article(url)
        time.sleep(REQUEST_DELAY)

        if len(art["content"]) < MIN_CONTENT_CHARS:
            print("   ⛔ skipped (no body)")
            skipped += 1
            continue

        dt = art["date"] or rss_entry_date(entry) or datetime.now(IST)

        if not is_fresh(dt):
            print(f"   ⏳ old ({dt:%d %b %Y %H:%M}) — skipped")
            skipped += 1
            continue

        items.append({
            "source": "PIB",
            "prid": prid,
            "title": art["title"] or rss_title,
            "ministry": art["ministry"],
            "url": url,
            "date": dt.strftime("%a, %d %b %Y %H:%M:%S %z"),
            "date_iso": dt.isoformat(),
            "content": art["content"],
            "content_chars": len(art["content"]),
            "type": "Press Release",
        })
        print(f"   ✅ {len(art['content'])} chars | {art['ministry'][:40]}")

    save(items, skipped)


def save(items, skipped):
    data = {"national_raw_news": [], "bihar_raw_news": []}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            print("⚠️ JSON corrupt — new file banaya")

    national = data.get("national_raw_news", [])

    seen = {x.get("prid") or x.get("url") for x in national}
    added = 0
    for it in items:
        key = it["prid"] or it["url"]
        if key in seen:
            continue
        national.insert(0, it)
        seen.add(key)
        added += 1

    # purani entries prune
    if PRUNE_DAYS > 0:
        cutoff = datetime.now(IST) - timedelta(days=PRUNE_DAYS)
        kept = []
        for x in national:
            try:
                if datetime.fromisoformat(x["date_iso"]) >= cutoff:
                    kept.append(x)
            except Exception:
                kept.append(x)      # date missing -> rakh lo
        national = kept

    data["national_raw_news"] = national
    data["generated_at"] = datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S")
    data["national_raw_count"] = len(national)
    data["bihar_raw_count"] = len(data.get("bihar_raw_news", []))
    data["total_news"] = data["national_raw_count"] + data["bihar_raw_count"]

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Added {added} | Skipped {skipped}")
    print(f"📦 Total national: {data['national_raw_count']}")


if __name__ == "__main__":
    process_pib_rss()
```



PIB_FEEDS = [
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",   # English
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=2&Regid=3",   # Hindi
]
