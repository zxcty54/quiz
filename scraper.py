
import os
import json
import re
import time
import email.utils
import urllib.parse
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from collections import Counter

import urllib3
from curl_cffi import requests
from bs4 import BeautifulSoup
from dateutil import parser as date_parser

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# ============================================================
# CONFIG
# ============================================================

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

# ------------------------------------------------------------
# DATE
# ------------------------------------------------------------

NOW = datetime.now()
TARGET_DT = NOW - timedelta(days=1)

TARGET_DATE = TARGET_DT.date()
TARGET_DATE_STR = TARGET_DT.strftime("%Y-%m-%d")
TARGET_DISPLAY = TARGET_DT.strftime("%d %b %Y")

print("=" * 80)
print("🗓️ NEWS SCRAPER DATE ENGINE")
print(f"🕒 Current date/time : {NOW.strftime('%Y-%m-%d %H:%M:%S')}")
print(f"🎯 TARGET DATE       : {TARGET_DATE_STR}")
print(f"🎯 TARGET DISPLAY    : {TARGET_DISPLAY}")
print("=" * 80)


# ============================================================
# CONTENT LIMITS
# ============================================================

MAX_WORDS = 1500

# Keep article if:
#   >= 500 characters
#       OR
#   >= 300 words
MIN_CONTENT_CHARS = 500
MIN_CONTENT_WORDS = 300

MAX_FETCH_CHARS = 30000


# ============================================================
# HTTP
# ============================================================

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/131.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,image/avif,image/webp,*/*;q=0.8"
    ),
    "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
    "Cache-Control": "no-cache",
}


def safe_fetch(url, timeout=20):
    """
    Multi-level fetch:
      1. curl_cffi normal
      2. curl_cffi verify=False
      3. normal requests verify=False
      4. ScrapingAnt if API key exists
    """

    if not url:
        return None

    # --------------------------------------------------------
    # 1. curl_cffi normal
    # --------------------------------------------------------

    try:
        r = requests.get(
            url,
            impersonate="chrome",
            headers=HEADERS,
            timeout=timeout,
            verify=True,
            allow_redirects=True,
        )

        if r.status_code == 200 and r.content:
            return r.content

        print(f"⚠️ HTTP {r.status_code}: {url}")

    except Exception as e:
        print(f"⚠️ CURL normal failed: {url} | {str(e)[:180]}")

    # --------------------------------------------------------
    # 2. curl_cffi SSL disabled
    # --------------------------------------------------------

    try:
        print(f"🔁 RETRY SSL OFF: {url}")

        r = requests.get(
            url,
            impersonate="chrome",
            headers=HEADERS,
            timeout=timeout,
            verify=False,
            allow_redirects=True,
        )

        if r.status_code == 200 and r.content:
            print("✅ SSL-disabled fetch succeeded")
            return r.content

        print(f"⚠️ HTTP {r.status_code} after SSL retry: {url}")

    except Exception as e:
        print(f"⚠️ CURL verify=False failed: {str(e)[:180]}")

    # --------------------------------------------------------
    # 3. ScrapingAnt
    # --------------------------------------------------------

    if SCRAPINGANT_KEY:

        try:
            encoded = urllib.parse.quote(url, safe="")

            sa_url = (
                "https://api.scrapingant.com/v2/general"
                f"?url={encoded}"
                f"&x-api-key={SCRAPINGANT_KEY}"
                "&browser=false"
            )

            print(f"🌐 SCRAPINGANT FALLBACK: {url}")

            r = requests.get(
                sa_url,
                headers=HEADERS,
                timeout=30,
                verify=False,
            )

            if r.status_code == 200 and r.content:
                print("✅ ScrapingAnt succeeded")
                return r.content

            print(f"⚠️ ScrapingAnt HTTP {r.status_code}")

        except Exception as e:
            print(f"⚠️ ScrapingAnt failed: {str(e)[:180]}")

    return None


# ============================================================
# TEXT
# ============================================================

def normalize_text(text):
    if not text:
        return ""

    text = str(text)

    text = re.sub(
        r"<!\[CDATA\[(.*?)\]\]>",
        r"\1",
        text,
        flags=re.DOTALL,
    )

    soup = BeautifulSoup(text, "html.parser")

    text = soup.get_text(" ", strip=True)

    text = re.sub(r"\s+", " ", text)

    return text.strip()


def word_count(text):
    return len(re.findall(r"\S+", text or ""))


def limit_words(text, max_words=MAX_WORDS):
    words = re.findall(r"\S+", text or "")

    if len(words) <= max_words:
        return " ".join(words)

    return " ".join(words[:max_words])


def content_is_useful(text):
    if not text:
        return False

    chars = len(text)
    words = word_count(text)

    return (
        chars >= MIN_CONTENT_CHARS
        or words >= MIN_CONTENT_WORDS
    )


# ============================================================
# DATE ENGINE
# ============================================================

def parse_any_date(value):
    if not value:
        return None

    value = normalize_text(value)

    if not value:
        return None

    # --------------------------------------------------------
    # Relative dates
    # --------------------------------------------------------

    now = datetime.now()

    low = value.lower()

    if low in ("today", "आज"):
        return now

    if low in ("yesterday", "कल"):
        return now - timedelta(days=1)

    # --------------------------------------------------------
    # Unix timestamp
    # --------------------------------------------------------

    if value.isdigit():

        try:
            ts = int(value)

            if ts > 10**11:
                ts = ts / 1000

            return datetime.fromtimestamp(ts)

        except Exception:
            pass

    # --------------------------------------------------------
    # RFC date
    # --------------------------------------------------------

    try:
        x = email.utils.parsedate_tz(value)

        if x:
            return datetime.fromtimestamp(
                email.utils.mktime_tz(x)
            )

    except Exception:
        pass

    # --------------------------------------------------------
    # Generic date parser
    # --------------------------------------------------------

    try:

        dt = date_parser.parse(
            value,
            fuzzy=True,
            dayfirst=True,
        )

        if dt.tzinfo:
            dt = dt.astimezone().replace(
                tzinfo=None
            )

        return dt

    except Exception:
        pass

    return None


def extract_date_from_url(url):
    if not url:
        return None

    url_low = url.lower()

    # --------------------------------------------------------
    # YYYY/MM/DD
    # --------------------------------------------------------

    m = re.search(
        r"/(20\d{2})[/-](\d{1,2})[/-](\d{1,2})",
        url_low,
    )

    if m:

        try:
            return datetime(
                int(m.group(1)),
                int(m.group(2)),
                int(m.group(3)),
            )

        except Exception:
            pass

    # --------------------------------------------------------
    # DD-Month-YYYY / DD_Month_YYYY
    # --------------------------------------------------------

    m = re.search(
        r"(\d{1,2})[-_](january|february|march|april|may|june|"
        r"july|august|september|october|november|december)[-_](20\d{2})",
        url_low,
    )

    if m:

        try:

            return date_parser.parse(
                f"{m.group(1)} {m.group(2)} {m.group(3)}"
            )

        except Exception:
            pass

    # --------------------------------------------------------
    # Month-DD-YYYY
    # --------------------------------------------------------

    m = re.search(
        r"(january|february|march|april|may|june|july|august|"
        r"september|october|november|december)[-_](\d{1,2})[-_](20\d{2})",
        url_low,
    )

    if m:

        try:

            return date_parser.parse(
                f"{m.group(1)} {m.group(2)} {m.group(3)}"
            )

        except Exception:
            pass

    # --------------------------------------------------------
    # DD Month YYYY
    # --------------------------------------------------------

    m = re.search(
        r"(\d{1,2})[-_ ]"
        r"(january|february|march|april|may|june|july|august|"
        r"september|october|november|december)"
        r"[-_ ](20\d{2})",
        url_low,
    )

    if m:

        try:

            return date_parser.parse(
                f"{m.group(1)} {m.group(2)} {m.group(3)}"
            )

        except Exception:
            pass

    return None


def extract_date_from_soup(soup):
    """
    Generic metadata/date extraction.
    """

    selectors = [

        # HTML5
        "time[datetime]",
        "time",

        # Meta
        'meta[property="article:published_time"]',
        'meta[property="article:modified_time"]',
        'meta[name="publish-date"]',
        'meta[name="publication-date"]',
        'meta[name="date"]',
        'meta[name="DC.date"]',
        'meta[name="dcterms.date"]',

        # OpenGraph
        'meta[property="og:updated_time"]',

    ]

    for selector in selectors:

        for tag in soup.select(selector):

            value = (
                tag.get("datetime")
                or tag.get("content")
                or tag.get_text(" ", strip=True)
            )

            dt = parse_any_date(value)

            if dt:
                return dt

    # --------------------------------------------------------
    # JSON-LD
    # --------------------------------------------------------

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        raw = script.string or script.get_text()

        if not raw:
            continue

        try:

            data = json.loads(raw)

            objects = []

            if isinstance(data, dict):
                objects.append(data)

                if isinstance(
                    data.get("@graph"),
                    list
                ):
                    objects.extend(
                        data["@graph"]
                    )

            elif isinstance(data, list):
                objects.extend(data)

            for obj in objects:

                if not isinstance(obj, dict):
                    continue

                for key in [
                    "datePublished",
                    "dateCreated",
                    "dateModified",
                ]:

                    dt = parse_any_date(
                        obj.get(key)
                    )

                    if dt:
                        return dt

        except Exception:
            continue

    return None


def date_matches_target(
    found_dt,
    source,
    title,
    url,
    fallback_allowed=False,
):
    """
    STRICT:
      Only target date is accepted.

    Missing date:
      Rejected unless fallback_allowed=True and a
      reliable source-level fallback exists.
    """

    if not found_dt:

        print(
            f"❌ DATE MISSING | "
            f"{source} | "
            f"TARGET={TARGET_DATE_STR} | "
            f"{title[:90]}"
        )

        return False

    found_date = found_dt.date()

    print(
        f"📅 DATE DEBUG | "
        f"{source} | "
        f"FOUND={found_date} | "
        f"TARGET={TARGET_DATE_STR} | "
        f"{'ACCEPT' if found_date == TARGET_DATE else 'REJECT'} | "
        f"{title[:80]}"
    )

    return found_date == TARGET_DATE


# ============================================================
# HTML ARTICLE EXTRACTION
# ============================================================

NOISE_SELECTORS = [
    "script",
    "style",
    "noscript",
    "nav",
    "footer",
    "header",
    "form",
    "iframe",
    "aside",
    ".advertisement",
    ".ads",
    ".ad",
    ".social-share",
    ".share-box",
    ".sharing",
    ".breadcrumb",
    ".breadcrumbs",
    ".menu",
    ".navbar",
    ".navigation",
    ".sidebar",
    ".related",
    ".recommended",
    ".comments",
    ".comment",
    ".newsletter",
    ".cookie",
    ".popup",
]


def remove_noise(soup):

    for selector in NOISE_SELECTORS:

        try:
            for tag in soup.select(selector):
                tag.decompose()

        except Exception:
            pass


def extract_jsonld_article(soup):

    results = []

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        raw = script.string or script.get_text()

        if not raw:
            continue

        try:

            data = json.loads(raw)

            objects = []

            if isinstance(data, dict):
                objects.append(data)

                if isinstance(
                    data.get("@graph"),
                    list
                ):
                    objects.extend(
                        data["@graph"]
                    )

            elif isinstance(data, list):
                objects.extend(data)

            for obj in objects:

                if not isinstance(obj, dict):
                    continue

                article_body = obj.get(
                    "articleBody"
                )

                if article_body:

                    text = normalize_text(
                        article_body
                    )

                    if content_is_useful(text):
                        results.append(text)

        except Exception:
            continue

    if not results:
        return ""

    return max(
        results,
        key=len
    )


def extract_article_text(soup):

    # --------------------------------------------------------
    # JSON-LD first
    # --------------------------------------------------------

    jsonld = extract_jsonld_article(soup)

    if content_is_useful(jsonld):
        return limit_words(jsonld)

    # --------------------------------------------------------
    # Remove portal noise
    # --------------------------------------------------------

    remove_noise(soup)

    # --------------------------------------------------------
    # Strong article containers
    # --------------------------------------------------------

    container_selectors = [

        # Generic
        "article",
        ".article-body",
        ".articleBody",
        ".article-content",
        ".article-content-body",
        ".story-body",
        ".story-content",
        ".story-element",
        ".entry-content",
        ".post-content",
        ".full-details",
        ".content-body",
        "#content-body",

        # PIB
        "#ContentPlaceHolder1_divpri",
        "#divpri",
        ".ReleaseIdText",
        ".release_text",
        ".innercontent",

        # Government
        ".view-content",
        ".field--name-body",
        ".field-name-body",

        # Sansad TV
        ".episode-content",
        ".episode-description",

    ]

    candidates = []

    for selector in container_selectors:

        try:

            for container in soup.select(
                selector
            ):

                paragraphs = container.find_all(
                    ["p", "li", "td"]
                )

                blocks = []

                for p in paragraphs:

                    txt = normalize_text(
                        p.get_text(" ", strip=True)
                    )

                    if len(txt) >= 35:
                        blocks.append(txt)

                text = " ".join(blocks)

                if len(text) > 300:
                    candidates.append(text)

        except Exception:
            continue

    # --------------------------------------------------------
    # Generic paragraph extraction
    # --------------------------------------------------------

    paragraphs = soup.find_all("p")

    blocks = []

    for p in paragraphs:

        txt = normalize_text(
            p.get_text(" ", strip=True)
        )

        if len(txt) >= 45:
            blocks.append(txt)

    generic_text = " ".join(blocks)

    if len(generic_text) > 300:
        candidates.append(generic_text)

    # --------------------------------------------------------
    # Choose largest meaningful candidate
    # --------------------------------------------------------

    if not candidates:
        return ""

    candidates.sort(
        key=len,
        reverse=True
    )

    text = candidates[0]

    # Remove common repeated portal strings
    repeated_noise = [
        "previous next",
        "read more",
        "share",
        "follow us",
        "copyright",
        "all rights reserved",
        "accessibility options",
        "skip to main content",
    ]

    for noise in repeated_noise:
        text = re.sub(
            re.escape(noise),
            " ",
            text,
            flags=re.I
        )

    text = normalize_text(text)

    return limit_words(text)


# ============================================================
# DEEP ARTICLE FETCH
# ============================================================

def fetch_article(
    url,
    source,
    title="",
    listing_date=None,
):

    print(
        f"\n🔍 ARTICLE FETCH | "
        f"{source} | {url}"
    )

    content = safe_fetch(
        url,
        timeout=25
    )

    if not content:

        print(
            f"❌ NO HTML | "
            f"{source} | {title[:100]}"
        )

        return {
            "content": "",
            "date": listing_date,
            "date_source": "listing",
        }

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

    except Exception as e:

        print(
            f"❌ HTML PARSE ERROR | "
            f"{source} | {e}"
        )

        return {
            "content": "",
            "date": listing_date,
            "date_source": "listing",
        }

    # --------------------------------------------------------
    # Deep date
    # --------------------------------------------------------

    article_date = extract_date_from_soup(
        soup
    )

    date_source = "article_meta"

    # URL date fallback
    if not article_date:

        article_date = extract_date_from_url(
            url
        )

        date_source = "url"

    # Listing date fallback
    if not article_date and listing_date:

        article_date = parse_any_date(
            listing_date
        )

        date_source = "listing"

    # --------------------------------------------------------
    # Content
    # --------------------------------------------------------

    text = extract_article_text(
        soup
    )

    words = word_count(text)
    chars = len(text)

    if text:

        print(
            f"📄 CONTENT DEBUG | "
            f"{source} | "
            f"{chars} chars | "
            f"{words} words | "
            f"DATE={article_date.date() if article_date else 'NO DATE'}"
        )

    else:

        print(
            f"⚠️ CONTENT EMPTY | "
            f"{source} | {title[:100]}"
        )

    return {
        "content": text,
        "date": article_date,
        "date_source": date_source,
    }


# ============================================================
# NEWS OBJECT
# ============================================================

def make_item(
    source,
    title,
    url,
    article_date,
    content,
):

    if not article_date:
        return None

    if article_date.date() != TARGET_DATE:
        return None

    content = limit_words(
        normalize_text(content)
    )

    if not content_is_useful(content):
        print(
            f"❌ CONTENT TOO SHORT | "
            f"{source} | "
            f"{len(content)} chars | "
            f"{word_count(content)} words | "
            f"{title[:80]}"
        )
        return None

    print(
        f"✅ ACCEPTED | "
        f"{source} | "
        f"{article_date.strftime('%Y-%m-%d')} | "
        f"{word_count(content)} words | "
        f"{title[:80]}"
    )

    return {
        "source": source,
        "title": normalize_text(title),
        "url": url,
        "date": article_date.strftime(
            "%Y-%m-%d"
        ),
        "content": content,
        "word_count": word_count(content),
        "char_count": len(content),
    }


# ============================================================
# RSS SCRAPER
# ============================================================

def scrape_rss(
    source,
    rss_url,
    max_items=30,
    category="national",
):

    print("\n" + "=" * 70)
    print(f"📰 RSS SOURCE: {source}")
    print(f"🔗 {rss_url}")
    print("=" * 70)

    result = []

    content = safe_fetch(
        rss_url,
        timeout=25
    )

    if not content:
        print(
            f"❌ RSS FETCH FAILED | {source}"
        )
        return result

    try:

        soup = BeautifulSoup(
            content,
            "xml"
        )

        items = soup.find_all("item")

        print(
            f"📦 RSS ITEMS FOUND: "
            f"{len(items)}"
        )

    except Exception as e:

        print(
            f"❌ RSS PARSE ERROR | "
            f"{source} | {e}"
        )

        return result

    for item in items[:max_items]:

        title_tag = item.find("title")
        link_tag = item.find("link")

        date_tag = (
            item.find("pubDate")
            or item.find("pubdate")
            or item.find("dc:date")
        )

        desc_tag = item.find(
            "description"
        )

        title = normalize_text(
            title_tag.get_text()
            if title_tag
            else ""
        )

        url = normalize_text(
            link_tag.get_text()
            if link_tag
            else ""
        )

        pub_date = normalize_text(
            date_tag.get_text()
            if date_tag
            else ""
        )

        if not title or not url:
            continue

        dt = parse_any_date(
            pub_date
        )

        if not dt:
            dt = extract_date_from_url(
                url
            )

        print(
            f"\n📝 {source} CANDIDATE"
        )
        print(
            f"   TITLE : {title[:100]}"
        )
        print(
            f"   DATE  : {pub_date or 'NO DATE'}"
        )
        print(
            f"   PARSED: "
            f"{dt.strftime('%Y-%m-%d') if dt else 'NO DATE'}"
        )
        print(
            f"   TARGET: {TARGET_DATE_STR}"
        )

        if not dt:

            print(
                f"❌ REJECT DATE MISSING | "
                f"{source} | {title[:80]}"
            )

            continue

        if dt.date() != TARGET_DATE:

            print(
                f"⏭️ REJECT OLD/NEW | "
                f"{source} | "
                f"FOUND={dt.date()} | "
                f"TARGET={TARGET_DATE}"
            )

            continue

        article = fetch_article(
            url,
            source,
            title,
            listing_date=dt
        )

        article_dt = article["date"]

        if not article_dt:
            continue

        if article_dt.date() != TARGET_DATE:

            print(
                f"❌ ARTICLE DATE MISMATCH | "
                f"{source} | "
                f"LISTING={dt.date()} | "
                f"ARTICLE={article_dt.date()} | "
                f"TARGET={TARGET_DATE}"
            )

            continue

        item_obj = make_item(
            source,
            title,
            url,
            article_dt,
            article["content"],
        )

        if item_obj:
            result.append(item_obj)

    print(
        f"\n✅ {source} usable: "
        f"{len(result)}"
    )

    return result


# ============================================================
# PIB
# ============================================================

def scrape_pib():

    source = "PIB"

    print("\n" + "=" * 80)
    print("🇮🇳 PIB DEEP SCRAPER")
    print("=" * 80)

    feeds = [
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=9&Regid=1",
    ]

    result = []

    seen_urls = set()

    for feed_url in feeds:

        print(
            f"\n🔎 PIB FEED: {feed_url}"
        )

        content = safe_fetch(
            feed_url,
            timeout=25
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "xml"
            )

            items = soup.find_all("item")

            print(
                f"📦 PIB ITEMS: {len(items)}"
            )

        except Exception as e:

            print(
                f"❌ PIB RSS ERROR: {e}"
            )

            continue

        for item in items[:30]:

            title_tag = item.find(
                "title"
            )

            link_tag = item.find(
                "link"
            )

            date_tag = (
                item.find("pubDate")
                or item.find("pubdate")
            )

            if not title_tag or not link_tag:
                continue

            title = normalize_text(
                title_tag.get_text()
            )

            url = normalize_text(
                link_tag.get_text()
            )

            pub_date = normalize_text(
                date_tag.get_text()
                if date_tag
                else ""
            )

            if not title or not url:
                continue

            if url in seen_urls:
                continue

            seen_urls.add(url)

            listing_dt = parse_any_date(
                pub_date
            )

            print(
                f"\n🔍 PIB CANDIDATE | "
                f"{title[:100]}"
            )

            print(
                f"📅 RSS DATE={pub_date or 'NO DATE'}"
            )

            if not listing_dt:

                print(
                    "❌ PIB DATE MISSING"
                )

                continue

            print(
                f"📅 FOUND={listing_dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if listing_dt.date() != TARGET_DATE:

                print(
                    "⏭️ PIB REJECT DATE"
                )

                continue

            # ------------------------------------------------
            # Force PressReleasePage URL
            # ------------------------------------------------

            prid = re.search(
                r"PRID=(\d+)",
                url,
                re.I
            )

            if prid:

                article_url = (
                    "https://www.pib.gov.in/"
                    "PressReleasePage.aspx?"
                    f"PRID={prid.group(1)}"
                )

            else:

                article_url = url

            article = fetch_article(
                article_url,
                source,
                title,
                listing_date=listing_dt
            )

            article_dt = article["date"]

            if not article_dt:
                continue

            if article_dt.date() != TARGET_DATE:

                print(
                    f"❌ PIB ARTICLE DATE MISMATCH | "
                    f"{article_dt.date()} != "
                    f"{TARGET_DATE}"
                )

                continue

            obj = make_item(
                source,
                title,
                article_url,
                article_dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n🇮🇳 PIB FINAL: {len(result)}"
    )

    return result


# ============================================================
# GOOGLE NEWS BIHAR
# ============================================================

def scrape_google_bihar():

    url = (
        "https://news.google.com/rss/search?"
        "q=Bihar+Government+OR+Bihar+Cabinet+OR+"
        "Bihar+Scheme+OR+Bihar+Infrastructure+"
        "when:2d&hl=hi&gl=IN&ceid=IN:hi"
    )

    return scrape_rss(
        "Google News Bihar",
        url,
        30,
        "bihar"
    )


# ============================================================
# CMO BIHAR
# ============================================================

def scrape_cmo_bihar():

    source = "CMO Bihar"

    print("\n" + "=" * 80)
    print("🏛️ CMO BIHAR")
    print("=" * 80)

    url = (
        "https://cm.bihar.gov.in/"
        "users/preessrelease.aspx"
    )

    html = safe_fetch(
        url,
        timeout=25
    )

    result = []

    if not html:
        print("❌ CMO LISTING FAILED")
        return result

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    rows = soup.find_all("tr")

    print(
        f"📦 CMO ROWS: {len(rows)}"
    )

    for row in rows:

        cols = row.find_all("td")

        if len(cols) < 2:
            continue

        row_text = normalize_text(
            row.get_text(" ", strip=True)
        )

        # Search date anywhere in row
        dt = None

        for value in [
            row_text,
            cols[0].get_text(
                " ",
                strip=True
            ),
        ]:

            dt = parse_any_date(value)

            if dt:
                break

        # Find links
        links = row.find_all("a")

        for a in links:

            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            href = a.get(
                "href"
            )

            if not title or not href:
                continue

            if len(title) < 10:
                continue

            article_url = urllib.parse.urljoin(
                url,
                href
            )

            print(
                f"\n🔍 CMO CANDIDATE | "
                f"{title[:100]}"
            )

            print(
                f"📅 ROW DATE="
                f"{dt.date() if dt else 'NO DATE'}"
            )

            print(
                f"🎯 TARGET={TARGET_DATE}"
            )

            if not dt:

                # Try article itself for date
                article = fetch_article(
                    article_url,
                    source,
                    title
                )

                dt = article["date"]

            else:

                article = fetch_article(
                    article_url,
                    source,
                    title,
                    listing_date=dt
                )

            if not dt:

                print(
                    "❌ CMO REJECT DATE MISSING"
                )

                continue

            if dt.date() != TARGET_DATE:

                print(
                    f"⏭️ CMO REJECT | "
                    f"FOUND={dt.date()} | "
                    f"TARGET={TARGET_DATE}"
                )

                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

            if len(result) >= 20:
                break

        if len(result) >= 20:
            break

    print(
        f"\n✅ CMO FINAL: {len(result)}"
    )

    return result


# ============================================================
# IPRD BIHAR
# ============================================================

def scrape_iprd_bihar():

    source = "IPRD Bihar"

    print("\n" + "=" * 80)
    print("📢 IPRD BIHAR")
    print("=" * 80)

    listing_url = (
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html"
    )

    html = safe_fetch(
        listing_url,
        timeout=30
    )

    result = []

    if not html:
        print("❌ IPRD LISTING FAILED")
        return result

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    links = []

    for a in soup.find_all("a"):

        href = a.get("href")
        title = normalize_text(
            a.get_text(
                " ",
                strip=True
            )
        )

        if not href or not title:
            continue

        if "SectionInformation" not in href:
            continue

        full_url = urllib.parse.urljoin(
            listing_url,
            href
        )

        if full_url not in [
            x[0] for x in links
        ]:

            links.append(
                (full_url, title)
            )

    print(
        f"🔗 IPRD candidate links: "
        f"{len(links)}"
    )

    for article_url, title in links[:80]:

        print(
            f"\n🔍 IPRD checking: "
            f"{title[:100]}"
        )

        article = fetch_article(
            article_url,
            source,
            title
        )

        dt = article["date"]

        if not dt:

            print(
                "❌ IPRD DATE MISSING"
            )

            continue

        print(
            f"📅 IPRD DATE={dt.date()} "
            f"TARGET={TARGET_DATE}"
        )

        if dt.date() != TARGET_DATE:

            print(
                "⏭️ IPRD REJECT DATE"
            )

            continue

        obj = make_item(
            source,
            title,
            article_url,
            dt,
            article["content"],
        )

        if obj:
            result.append(obj)

    print(
        f"\n✅ IPRD FINAL: {len(result)}"
    )

    return result


# ============================================================
# BIHAR CABINET
# ============================================================

def scrape_bihar_cabinet():

    source = "Bihar Cabinet"

    print("\n" + "=" * 80)
    print("🏛️ BIHAR CABINET")
    print("=" * 80)

    listing_urls = [
        "https://cabinet.bihar.gov.in/",
        "https://cabinet.bih.nic.in/",
    ]

    result = []

    for listing_url in listing_urls:

        html = safe_fetch(
            listing_url,
            timeout=25
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href or len(title) < 10:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            # Only cabinet-looking links
            combined = (
                title + " " + article_url
            ).lower()

            if not any(
                x in combined
                for x in [
                    "cabinet",
                    "decision",
                    "meeting",
                    "press",
                    "order",
                    "nirnay",
                ]
            ):
                continue

            print(
                f"\n🔍 CABINET: "
                f"{title[:100]}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:
                continue

            print(
                f"📅 FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:
                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ Bihar Cabinet FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# SANSAD TV
# ============================================================

def scrape_sansad_tv():

    source = "Sansad TV"

    print("\n" + "=" * 80)
    print("📺 SANSAD TV")
    print("=" * 80)

    listing_urls = [
        "https://sansadtv.nic.in/",
        "https://sansadtv.nic.in/show_type/sansad-mein-aaj",
        "https://sansadtv.nic.in/category/news",
    ]

    result = []

    seen = set()

    for listing_url in listing_urls:

        print(
            f"\n🔎 Listing: {listing_url}"
        )

        html = safe_fetch(
            listing_url,
            timeout=30
        )

        if not html:
            print(
                "⚠️ Sansad TV listing fetch failed"
            )
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if (
                "sansadtv.nic.in"
                not in article_url
            ):
                continue

            if article_url in seen:
                continue

            # Episode/article candidates
            if not any(
                x in article_url.lower()
                for x in [
                    "/episode/",
                    "/news/",
                    "/article/",
                ]
            ):
                continue

            seen.add(article_url)

            if len(title) < 10:
                title = (
                    article_url
                    .rstrip("/")
                    .split("/")
                    [-1]
                    .replace("-", " ")
                )

            print(
                f"\n🔍 SANSAD ARTICLE: "
                f"{article_url}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:

                # Try URL date again
                dt = extract_date_from_url(
                    article_url
                )

            if not dt:

                print(
                    "❌ SANSAD DATE MISSING"
                )

                continue

            print(
                f"📅 SANSAD FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:

                print(
                    "⏭️ SANSAD REJECT DATE"
                )

                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ Sansad TV FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# PRS INDIA
# ============================================================

def scrape_prs():

    source = "PRS India"

    print("\n" + "=" * 80)
    print("🏛️ PRS INDIA")
    print("=" * 80)

    listing_urls = [
        "https://prsindia.org/",
        "https://prsindia.org/latest-updates",
        "https://prsindia.org/parliament",
        "https://prsindia.org/parliamentary-committees",
    ]

    result = []

    seen = set()

    for listing_url in listing_urls:

        print(
            f"\n🔎 PRS LISTING: "
            f"{listing_url}"
        )

        html = safe_fetch(
            listing_url,
            timeout=30
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if (
                "prsindia.org"
                not in article_url
            ):
                continue

            if article_url in seen:
                continue

            seen.add(article_url)

            # Avoid pure navigation
            if len(title) < 15:
                continue

            print(
                f"\n🔍 PRS ARTICLE FETCH: "
                f"{article_url}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:

                print(
                    f"❌ PRS DATE MISSING | "
                    f"{title[:100]}"
                )

                continue

            print(
                f"📅 PRS FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:

                print(
                    "⏭️ PRS REJECT DATE"
                )

                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ PRS FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# INDIA.GOV.IN
# ============================================================

def scrape_india_gov():

    source = "India.gov.in"

    print("\n" + "=" * 80)
    print("🇮🇳 INDIA.GOV.IN")
    print("=" * 80)

    listing_urls = [
        "https://www.india.gov.in/news",
        "https://www.india.gov.in/spotlight",
    ]

    result = []

    seen = set()

    for listing_url in listing_urls:

        html = safe_fetch(
            listing_url,
            timeout=30
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if (
                "india.gov.in"
                not in article_url
            ):
                continue

            if article_url in seen:
                continue

            if len(title) < 15:
                continue

            seen.add(article_url)

            print(
                f"\n🔍 INDIA.GOV ARTICLE: "
                f"{title[:100]}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:
                continue

            print(
                f"📅 FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:
                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ India.gov.in FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# NEWS ON AIR NATIONAL
# ============================================================

def scrape_news_on_air():

    source = "News On AIR"

    print("\n" + "=" * 80)
    print("📻 NEWS ON AIR NATIONAL")
    print("=" * 80)

    listing_urls = [
        "https://www.newsonair.gov.in/",
        "https://www.newsonair.gov.in/category/national/",
        "https://www.newsonair.gov.in/category/top-news/",
    ]

    result = []

    seen = set()

    for listing_url in listing_urls:

        html = safe_fetch(
            listing_url,
            timeout=30
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if (
                "newsonair.gov.in"
                not in article_url
            ):
                continue

            if article_url in seen:
                continue

            if len(title) < 15:
                continue

            # Skip category/menu pages
            if any(
                x in article_url.rstrip("/")
                for x in [
                    "/category/",
                    "/tag/",
                    "/page/",
                ]
            ):
                continue

            seen.add(article_url)

            print(
                f"\n🔍 AIR ARTICLE: "
                f"{title[:100]}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:
                continue

            print(
                f"📅 FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:
                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ News On AIR FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# NEWS ON AIR BIHAR
# ============================================================

def scrape_news_on_air_bihar():

    source = "News On AIR Bihar"

    print("\n" + "=" * 80)
    print("📻 NEWS ON AIR BIHAR")
    print("=" * 80)

    urls = [
        "https://www.newsonair.gov.in/category/regional/",
        "https://www.newsonair.gov.in/category/bihar/",
    ]

    result = []

    seen = set()

    for listing_url in urls:

        html = safe_fetch(
            listing_url,
            timeout=25
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href or len(title) < 15:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if article_url in seen:
                continue

            if "newsonair.gov.in" not in article_url:
                continue

            seen.add(article_url)

            print(
                f"\n🔍 AIR BIHAR: "
                f"{title[:100]}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:
                continue

            print(
                f"📅 FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:
                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ News On AIR Bihar FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# PTI
# ============================================================

def scrape_pti():

    source = "PTI"

    print("\n" + "=" * 80)
    print("📰 PTI")
    print("=" * 80)

    listing_urls = [
        "https://www.ptinews.com/",
        "https://www.ptinews.com/latest-news",
    ]

    result = []

    seen = set()

    for listing_url in listing_urls:

        html = safe_fetch(
            listing_url,
            timeout=30
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all("a"):

            href = a.get("href")
            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            article_url = urllib.parse.urljoin(
                listing_url,
                href
            )

            if article_url in seen:
                continue

            if "ptinews.com" not in article_url:
                continue

            if len(title) < 15:
                continue

            seen.add(article_url)

            print(
                f"\n🔍 PTI ARTICLE: "
                f"{title[:100]}"
            )

            article = fetch_article(
                article_url,
                source,
                title
            )

            dt = article["date"]

            if not dt:
                continue

            print(
                f"📅 FOUND={dt.date()} "
                f"TARGET={TARGET_DATE}"
            )

            if dt.date() != TARGET_DATE:
                continue

            obj = make_item(
                source,
                title,
                article_url,
                dt,
                article["content"],
            )

            if obj:
                result.append(obj)

    print(
        f"\n✅ PTI FINAL: "
        f"{len(result)}"
    )

    return result


# ============================================================
# NATIONAL RSS
# ============================================================

def scrape_national_sources():

    result = []

    rss_sources = [

        (
            "The Hindu",
            "https://www.thehindu.com/news/national/feeder/default.rss",
        ),

        (
            "Indian Express",
            "https://indianexpress.com/section/india/feed/",
        ),

    ]

    for source, url in rss_sources:

        result.extend(
            scrape_rss(
                source,
                url,
                max_items=30
            )
        )

    return result


# ============================================================
# DEDUPLICATION
# ============================================================

def normalize_title_for_dedupe(title):

    title = normalize_text(title)

    title = re.sub(
        r"[^a-zA-Z0-9\u0900-\u097F]+",
        "",
        title.lower()
    )

    return title[:180]


def deduplicate(items):

    seen_urls = set()
    seen_titles = set()

    result = []

    dropped = 0

    for item in items:

        url = item.get(
            "url",
            ""
        )

        title_key = normalize_title_for_dedupe(
            item.get(
                "title",
                ""
            )
        )

        if url and url in seen_urls:
            dropped += 1
            continue

        if title_key and title_key in seen_titles:
            dropped += 1
            continue

        if url:
            seen_urls.add(url)

        if title_key:
            seen_titles.add(
                title_key
            )

        result.append(item)

    print(
        f"🧹 DEDUP | "
        f"Input={len(items)} | "
        f"Dropped={dropped} | "
        f"Unique={len(result)}"
    )

    return result


# ============================================================
# SOURCE STATS
# ============================================================

def get_source_stats(items):

    counter = Counter()

    for item in items:

        counter[
            item.get(
                "source",
                "Unknown"
            )
        ] += 1

    return dict(
        counter
    )


# ============================================================
# MAIN
# ============================================================

def run_scraper():

    print("\n")
    print("#" * 90)
    print("🚀 DEEP GOVERNMENT + NATIONAL NEWS SCRAPER")
    print("#" * 90)

    print(
        f"🎯 ONLY TARGET DATE: "
        f"{TARGET_DATE_STR}"
    )

    national = []
    bihar = []

    # ========================================================
    # NATIONAL
    # ========================================================

    # PIB
    try:
        national.extend(
            scrape_pib()
        )
    except Exception as e:
        print(
            f"❌ PIB CRASH: {e}"
        )

    # Hindu + Indian Express
    try:
        national.extend(
            scrape_national_sources()
        )
    except Exception as e:
        print(
            f"❌ NATIONAL RSS CRASH: {e}"
        )

    # PTI
    try:
        national.extend(
            scrape_pti()
        )
    except Exception as e:
        print(
            f"❌ PTI CRASH: {e}"
        )

    # PRS
    try:
        national.extend(
            scrape_prs()
        )
    except Exception as e:
        print(
            f"❌ PRS CRASH: {e}"
        )

    # India.gov.in
    try:
        national.extend(
            scrape_india_gov()
        )
    except Exception as e:
        print(
            f"❌ INDIA.GOV CRASH: {e}"
        )

    # Sansad TV
    try:
        national.extend(
            scrape_sansad_tv()
        )
    except Exception as e:
        print(
            f"❌ SANSAD TV CRASH: {e}"
        )

    # News On AIR National
    try:
        national.extend(
            scrape_news_on_air()
        )
    except Exception as e:
        print(
            f"❌ NEWS ON AIR CRASH: {e}"
        )

    # ========================================================
    # BIHAR
    # ========================================================

    # Google Bihar
    try:
        bihar.extend(
            scrape_google_bihar()
        )
    except Exception as e:
        print(
            f"❌ GOOGLE BIHAR CRASH: {e}"
        )

    # CMO
    try:
        bihar.extend(
            scrape_cmo_bihar()
        )
    except Exception as e:
        print(
            f"❌ CMO CRASH: {e}"
        )

    # IPRD
    try:
        bihar.extend(
            scrape_iprd_bihar()
        )
    except Exception as e:
        print(
            f"❌ IPRD CRASH: {e}"
        )

    # Bihar Cabinet
    try:
        bihar.extend(
            scrape_bihar_cabinet()
        )
    except Exception as e:
        print(
            f"❌ BIHAR CABINET CRASH: {e}"
        )

    # News On AIR Bihar
    try:
        bihar.extend(
            scrape_news_on_air_bihar()
        )
    except Exception as e:
        print(
            f"❌ AIR BIHAR CRASH: {e}"
        )

    # ========================================================
    # DEDUPE
    # ========================================================

    print("\n" + "=" * 80)
    print("🧹 FINAL DEDUPLICATION")
    print("=" * 80)

    national = deduplicate(
        national
    )

    bihar = deduplicate(
        bihar
    )

    # ========================================================
    # FINAL SOURCE STATS
    # ========================================================

    national_stats = get_source_stats(
        national
    )

    bihar_stats = get_source_stats(
        bihar
    )

    all_items = national + bihar

    all_stats = get_source_stats(
        all_items
    )

    print("\n" + "=" * 80)
    print("📊 FINAL SOURCE BREAKDOWN")
    print("=" * 80)

    print(
        json.dumps(
            all_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print("\n🇮🇳 NATIONAL:")
    print(
        json.dumps(
            national_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print("\n🏛️ BIHAR:")
    print(
        json.dumps(
            bihar_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    # ========================================================
    # RAW JSON
    # ========================================================

    payload = {

        "generated_at":
            datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "target_date":
            TARGET_DATE_STR,

        "target_date_display":
            TARGET_DISPLAY,

        "date_rule":
            "ONLY EXACT TARGET DATE",

        "content_rule":
            "Minimum 500 chars OR 300 words; maximum 1500 words",

        "national_raw_count":
            len(national),

        "bihar_raw_count":
            len(bihar),

        "total_raw_count":
            len(all_items),

        "source_breakdown":
            all_stats,

        "national_source_breakdown":
            national_stats,

        "bihar_source_breakdown":
            bihar_stats,

        "national_raw_news":
            national,

        "bihar_raw_news":
            bihar,
    }

    with open(
        "rawnews.json",
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            payload,
            f,
            ensure_ascii=False,
            indent=2
        )

    print("\n" + "=" * 80)
    print("💾 rawnews.json CREATED")
    print("=" * 80)

    print(
        f"🎯 Target date : {TARGET_DATE_STR}"
    )

    print(
        f"🇮🇳 National   : {len(national)}"
    )

    print(
        f"🏛️ Bihar      : {len(bihar)}"
    )

    print(
        f"📰 Total      : {len(all_items)}"
    )

    print(
        f"📦 File       : rawnews.json"
    )

    print("=" * 80)


if __name__ == "__main__":
    run_scraper()

