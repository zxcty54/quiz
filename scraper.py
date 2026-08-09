import os
import re
import json
import time
import hashlib
import warnings
import feedparser

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, parse_qs, urlencode, urlunparse

from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning


# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "rawnews.json"

TIMEOUT = 25

# Per source maximum
MAX_PER_SOURCE = 10

# Content quality requirement
MIN_CONTENT_CHARS = 500
MIN_CONTENT_WORDS = 300
MAX_CONTENT_CHARS = 30000


# Article fetching attempts
MAX_FETCH_ATTEMPTS = 3

# Optional ScrapingAnt
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "").strip()

# Current date
IST = timezone(timedelta(hours=5, minutes=30))


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/150.0.0.0 Safari/537.36"
    ),
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,image/avif,image/webp,*/*;q=0.8"
    ),
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
}


warnings.filterwarnings(
    "ignore",
    category=MarkupResemblesLocatorWarning
)


# ============================================================
# DATE
# ============================================================

def now_ist():
    return datetime.now(IST)


TODAY = now_ist().date()
YESTERDAY = TODAY - timedelta(days=1)


# ============================================================
# DEBUG
# ============================================================

def debug(msg):
    print(f"🔍 {msg}")


def warn(msg):
    print(f"⚠️ {msg}")


def success(msg):
    print(f"✅ {msg}")


# ============================================================
# URL CLEANING
# ============================================================

def clean_url(url):

    if not url:
        return ""

    url = str(url).strip()

    # Markdown:
    # [https://example.com](https://example.com)
    m = re.search(
        r'\]\((https?://[^)]+)\)',
        url
    )

    if m:
        url = m.group(1)

    # Remove markdown wrapper
    url = re.sub(
        r'^\[.*?\]\(',
        '',
        url
    )

    url = re.sub(
        r'\)$',
        '',
        url
    )

    # Escaped markdown characters
    url = url.replace("\\&", "&")
    url = url.replace("\\:", ":")
    url = url.replace("\\_", "_")

    url = url.strip()

    if url.startswith("javascript:"):
        return ""

    if url.startswith("mailto:"):
        return ""

    if not url.startswith(
        ("http://", "https://")
    ):
        return ""

    return url


# ============================================================
# TEXT
# ============================================================

def clean_text(text):

    if not text:
        return ""

    text = BeautifulSoup(
        str(text),
        "html.parser"
    ).get_text(
        " ",
        strip=True
    )

    text = text.replace("\xa0", " ")
    text = text.replace("\u200b", " ")
    text = text.replace("\ufeff", " ")

    text = re.sub(
        r'\s+',
        ' ',
        text
    )

    return text.strip()


def clean_title(title):

    title = clean_text(title)

    title = re.sub(
        r'\s*[-|–—]\s*'
        r'(PIB|Press Information Bureau|News On AIR|'
        r'Sansad TV|Prasar Bharati).*$',
        '',
        title,
        flags=re.I
    )

    return title.strip()


# ============================================================
# CONTENT QUALITY
# ============================================================

def word_count(text):

    if not text:
        return 0

    return len(
        re.findall(
            r'\S+',
            text
        )
    )


def content_quality(text):

    text = clean_text(text)

    chars = len(text)
    words = word_count(text)

    # User requirement:
    # >500 characters OR >300 words
    valid = (
        chars >= MIN_CONTENT_CHARS
        or words >= MIN_CONTENT_WORDS
    )

    return valid, chars, words


# ============================================================
# BOILERPLATE
# ============================================================

PORTAL_BOILERPLATE = [
    "accessibility options",
    "skip to main content",
    "previous next",
    "state profile",
    "governance profile",
    "facts and figure",
    "distribution of population",
    "web information manager",
    "website information",
    "site owned by",
    "copyright",
    "privacy policy",
    "terms and conditions",
    "feedback",
    "contact us",
    "sitemap",
    "login",
    "forgot password",
    "quick links",
    "important links",
    "useful links",
    "read more",
    "subscribe",
    "newsletter",
    "follow us",
]


def boilerplate_score(text):

    if not text:
        return 0

    low = text.lower()

    return sum(
        1
        for x in PORTAL_BOILERPLATE
        if x in low
    )


def is_bad_portal_content(text):

    if not text:
        return True

    score = boilerplate_score(text)

    # Very strong portal contamination
    if score >= 7:
        return True

    return False


# ============================================================
# REMOVE BOILERPLATE FROM ARTICLE
# ============================================================

def remove_common_boilerplate(text):

    if not text:
        return ""

    # Remove obvious footer areas
    patterns = [

        r'Copyright.*?(?=$)',

        r'Help Web Information Manager.*?(?=$)',

        r'We have tried to put most accurate.*?(?=$)',

        r'Website Information.*?(?=$)',

        r'Feedback.*?(?=$)',
    ]

    for pattern in patterns:

        text = re.sub(
            pattern,
            "",
            text,
            flags=re.I
        )

    return clean_text(text)


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

    # feedparser date
    try:

        d = datetime.strptime(
            value,
            "%a, %d %b %Y %H:%M:%S %z"
        )

        return d.astimezone(IST)

    except Exception:
        pass

    # GMT
    try:

        d = datetime.strptime(
            value,
            "%a, %d %b %Y %H:%M:%S GMT"
        )

        return d.replace(
            tzinfo=timezone.utc
        ).astimezone(IST)

    except Exception:
        pass

    value2 = re.sub(
        r'\b(IST|GMT|UTC)\b',
        '',
        value,
        flags=re.I
    ).strip()

    for fmt in DATE_FORMATS:

        try:

            d = datetime.strptime(
                value2,
                fmt
            )

            if d.tzinfo is None:
                d = d.replace(
                    tzinfo=IST
                )

            return d.astimezone(IST)

        except Exception:
            continue

    # Search inside text
    patterns = [

        r'\b\d{1,2}[-/]\d{1,2}[-/]\d{4}\b',

        r'\b\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4}\b',

        r'\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b',

        r'\b\d{4}-\d{2}-\d{2}\b',

    ]

    for pattern in patterns:

        m = re.search(
            pattern,
            value
        )

        if not m:
            continue

        for fmt in [

            "%d-%m-%Y",
            "%d/%m/%Y",
            "%d-%b-%Y",
            "%d-%B-%Y",
            "%Y-%m-%d",

        ]:

            try:

                d = datetime.strptime(
                    m.group(0),
                    fmt
                )

                return d.replace(
                    tzinfo=IST
                )

            except Exception:
                continue

    return None


# ============================================================
# DATE FROM HTML
# ============================================================

def extract_date_from_soup(soup):

    selectors = [

        "meta[property='article:published_time']",

        "meta[property='og:published_time']",

        "meta[name='publish-date']",

        "meta[name='date']",

        "meta[name='DC.date']",

        "meta[itemprop='datePublished']",

        "meta[itemprop='dateModified']",

        "time",

        ".date",

        ".published",

        ".publish-date",

        ".news-date",

        ".article-date",

        ".date-time",

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
                or el.get_text(
                    " ",
                    strip=True
                )
            )

            d = parse_date(value)

            if d:
                return d

    return None


# ============================================================
# HTTP FETCH
# ============================================================

def curl_fetch(url, verify=True):

    try:

        r = curl_requests.get(
            url,
            headers=HEADERS,
            timeout=TIMEOUT,
            impersonate="chrome",
            allow_redirects=True,
            verify=verify
        )

        if r.status_code >= 400:

            warn(
                f"HTTP {r.status_code}: {url}"
            )

            return None

        return r.text

    except Exception as e:

        warn(
            f"CURL failed: {url} | {e}"
        )

        return None


def normal_fetch(url, verify=True):

    try:

        r = normal_requests.get(
            url,
            headers=HEADERS,
            timeout=TIMEOUT,
            allow_redirects=True,
            verify=verify
        )

        if r.status_code >= 400:

            warn(
                f"REQUESTS HTTP {r.status_code}: {url}"
            )

            return None

        return r.text

    except Exception as e:

        warn(
            f"Requests failed: {url} | {e}"
        )

        return None


def scrapingant_fetch(url):

    if not SCRAPINGANT_API_KEY:
        return None

    try:

        endpoint = (
            "https://api.scrapingant.com/v2/general"
        )

        params = {
            "url": url,
            "x-api-key": SCRAPINGANT_API_KEY,
            "browser": "true",
        }

        r = normal_requests.get(
            endpoint,
            params=params,
            timeout=60
        )

        if r.status_code >= 400:

            warn(
                f"ScrapingAnt HTTP {r.status_code}: {url}"
            )

            return None

        return r.text

    except Exception as e:

        warn(
            f"ScrapingAnt failed: {url} | {e}"
        )

        return None


def fetch_url(url):

    url = clean_url(url)

    if not url:
        return None

    # -----------------------------------------
    # Attempt 1: curl SSL
    # -----------------------------------------

    html = curl_fetch(
        url,
        verify=True
    )

    if html:
        return html

    # -----------------------------------------
    # Attempt 2: curl SSL disabled
    # Useful for Sansad TV etc.
    # -----------------------------------------

    debug(
        f"Retrying with SSL verification disabled: {url}"
    )

    html = curl_fetch(
        url,
        verify=False
    )

    if html:
        return html

    # -----------------------------------------
    # Attempt 3: normal requests
    # -----------------------------------------

    html = normal_fetch(
        url,
        verify=True
    )

    if html:
        return html

    # -----------------------------------------
    # Attempt 4: normal requests verify=False
    # -----------------------------------------

    debug(
        f"Retrying normal requests verify=False: {url}"
    )

    html = normal_fetch(
        url,
        verify=False
    )

    if html:
        return html

    # -----------------------------------------
    # Attempt 5: ScrapingAnt
    # -----------------------------------------

    if SCRAPINGANT_API_KEY:

        debug(
            f"Trying ScrapingAnt: {url}"
        )

        html = scrapingant_fetch(url)

        if html:
            return html

    warn(
        f"❌ ALL FETCH METHODS FAILED: {url}"
    )

    return None


# ============================================================
# PIB URL CONVERTER
# ============================================================

def convert_pib_article_url(url):

    url = clean_url(url)

    if not url:
        return ""

    parsed = urlparse(url)

    query = parse_qs(
        parsed.query
    )

    prid = (
        query.get("PRID", [None])[0]
    )

    if not prid:
        m = re.search(
            r'PRID=(\d+)',
            url,
            flags=re.I
        )

        if m:
            prid = m.group(1)

    if not prid:
        return url

    return (
        "https://www.pib.gov.in/"
        f"PressReleasePage.aspx?PRID={prid}"
        "&reg=3&lang=1"
    )


# ============================================================
# PIB ARTICLE CANDIDATE URLS
# ============================================================

def pib_article_urls(url):

    urls = []

    original = clean_url(url)

    if original:
        urls.append(original)

    converted = convert_pib_article_url(
        original
    )

    if converted:
        urls.append(converted)

    # iframe version
    if "PressReleasePage.aspx" in converted:

        iframe = converted.replace(
            "PressReleasePage.aspx",
            "PressReleaseIframePage.aspx"
        )

        urls.append(iframe)

    # Remove duplicates
    output = []

    seen = set()

    for u in urls:

        if u and u not in seen:

            seen.add(u)
            output.append(u)

    return output


# ============================================================
# GENERIC ARTICLE EXTRACTION
# ============================================================

def extract_article_content(
    soup,
    source=""
):

    # --------------------------------------------------------
    # REMOVE NON ARTICLE ELEMENTS
    # --------------------------------------------------------

    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "canvas",
        "iframe",
        "nav",
        "footer",
        "form",
        "aside"
    ]):

        tag.decompose()

    # --------------------------------------------------------
    # JSON-LD articleBody
    # --------------------------------------------------------

    jsonld_candidates = []

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        try:

            data = json.loads(
                script.string or
                script.get_text()
            )

            objects = (
                data
                if isinstance(data, list)
                else [data]
            )

            for obj in objects:

                if not isinstance(
                    obj,
                    dict
                ):
                    continue

                body = obj.get(
                    "articleBody"
                )

                if body:

                    txt = clean_text(body)

                    if txt:
                        jsonld_candidates.append(txt)

        except Exception:
            pass

    # --------------------------------------------------------
    # Strong article selectors
    # --------------------------------------------------------

    selectors = [

        "[itemprop='articleBody']",

        "article",

        ".article-body",

        ".articleBody",

        ".article-content",

        ".articleContent",

        ".story-content",

        ".storyContent",

        ".news-content",

        ".newsContent",

        ".press-release",

        ".pressrelease",

        ".press-release-content",

        ".pressRelease",

        ".release-content",

        ".content-area",

        ".main-content",

        ".post-content",

        ".entry-content",

        ".single-content",

        ".td-post-content",

        ".content",

        "main",

    ]

    candidates = []

    candidates.extend(
        jsonld_candidates
    )

    for selector in selectors:

        try:

            elements = soup.select(
                selector
            )

        except Exception:
            continue

        for el in elements:

            txt = clean_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 300:
                candidates.append(txt)

    # --------------------------------------------------------
    # Paragraph extraction
    # --------------------------------------------------------

    paragraphs = []

    for p in soup.find_all("p"):

        txt = clean_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(txt) >= 30:
            paragraphs.append(txt)

    if paragraphs:

        joined = clean_text(
            " ".join(paragraphs)
        )

        candidates.append(
            joined
        )

    # --------------------------------------------------------
    # Div based article extraction
    # --------------------------------------------------------

    for div in soup.find_all(
        ["div", "section"]
    ):

        txt = clean_text(
            div.get_text(
                " ",
                strip=True
            )
        )

        if (
            len(txt) >= 500
            and len(txt) <= 150000
        ):

            candidates.append(txt)

    # --------------------------------------------------------
    # Choose best candidate
    # --------------------------------------------------------

    if not candidates:
        return ""

    # Clean
    cleaned = []

    for text in candidates:

        text = remove_common_boilerplate(
            text
        )

        if not text:
            continue

        if is_bad_portal_content(
            text
        ):
            continue

        cleaned.append(text)

    if not cleaned:
        return ""

    # Score by length + paragraph quality
    def score(text):

        words = word_count(text)

        chars = len(text)

        return (
            min(chars, 100000)
            + min(words * 2, 50000)
        )

    best = max(
        cleaned,
        key=score
    )

    return clean_text(best)


# ============================================================
# GENERIC ARTICLE FETCH
# ============================================================

def fetch_generic_article_content(
    url,
    source=""
):

    url = clean_url(url)

    if not url:
        return "", None

    candidate_urls = [
        url
    ]

    # PIB special
    if source == "PIB":

        candidate_urls = pib_article_urls(
            url
        )

    for candidate_url in candidate_urls:

        debug(
            f"{source} ARTICLE FETCH: "
            f"{candidate_url}"
        )

        html = fetch_url(
            candidate_url
        )

        if not html:

            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        date = extract_date_from_soup(
            soup
        )

        content = extract_article_content(
            soup,
            source
        )

        valid, chars, words = content_quality(
            content
        )

        if valid:

            success(
                f"{source} CONTENT FOUND | "
                f"{chars} chars | "
                f"{words} words"
            )

            return content, date

        debug(
            f"{source} CONTENT TOO SHORT | "
            f"{chars} chars | "
            f"{words} words | "
            f"{candidate_url}"
        )

    warn(
        f"{source} NO ARTICLE CONTENT: {url}"
    )

    return "", None


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

    title = clean_title(
        title
    )

    url = clean_url(
        url
    )

    content = clean_text(
        content
    )

    # ========================================================
    # YESTERDAY-ONLY DATE FILTER
    # Keep ALL existing sources/scrapers unchanged.
    # Only accept articles whose actual parsed publication date
    # is exactly yesterday in IST.
    # ========================================================
    parsed_date = date

    if isinstance(parsed_date, str):
        parsed_date = parse_date(parsed_date)

    if not parsed_date:
        warn(
            f"DEBUG DATE REJECTED | {source} | NO DATE | "
            f"{title[:100]}"
        )
        return None

    if parsed_date.tzinfo is None:
        parsed_date = parsed_date.replace(tzinfo=IST)
    else:
        parsed_date = parsed_date.astimezone(IST)

    article_day = parsed_date.date()

    if article_day != YESTERDAY:
        debug(
            f"DATE FILTER REJECTED | {source} | "
            f"article={article_day} | target={YESTERDAY} | "
            f"{title[:100]}"
        )
        return None

    debug(
        f"DATE ACCEPTED | {source} | "
        f"{article_day} | target={YESTERDAY} | "
        f"{title[:100]}"
    )

    date = parsed_date

    if not title:
        return None

    if not url:
        return None

    # NEVER allow title as content
    if (
        not content
        or content.lower() == title.lower()
    ):

        warn(
            f"DEBUG NO CONTENT | "
            f"{source} | {title[:120]}"
        )

        return None

    valid, chars, words = content_quality(
        content
    )

    if not valid:

        warn(
            f"DEBUG CONTENT TOO SHORT | "
            f"{source} | "
            f"{chars} chars | "
            f"{words} words | "
            f"{title[:100]}"
        )

        return None

    if is_bad_portal_content(
        content
    ):

        warn(
            f"DEBUG PORTAL CONTENT REJECTED | "
            f"{source} | "
            f"{title[:100]}"
        )

        return None

    return {
        "source": source,

        "title": title,

        "url": url,

        "date": (
            date.strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            )
            if isinstance(
                date,
                datetime
            )
            else (
                date or ""
            )
        ),

        "content": content,

        "content_chars": chars,

        "content_words": words,

        "type": item_type,
    }


# ============================================================
# HASH / DEDUP
# ============================================================

def normalize_for_hash(text):

    text = clean_text(
        text
    ).lower()

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

        url = clean_url(
            item.get("url", "")
        )

        title = item.get(
            "title",
            ""
        )

        key = (
            url
            or title
            or item.get(
                "content",
                ""
            )
        )

        key = hashlib.sha1(
            normalize_for_hash(
                key
            ).encode(
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
        f"🧹 Deduplication: "
        f"Input={len(items)} | "
        f"Dropped={dropped} | "
        f"Unique={len(output)}"
    )

    return output


# ============================================================
# RECENT DATE CHECK
# ============================================================

def recent_enough(
    date,
    days=3
):

    if not date:
        return True

    age = (
        TODAY - date.date()
    ).days

    return age <= days


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


def scrape_pib():

    print("\n")
    print("=" * 70)
    print("🇮🇳 PIB")
    print("=" * 70)

    entries = []

    for feed_url in PIB_FEEDS:

        print(
            f"\n🔎 PIB RSS: {feed_url}"
        )

        html = fetch_url(
            feed_url
        )

        if not html:

            continue

        parsed = feedparser.parse(
            html
        )

        rss_entries = (
            parsed.entries or []
        )

        print(
            f"Found RSS items: "
            f"{len(rss_entries)}"
        )

        for entry in rss_entries:

            title = clean_title(
                entry.get(
                    "title",
                    ""
                )
            )

            link = clean_url(
                entry.get(
                    "link",
                    ""
                )
            )

            if not title or not link:
                continue

            date = None

            for field in [
                "published",
                "updated",
                "pubDate",
                "date",
            ]:

                value = entry.get(
                    field
                )

                if value:

                    date = parse_date(
                        value
                    )

                    if date:
                        break

            if not date:

                for field in [
                    "published_parsed",
                    "updated_parsed",
                ]:

                    st = entry.get(
                        field
                    )

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
                            ).astimezone(
                                IST
                            )

                            break

                        except Exception:
                            pass

            print(
                "   PIB RSS:",
                (
                    date.strftime(
                        "%Y-%m-%d %H:%M"
                    )
                    if date
                    else "NO DATE"
                ),
                "|",
                title[:100]
            )

            entries.append({
                "title": title,
                "url": link,
                "date": date,
            })

    entries = deduplicate([
        {
            "source": "PIB",
            "title": x["title"],
            "url": x["url"],
            "date": (
                x["date"].strftime(
                    "%Y-%m-%d"
                )
                if x["date"]
                else ""
            ),
        }
        for x in entries
    ])

    # --------------------------------------------------------
    # Fetch every RSS article
    # --------------------------------------------------------

    results = []

    for item in entries[
        :MAX_PER_SOURCE * 2
    ]:

        content, article_date = (
            fetch_generic_article_content(
                item["url"],
                "PIB"
            )
        )

        if not content:

            print(
                f"⚠️ DEBUG PIB NO ARTICLE CONTENT | "
                f"{item['title'][:120]}"
            )

            continue

        final_date = (
            article_date
            or parse_date(
                item["date"]
            )
        )

        obj = make_item(
            source="PIB",
            title=item["title"],
            url=item["url"],
            date=final_date,
            content=content,
            item_type="RSS + Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ PIB usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR
# ============================================================

NEWS_ON_AIR_URLS = [

    "https://newsonair.gov.in/",

    "https://newsonair.gov.in/category/news/",

    "https://newsonair.gov.in/category/national-news/",

]


def scrape_news_on_air():

    print("\n")
    print("=" * 70)
    print("📻 NEWS ON AIR")
    print("=" * 70)

    candidates = []

    for page_url in NEWS_ON_AIR_URLS:

        print(
            f"🔎 Listing: {page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 25
            ):
                continue

            if "newsonair.gov.in" not in href:
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    # --------------------------------------------------------
    # Unique
    # --------------------------------------------------------

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 News On AIR candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "News On AIR"
            )
        )

        if not content:

            warn(
                f"DEBUG AIR NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="News On AIR",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ News On AIR usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# CMO BIHAR
# ============================================================

CMO_URLS = [

    "https://cm.bihar.gov.in/users/preessrelease.aspx",

    "https://cm.bihar.gov.in/",

]


def scrape_cmo_bihar():

    print("\n")
    print("=" * 70)
    print("🏛️ CMO BIHAR")
    print("=" * 70)

    candidates = []

    for page_url in CMO_URLS:

        print(
            f"🔎 CMO Listing: {page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 20
            ):
                continue

            if "cm.bihar.gov.in" not in href:
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
                    "feedback",
                    "sitemap",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 CMO candidate articles: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "CMO Bihar"
            )
        )

        if not content:

            warn(
                f"DEBUG CMO NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="CMO Bihar",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Press Release"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ CMO Bihar usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# IPRD BIHAR
# ============================================================

IPRD_PAGES = [

    "https://state.bihar.gov.in/prdbihar/",

    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931",

    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930",

    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=6996",

]


def scrape_iprd_bihar():

    print("\n")
    print("=" * 70)
    print("📢 IPRD BIHAR")
    print("=" * 70)

    candidates = []

    for page_url in IPRD_PAGES:

        print(
            f"🔎 IPRD Listing: {page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 25
            ):
                continue

            if "state.bihar.gov.in/prdbihar" not in href.lower():
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
                    "accessibility",
                    "previous",
                    "next",
                    "department",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 IPRD candidate articles: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        print(
            f"🔍 IPRD checking: "
            f"{title[:100]}"
        )

        content, date = (
            fetch_generic_article_content(
                url,
                "IPRD Bihar"
            )
        )

        if not content:

            warn(
                f"DEBUG IPRD NO ARTICLE CONTENT | "
                f"{title[:120]}"
            )

            continue

        # Reject huge portal/archive pages
        if len(content) > 150000:

            warn(
                f"DEBUG IPRD PORTAL/ARCHIVE TOO LARGE | "
                f"{len(content)} chars | "
                f"{title[:100]}"
            )

            continue

        if date and not recent_enough(
            date,
            7
        ):

            debug(
                f"IPRD OLD ARTICLE SKIPPED | "
                f"{date.date()} | "
                f"{title[:100]}"
            )

            continue

        obj = make_item(
            source="IPRD Bihar",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Press Release"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ IPRD Bihar usable: "
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

    print("\n")
    print("=" * 70)
    print("🏛️ BIHAR CABINET")
    print("=" * 70)

    candidates = []

    for page_url in CABINET_PAGES:

        print(
            f"🔎 Cabinet Listing: "
            f"{page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 20
            ):
                continue

            if "state.bihar.gov.in/csd" not in href.lower():
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
                    "approved",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 Cabinet candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "Bihar Cabinet"
            )
        )

        if not content:

            warn(
                f"DEBUG CABINET NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="Bihar Cabinet",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Cabinet Decision"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ Bihar Cabinet usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SANSAD TV
# ============================================================

SANSAD_PAGES = [

    "https://sansadtv.nic.in/",

    "https://sansadtv.nic.in/show_type/sansad-mein-aaj",

    "https://sansadtv.nic.in/category/news",

]


def scrape_sansad_tv():

    print("\n")
    print("=" * 70)
    print("📺 SANSAD TV")
    print("=" * 70)

    candidates = []

    for page_url in SANSAD_PAGES:

        print(
            f"\n🔎 Listing: {page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 20
            ):
                continue

            if "sansadtv.nic.in" not in href:
                continue

            low = title.lower()

            if any(
                x in low
                for x in [
                    "home",
                    "login",
                    "contact",
                    "privacy",
                    "terms",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 Sansad TV unique candidate articles: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "Sansad TV"
            )
        )

        if not content:

            warn(
                f"DEBUG SANSAD NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="Sansad TV",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ Sansad TV usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PTI
# ============================================================

PTI_PAGES = [

    "https://www.ptinews.com/",

    "https://www.ptinews.com/latest-news",

    "https://www.ptinews.com/category/national",

]


def scrape_pti():

    print("\n")
    print("=" * 70)
    print("📰 PTI")
    print("=" * 70)

    candidates = []

    for page_url in PTI_PAGES:

        print(
            f"🔎 PTI Listing: "
            f"{page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 25
            ):
                continue

            if "ptinews.com" not in href:
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 PTI candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "PTI"
            )
        )

        if not content:

            warn(
                f"DEBUG PTI NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="PTI",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="PTI Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ PTI usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PRS INDIA
# ============================================================

PRS_PAGES = [

    "https://prsindia.org/",

    "https://prsindia.org/latest-updates",

    "https://prsindia.org/theprsblog",

]


def scrape_prs():

    print("\n")
    print("=" * 70)
    print("🏛️ PRS INDIA")
    print("=" * 70)

    candidates = []

    for page_url in PRS_PAGES:

        print(
            f"🔎 PRS Listing: "
            f"{page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 20
            ):
                continue

            if "prsindia.org" not in href:
                continue

            low = title.lower()

            if any(
                x in low
                for x in [
                    "home",
                    "about",
                    "contact",
                    "login",
                    "donate",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 PRS candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "PRS India"
            )
        )

        if not content:

            warn(
                f"DEBUG PRS NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="PRS India",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="PRS Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ PRS India usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# INDIA.GOV.IN
# ============================================================

INDIA_GOV_PAGES = [

    "https://www.india.gov.in/",

    "https://www.india.gov.in/news",

    "https://www.india.gov.in/spotlight",

]


def scrape_india_gov():

    print("\n")
    print("=" * 70)
    print("🇮🇳 INDIA.GOV.IN")
    print("=" * 70)

    candidates = []

    for page_url in INDIA_GOV_PAGES:

        print(
            f"🔎 India.gov.in Listing: "
            f"{page_url}"
        )

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = clean_url(
                urljoin(
                    page_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                not href
                or len(title) < 25
            ):
                continue

            if "india.gov.in" not in href:
                continue

            low = title.lower()

            if any(
                x in low
                for x in [
                    "home",
                    "about",
                    "contact",
                    "feedback",
                    "sitemap",
                    "login",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []

    seen = set()

    for title, url in candidates:

        if url in seen:
            continue

        seen.add(url)

        unique.append(
            (
                title,
                url
            )
        )

    print(
        f"🔗 India.gov.in candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, url in unique:

        content, date = (
            fetch_generic_article_content(
                url,
                "India.gov.in"
            )
        )

        if not content:

            warn(
                f"DEBUG INDIA.GOV NO CONTENT | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(
            source="India.gov.in",
            title=title,
            url=url,
            date=date,
            content=content,
            item_type="Government Article"
        )

        if obj:
            results.append(obj)

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ India.gov.in usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SOURCE RUNNER
# ============================================================

def safe_source(
    name,
    function
):

    try:

        return function()

    except Exception as e:

        print(
            f"\n❌ {name} SCRAPER ERROR:"
        )

        print(
            repr(e)
        )

        return []


# ============================================================
# BUILD ALL NEWS
# ============================================================

def build_news():

    print("\n")
    print("=" * 80)
    print("🚀 STARTING ALL NEWS SOURCES")
    print("=" * 80)

    all_results = []

    source_results = {}

    # ========================================================
    # EVERY SOURCE IS ALWAYS RUN
    # NO FALLBACK DROPS ANY SOURCE
    # ========================================================

    source_results["PIB"] = safe_source(
        "PIB",
        scrape_pib
    )

    source_results["News On AIR"] = safe_source(
        "News On AIR",
        scrape_news_on_air
    )

    source_results["CMO Bihar"] = safe_source(
        "CMO Bihar",
        scrape_cmo_bihar
    )

    source_results["IPRD Bihar"] = safe_source(
        "IPRD Bihar",
        scrape_iprd_bihar
    )

    source_results["Bihar Cabinet"] = safe_source(
        "Bihar Cabinet",
        scrape_bihar_cabinet
    )

    source_results["Sansad TV"] = safe_source(
        "Sansad TV",
        scrape_sansad_tv
    )

    source_results["PTI"] = safe_source(
        "PTI",
        scrape_pti
    )

    source_results["PRS India"] = safe_source(
        "PRS India",
        scrape_prs
    )

    source_results["India.gov.in"] = safe_source(
        "India.gov.in",
        scrape_india_gov
    )

    # ========================================================
    # SOURCE BREAKDOWN
    # ========================================================

    breakdown = {}

    for source, items in source_results.items():

        items = deduplicate(
            items
        )

        source_results[source] = items

        breakdown[source] = len(
            items
        )

        all_results.extend(
            items
        )

    all_results = deduplicate(
        all_results
    )

    # ========================================================
    # SEPARATE BIHAR / NATIONAL
    # ========================================================

    bihar_sources = {
        "CMO Bihar",
        "IPRD Bihar",
        "Bihar Cabinet",
    }

    bihar = []

    national = []

    for item in all_results:

        source = item.get(
            "source",
            ""
        )

        if source in bihar_sources:

            bihar.append(
                item
            )

        else:

            national.append(
                item
            )

    # ========================================================
    # FINAL REPORT
    # ========================================================

    print("\n")
    print("=" * 80)
    print("📊 FINAL SOURCE BREAKDOWN")
    print("=" * 80)

    print(
        json.dumps(
            breakdown,
            ensure_ascii=False,
            indent=2
        )
    )

    print(
        f"\n🇮🇳 National / Other : "
        f"{len(national)}"
    )

    print(
        f"🏛️ Bihar             : "
        f"{len(bihar)}"
    )

    print(
        f"📰 Total              : "
        f"{len(all_results)}"
    )

    # ========================================================
    # SOURCES THAT RETURNED ZERO
    # ========================================================

    print("\n⚠️ SOURCE ZERO REPORT")

    for source, count in breakdown.items():

        if count == 0:

            print(
                f"❌ {source}: 0"
            )

        else:

            print(
                f"✅ {source}: {count}"
            )

    return (
        national,
        bihar,
        breakdown
    )


# ============================================================
# SAVE
# ============================================================

def save_output(
    national,
    bihar,
    breakdown
):

    all_news = (
        national
        + bihar
    )

    output = {

        "generated_at":
            now_ist().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "bihar_raw_count":
            len(bihar),

        "national_raw_count":
            len(national),

        "total_raw_count":
            len(all_news),

        "bihar_raw_news":
            bihar,

        "national_raw_news":
            national,

        "source_breakdown":
            breakdown,
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

    print("\n")
    print("=" * 80)
    print(
        f"💾 {OUTPUT_FILE} saved"
    )
    print(
        f"📦 Total records: "
        f"{len(all_news)}"
    )
    print("=" * 80)


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":

    try:

        national, bihar, breakdown = (
            build_news()
        )

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
            "\n❌ FATAL ERROR:"
        )

        print(
            repr(e)
        )

        raise
