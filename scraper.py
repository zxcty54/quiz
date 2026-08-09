import os
import re
import json
import time
import hashlib
import warnings
import html as html_lib
import feedparser

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, parse_qs, unquote

from curl_cffi import requests
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning


# ============================================================
# CONFIG
# ============================================================

OUTPUT_FILE = "rawnews.json"

TIMEOUT = 25
MAX_PER_SOURCE = 15

# Minimum real article content.
# Title is NEVER accepted as content.
MIN_CONTENT_CHARS = 180

# Maximum content accepted from an article page.
# Prevents IPRD portal/home pages from becoming giant JSON entries.
MAX_CONTENT_CHARS = 50000

# If a candidate is suspiciously large, reject it.
PORTAL_MAX_CHARS = 120000

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
# TIME
# ============================================================

IST = timezone(timedelta(hours=5, minutes=30))


def now_ist():
    return datetime.now(IST)


TODAY = now_ist().date()
YESTERDAY = TODAY - timedelta(days=1)


# ============================================================
# DEBUG
# ============================================================

def debug(msg):
    print(msg, flush=True)


def debug_content_failure(source, url, reason):
    debug(
        f"   ⚠️ DEBUG {source.upper()} NO CONTENT | "
        f"{reason} | {url}"
    )


# ============================================================
# URL
# ============================================================

def clean_url(url):
    if not url:
        return ""

    url = str(url).strip()

    # Markdown URL:
    # [text](https://example.com)
    m = re.search(
        r"\](https?://[^)]+)",
        url
    )

    if m:
        url = m.group(1)

    # Markdown wrapper
    url = re.sub(
        r"^.*?\(",
        "",
        url
    )

    if url.endswith(")"):
        url = url[:-1]

    url = html_lib.unescape(url)

    url = url.replace("\\&", "&")
    url = url.replace("\\:", ":")
    url = url.strip()

    if url.startswith(
        ("javascript:", "mailto:", "#")
    ):
        return ""

    if not url.startswith(
        ("http://", "https://")
    ):
        return ""

    return url


def same_domain(url, domain):
    try:
        host = urlparse(url).netloc.lower()
        return domain.lower() in host
    except Exception:
        return False


# ============================================================
# HTTP
# ============================================================

def fetch_url(url, timeout=TIMEOUT):
    url = clean_url(url)

    if not url:
        return None

    attempts = [
        {
            "impersonate": "chrome",
            "verify": True,
        },
        {
            "impersonate": "chrome",
            "verify": False,
        },
    ]

    last_error = None

    for attempt_no, options in enumerate(
        attempts,
        start=1
    ):

        try:

            r = requests.get(
                url,
                headers=HEADERS,
                timeout=timeout,
                allow_redirects=True,
                **options
            )

            if r.status_code >= 400:

                debug(
                    f"   ⚠️ HTTP {r.status_code}: {url}"
                )

                # Try second strategy only for server errors.
                if attempt_no == 1 and r.status_code >= 500:
                    continue

                return None

            text = r.text

            if not text:
                debug(
                    f"   ⚠️ EMPTY HTTP RESPONSE: {url}"
                )
                return None

            return text

        except Exception as e:

            last_error = e

            if attempt_no == 1:
                continue

    debug(
        f"   ⚠️ FETCH FAILED: {url} | {last_error}"
    )

    return None


# ============================================================
# TEXT
# ============================================================

def clean_text(text):
    if not text:
        return ""

    text = html_lib.unescape(str(text))

    soup = BeautifulSoup(
        text,
        "html.parser"
    )

    text = soup.get_text(
        " ",
        strip=True
    )

    text = html_lib.unescape(text)

    text = text.replace("\xa0", " ")
    text = text.replace("\u200b", "")
    text = text.replace("\ufeff", "")

    text = re.sub(
        r"\s+",
        " ",
        text
    )

    return text.strip()


def clean_title(title):
    title = clean_text(title)

    title = re.sub(
        r"\s*[-|–—]\s*(PIB|Press Information Bureau|News On AIR).*$",
        "",
        title,
        flags=re.I
    )

    return title.strip()


# ============================================================
# DATE
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

    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=IST)

        return value.astimezone(IST)

    value = clean_text(value)

    if not value:
        return None

    # feedparser RFC
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

    # Search date embedded in string.
    patterns = [
        r"\b\d{1,2}[-/]\d{1,2}[-/]\d{4}\b",
        r"\b\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4}\b",
        r"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b",
        r"\b[A-Za-z]{3,9}\s+\d{1,2},\s+\d{4}\b",
        r"\b\d{4}-\d{2}-\d{2}\b",
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
            "%d %b %Y",
            "%d %B %Y",
            "%B %d, %Y",
            "%b %d, %Y",
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
        "time",
        "meta[property='article:published_time']",
        "meta[property='article:modified_time']",
        "meta[name='publish-date']",
        "meta[name='date']",
        "meta[name='DC.date']",
        "meta[name='datePublished']",
        "meta[itemprop='datePublished']",
        "meta[itemprop='dateCreated']",
        ".date",
        ".published",
        ".publish-date",
        ".news-date",
        ".posted-date",
        ".entry-date",
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
                or el.get("data-date")
                or el.get_text(
                    " ",
                    strip=True
                )
            )

            d = parse_date(value)

            if d:
                return d

    text = soup.get_text(
        " ",
        strip=True
    )

    # PIB specific:
    # Posted On: 17 NOV 2024 5:30PM by PIB Delhi
    pib_patterns = [
        r"Posted\s*On\s*:\s*"
        r"(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}"
        r"(?:\s+\d{1,2}:\d{2}\s*(?:AM|PM))?)",

        r"प्रविष्टि\s*तिथि\s*:\s*"
        r"(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}"
        r"(?:\s+\d{1,2}:\d{2}\s*(?:AM|PM))?)",
    ]

    for pattern in pib_patterns:

        m = re.search(
            pattern,
            text,
            flags=re.I
        )

        if m:

            raw = m.group(1)

            for fmt in [
                "%d %b %Y %I:%M%p",
                "%d %b %Y %I:%M %p",
                "%d %b %Y",
            ]:

                try:

                    d = datetime.strptime(
                        raw,
                        fmt
                    )

                    return d.replace(
                        tzinfo=IST
                    )

                except Exception:
                    continue

    patterns = [
        r"\b\d{1,2}-[A-Za-z]{3}-\d{4}\b",
        r"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b",
        r"\b\d{1,2}/\d{1,2}/\d{4}\b",
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
# COMMON BOILERPLATE
# ============================================================

BOILERPLATE_PATTERNS = [
    "we have tried to put most accurate",
    "help web information manager",
    "feedback.commonportal",
    "copyright iprd",
    "website maintained by dreamline",
    "site owned by chief minister secretariat",
    "privacy policy",
    "copyright ©",
    "web information manager",
    "screen-reader",
    "screen reader",
    "visitor counter",
    "total visitors",
    "previous next",
]


def boilerplate_score(text):
    if not text:
        return 99

    low = text.lower()

    return sum(
        1
        for pattern in BOILERPLATE_PATTERNS
        if pattern in low
    )


def is_boilerplate(text):
    return boilerplate_score(text) >= 3


def remove_boilerplate_lines(text):
    if not text:
        return ""

    lines = re.split(
        r"(?<=[.!?।])\s+",
        text
    )

    cleaned = []

    bad_fragments = [
        "we have tried to put most accurate",
        "help web information manager",
        "feedback.commonportal",
        "website maintained by dreamline",
        "web information manager",
        "screen-reader",
        "privacy policy",
        "copyright iprd",
        "site owned by chief minister",
        "total visitors",
        "previous next",
    ]

    for line in lines:

        low = line.lower()

        if any(
            bad in low
            for bad in bad_fragments
        ):
            continue

        cleaned.append(line)

    return clean_text(
        " ".join(cleaned)
    )


# ============================================================
# CONTENT VALIDATION
# ============================================================

def validate_article_content(
    content,
    title="",
    source="",
    url=""
):

    content = clean_text(content)

    if not content:
        return "", "EMPTY"

    content = remove_boilerplate_lines(
        content
    )

    if not content:
        return "", "EMPTY_AFTER_CLEAN"

    if title:
        title_clean = normalize_for_hash(
            title
        )

        content_clean = normalize_for_hash(
            content
        )

        # If almost entire content is title,
        # reject it.
        if (
            len(content_clean) < 300
            and content_clean == title_clean
        ):
            return "", "TITLE_ONLY"

    if is_boilerplate(content):
        return "", (
            f"PORTAL_BOILERPLATE_SCORE_"
            f"{boilerplate_score(content)}"
        )

    if len(content) < MIN_CONTENT_CHARS:
        return "", (
            f"CONTENT_TOO_SHORT_{len(content)}"
        )

    if len(content) > PORTAL_MAX_CHARS:
        return "", (
            f"CONTENT_TOO_LARGE_{len(content)}"
        )

    # Hard truncate only legitimate long articles.
    if len(content) > MAX_CONTENT_CHARS:
        content = content[
            :MAX_CONTENT_CHARS
        ]

    return content, None


# ============================================================
# GENERIC ARTICLE EXTRACTOR
# ============================================================

def score_candidate(
    text,
    selector="",
    source="",
    title=""
):

    if not text:
        return -999

    length = len(text)

    score = 0

    if length >= MIN_CONTENT_CHARS:
        score += 10

    if length >= 500:
        score += 10

    if length >= 1000:
        score += 10

    if length > PORTAL_MAX_CHARS:
        score -= 100

    if length > MAX_CONTENT_CHARS:
        score -= 15

    if title:
        nt = normalize_for_hash(title)
        nc = normalize_for_hash(text)

        if nt and nc.startswith(nt):
            score += 3

    preferred = [
        "article",
        "articlebody",
        "article-body",
        "entry-content",
        "story-content",
        "news-content",
        "press-release",
        "pressrelease",
        "content",
        "main",
    ]

    low_selector = selector.lower()

    for p in preferred:

        if p in low_selector:
            score += 15
            break

    # Paragraph-like text is usually better than
    # giant navigation dumps.
    sentences = re.split(
        r"[.!?।]\s+",
        text
    )

    if len(sentences) >= 4:
        score += 10

    # Excessive portal boilerplate.
    score -= boilerplate_score(text) * 15

    return score


def generic_extract_from_soup(
    soup,
    title="",
    source=""
):

    # Work on a copy-like soup by removing dangerous tags.
    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "canvas",
        "iframe",
        "form",
        "nav",
        "footer",
        "aside",
    ]):
        tag.decompose()

    candidates = []

    selectors = [
        "article",
        "[itemprop='articleBody']",
        "[itemprop='articlebody']",
        ".article-body",
        ".articleBody",
        ".article-content",
        ".articleContent",
        ".entry-content",
        ".story-content",
        ".storyContent",
        ".news-content",
        ".newsContent",
        ".press-release",
        ".pressrelease",
        ".press-release-content",
        ".content-area",
        ".main-content",
        ".news-detail",
        ".news-details",
        ".detail-content",
        ".post-content",
        "main",
    ]

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

            if not txt:
                continue

            candidates.append(
                (
                    score_candidate(
                        txt,
                        selector,
                        source,
                        title
                    ),
                    txt,
                    selector
                )
            )

    # Paragraph strategy.
    paragraphs = []

    for p in soup.find_all("p"):

        txt = clean_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(txt) >= 35:
            paragraphs.append(txt)

    if paragraphs:

        # Remove duplicate paragraphs.
        seen = set()
        unique = []

        for p in paragraphs:

            key = normalize_for_hash(p)

            if key in seen:
                continue

            seen.add(key)
            unique.append(p)

        paragraph_text = " ".join(
            unique
        )

        candidates.append(
            (
                score_candidate(
                    paragraph_text,
                    "PARAGRAPH_SCORE",
                    source,
                    title
                ) + 20,
                paragraph_text,
                "PARAGRAPH_SCORE"
            )
        )

    if not candidates:
        return "", "NO_CANDIDATES"

    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    for score, text, method in candidates:

        cleaned, reason = validate_article_content(
            text,
            title=title,
            source=source
        )

        if cleaned:

            debug(
                f"   ✅ {source} CONTENT METHOD="
                f"{method} | chars={len(cleaned)} "
                f"| score={score}"
            )

            return cleaned, method

    return "", (
        f"ALL_CANDIDATES_REJECTED | "
        f"best={candidates[0][2]} "
        f"chars={len(candidates[0][1])}"
    )


def fetch_generic_article_content(
    url,
    title="",
    source=""
):

    url = clean_url(url)

    if not url:
        return "", None, "INVALID_URL"

    html = fetch_url(url)

    if not html:
        return "", None, "FETCH_FAILED"

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    date = extract_date_from_soup(
        soup
    )

    content, method = generic_extract_from_soup(
        soup,
        title=title,
        source=source
    )

    if content:
        return content, date, method

    return "", date, method


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
]


def extract_prid(url):

    try:
        qs = parse_qs(
            urlparse(url).query
        )

        values = qs.get("PRID")

        if values:
            return values[0]

    except Exception:
        pass

    m = re.search(
        r"PRID[=/](\d+)",
        url,
        flags=re.I
    )

    if m:
        return m.group(1)

    return ""


def pib_alternate_urls(original_url):
    prid = extract_prid(
        original_url
    )

    if not prid:
        return []

    return [
        (
            f"https://www.pib.gov.in/"
            f"PressReleaseIframePage.aspx"
            f"?PRID={prid}&lang=1&reg=3",
            "PIB_IFRAME_LANG_REG"
        ),
        (
            f"https://www.pib.gov.in/"
            f"PressReleasePage.aspx"
            f"?PRID={prid}&lang=1&reg=3",
            "PIB_PRESS_RELEASE_PAGE"
        ),
        (
            f"https://www.pib.gov.in/"
            f"PressReleseDetailm.aspx"
            f"?PRID={prid}",
            "PIB_DETAIL_M"
        ),
        (
            f"https://www.pib.gov.in/"
            f"PressReleseDetail.aspx"
            f"?PRID={prid}",
            "PIB_DETAIL"
        ),
        (
            f"https://pib.gov.in/"
            f"newsite/PrintRelease.aspx"
            f"?relid={prid}",
            "PIB_PRINT_RELEASE"
        ),
        (
            f"https://pib.gov.in/"
            f"PressReleasePage.aspx"
            f"?PRID={prid}",
            "PIB_PRESS_RELEASE_PAGE_SIMPLE"
        ),
        (
            f"https://pib.gov.in/"
            f"PressReleaseIframePage.aspx"
            f"?PRID={prid}",
            "PIB_IFRAME_SIMPLE"
        ),
    ]


def extract_pib_specific(soup, title):
    """
    PIB-specific extraction.
    PIB pages have Posted On + article body.
    Multiple selectors and text-boundary strategies are used.
    """

    # Remove obvious non-content sections.
    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "canvas",
        "iframe",
        "form",
        "nav",
        "footer",
    ]):
        tag.decompose()

    # Remove known UI elements.
    for selector in [
        ".social",
        ".share",
        ".print",
        ".visitor",
        ".breadcrumb",
        ".navbar",
        ".menu",
        "#menu",
    ]:
        try:
            for el in soup.select(selector):
                el.decompose()
        except Exception:
            pass

    candidates = []

    selectors = [
        "[itemprop='articleBody']",
        "[itemprop='articlebody']",
        ".article-body",
        ".articleBody",
        ".press-release",
        ".pressrelease",
        ".press-release-content",
        ".pressReleaseContent",
        ".release-content",
        ".releaseContent",
        ".content",
        ".main-content",
        "article",
        "main",
    ]

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

            if not txt:
                continue

            candidates.append(
                (
                    score_candidate(
                        txt,
                        selector,
                        "PIB",
                        title
                    ) + 30,
                    txt,
                    selector
                )
            )

    # PIB article paragraphs.
    paragraphs = []

    for p in soup.find_all("p"):

        txt = clean_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(txt) < 35:
            continue

        low = txt.lower()

        if any(
            x in low
            for x in [
                "share on",
                "follow us",
                "visitor",
                "copyright",
                "feedback",
            ]
        ):
            continue

        paragraphs.append(txt)

    if paragraphs:

        seen = set()
        unique = []

        for p in paragraphs:

            key = normalize_for_hash(p)

            if key in seen:
                continue

            seen.add(key)
            unique.append(p)

        joined = " ".join(
            unique
        )

        candidates.append(
            (
                score_candidate(
                    joined,
                    "PIB_PARAGRAPH_SCORE",
                    "PIB",
                    title
                ) + 50,
                joined,
                "PIB_PARAGRAPH_SCORE"
            )
        )

    # Text-boundary extraction around Posted On.
    full_text = clean_text(
        soup.get_text(
            " ",
            strip=True
        )
    )

    posted_patterns = [
        r"Posted\s*On\s*:\s*"
        r"\d{1,2}\s+[A-Za-z]{3}\s+\d{4}"
        r".*?(?=Image:|Share|Feedback|Copyright|$)",

        r"Posted\s*On\s*:\s*"
        r"\d{1,2}\s+[A-Za-z]{3}\s+\d{4}"
        r".*",
    ]

    for pattern in posted_patterns:

        m = re.search(
            pattern,
            full_text,
            flags=re.I
        )

        if not m:
            continue

        block = clean_text(
            m.group(0)
        )

        # Remove the Posted On header.
        block = re.sub(
            r"^Posted\s*On\s*:\s*"
            r"\d{1,2}\s+[A-Za-z]{3}\s+\d{4}"
            r"(?:\s+\d{1,2}:\d{2}\s*(?:AM|PM))?"
            r"(?:\s+by\s+[^ ]+)?",
            "",
            block,
            flags=re.I
        )

        if len(block) >= MIN_CONTENT_CHARS:

            candidates.append(
                (
                    score_candidate(
                        block,
                        "PIB_POSTED_ON_BOUNDARY",
                        "PIB",
                        title
                    ) + 20,
                    block,
                    "PIB_POSTED_ON_BOUNDARY"
                )
            )

    if not candidates:
        return "", "PIB_NO_CANDIDATES"

    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    for score, text, method in candidates:

        content, reason = validate_article_content(
            text,
            title=title,
            source="PIB"
        )

        if content:

            return (
                content,
                method
            )

    return "", (
        "PIB_ALL_CANDIDATES_REJECTED"
    )


def fetch_pib_article(
    url,
    title
):

    urls = [
        (
            clean_url(url),
            "PIB_ORIGINAL"
        )
    ]

    urls.extend(
        pib_alternate_urls(url)
    )

    seen_urls = set()

    for candidate_url, method_name in urls:

        candidate_url = clean_url(
            candidate_url
        )

        if not candidate_url:
            continue

        if candidate_url in seen_urls:
            continue

        seen_urls.add(candidate_url)

        debug(
            f"   🔎 PIB attempt: "
            f"{method_name}"
        )

        html = fetch_url(
            candidate_url
        )

        if not html:

            debug(
                f"   ⚠️ PIB {method_name} "
                f"FETCH FAILED"
            )

            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        date = extract_date_from_soup(
            soup
        )

        content, method = extract_pib_specific(
            soup,
            title
        )

        if content:

            debug(
                f"   ✅ PIB SUCCESS | "
                f"{method_name} + {method} | "
                f"{len(content)} chars"
            )

            return (
                content,
                date,
                f"{method_name}+{method}"
            )

        debug(
            f"   ⚠️ PIB {method_name} "
            f"NO ARTICLE CONTENT"
        )

    return "", None, "PIB_ALL_METHODS_FAILED"


def scrape_pib():
    print("\n🇮🇳 PIB NATIONAL SCRAPER")

    entries = []

    for feed_url in PIB_FEEDS:

        print(
            f"🔎 PIB feed: {feed_url}"
        )

        raw = fetch_url(
            feed_url
        )

        if not raw:
            print(
                "Found RSS items: 0"
            )
            continue

        try:

            parsed = feedparser.parse(
                raw
            )

            feed_entries = (
                parsed.entries or []
            )

        except Exception as e:

            debug(
                f"⚠️ PIB feed parse error: {e}"
            )

            continue

        print(
            f"Found RSS items: "
            f"{len(feed_entries)}"
        )

        for entry in feed_entries:

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

                    if not st:
                        continue

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

            entries.append(
                {
                    "title": title,
                    "url": link,
                    "date": date,
                }
            )

    entries = deduplicate_raw(
        entries
    )

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(entries)}"
    )

    # RSS dates are often missing on PIB.
    # Therefore do NOT throw away undated items.
    results = []

    for item in entries[
        :MAX_PER_SOURCE * 3
    ]:

        content, article_date, method = (
            fetch_pib_article(
                item["url"],
                item["title"]
            )
        )

        final_date = (
            article_date
            or item["date"]
        )

        if not content:

            debug_content_failure(
                "PIB",
                item["url"],
                method
            )

            continue

        obj = make_item(
            source="PIB",
            title=item["title"],
            url=item["url"],
            date=final_date,
            content=content,
            item_type="RSS + PIB Article"
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

    print(
        f"✅ PIB usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR NATIONAL
# ============================================================

AIR_NATIONAL_PAGES = [
    "https://newsonair.gov.in/category/national/",
    "https://newsonair.gov.in/category/national/page/2/",
    "https://newsonair.gov.in/category/national/page/3/",
]


def scrape_news_on_air_national():
    print(
        "\n📻 NEWS ON AIR NATIONAL SCRAPER"
    )

    results = []
    seen_urls = set()

    for page_url in AIR_NATIONAL_PAGES:

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        # Current News On AIR category pages
        # contain article links.
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

            if not href:
                continue

            if not same_domain(
                href,
                "newsonair.gov.in"
            ):
                continue

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 25:
                continue

            low_url = href.lower()

            if any(
                x in low_url
                for x in [
                    "/category/",
                    "/page/",
                    "/tag/",
                    "/author/",
                    "/feed/",
                ]
            ):
                continue

            low_title = title.lower()

            if any(
                x in low_title
                for x in [
                    "privacy policy",
                    "copyright",
                    "contact us",
                    "home",
                    "listen news",
                ]
            ):
                continue

            if href in seen_urls:
                continue

            seen_urls.add(href)

            content, date, method = (
                fetch_generic_article_content(
                    href,
                    title=title,
                    source="News On AIR"
                )
            )

            if not content:

                debug_content_failure(
                    "News On AIR",
                    href,
                    method
                )

                continue

            obj = make_item(
                source="News On AIR",
                title=title,
                url=href,
                date=date,
                content=content,
                item_type="National News"
            )

            if obj:
                results.append(
                    obj
                )

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ News On AIR usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# CMO BIHAR
# ============================================================

CMO_URLS = [
    "https://cm.bihar.gov.in/users/preessrelease.aspx",
    "https://cm.bihar.gov.in/users/PressReleaseN.aspx",
]


def scrape_cmo_bihar():
    print(
        "\n🏛️ CMO BIHAR SCRAPER"
    )

    results = []
    seen = set()

    for page_url in CMO_URLS:

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        # CMO listing often stores the date
        # in table rows with title/link.
        for row in soup.find_all("tr"):

            links = row.find_all(
                "a",
                href=True
            )

            if not links:
                continue

            row_text = clean_text(
                row.get_text(
                    " ",
                    strip=True
                )
            )

            date = parse_date(
                row_text
            )

            for a in links:

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

                if any(
                    x in low
                    for x in [
                        "home",
                        "contact",
                        "login",
                        "gallery",
                        "photo",
                        "feedback",
                        "view/download",
                    ]
                ):
                    continue

                if href in seen:
                    continue

                seen.add(href)

                content, article_date, method = (
                    fetch_generic_article_content(
                        href,
                        title=title,
                        source="CMO Bihar"
                    )
                )

                if not content:

                    debug_content_failure(
                        "CMO Bihar",
                        href,
                        method
                    )

                    continue

                final_date = (
                    article_date
                    or date
                )

                obj = make_item(
                    source="CMO Bihar",
                    title=title,
                    url=href,
                    date=final_date,
                    content=content,
                    item_type="CMO Press Release"
                )

                if obj:
                    results.append(
                        obj
                    )

                if len(results) >= MAX_PER_SOURCE:
                    break

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    # Fallback: if table structure changes,
    # scan all links.
    if len(results) < 5:

        debug(
            "⚠️ CMO table extraction weak. "
            "Running link fallback."
        )

        for page_url in CMO_URLS:

            html = fetch_url(
                page_url
            )

            if not html:
                continue

            soup = BeautifulSoup(
                html,
                "html.parser"
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

                if href in seen:
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
                    ]
                ):
                    continue

                seen.add(href)

                content, date, method = (
                    fetch_generic_article_content(
                        href,
                        title=title,
                        source="CMO Bihar"
                    )
                )

                if not content:

                    debug_content_failure(
                        "CMO Bihar",
                        href,
                        method
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

                if len(results) >= MAX_PER_SOURCE:
                    break

            if len(results) >= MAX_PER_SOURCE:
                break

    results = deduplicate(
        results
    )

    print(
        f"✅ CMO Bihar usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# IPRD BIHAR
# ============================================================

IPRD_PAGES = [
    "https://state.bihar.gov.in/prdbihar/",
    "https://state.bihar.gov.in/prdbihar/CitizenHome.html",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8931",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=8930",
    "https://state.bihar.gov.in/prdbihar/SectionInformation.html?editForm&rowId=6996",
]


def looks_like_iprd_portal_page(
    title,
    content,
    url
):

    low_title = title.lower()
    low_content = content.lower()

    portal_title_patterns = [
        "order/circular/notification",
        "compendium of government circulars",
        "hindi translation of judgement/order",
        "empanelled cultural parties",
        "accessibility options",
        "total prohibition of alcohol",
        "physical and financial progress",
        "state profile",
        "governance profile",
        "facts and figure",
    ]

    if any(
        x in low_title
        for x in portal_title_patterns
    ):
        return True

    # These are typical portal homepage fragments.
    portal_fragments = [
        "speech given by honourable governor",
        "state profile bihar is located",
        "governance profile",
        "read more",
        "distribution of population",
        "website maintained by dreamline",
        "content managed by information and public relations department",
    ]

    hits = sum(
        1
        for x in portal_fragments
        if x in low_content
    )

    if hits >= 2:
        return True

    if len(content) > PORTAL_MAX_CHARS:
        return True

    return False


def scrape_iprd_bihar():
    print(
        "\n📢 IPRD BIHAR SCRAPER"
    )

    results = []
    seen = set()

    for page_url in IPRD_PAGES:

        html = fetch_url(
            page_url
        )

        if not html:
            continue

        soup = BeautifulSoup(
            html,
            "html.parser"
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

            if not href:
                continue

            if "state.bihar.gov.in/prdbihar" not in href.lower():
                continue

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
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
                    "department",
                    "accessibility",
                ]
            ):
                continue

            links.append(
                (
                    title,
                    href
                )
            )

        # Deduplicate candidate links.
        unique_links = []
        local_seen = set()

        for title, href in links:

            if href in local_seen:
                continue

            local_seen.add(href)

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

        for title, href in unique_links[:50]:

            debug(
                f"   🔍 IPRD checking: "
                f"{title[:100]}"
            )

            if href in seen:
                continue

            seen.add(href)

            content, date, method = (
                fetch_generic_article_content(
                    href,
                    title=title,
                    source="IPRD Bihar"
                )
            )

            if not content:

                debug_content_failure(
                    "IPRD Bihar",
                    href,
                    method
                )

                continue

            if looks_like_iprd_portal_page(
                title,
                content,
                href
            ):

                debug(
                    f"   ⚠️ DEBUG IPRD REJECTED | "
                    f"PORTAL_PAGE | {title[:100]}"
                )

                continue

            obj = make_item(
                source="IPRD Bihar",
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

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ IPRD Bihar usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# DEDUPLICATION
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


def deduplicate_raw(items):

    seen = set()
    output = []

    for item in items:

        key_source = (
            item.get("url")
            or item.get("title")
            or ""
        )

        key = hashlib.sha1(
            normalize_for_hash(
                key_source
            ).encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if key in seen:
            continue

        seen.add(key)
        output.append(item)

    return output


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
            normalize_for_hash(
                key_source
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

    # VERY IMPORTANT:
    # Never use title as content.
    if not content:
        return None

    content, reason = validate_article_content(
        content,
        title=title,
        source=source,
        url=url
    )

    if not content:

        debug(
            f"   ⚠️ DEBUG ITEM REJECTED | "
            f"{source} | {reason} | {title[:100]}"
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
        "content_chars": len(
            content
        ),
        "type": item_type,
    }


# ============================================================
# BUILD NEWS
# ============================================================

def build_news():

    # ========================================================
    # NATIONAL
    # ========================================================

    print(
        "\n"
        + "=" * 65
    )

    print(
        "🇮🇳 NATIONAL NEWS"
    )

    print(
        "=" * 65
    )

    # IMPORTANT:
    # PIB and AIR are BOTH scraped.
    # AIR is NOT a fallback replacing PIB.
    pib = scrape_pib()

    air = scrape_news_on_air_national()

    national = deduplicate(
        pib + air
    )

    # ========================================================
    # BIHAR
    # ========================================================

    print(
        "\n"
        + "=" * 65
    )

    print(
        "🏛️ BIHAR NEWS"
    )

    print(
        "=" * 65
    )

    # IMPORTANT:
    # CMO and IPRD are BOTH scraped.
    cmo = scrape_cmo_bihar()

    iprd = scrape_iprd_bihar()

    bihar = deduplicate(
        cmo + iprd
    )

    # ========================================================
    # SOURCE BREAKDOWN
    # ========================================================

    print(
        "\n📊 SOURCE BREAKDOWN"
    )

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

    print(
        json.dumps(
            breakdown,
            ensure_ascii=False,
            indent=2
        )
    )

    print(
        f"\n🇮🇳 National News : "
        f"{len(national)}"
    )

    print(
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

    output = {
        "generated_at": now_ist().strftime(
            "%Y-%m-%d %H:%M:%S"
        ),

        "bihar_raw_count": len(
            bihar
        ),

        "national_raw_count": len(
            national
        ),

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

    size_mb = (
        os.path.getsize(
            OUTPUT_FILE
        )
        / (
            1024 * 1024
        )
    )

    print(
        f"\n💾 {OUTPUT_FILE} "
        f"updated successfully!"
    )

    print(
        f"📦 JSON size: "
        f"{size_mb:.2f} MB"
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

        print(
            "\n⛔ Scraper stopped by user."
        )

    except Exception as e:

        print(
            f"\n❌ FATAL ERROR: "
            f"{type(e).__name__}: {e}"
        )

        raise