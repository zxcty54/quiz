import os
import re
import json
import time
import hashlib
import warnings
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

TIMEOUT = 25

# Maximum articles saved from each source
MAX_PER_SOURCE = 15

# Hard content limit
MAX_CONTENT_WORDS = 1500

# A valid article should normally have at least this much content.
MIN_CONTENT_CHARS = 500
MIN_CONTENT_WORDS = 80

# Recent article window.
# Some official sources publish late, so keep a 3-day window.
RECENT_DAYS = 3

# For sources where publication date is not easily available.
ALLOW_UNDATED = True

SLEEP_BETWEEN_REQUESTS = 0.15


IST = timezone(timedelta(hours=5, minutes=30))


# ============================================================
# HEADERS
# ============================================================

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
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
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
MIN_RECENT_DATE = TODAY - timedelta(days=RECENT_DAYS)


# ============================================================
# DEBUG
# ============================================================

def debug(message):
    print(message, flush=True)


def debug_fetch(source, url):
    debug(f"\n🔍 {source} FETCH: {url}")


# ============================================================
# URL CLEANING
# ============================================================

def clean_url(url):
    if not url:
        return ""

    url = str(url).strip()

    # Markdown link:
    # [text](https://example.com)
    m = re.search(
        r"\]\((https?://[^)]+)\)",
        url
    )

    if m:
        url = m.group(1)

    # Remove markdown wrapper
    url = re.sub(
        r"^\[.*?\]\(",
        "",
        url
    )

    url = re.sub(
        r"\)$",
        "",
        url
    )

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
# TEXT CLEANING
# ============================================================

def clean_text(text):
    if not text:
        return ""

    try:
        text = BeautifulSoup(
            str(text),
            "html.parser"
        ).get_text(
            " ",
            strip=True
        )
    except Exception:
        text = str(text)

    text = text.replace("\xa0", " ")
    text = text.replace("\u200b", " ")
    text = text.replace("\ufeff", " ")

    # Remove encoded junk
    text = re.sub(
        r"[\x00-\x08\x0b\x0c\x0e-\x1f]",
        " ",
        text
    )

    text = re.sub(
        r"\s+",
        " ",
        text
    )

    return text.strip()


def clean_title(title):
    title = clean_text(title)

    title = re.sub(
        r"\s*[-|–—]\s*"
        r"(PIB|Press Information Bureau|News On AIR)"
        r".*$",
        "",
        title,
        flags=re.I
    )

    return title.strip()


# ============================================================
# WORD LIMIT
# ============================================================

def limit_words(text, max_words=MAX_CONTENT_WORDS):
    text = clean_text(text)

    if not text:
        return ""

    words = text.split()

    if len(words) <= max_words:
        return text

    return " ".join(
        words[:max_words]
    )


# ============================================================
# CONTENT QUALITY
# ============================================================

PORTAL_BOILERPLATE = [
    "accessibility options",
    "skip to main content",
    "screen reader access",
    "site map",
    "sitemap",
    "web information manager",
    "website information manager",
    "help web information manager",
    "copyright",
    "all rights reserved",
    "privacy policy",
    "terms and conditions",
    "feedback",
    "contact us",
    "login",
    "register",
    "previous next",
    "previous | next",
    "previousnext",
    "search",
    "home about us",
    "read more",
    "know more",
    "quick links",
    "important links",
]


def boilerplate_score(text):
    if not text:
        return 999

    low = text.lower()

    score = 0

    for pattern in PORTAL_BOILERPLATE:
        if pattern in low:
            score += 1

    return score


def is_portal_garbage(text):
    if not text:
        return True

    score = boilerplate_score(text)

    if score >= 5:
        return True

    return False


def content_quality(text):
    """
    Returns:
        valid, reason
    """

    text = clean_text(text)

    if not text:
        return False, "EMPTY"

    words = text.split()

    chars = len(text)

    if chars < MIN_CONTENT_CHARS and len(words) < MIN_CONTENT_WORDS:
        return False, (
            f"CONTENT_TOO_SHORT_"
            f"{chars}_CHARS_"
            f"{len(words)}_WORDS"
        )

    if is_portal_garbage(text):
        return False, (
            f"PORTAL_BOILERPLATE_SCORE_"
            f"{boilerplate_score(text)}"
        )

    return True, "OK"


# ============================================================
# REMOVE COMMON BOILERPLATE
# ============================================================

def remove_common_boilerplate(text):
    if not text:
        return ""

    patterns = [

        r"We have tried to put most accurate.*?$",

        r"Help Web Information Manager.*?$",

        r"Copyright.*?$",

        r"All Rights Reserved.*?$",

        r"©.*?$",
    ]

    for pattern in patterns:
        text = re.sub(
            pattern,
            "",
            text,
            flags=re.I
        )

    # Remove repeated navigation phrases
    replacements = [
        "Previous Next",
        "Previous | Next",
        "Next Previous",
    ]

    for x in replacements:
        text = text.replace(
            x,
            " "
        )

    return clean_text(text)


# ============================================================
# FETCH ENGINE
# ============================================================

def fetch_url(
    url,
    timeout=TIMEOUT,
    source="UNKNOWN",
    allow_ssl_fallback=True
):

    url = clean_url(url)

    if not url:
        return None

    debug_fetch(
        source,
        url
    )

    time.sleep(
        SLEEP_BETWEEN_REQUESTS
    )

    # --------------------------------------------------------
    # 1. curl_cffi normal
    # --------------------------------------------------------

    try:

        r = requests.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            impersonate="chrome",
            allow_redirects=True,
            verify=True,
        )

        if r.status_code == 404:
            debug(
                f"⚠️ HTTP 404: {url}"
            )
            return None

        if r.status_code >= 400:
            debug(
                f"⚠️ HTTP {r.status_code}: {url}"
            )
        else:
            if r.text and len(r.text) > 100:
                return r.text

    except Exception as e:

        error = str(e)

        debug(
            f"⚠️ CURL failed: {url} | {error}"
        )

        # SSL-specific retry
        if (
            allow_ssl_fallback
            and (
                "certificate" in error.lower()
                or "ssl" in error.lower()
                or "curl: (60)" in error.lower()
            )
        ):

            debug(
                f"🔍 Retrying with SSL "
                f"verification disabled: {url}"
            )

            try:

                r = requests.get(
                    url,
                    headers=HEADERS,
                    timeout=timeout,
                    impersonate="chrome",
                    allow_redirects=True,
                    verify=False,
                )

                if r.status_code == 404:
                    debug(
                        f"⚠️ HTTP 404 after SSL retry: {url}"
                    )
                    return None

                if r.status_code < 400:
                    if r.text and len(r.text) > 100:
                        return r.text

            except Exception as e2:

                debug(
                    f"⚠️ SSL fallback failed: "
                    f"{url} | {e2}"
                )

    # --------------------------------------------------------
    # 2. Normal requests fallback
    # --------------------------------------------------------

    try:

        r = requests.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            allow_redirects=True,
            verify=True,
        )

        if r.status_code == 404:
            debug(
                f"⚠️ REQUESTS HTTP 404: {url}"
            )
            return None

        if r.status_code < 400:

            if r.text and len(r.text) > 100:
                return r.text

    except Exception as e:

        debug(
            f"⚠️ REQUESTS failed: "
            f"{url} | {e}"
        )

        if allow_ssl_fallback:

            debug(
                f"🔍 Retrying normal requests "
                f"verify=False: {url}"
            )

            try:

                r = requests.get(
                    url,
                    headers=HEADERS,
                    timeout=timeout,
                    allow_redirects=True,
                    verify=False,
                )

                if r.status_code == 404:
                    debug(
                        f"⚠️ REQUESTS HTTP 404: {url}"
                    )
                    return None

                if r.status_code < 400:

                    if r.text and len(r.text) > 100:
                        return r.text

            except Exception as e2:

                debug(
                    f"⚠️ REQUESTS SSL fallback failed: "
                    f"{url} | {e2}"
                )

    return None


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

    "%B %d, %Y",

    "%b %d, %Y",
]


def parse_date(value):

    if not value:
        return None

    value = clean_text(value)

    # RFC
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
        r"\b(IST|GMT|UTC)\b",
        "",
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

    # Search date inside text
    patterns = [

        r"\b\d{1,2}[-/]\d{1,2}[-/]\d{4}\b",

        r"\b\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4}\b",

        r"\b\d{4}-\d{2}-\d{2}\b",

        r"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b",

        r"\b[A-Za-z]{3,9}\s+\d{1,2},\s+\d{4}\b",
    ]

    for pattern in patterns:

        m = re.search(
            pattern,
            value
        )

        if not m:
            continue

        for fmt in DATE_FORMATS:

            try:

                d = datetime.strptime(
                    m.group(0),
                    fmt
                )

                if d.tzinfo is None:
                    d = d.replace(
                        tzinfo=IST
                    )

                return d.astimezone(IST)

            except Exception:
                continue

    return None


# ============================================================
# DATE FROM URL
# ============================================================

MONTHS = {
    "january": 1,
    "february": 2,
    "march": 3,
    "april": 4,
    "may": 5,
    "june": 6,
    "july": 7,
    "august": 8,
    "september": 9,
    "october": 10,
    "november": 11,
    "december": 12,
}


def extract_date_from_url(url):

    if not url:
        return None

    decoded = unquote(
        url.lower()
    )

    # 16-march-2026
    m = re.search(
        r"(\d{1,2})[-_/]"
        r"(january|february|march|april|may|june|july|"
        r"august|september|october|november|december)"
        r"[-_/](\d{4})",
        decoded
    )

    if m:

        try:

            return datetime(
                int(m.group(3)),
                MONTHS[m.group(2)],
                int(m.group(1)),
                tzinfo=IST
            )

        except Exception:
            pass

    # 2026-03-16
    m = re.search(
        r"(\d{4})[-_/]"
        r"(\d{1,2})[-_/]"
        r"(\d{1,2})",
        decoded
    )

    if m:

        try:

            return datetime(
                int(m.group(1)),
                int(m.group(2)),
                int(m.group(3)),
                tzinfo=IST
            )

        except Exception:
            pass

    # 16-03-2026
    m = re.search(
        r"(\d{1,2})[-_/]"
        r"(\d{1,2})[-_/]"
        r"(\d{4})",
        decoded
    )

    if m:

        try:

            return datetime(
                int(m.group(3)),
                int(m.group(2)),
                int(m.group(1)),
                tzinfo=IST
            )

        except Exception:
            pass

    return None


# ============================================================
# DATE FROM HTML
# ============================================================

def extract_date_from_soup(soup):

    selectors = [

        "time",

        "meta[property='article:published_time']",

        "meta[property='article:modified_time']",

        "meta[name='publish-date']",

        "meta[name='published-date']",

        "meta[name='date']",

        "meta[name='DC.date']",

        "meta[itemprop='datePublished']",

        "meta[itemprop='dateCreated']",

        "meta[name='dcterms.date']",

        ".date",

        ".published",

        ".publish-date",

        ".publication-date",

        ".news-date",

        ".article-date",

        ".post-date",

    ]

    for selector in selectors:

        try:

            elements = soup.select(
                selector
            )

        except Exception:
            continue

        for el in elements:

            value = (
                el.get("content")
                or el.get("datetime")
                or el.get("value")
                or el.get_text(
                    " ",
                    strip=True
                )
            )

            d = parse_date(
                value
            )

            if d:
                return d

    # visible date fallback
    text = soup.get_text(
        " ",
        strip=True
    )

    patterns = [

        r"\b\d{1,2}-[A-Za-z]{3}-\d{4}\b",

        r"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b",

        r"\b\d{1,2}/\d{1,2}/\d{4}\b",

        r"\b[A-Za-z]{3,9}\s+\d{1,2},\s+\d{4}\b",
    ]

    for pattern in patterns:

        m = re.search(
            pattern,
            text
        )

        if m:

            d = parse_date(
                m.group(0)
            )

            if d:
                return d

    return None


# ============================================================
# REMOVE HTML NOISE
# ============================================================

def remove_noise(soup):

    # Never keep these as article text
    tags = [

        "script",
        "style",
        "noscript",
        "svg",
        "iframe",
        "canvas",

        "nav",
        "footer",
        "header",

        "form",

        "aside",

        "noscript",

    ]

    for tag in soup(tags):

        try:
            tag.decompose()
        except Exception:
            pass

    # Remove common UI classes
    bad_keywords = [

        "navigation",
        "navbar",
        "menu",
        "sidebar",
        "footer",
        "header",
        "breadcrumb",
        "social",
        "share",
        "advert",
        "advertisement",
        "cookie",
        "popup",
        "modal",
        "related",
        "comment",
        "comments",
        "newsletter",
        "login",
        "accessibility",
    ]

    for element in soup.find_all(
        True
    ):

        classes = " ".join(
            element.get("class", [])
        ).lower()

        element_id = (
            element.get("id", "")
            or ""
        ).lower()

        combined = (
            classes + " " + element_id
        )

        if any(
            key in combined
            for key in bad_keywords
        ):

            try:
                element.decompose()
            except Exception:
                pass

    return soup


# ============================================================
# EXTRACT ARTICLE CONTENT
# ============================================================

ARTICLE_SELECTORS = [

    "article",

    "[itemprop='articleBody']",

    "[itemprop='text']",

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

    ".entry-content",

    ".post-content",

    ".postContent",

    ".content-area",

    ".main-content",

    ".mainContent",

    ".single-content",

    ".page-content",

    ".details",

    ".detail",

    "main",
]


def extract_candidate_blocks(soup):

    candidates = []

    for selector in ARTICLE_SELECTORS:

        try:

            elements = soup.select(
                selector
            )

        except Exception:
            continue

        for el in elements:

            # Do not destroy original soup here
            txt = clean_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if not txt:
                continue

            candidates.append(
                txt
            )

    # Paragraph fallback
    paragraphs = []

    try:

        for p in soup.find_all("p"):

            txt = clean_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 35:

                paragraphs.append(
                    txt
                )

    except Exception:
        pass

    if paragraphs:

        candidates.append(
            " ".join(
                paragraphs
            )
        )

    return candidates


def fetch_article_content(
    url,
    source="UNKNOWN",
    title=""
):

    url = clean_url(
        url
    )

    if not url:
        return "", None

    html = fetch_url(
        url,
        source=source
    )

    if not html:

        debug(
            f"⚠️ DEBUG NO HTML | "
            f"{source} | {url}"
        )

        return "", None

    try:

        soup = BeautifulSoup(
            html,
            "lxml"
        )

    except Exception:

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

    date = extract_date_from_soup(
        soup
    )

    if not date:

        date = extract_date_from_url(
            url
        )

    soup = remove_noise(
        soup
    )

    candidates = extract_candidate_blocks(
        soup
    )

    if not candidates:

        debug(
            f"⚠️ DEBUG NO CONTENT | "
            f"{source} | {url}"
        )

        return "", date

    # Remove duplicates
    unique = []

    seen = set()

    for candidate in candidates:

        candidate = remove_common_boilerplate(
            candidate
        )

        if not candidate:
            continue

        key = hashlib.sha1(
            candidate[:3000].encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if key in seen:
            continue

        seen.add(key)
        unique.append(
            candidate
        )

    if not unique:

        debug(
            f"⚠️ DEBUG NO CLEAN CONTENT | "
            f"{source} | {url}"
        )

        return "", date

    # Longest candidate is generally article body
    content = max(
        unique,
        key=len
    )

    content = remove_common_boilerplate(
        content
    )

    valid, reason = content_quality(
        content
    )

    if not valid:

        debug(
            f"⚠️ DEBUG {source} "
            f"CONTENT REJECTED | "
            f"{reason} | {title[:100]}"
        )

        return "", date

    original_words = len(
        content.split()
    )

    content = limit_words(
        content,
        MAX_CONTENT_WORDS
    )

    debug(
        f"✅ {source} CONTENT FOUND | "
        f"{len(content)} chars | "
        f"{len(content.split())} words"
        f"{' | TRUNCATED' if original_words > MAX_CONTENT_WORDS else ''}"
    )

    return content, date


# ============================================================
# RECENT DATE FILTER
# ============================================================

def is_recent(
    date,
    allow_undated=True,
    max_days=RECENT_DAYS
):

    if not date:

        return allow_undated

    article_date = date.date()

    age = (
        TODAY - article_date
    ).days

    if age < 0:

        # Future date usually means
        # bad website metadata.
        return True

    return age <= max_days


def debug_old(
    source,
    title,
    date
):

    if not date:
        return

    age = (
        TODAY - date.date()
    ).days

    debug(
        f"⚠️ DEBUG {source} OLD ARTICLE | "
        f"{date.date()} | "
        f"Age: {age} days | "
        f"{title[:100]}"
    )


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

    if not title:
        return None

    if not url:
        return None

    if not content:

        debug(
            f"⚠️ DEBUG NO CONTENT ITEM | "
            f"{source} | {title}"
        )

        return None

    valid, reason = content_quality(
        content
    )

    if not valid:

        debug(
            f"⚠️ DEBUG {source} REJECTED | "
            f"{reason} | {title}"
        )

        return None

    content = limit_words(
        content
    )

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

        "content_chars": len(
            content
        ),

        "content_words": len(
            content.split()
        ),

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
        r"[^a-z0-9\u0900-\u097f]+",
        " ",
        text
    )

    return text.strip()


def deduplicate(items):

    seen_urls = set()
    seen_content = set()

    output = []

    dropped = 0

    for item in items:

        url = clean_url(
            item.get(
                "url",
                ""
            )
        )

        title = item.get(
            "title",
            ""
        )

        content = item.get(
            "content",
            ""
        )

        url_key = url.lower()

        content_key = hashlib.sha1(
            normalize_for_hash(
                content[:3000]
            ).encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if (
            url_key in seen_urls
            or content_key in seen_content
        ):

            dropped += 1
            continue

        seen_urls.add(
            url_key
        )

        seen_content.add(
            content_key
        )

        output.append(
            item
        )

    debug(
        f"🧹 Deduplication: "
        f"Input={len(items)} | "
        f"Dropped={dropped} | "
        f"Unique={len(output)}"
    )

    return output


# ============================================================
# PIB
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


def resolve_pib_article_url(
    url
):

    url = clean_url(
        url
    )

    if not url:
        return ""

    # Already correct article
    if (
        "PressReleasePage.aspx"
        in url
    ):

        return url

    # RSS often provides
    # PressReleaseIframePage.aspx?PRID=xxxx
    m = re.search(
        r"PRID=(\d+)",
        url,
        flags=re.I
    )

    if m:

        prid = m.group(1)

        return (
            "https://www.pib.gov.in/"
            "PressReleasePage.aspx?"
            f"PRID={prid}&reg=3&lang=1"
        )

    return url


def scrape_pib():

    debug(
        "\n================================================="
    )

    debug(
        "🇮🇳 PIB SCRAPER"
    )

    debug(
        "================================================="
    )

    candidates = []

    for feed_url in PIB_FEEDS:

        debug(
            f"🔎 PIB feed: {feed_url}"
        )

        raw = fetch_url(
            feed_url,
            source="PIB RSS"
        )

        if not raw:

            debug(
                "Found RSS items: 0"
            )

            continue

        try:

            parsed = feedparser.parse(
                raw
            )

            entries = (
                parsed.entries
                or []
            )

        except Exception as e:

            debug(
                f"⚠️ PIB feed parse error: {e}"
            )

            continue

        debug(
            f"Found RSS items: "
            f"{len(entries)}"
        )

        for entry in entries:

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

            link = resolve_pib_article_url(
                link
            )

            if not link:
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

            debug(
                "PIB RSS: "
                + (
                    date.strftime(
                        "%Y-%m-%d %H:%M"
                    )
                    if date
                    else "NO DATE"
                )
                + " | "
                + title[:100]
            )

            candidates.append({
                "title": title,
                "url": link,
                "date": date,
            })

    candidates = deduplicate([
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
            "content": "rss",
        }
        for x in candidates
    ])

    # Reparse date
    parsed_candidates = []

    for x in candidates:

        d = parse_date(
            x.get(
                "date",
                ""
            )
        )

        parsed_candidates.append({
            "title": x["title"],
            "url": x["url"],
            "date": d,
        })

    # Recent first
    dated = [
        x for x in parsed_candidates
        if x["date"]
        and is_recent(
            x["date"],
            allow_undated=False
        )
    ]

    undated = [
        x for x in parsed_candidates
        if not x["date"]
    ]

    dated.sort(
        key=lambda x: x["date"],
        reverse=True
    )

    selected = dated[
        :MAX_PER_SOURCE
    ]

    # Emergency fallback only when
    # RSS metadata is broken.
    if len(selected) < 5:

        debug(
            "⚠️ PIB recent RSS count low. "
            "Trying undated RSS candidates."
        )

        selected += undated[
            :MAX_PER_SOURCE - len(selected)
        ]

    results = []

    for item in selected:

        article_url = resolve_pib_article_url(
            item["url"]
        )

        content, article_date = (
            fetch_article_content(
                article_url,
                source="PIB",
                title=item["title"]
            )
        )

        final_date = (
            article_date
            or item["date"]
            or extract_date_from_url(
                article_url
            )
        )

        if final_date and not is_recent(
            final_date
        ):

            debug_old(
                "PIB",
                item["title"],
                final_date
            )

            continue

        if not content:

            debug(
                f"⚠️ DEBUG PIB NO ARTICLE CONTENT | "
                f"{item['title']}"
            )

            continue

        obj = make_item(
            source="PIB",
            title=item["title"],
            url=article_url,
            date=final_date,
            content=content,
            item_type="RSS + Article"
        )

        if obj:
            results.append(
                obj
            )

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    debug(
        f"✅ PIB usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR NATIONAL
# ============================================================

NEWS_ON_AIR_HOME = (
    "https://newsonair.gov.in/"
)


def scrape_news_on_air_national():

    debug(
        "\n================================================="
    )

    debug(
        "📻 NEWS ON AIR NATIONAL"
    )

    debug(
        "================================================="
    )

    html = fetch_url(
        NEWS_ON_AIR_HOME,
        source="News On AIR"
    )

    if not html:
        return []

    soup = BeautifulSoup(
        html,
        "lxml"
    )

    candidates = []

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = clean_url(
            urljoin(
                NEWS_ON_AIR_HOME,
                a.get("href")
            )
        )

        title = clean_title(
            a.get_text(
                " ",
                strip=True
            )
        )

        if not href:
            continue

        if len(title) < 25:
            continue

        low = title.lower()

        if any(
            x in low
            for x in [
                "cricket",
                "football",
                "tennis",
                "badminton",
                "sports",
            ]
        ):
            continue

        candidates.append(
            (
                title,
                href
            )
        )

    # URL dedup
    unique = []
    seen = set()

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        content, date = (
            fetch_article_content(
                href,
                source="News On AIR",
                title=title
            )
        )

        if date and not is_recent(
            date
        ):

            debug_old(
                "News On AIR",
                title,
                date
            )

            continue

        if not content:

            debug(
                f"⚠️ DEBUG AIR NO CONTENT | "
                f"{title}"
            )

            continue

        obj = make_item(
            source="News On AIR",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="News On AIR"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ News On AIR usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR BIHAR
# ============================================================

NEWS_ON_AIR_BIHAR_URLS = [

    "https://newsonair.gov.in/category/regional-news/",

    "https://newsonair.gov.in/category/bihar/",

    "https://newsonair.gov.in/",
]


BIHAR_KEYWORDS = [

    "bihar",
    "patna",
    "nitish",
    "samrat choudhary",
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
    "motihari",
    "east champaran",
    "west champaran",
    "betia",
    "araria",
    "katihar",
    "kishanganj",
    "saharsa",
    "supaul",
    "madhepura",
    "buxar",
    "bhojpur",
    "rohtas",
    "aurangabad",
    "jehanabad",
    "nalanda",
    "nawada",
    "jamui",
    "lakhisarai",
    "sheikhpura",
    "kaimur",
    "siwan",
    "gopalganj",
    "khagaria",
    "munger",
    "bankа",
]


def scrape_news_on_air_bihar():

    debug(
        "\n📻 NEWS ON AIR BIHAR"
    )

    results = []

    for page_url in NEWS_ON_AIR_BIHAR_URLS:

        if len(results) >= MAX_PER_SOURCE:
            break

        html = fetch_url(
            page_url,
            source="News On AIR Bihar"
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

            if len(results) >= MAX_PER_SOURCE:
                break

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

            if not href:
                continue

            if len(title) < 25:
                continue

            low = title.lower()

            if not any(
                key in low
                for key in BIHAR_KEYWORDS
            ):
                continue

            content, date = (
                fetch_article_content(
                    href,
                    source="News On AIR Bihar",
                    title=title
                )
            )

            if date and not is_recent(
                date
            ):

                debug_old(
                    "News On AIR Bihar",
                    title,
                    date
                )

                continue

            if not content:

                debug(
                    f"⚠️ DEBUG AIR BIHAR "
                    f"NO CONTENT | {title}"
                )

                continue

            obj = make_item(
                source="News On AIR Bihar",
                title=title,
                url=href,
                date=date,
                content=content,
                item_type="Regional News"
            )

            if obj:
                results.append(
                    obj
                )

    results = deduplicate(
        results
    )

    debug(
        f"✅ News On AIR Bihar usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# CMO BIHAR
# ============================================================

CMO_URL = (
    "https://cm.bihar.gov.in/"
    "users/preessrelease.aspx"
)


def scrape_cmo_bihar():

    debug(
        "\n================================================="
    )

    debug(
        "🏛️ CMO BIHAR"
    )

    debug(
        "================================================="
    )

    html = fetch_url(
        CMO_URL,
        source="CMO Bihar"
    )

    if not html:
        return []

    soup = BeautifulSoup(
        html,
        "lxml"
    )

    candidates = []

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = clean_url(
            urljoin(
                CMO_URL,
                a.get("href")
            )
        )

        title = clean_title(
            a.get_text(
                " ",
                strip=True
            )
        )

        if not href:
            continue

        if len(title) < 20:
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
                "accessibility",
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

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        content, date = (
            fetch_article_content(
                href,
                source="CMO Bihar",
                title=title
            )
        )

        if date and not is_recent(
            date
        ):

            debug_old(
                "CMO Bihar",
                title,
                date
            )

            continue

        if not content:

            debug(
                f"⚠️ DEBUG CMO NO CONTENT | "
                f"{title}"
            )

            continue

        obj = make_item(
            source="CMO Bihar",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="CMO Press Release"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ CMO Bihar usable news: "
        f"{len(results)}"
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
        "https://state.bihar.gov.in/prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=8931"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=8930"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=6996"
    ),
]


def is_iprd_bad_page(
    title,
    url,
    content=""
):

    low_title = title.lower()
    low_url = url.lower()

    # Known evergreen / portal sections
    bad_title_terms = [

        "accessibility",

        "total prohibition of alcohol",

        "physical and financial progress",

        "national highways,state highways",

        "communication sector in bihar gsdp",

        "impact assessment of total prohibition",

        "speech given by honourable governor",

        "state profile",

        "governance profile",

        "facts and figure",

        "order/circular/notification",

        "compendium of government circulars orders",

        "hindi translation of judgement/order",

        "empanelled cultural parties",
    ]

    for term in bad_title_terms:

        if term in low_title:

            return True, (
                f"IPRD_KNOWN_PORTAL_PAGE_{term}"
            )

    # Generic profile pages
    if "sectioninformation" in low_url:

        # Huge evergreen portal pages
        if content:

            words = len(
                content.split()
            )

            if words > 5000:

                return True, (
                    f"IPRD_CONTENT_TOO_LARGE_{words}"
                )

    return False, ""


def scrape_iprd_bihar():

    debug(
        "\n================================================="
    )

    debug(
        "📢 IPRD BIHAR"
    )

    debug(
        "================================================="
    )

    results = []

    for source, page_url in IPRD_PAGES:

        html = fetch_url(
            page_url,
            source="IPRD Bihar Listing"
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "lxml"
        )

        links = []

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

            if not href:
                continue

            if (
                "state.bihar.gov.in"
                not in href.lower()
            ):
                continue

            if len(title) < 20:
                continue

            links.append(
                (
                    title,
                    href
                )
            )

        # dedup links
        seen = set()

        unique_links = []

        for title, href in links:

            if href in seen:
                continue

            seen.add(
                href
            )

            unique_links.append(
                (
                    title,
                    href
                )
            )

        debug(
            f"🔎 IPRD candidate links: "
            f"{len(unique_links)}"
        )

        for title, href in unique_links:

            if len(results) >= MAX_PER_SOURCE:
                break

            debug(
                f"🔍 IPRD checking: "
                f"{title}"
            )

            # Early title filter
            bad, reason = is_iprd_bad_page(
                title,
                href
            )

            if bad:

                debug(
                    f"⚠️ DEBUG IPRD REJECTED | "
                    f"{reason} | {title}"
                )

                continue

            content, date = (
                fetch_article_content(
                    href,
                    source="IPRD Bihar",
                    title=title
                )
            )

            if not content:

                debug(
                    f"⚠️ DEBUG IPRD NO CONTENT | "
                    f"{title}"
                )

                continue

            bad, reason = is_iprd_bad_page(
                title,
                href,
                content
            )

            if bad:

                debug(
                    f"⚠️ DEBUG IPRD REJECTED | "
                    f"{reason} | {title}"
                )

                continue

            if date and not is_recent(
                date
            ):

                debug_old(
                    "IPRD Bihar",
                    title,
                    date
                )

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
                results.append(
                    obj
                )

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    debug(
        f"✅ IPRD Bihar usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# BIHAR CABINET
# ============================================================

CABINET_PAGES = [

    "https://state.bihar.gov.in/csd/",

    "https://state.bihar.gov.in/csd/"
    "CitizenHome.html",

    "https://state.bihar.gov.in/csd/"
    "SectionInformation.html?"
    "editForm&rowId=2929",

    "https://state.bihar.gov.in/csd/"
    "SectionInformation.html?"
    "editForm&rowId=1323",

    "https://state.bihar.gov.in/csd/"
    "SectionInformation.html?"
    "editForm&rowId=4935",
]


def scrape_bihar_cabinet():

    debug(
        "\n================================================="
    )

    debug(
        "🏛️ BIHAR CABINET"
    )

    debug(
        "================================================="
    )

    results = []

    for page_url in CABINET_PAGES:

        html = fetch_url(
            page_url,
            source="Bihar Cabinet Listing"
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

            if len(results) >= MAX_PER_SOURCE:
                break

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

            if not href:
                continue

            if (
                "state.bihar.gov.in/csd"
                not in href.lower()
            ):
                continue

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
                    "approved",
                    "meeting",
                    "resolution",
                ]
            ):
                continue

            content, date = (
                fetch_article_content(
                    href,
                    source="Bihar Cabinet",
                    title=title
                )
            )

            if date and not is_recent(
                date,
                max_days=7
            ):

                debug_old(
                    "Bihar Cabinet",
                    title,
                    date
                )

                continue

            if not content:

                debug(
                    f"⚠️ DEBUG CABINET "
                    f"NO CONTENT | {title}"
                )

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
                results.append(
                    obj
                )

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    debug(
        f"✅ Bihar Cabinet usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SANSAD TV
# ============================================================

SANSAD_PAGES = [

    "https://sansadtv.nic.in/",

    "https://sansadtv.nic.in/"
    "show_type/sansad-mein-aaj",

    "https://sansadtv.nic.in/"
    "category/news",
]


def is_sansad_old(
    title,
    url,
    date=None
):

    # HTML date
    if date:

        if not is_recent(
            date
        ):

            debug_old(
                "Sansad TV",
                title,
                date
            )

            return True

        return False

    # URL fallback
    url_date = extract_date_from_url(
        url
    )

    if url_date:

        if not is_recent(
            url_date
        ):

            debug_old(
                "Sansad TV",
                title,
                url_date
            )

            return True

    # Title fallback
    title_date = extract_date_from_url(
        title
    )

    if title_date:

        if not is_recent(
            title_date
        ):

            debug_old(
                "Sansad TV",
                title,
                title_date
            )

            return True

    return False


def scrape_sansad_tv():

    debug(
        "\n================================================="
    )

    debug(
        "📺 SANSAD TV"
    )

    debug(
        "================================================="
    )

    candidates = []

    for page_url in SANSAD_PAGES:

        html = fetch_url(
            page_url,
            source="Sansad TV Listing"
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

            if not href:
                continue

            if (
                "sansadtv.nic.in"
                not in href.lower()
            ):
                continue

            if len(title) < 15:
                continue

            # Article / episode only
            if not any(
                x in href.lower()
                for x in [
                    "/episode/",
                    "/news/",
                    "/show/",
                    "/video/",
                    "/program/",
                ]
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    # Dedup
    unique = []
    seen = set()

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    debug(
        f"🔗 Sansad TV unique candidate "
        f"articles: {len(unique)}"
    )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        # URL date first
        url_date = extract_date_from_url(
            href
        )

        if url_date and not is_recent(
            url_date
        ):

            debug_old(
                "Sansad TV",
                title,
                url_date
            )

            continue

        content, date = (
            fetch_article_content(
                href,
                source="Sansad TV",
                title=title
            )
        )

        final_date = (
            date
            or url_date
            or extract_date_from_url(
                title
            )
        )

        if is_sansad_old(
            title,
            href,
            final_date
        ):
            continue

        if not content:

            debug(
                f"⚠️ DEBUG SANSAD NO CONTENT | "
                f"{title}"
            )

            continue

        obj = make_item(
            source="Sansad TV",
            title=title,
            url=href,
            date=final_date,
            content=content,
            item_type="Sansad TV"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ Sansad TV usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PRS INDIA
# ============================================================

PRS_HOME = (
    "https://prsindia.org/"
)


PRS_LISTING_PAGES = [

    "https://prsindia.org/",

    "https://prsindia.org/bills",

    "https://prsindia.org/billtrack",

    "https://prsindia.org/theprsblog",

    "https://prsindia.org/parliament",

    "https://prsindia.org/state-legislatures",

    "https://prsindia.org/budgets",

    "https://prsindia.org/policy",

    "https://prsindia.org/committee-reports",

    "https://prsindia.org/parliamentary-committees",
]


def is_prs_bad_page(
    title,
    url
):

    low_title = title.lower()
    low_url = url.lower()

    # Directory / evergreen sections
    bad_exact = [

        "parliament committees",

        "parliamentary committees",

        "committee reports",

        "state legislatures",

        "bills",

        "bill track",

        "budgets",

        "policy",
    ]

    for term in bad_exact:

        if low_title.strip() == term:
            return True

    # Committee profile
    if (
        "/parliamentary-committees/"
        in low_url
    ):
        return True

    # Generic committee landing
    if (
        low_url.rstrip("/")
        in [
            "https://prsindia.org/"
            "parliament-committees",
            "https://prsindia.org/"
            "parliamentary-committees",
        ]
    ):
        return True

    return False


def prs_candidate_is_current(
    title,
    url
):

    low = (
        title + " " + url
    ).lower()

    current_indicators = [

        "/billtrack/",

        "/theprsblog/",

        "/parliament/",

        "/committee-reports/",

        "/policy/",

        "/budgets/",

        "/state-legislatures/",

        "bill",

        "act",

        "ordinance",

        "parliament",

        "committee report",

        "session",

        "policy",

        "budget",

        "report",

        "passed",

        "introduced",

        "lok sabha",

        "rajya sabha",
    ]

    return any(
        x in low
        for x in current_indicators
    )


def scrape_prs():

    debug(
        "\n================================================="
    )

    debug(
        "📚 PRS INDIA"
    )

    debug(
        "================================================="
    )

    candidates = []

    for listing_url in PRS_LISTING_PAGES:

        html = fetch_url(
            listing_url,
            source="PRS India Listing"
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
                    listing_url,
                    a.get("href")
                )
            )

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not href:
                continue

            if (
                "prsindia.org"
                not in href.lower()
            ):
                continue

            if len(title) < 20:
                continue

            if is_prs_bad_page(
                title,
                href
            ):
                continue

            if not prs_candidate_is_current(
                title,
                href
            ):
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    # Dedup
    unique = []
    seen = set()

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    debug(
        f"🔗 PRS unique candidates: "
        f"{len(unique)}"
    )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        debug(
            f"🔍 PRS India ARTICLE FETCH: "
            f"{href}"
        )

        content, date = (
            fetch_article_content(
                href,
                source="PRS India",
                title=title
            )
        )

        if not content:

            debug(
                f"⚠️ DEBUG PRS NO CONTENT | "
                f"{title}"
            )

            continue

        # Reject committee profiles / evergreen
        if is_prs_bad_page(
            title,
            href
        ):

            debug(
                f"⚠️ DEBUG PRS REJECTED "
                f"PROFILE/DIRECTORY | "
                f"{title}"
            )

            continue

        if date and not is_recent(
            date,
            max_days=14
        ):

            debug_old(
                "PRS India",
                title,
                date
            )

            continue

        obj = make_item(
            source="PRS India",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="PRS Current Affairs"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ PRS India usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PTI
# ============================================================

PTI_PAGES = [

    "https://www.ptinews.com/",

    "https://www.ptinews.com/latest-news",

]


def scrape_pti():

    debug(
        "\n================================================="
    )

    debug(
        "📰 PTI"
    )

    debug(
        "================================================="
    )

    candidates = []

    for page_url in PTI_PAGES:

        html = fetch_url(
            page_url,
            source="PTI Listing"
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

            if not href:
                continue

            if (
                "ptinews.com"
                not in href.lower()
            ):
                continue

            if len(title) < 25:
                continue

            candidates.append(
                (
                    title,
                    href
                )
            )

    unique = []
    seen = set()

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        content, date = (
            fetch_article_content(
                href,
                source="PTI",
                title=title
            )
        )

        if date and not is_recent(
            date
        ):

            debug_old(
                "PTI",
                title,
                date
            )

            continue

        if not content:

            debug(
                f"⚠️ DEBUG PTI NO CONTENT | "
                f"{title}"
            )

            continue

        obj = make_item(
            source="PTI",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="PTI"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ PTI usable: "
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

    debug(
        "\n================================================="
    )

    debug(
        "🇮🇳 INDIA.GOV.IN"
    )

    debug(
        "================================================="
    )

    candidates = []

    for page_url in INDIA_GOV_PAGES:

        html = fetch_url(
            page_url,
            source="India.gov.in Listing"
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

            if not href:
                continue

            if (
                "india.gov.in"
                not in href.lower()
            ):
                continue

            if len(title) < 25:
                continue

            low = title.lower()

            if any(
                x in low
                for x in [
                    "home",
                    "login",
                    "register",
                    "contact",
                    "sitemap",
                    "accessibility",
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

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(
            href
        )

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, href in unique:

        if len(results) >= MAX_PER_SOURCE:
            break

        content, date = (
            fetch_article_content(
                href,
                source="India.gov.in",
                title=title
            )
        )

        if date and not is_recent(
            date
        ):

            debug_old(
                "India.gov.in",
                title,
                date
            )

            continue

        if not content:

            debug(
                f"⚠️ DEBUG INDIA.GOV "
                f"NO CONTENT | {title}"
            )

            continue

        obj = make_item(
            source="India.gov.in",
            title=title,
            url=href,
            date=date,
            content=content,
            item_type="Government Portal"
        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    debug(
        f"✅ India.gov.in usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SOURCE SAFE RUNNER
# ============================================================

def safe_run(
    source_name,
    function
):

    try:

        result = function()

        if not isinstance(
            result,
            list
        ):
            return []

        return result

    except Exception as e:

        debug(
            f"\n❌ {source_name} "
            f"SCRAPER ERROR: {e}"
        )

        return []


# ============================================================
# BUILD NEWS
# ============================================================

def build_news():

    debug(
        "\n\n"
        "########################################################"
    )

    debug(
        "#              NEWS SCRAPER START                      #"
    )

    debug(
        "########################################################"
    )

    debug(
        f"📅 Today IST: {TODAY}"
    )

    debug(
        f"📅 Recent window: "
        f"{MIN_RECENT_DATE} → {TODAY}"
    )

    # ========================================================
    # NATIONAL SOURCES
    # ========================================================

    pib = safe_run(
        "PIB",
        scrape_pib
    )

    air_national = safe_run(
        "News On AIR",
        scrape_news_on_air_national
    )

    sansad = safe_run(
        "Sansad TV",
        scrape_sansad_tv
    )

    pti = safe_run(
        "PTI",
        scrape_pti
    )

    prs = safe_run(
        "PRS India",
        scrape_prs
    )

    india_gov = safe_run(
        "India.gov.in",
        scrape_india_gov
    )

    # ========================================================
    # BIHAR SOURCES
    # ========================================================

    cmo = safe_run(
        "CMO Bihar",
        scrape_cmo_bihar
    )

    iprd = safe_run(
        "IPRD Bihar",
        scrape_iprd_bihar
    )

    cabinet = safe_run(
        "Bihar Cabinet",
        scrape_bihar_cabinet
    )

    air_bihar = safe_run(
        "News On AIR Bihar",
        scrape_news_on_air_bihar
    )

    # ========================================================
    # DO NOT DROP ANY SOURCE
    # ========================================================

    national = (
        pib
        + air_national
        + sansad
        + pti
        + prs
        + india_gov
    )

    bihar = (
        cmo
        + iprd
        + cabinet
        + air_bihar
    )

    national = deduplicate(
        national
    )

    bihar = deduplicate(
        bihar
    )

    # ========================================================
    # SOURCE BREAKDOWN
    # ========================================================

    breakdown = {}

    for item in (
        national + bihar
    ):

        source = item.get(
            "source",
            "Unknown"
        )

        breakdown[source] = (
            breakdown.get(
                source,
                0
            ) + 1
        )

    # Make sure every requested
    # source appears even if zero.
    expected_sources = [

        "PIB",

        "News On AIR",

        "News On AIR Bihar",

        "CMO Bihar",

        "IPRD Bihar",

        "Bihar Cabinet Decision",

        "Sansad TV",

        "PRS India",

        "PTI",

        "India.gov.in",
    ]

    for source in expected_sources:

        breakdown.setdefault(
            source,
            0
        )

    # ========================================================
    # PRINT
    # ========================================================

    debug(
        "\n================================================="
    )

    debug(
        "📊 SOURCE BREAKDOWN"
    )

    debug(
        "================================================="
    )

    debug(
        json.dumps(
            breakdown,
            ensure_ascii=False,
            indent=2
        )
    )

    debug(
        f"\n🇮🇳 National News : "
        f"{len(national)}"
    )

    debug(
        f"🏛️ Bihar News    : "
        f"{len(bihar)}"
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

        "content_max_words":
            MAX_CONTENT_WORDS,

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

    size_mb = (
        os.path.getsize(
            OUTPUT_FILE
        ) / (
            1024 * 1024
        )
    )

    debug(
        "\n================================================="
    )

    debug(
        f"💾 {OUTPUT_FILE} updated successfully!"
    )

    debug(
        f"📦 File size: "
        f"{size_mb:.2f} MB"
    )

    debug(
        f"📰 Total items: "
        f"{len(all_news)}"
    )

    debug(
        "================================================="
    )


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

        debug(
            "\n⛔ Scraper stopped by user."
        )

    except Exception as e:

        debug(
            f"\n❌ FATAL ERROR: {e}"
        )

        raise
