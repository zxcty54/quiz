import os
import re
import json
import time
import warnings
import hashlib
import feedparser
from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, unquote

from curl_cffi import requests
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "rawnews.json"

TIMEOUT = 20
MAX_PER_SOURCE = 15

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/150.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
}

warnings.filterwarnings(
    "ignore",
    category=MarkupResemblesLocatorWarning
)

# ============================================================
# DATE
# ============================================================

IST = timezone(timedelta(hours=5, minutes=30))


def now_ist():
    return datetime.now(IST)


TODAY = now_ist().date()
YESTERDAY = TODAY - timedelta(days=1)


# ============================================================
# HTTP
# ============================================================

def fetch_url(url, timeout=TIMEOUT):
    if not url:
        return None

    url = clean_url(url)

    if not url:
        return None

    if url.lower().startswith("javascript:"):
        return None

    try:
        r = requests.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            impersonate="chrome",
            allow_redirects=True
        )

        if r.status_code >= 400:
            print(f"⚠️ HTTP {r.status_code}: {url}")
            return None

        return r.text

    except Exception as e:
        print(f"⚠️ Direct fetch failed: {url} | {e}")
        return None


# ============================================================
# URL CLEANING
# ============================================================

def clean_url(url):
    if not url:
        return ""

    url = str(url).strip()

    # Markdown URL
    m = re.search(r'\]\((https?://[^)]+)\)', url)
    if m:
        url = m.group(1)

    # Remove markdown wrapper
    url = re.sub(r'^\[.*?\]\(', '', url)
    url = re.sub(r'\)$', '', url)

    url = url.replace("\\&", "&")
    url = url.replace("\\:", ":")
    url = url.strip()

    if url.startswith("javascript:"):
        return ""

    if url.startswith("mailto:"):
        return ""

    if not url.startswith(("http://", "https://")):
        return ""

    return url


# ============================================================
# TEXT CLEANING
# ============================================================

def clean_text(text):
    if not text:
        return ""

    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)

    text = re.sub(r'\s+', ' ', text)
    text = text.replace("\xa0", " ")

    return text.strip()


def clean_title(title):
    title = clean_text(title)

    title = re.sub(
        r'\s*[-|–—]\s*(PIB|Press Information Bureau|News On AIR).*$',
        '',
        title,
        flags=re.I
    )

    return title.strip()


# ============================================================
# DATE PARSER
# ============================================================

DATE_FORMATS = [
    "%a, %d %b %Y %H:%M:%S %z",
    "%a, %d %b %Y %H:%M:%S GMT",
    "%d-%b-%Y",
    "%d-%B-%Y",
    "%d/%m/%Y",
    "%d-%m-%Y",
    "%Y-%m-%d",
    "%Y-%m-%d %H:%M:%S",
    "%d %b %Y",
    "%d %B %Y",
]


def parse_date(value):
    if not value:
        return None

    value = clean_text(value)

    # RFC date
    try:
        d = datetime.strptime(
            value,
            "%a, %d %b %Y %H:%M:%S %z"
        )
        return d.astimezone(IST)
    except Exception:
        pass

    # GMT manually
    try:
        d = datetime.strptime(
            value,
            "%a, %d %b %Y %H:%M:%S GMT"
        )
        return d.replace(tzinfo=timezone.utc).astimezone(IST)
    except Exception:
        pass

    # Remove common suffixes
    value2 = re.sub(
        r'\b(IST|GMT|UTC)\b',
        '',
        value,
        flags=re.I
    ).strip()

    for fmt in DATE_FORMATS:
        try:
            d = datetime.strptime(value2, fmt)

            if d.tzinfo is None:
                d = d.replace(tzinfo=IST)

            return d.astimezone(IST)

        except Exception:
            continue

    # Search date inside string
    patterns = [
        r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})',
        r'(\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4})',
        r'(\d{4}-\d{2}-\d{2})',
    ]

    for pattern in patterns:
        m = re.search(pattern, value)
        if m:
            for fmt in [
                "%d-%m-%Y",
                "%d/%m/%Y",
                "%d-%b-%Y",
                "%d-%B-%Y",
                "%Y-%m-%d",
            ]:
                try:
                    d = datetime.strptime(m.group(1), fmt)
                    return d.replace(tzinfo=IST)
                except Exception:
                    continue

    return None


# ============================================================
# DATE FROM HTML
# ============================================================

def extract_date_from_soup(soup):
    selectors = [
        "time",
        "meta[property='article:published_time']",
        "meta[name='publish-date']",
        "meta[name='date']",
        "meta[name='DC.date']",
        "meta[itemprop='datePublished']",
        "span.date",
        ".date",
        ".published",
        ".publish-date",
        ".news-date",
    ]

    for selector in selectors:
        try:
            elements = soup.select(selector)
        except Exception:
            continue

        for el in elements:
            value = (
                el.get("content")
                or el.get("datetime")
                or el.get_text(" ", strip=True)
            )

            d = parse_date(value)

            if d:
                return d

    # Search visible text for dates
    text = soup.get_text(" ", strip=True)

    patterns = [
        r'\b\d{1,2}-[A-Za-z]{3}-\d{4}\b',
        r'\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b',
        r'\b\d{1,2}/\d{1,2}/\d{4}\b',
    ]

    for pattern in patterns:
        m = re.search(pattern, text)

        if m:
            d = parse_date(m.group(0))

            if d:
                return d

    return None


# ============================================================
# GENERIC ARTICLE CONTENT
# ============================================================

def fetch_generic_article_content(url):
    """
    Fetch actual article page and extract meaningful content.
    """

    url = clean_url(url)

    if not url:
        return "", None

    html = fetch_url(url)

    if not html:
        return "", None

    soup = BeautifulSoup(html, "html.parser")

    # Remove unwanted
    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "nav",
        "footer",
        "header",
        "form",
        "iframe"
    ]):
        tag.decompose()

    date = extract_date_from_soup(soup)

    candidates = []

    selectors = [
        "article",
        "[itemprop='articleBody']",
        ".article-body",
        ".articleBody",
        ".story-content",
        ".storyContent",
        ".news-content",
        ".newsContent",
        ".press-release",
        ".pressrelease",
        ".content-area",
        ".main-content",
        "main",
    ]

    for selector in selectors:
        try:
            for el in soup.select(selector):
                txt = clean_text(el.get_text(" ", strip=True))

                if len(txt) > 100:
                    candidates.append(txt)
        except Exception:
            pass

    # Paragraph fallback
    if not candidates:
        paragraphs = []

        for p in soup.find_all("p"):
            txt = clean_text(p.get_text(" ", strip=True))

            if len(txt) >= 40:
                paragraphs.append(txt)

        if paragraphs:
            candidates.append(" ".join(paragraphs))

    if not candidates:
        body = soup.body

        if body:
            txt = clean_text(body.get_text(" ", strip=True))

            if len(txt) > 100:
                candidates.append(txt)

    if not candidates:
        return "", date

    # longest reasonable candidate
    content = max(candidates, key=len)

    content = remove_common_boilerplate(content)

    return content, date


# ============================================================
# BOILERPLATE FILTER
# ============================================================

BOILERPLATE_PATTERNS = [
    "we have tried to put most accurate and appropriate data",
    "help web information manager",
    "feedback.commonportal",
    "copyright iprd",
    "information and public relations department office",
    "forgot email",
    "not your computer",
    "learn more about using",
    "phone directory",
]


def is_boilerplate(text):
    if not text:
        return True

    low = text.lower()

    hits = sum(
        1 for p in BOILERPLATE_PATTERNS
        if p in low
    )

    return hits >= 2


def remove_common_boilerplate(text):
    if not text:
        return ""

    for pattern in [
        r"We have tried to put most accurate.*$",
        r"Help Web Information Manager.*$",
        r"Copyright IPRD.*$",
    ]:
        text = re.sub(
            pattern,
            "",
            text,
            flags=re.I
        )

    return clean_text(text)


# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(
    source,
    title,
    url,
    date=None,
    content="",
    item_type="Scraped"
):
    title = clean_title(title)
    url = clean_url(url)
    content = clean_text(content)

    if not title:
        return None

    if not url:
        return None

    if is_boilerplate(content):
        return None

    if not content:
        return None

    return {
        "source": source,
        "title": title,
        "url": url,
        "date": (
            date.strftime("%a, %d %b %Y %H:%M:%S GMT")
            if isinstance(date, datetime)
            else (date or "")
        ),
        "content": content,
        "content_chars": len(content),
        "type": item_type,
    }


# ============================================================
# DEDUPLICATION
# ============================================================

def normalize_for_hash(text):
    text = clean_text(text).lower()

    text = re.sub(
        r'[^a-z0-9\u0900-\u097f]+',
        ' ',
        text
    )

    return text.strip()


def deduplicate(items):
    seen = set()
    output = []
    dropped = 0

    for item in items:

        key_source = (
            item.get("url")
            or item.get("title")
            or item.get("content", "")
        )

        key = hashlib.sha1(
            normalize_for_hash(key_source).encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if key in seen:
            dropped += 1
            continue

        seen.add(key)
        output.append(item)

    print(
        f"🧹 Deduplication: Input={len(items)} | "
        f"Dropped={dropped} | Unique={len(output)}"
    )

    return output


# ============================================================
# PIB RSS
# ============================================================

PIB_FEEDS = [
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=9&Regid=1",
]


def scrape_pib_rss():
    print("\n🇮🇳 PIB NATIONAL SCRAPER")

    all_entries = []

    for feed_url in PIB_FEEDS:

        print(f"🔎 PIB feed: {feed_url}")

        try:
            raw = fetch_url(feed_url)

            if not raw:
                print("Found RSS items: 0")
                continue

            parsed = feedparser.parse(raw)

            entries = parsed.entries or []

            print(f"Found RSS items: {len(entries)}")

            for entry in entries:

                title = clean_title(
                    entry.get("title", "")
                )

                link = clean_url(
                    entry.get("link", "")
                )

                if not link:
                    continue

                date = None

                for field in [
                    "published",
                    "updated",
                    "pubDate",
                    "date"
                ]:
                    value = entry.get(field)

                    if value:
                        date = parse_date(value)

                        if date:
                            break

                # feedparser structured date
                if not date:
                    for field in [
                        "published_parsed",
                        "updated_parsed"
                    ]:
                        st = entry.get(field)

                        if st:
                            try:
                                date = datetime(
                                    st.tm_year,
                                    st.tm_mon,
                                    st.tm_mday,
                                    st.tm_hour,
                                    st.tm_min,
                                    st.tm_sec,
                                    tzinfo=timezone.utc
                                ).astimezone(IST)

                                break
                            except Exception:
                                pass

                print(
                    "   PIB RSS:",
                    date.strftime("%Y-%m-%d %H:%M")
                    if date else "NO DATE",
                    "|",
                    title[:90]
                )

                content = clean_text(
                    entry.get("summary", "")
                    or entry.get("description", "")
                )

                all_entries.append({
                    "title": title,
                    "url": link,
                    "date": date,
                    "content": content,
                })

        except Exception as e:
            print(f"⚠️ PIB RSS error: {e}")

    all_entries = deduplicate([
        {
            "source": "PIB",
            "title": x["title"],
            "url": x["url"],
            "date": (
                x["date"].strftime("%Y-%m-%d")
                if x["date"] else ""
            ),
            "content": x["content"],
        }
        for x in all_entries
    ])

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(all_entries)}"
    )

    # Re-parse dates because dedup output is strings
    usable = []

    yesterday_items = []
    today_items = []
    undated_items = []

    for item in all_entries:

        d = parse_date(item["date"])

        if d:
            if d.date() == YESTERDAY:
                yesterday_items.append(item)

            elif d.date() == TODAY:
                today_items.append(item)

        else:
            undated_items.append(item)

    print(
        f"📅 PIB yesterday items: "
        f"{len(yesterday_items)}"
    )

    print(
        f"📅 PIB today items: "
        f"{len(today_items)}"
    )

    # ========================================================
    # Priority:
    # Yesterday first
    # Then today
    # ========================================================

    selected = yesterday_items[:MAX_PER_SOURCE]

    if len(selected) < 5:
        selected += today_items[:MAX_PER_SOURCE - len(selected)]

    # If RSS date parser fails, use latest undated RSS entries
    if len(selected) < 5:
        print(
            "⚠️ PIB date filtering produced too few items. "
            "Using latest RSS entries as emergency fallback."
        )

        remaining = [
            x for x in all_entries
            if x not in selected
        ]

        selected += remaining[
            :MAX_PER_SOURCE - len(selected)
        ]

    results = []

    for item in selected[:MAX_PER_SOURCE]:

        content, article_date = fetch_generic_article_content(
            item["url"]
        )

        final_date = article_date or parse_date(
            item["date"]
        )

        final_content = content or item["content"]

        if not final_content:
            final_content = item["title"]

        obj = make_item(
            source="PIB",
            title=item["title"],
            url=item["url"],
            date=final_date,
            content=final_content,
            item_type="RSS + Article"
        )

        if obj:
            results.append(obj)

    print(
        f"✅ PIB usable news: {len(results)}"
    )

    return deduplicate(results)


# ============================================================
# PIB WEBSITE FALLBACK
# ============================================================

PIB_HOME = "https://pib.gov.in/"


def scrape_pib_website_fallback():
    print("\n🔎 PIB WEBSITE FALLBACK")

    html = fetch_url(PIB_HOME)

    if not html:
        return []

    soup = BeautifulSoup(html, "html.parser")

    candidates = []

    for a in soup.find_all("a", href=True):

        href = clean_url(
            urljoin(PIB_HOME, a.get("href", ""))
        )

        if not href:
            continue

        if "pib.gov.in" not in href.lower():
            continue

        title = clean_title(
            a.get_text(" ", strip=True)
        )

        if len(title) < 20:
            continue

        low = title.lower()

        if any(
            x in low
            for x in [
                "home",
                "about us",
                "contact",
                "login",
                "feedback",
                "sitemap"
            ]
        ):
            continue

        candidates.append(
            (title, href)
        )

    # dedupe
    seen = set()
    unique = []

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(href)
        unique.append((title, href))

    results = []

    for title, url in unique[:30]:

        content, date = fetch_generic_article_content(
            url
        )

        if not content:
            continue

        # Only recent PIB articles
        if date:
            age = (TODAY - date.date()).days

            if age > 2:
                continue

        obj = make_item(
            source="PIB",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Website Fallback"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)

    print(
        f"✅ PIB website fallback: {len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR NATIONAL
# ============================================================

NEWS_ON_AIR_HOME = "https://newsonair.gov.in/"


def scrape_news_on_air_national():
    print("\n📻 NEWS ON AIR NATIONAL SCRAPER")

    html = fetch_url(NEWS_ON_AIR_HOME)

    if not html:
        return []

    soup = BeautifulSoup(html, "html.parser")

    results = []

    for a in soup.find_all("a", href=True):

        href = clean_url(
            urljoin(NEWS_ON_AIR_HOME, a.get("href"))
        )

        if not href:
            continue

        title = clean_title(
            a.get_text(" ", strip=True)
        )

        if len(title) < 25:
            continue

        # Skip sports
        low = title.lower()

        if any(
            x in low
            for x in [
                "cricket",
                "football",
                "tennis",
                "badminton",
                "sports"
            ]
        ):
            continue

        content, date = fetch_generic_article_content(
            href
        )

        if not content:
            content = title

        obj = make_item(
            source="News On AIR",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="News On AIR"
        )

        if obj:
            results.append(obj)

        if len(results) >= 20:
            break

    results = deduplicate(results)

    print(
        f"✅ News On AIR usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# CMO BIHAR
# ============================================================

CMO_URL = "https://cm.bihar.gov.in/users/preessrelease.aspx"


def scrape_cmo_bihar():
    print("\n🏛️ CMO BIHAR SCRAPER")

    html = fetch_url(CMO_URL)

    if not html:
        return []

    soup = BeautifulSoup(html, "html.parser")

    results = []

    for a in soup.find_all("a", href=True):

        href = clean_url(
            urljoin(CMO_URL, a.get("href"))
        )

        if not href:
            continue

        title = clean_title(
            a.get_text(" ", strip=True)
        )

        if len(title) < 25:
            continue

        low = title.lower()

        if any(
            x in low
            for x in [
                "home",
                "contact",
                "login",
                "gallery",
                "photo",
                "feedback"
            ]
        ):
            continue

        content, date = fetch_generic_article_content(
            href
        )

        # CMO sometimes gives only title on listing page
        if not content:
            content = title
            item_type = "Title Scraped"
        else:
            item_type = "Article Scraped"

        obj = make_item(
            source="CMO Bihar",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type=item_type
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)

    print(
        f"✅ CMO Bihar usable news: {len(results)}"
    )

    return results


# ============================================================
# IPRD BIHAR
# ============================================================

IPRD_PAGES = [
    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/"
    ),
    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931"
    ),
    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930"
    ),
    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=6996"
    ),
]


def scrape_iprd_bihar():
    print("\n📢 IPRD BIHAR SCRAPER")

    results = []

    for source, page_url in IPRD_PAGES:

        html = fetch_url(page_url)

        if not html:
            continue

        soup = BeautifulSoup(html, "html.parser")

        links = []

        for a in soup.find_all("a", href=True):

            href = clean_url(
                urljoin(page_url, a.get("href"))
            )

            if not href:
                continue

            if "state.bihar.gov.in" not in href:
                continue

            title = clean_title(
                a.get_text(" ", strip=True)
            )

            if len(title) < 25:
                continue

            low = title.lower()

            if any(
                x in low
                for x in [
                    "home",
                    "contact",
                    "feedback",
                    "copyright",
                    "web information manager",
                    "department"
                ]
            ):
                continue

            links.append(
                (title, href)
            )

        # Actual articles
        for title, href in links[:40]:

            content, date = fetch_generic_article_content(
                href
            )

            if not content:
                continue

            if is_boilerplate(content):
                continue

            # Don't take old archive pages
            if date:
                age = (TODAY - date.date()).days

                if age > 3:
                    continue

            obj = make_item(
                source=source,
                title=title,
                url=href,
                date=date,
                content=content,
                item_type="Press Release"
            )

            if obj:
                results.append(obj)

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)

    print(
        f"✅ IPRD Bihar usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# BIHAR CABINET
# ============================================================

CABINET_PAGES = [
    "https://state.bihar.gov.in/csd/",
    "https://state.bihar.gov.in/csd/CitizenHome.html",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=2929",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=1323",
    "https://state.bihar.gov.in/csd/SectionInformation.html?editForm&rowId=4935",
]


def scrape_bihar_cabinet():
    print("\n🏛️ BIHAR CABINET SCRAPER")

    results = []

    for page_url in CABINET_PAGES:

        html = fetch_url(page_url)

        if not html:
            continue

        soup = BeautifulSoup(html, "html.parser")

        for a in soup.find_all("a", href=True):

            href = clean_url(
                urljoin(page_url, a.get("href"))
            )

            if not href:
                continue

            if "state.bihar.gov.in/csd" not in href.lower():
                continue

            title = clean_title(
                a.get_text(" ", strip=True)
            )

            if len(title) < 20:
                continue

            low = title.lower()

            if not any(
                x in low
                for x in [
                    "cabinet",
                    "decision",
                    "decisions",
                    "press",
                    "approval",
                    "approved"
                ]
            ):
                continue

            content, date = fetch_generic_article_content(
                href
            )

            if not content:
                continue

            if is_boilerplate(content):
                continue

            if date:
                age = (TODAY - date.date()).days

                if age > 7:
                    continue

            obj = make_item(
                source="Bihar Cabinet Decision",
                title=title,
                url=href,
                date=date,
                content=content,
                item_type="Cabinet Decision"
            )

            if obj:
                results.append(obj)

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)

    print(
        f"✅ Bihar Cabinet usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR BIHAR
# ============================================================

NEWS_ON_AIR_BIHAR_URLS = [
    "https://newsonair.gov.in/category/regional-news/",
    "https://newsonair.gov.in/category/regional/",
    "https://newsonair.gov.in/",
]


def scrape_news_on_air_bihar():
    print("\n📻 NEWS ON AIR BIHAR FALLBACK")

    results = []

    for page_url in NEWS_ON_AIR_BIHAR_URLS:

        html = fetch_url(page_url)

        if not html:
            continue

        soup = BeautifulSoup(html, "html.parser")

        for a in soup.find_all("a", href=True):

            href = clean_url(
                urljoin(page_url, a.get("href"))
            )

            if not href:
                continue

            title = clean_title(
                a.get_text(" ", strip=True)
            )

            if len(title) < 25:
                continue

            low = title.lower()

            # Bihar relevance
            if not any(
                x in low
                for x in [
                    "bihar",
                    "patna",
                    "nitish",
                    "muzaffarpur",
                    "gaya",
                    "darbhanga",
                    "purnea",
                    "purnia",
                    "begusarai",
                    "bhagalpur",
                    "sitamarhi",
                    "saran",
                    "vaishali",
                    "samastipur",
                    "madhubani",
                    "motihari"
                ]
            ):
                continue

            content, date = fetch_generic_article_content(
                href
            )

            if not content:
                content = title

            obj = make_item(
                source="News On AIR Bihar",
                title=title,
                url=href,
                date=date,
                content=content,
                item_type="Regional News"
            )

            if obj:
                results.append(obj)

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(results)

    print(
        f"✅ News On AIR Bihar usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SOURCE PRIORITY
# ============================================================

def build_news():

    # --------------------------------------------------------
    # NATIONAL
    # --------------------------------------------------------

    pib = scrape_pib_rss()

    if len(pib) < 5:

        print(
            "⚠️ PIB RSS insufficient."
        )

        pib_web = scrape_pib_website_fallback()

        pib = deduplicate(
            pib + pib_web
        )

    if len(pib) >= 5:

        national = pib

    else:

        print(
            "⚠️ PIB still insufficient."
        )

        print(
            "📻 Using News On AIR fallback..."
        )

        air = scrape_news_on_air_national()

        national = deduplicate(
            pib + air
        )

    # --------------------------------------------------------
    # BIHAR
    # --------------------------------------------------------

    cmo = scrape_cmo_bihar()

    iprd = scrape_iprd_bihar()

    cabinet = scrape_bihar_cabinet()

    bihar = deduplicate(
        cmo + iprd + cabinet
    )

    # If Bihar official sources weak
    if len(bihar) < 5:

        air_bihar = scrape_news_on_air_bihar()

        bihar = deduplicate(
            bihar + air_bihar
        )

    # --------------------------------------------------------
    # FINAL
    # --------------------------------------------------------

    national = deduplicate(national)
    bihar = deduplicate(bihar)

    print("\n📊 SOURCE BREAKDOWN")

    breakdown = {}

    for item in national + bihar:

        source = item.get(
            "source",
            "Unknown"
        )

        breakdown[source] = (
            breakdown.get(source, 0) + 1
        )

    print(
        json.dumps(
            breakdown,
            ensure_ascii=False,
            indent=2
        )
    )

    print(
        f"\n🇮🇳 National News : {len(national)}"
    )

    print(
        f"🏛️ Bihar News    : {len(bihar)}"
    )

    return national, bihar, breakdown


# ============================================================
# SAVE
# ============================================================

def save_output(national, bihar, breakdown):

    all_news = national + bihar

    output = {
        "generated_at": now_ist().strftime(
            "%Y-%m-%d %H:%M:%S"
        ),
        "bihar_raw_count": len(bihar),
        "national_raw_count": len(national),
        "bihar_raw_news": bihar,
        "national_raw_news": national,
        "source_breakdown": breakdown,
    }

    with open(
        OUTPUT_FILE,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            output,
            f,
            ensure_ascii=False,
            indent=2
        )

    print(
        f"\n💾 {OUTPUT_FILE} updated successfully!"
    )


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":

    try:

        national, bihar, breakdown = build_news()

        save_output(
            national,
            bihar,
            breakdown
        )

    except KeyboardInterrupt:

        print(
            "\n⛔ Scraper stopped by user."
        )

    except Exception as e:

        print(
            f"\n❌ FATAL ERROR: {e}"
        )
        raise
