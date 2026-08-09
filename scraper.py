import os
import re
import json
import time
import warnings
import hashlib
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
# Anything below this is considered suspicious.
MIN_CONTENT_CHARS = 300

# Avoid gigantic portal/speech/archive pages.
MAX_CONTENT_CHARS = 50000

RETRY_COUNT = 2

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

IST = timezone(timedelta(hours=5, minutes=30))


def now_ist():
    return datetime.now(IST)


TODAY = now_ist().date()
YESTERDAY = TODAY - timedelta(days=1)


# ============================================================
# URL CLEANING
# ============================================================

def clean_url(url):
    if not url:
        return ""

    url = str(url).strip()

    # Markdown URL:
    # [text](https://example.com)
    m = re.search(
        r'\]\((https?://[^)]+)\)',
        url
    )

    if m:
        url = m.group(1)

    # Markdown wrapper
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
    url = url.replace("\\?", "?")
    url = url.replace("\\=", "=")

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
# HTTP FETCH
# ============================================================

def fetch_url(
    url,
    timeout=TIMEOUT,
    retries=RETRY_COUNT
):
    """
    Robust HTTP fetch.

    For Bihar state portal:
    first normal SSL verification,
    then controlled verify=False fallback.
    """

    if not url:
        return None

    url = clean_url(url)

    if not url:
        return None

    host = urlparse(url).netloc.lower()

    # Bihar government portal has been returning
    # local CA verification problems in curl.
    is_bihar_state = (
        "state.bihar.gov.in" in host
    )

    last_error = None

    for attempt in range(
        retries + 1
    ):

        try:

            response = requests.get(
                url,
                headers=HEADERS,
                timeout=timeout,
                impersonate="chrome",
                allow_redirects=True,
                verify=True
            )

            if response.status_code >= 400:

                print(
                    f"⚠️ HTTP "
                    f"{response.status_code}: "
                    f"{url}"
                )

                # Try once again for transient errors
                if attempt < retries:
                    time.sleep(1)
                    continue

                return None

            return response.text

        except Exception as e:

            last_error = e

            # Bihar portal SSL fallback
            if (
                is_bihar_state
                and attempt == 0
            ):

                print(
                    f"⚠️ Bihar SSL verification failed. "
                    f"Retrying without certificate verification: "
                    f"{url}"
                )

                try:

                    response = requests.get(
                        url,
                        headers=HEADERS,
                        timeout=timeout,
                        impersonate="chrome",
                        allow_redirects=True,
                        verify=False
                    )

                    if response.status_code < 400:
                        return response.text

                    print(
                        f"⚠️ HTTP "
                        f"{response.status_code}: "
                        f"{url}"
                    )

                except Exception as e2:

                    last_error = e2

            if attempt < retries:
                time.sleep(1)

    print(
        f"⚠️ Direct fetch failed: "
        f"{url} | {last_error}"
    )

    return None


# ============================================================
# TEXT CLEANING
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

    text = (
        text
        .replace("\xa0", " ")
        .replace("\u200b", "")
        .replace("\ufeff", "")
    )

    text = re.sub(
        r'\s+',
        ' ',
        text
    )

    return text.strip()


def clean_title(title):

    title = clean_text(title)

    if not title:
        return ""

    title = re.sub(
        r'\s*[-|–—]\s*'
        r'(PIB|Press Information Bureau|'
        r'News On AIR|Akashvani News).*$',
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

    # feedparser / RFC
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

        return (
            d
            .replace(tzinfo=timezone.utc)
            .astimezone(IST)
        )

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

    # Search date inside larger string
    patterns = [

        r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})',

        r'(\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4})',

        r'(\d{4}-\d{2}-\d{2})',

        r'(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})',

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
            "%d %b %Y",
            "%d %B %Y",
        ]:

            try:

                d = datetime.strptime(
                    m.group(1),
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

        "meta[itemprop='dateModified']",

        "span.date",

        ".date",

        ".published",

        ".publish-date",

        ".news-date",

        ".entry-date",

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

    # Visible text
    text = soup.get_text(
        " ",
        strip=True
    )

    patterns = [

        r'\b\d{1,2}-[A-Za-z]{3}-\d{4}\b',

        r'\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b',

        r'\b\d{1,2}/\d{1,2}/\d{4}\b',

        r'\b\d{4}-\d{2}-\d{2}\b',

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

PORTAL_BOILERPLATE_PATTERNS = [

    "accessibility options",

    "skip to main content",

    "screen reader access",

    "site owned by",

    "website visitor",

    "visitor count",

    "web information manager",

    "help web information manager",

    "copyright",

    "privacy policy",

    "terms and conditions",

    "feedback",

    "contact us",

    "sitemap",

    "previous next",

    "state profile",

    "governance profile",

    "facts and figure",

    "distribution of population",

    "read more",

]


def boilerplate_score(text):

    if not text:
        return 0

    low = text.lower()

    score = 0

    for pattern in PORTAL_BOILERPLATE_PATTERNS:

        if pattern in low:
            score += 1

    return score


def is_boilerplate(text):

    if not text:
        return True

    return (
        boilerplate_score(text) >= 4
    )


def remove_common_boilerplate(text):

    if not text:
        return ""

    patterns = [

        r"We have tried to put most accurate.*?$",

        r"Help Web Information Manager.*?$",

        r"Copyright IPRD.*?$",

        r"Website Visitor.*?$",

    ]

    for pattern in patterns:

        text = re.sub(
            pattern,
            "",
            text,
            flags=re.I | re.S
        )

    return clean_text(text)


# ============================================================
# GENERIC ARTICLE CONTENT
# ============================================================

def fetch_generic_article_content(url):

    url = clean_url(url)

    if not url:
        return "", None

    html = fetch_url(
        url
    )

    if not html:
        return "", None

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    date = extract_date_from_soup(
        soup
    )

    # Remove dangerous/noise elements
    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "nav",
        "footer",
        "header",
        "form",
        "iframe",
        "canvas",
        "button"
    ]):

        tag.decompose()

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

        ".release-content",

        ".content-area",

        ".main-content",

        ".entry-content",

        ".post-content",

        "main",

    ]

    for selector in selectors:

        try:

            for el in soup.select(
                selector
            ):

                txt = clean_text(
                    el.get_text(
                        " ",
                        strip=True
                    )
                )

                if (
                    len(txt)
                    >= MIN_CONTENT_CHARS
                ):

                    candidates.append(
                        txt
                    )

        except Exception:
            pass

    # Paragraph fallback
    if not candidates:

        paragraphs = []

        for p in soup.find_all("p"):

            txt = clean_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) < 40:
                continue

            low = txt.lower()

            if any(
                x in low
                for x in [
                    "privacy policy",
                    "copyright",
                    "contact us",
                    "sitemap",
                    "feedback",
                ]
            ):
                continue

            paragraphs.append(
                txt
            )

        if paragraphs:

            combined = " ".join(
                paragraphs
            )

            if (
                len(combined)
                >= MIN_CONTENT_CHARS
            ):

                candidates.append(
                    combined
                )

    if not candidates:
        return "", date

    content = max(
        candidates,
        key=len
    )

    content = (
        remove_common_boilerplate(
            content
        )
    )

    if len(content) < MIN_CONTENT_CHARS:
        return "", date

    if len(content) > MAX_CONTENT_CHARS:
        print(
            f"⚠️ DEBUG GENERIC CONTENT TOO LARGE "
            f"| {len(content):,}"
        )
        return "", date

    return content, date


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

    # NEVER allow title as content
    if (
        content
        and normalize_for_hash(content)
        == normalize_for_hash(title)
    ):

        print(
            f"⚠️ DEBUG REJECTED "
            f"| CONTENT IS TITLE | "
            f"{title[:100]}"
        )

        return None

    if not content:
        return None

    if len(content) < MIN_CONTENT_CHARS:

        print(
            f"⚠️ DEBUG REJECTED "
            f"| CONTENT TOO SHORT "
            f"| chars={len(content)} "
            f"| {title[:100]}"
        )

        return None

    if len(content) > MAX_CONTENT_CHARS:

        print(
            f"⚠️ DEBUG REJECTED "
            f"| CONTENT TOO LARGE "
            f"| chars={len(content)} "
            f"| {title[:100]}"
        )

        return None

    if is_boilerplate(content):

        print(
            f"⚠️ DEBUG REJECTED "
            f"| PORTAL BOILERPLATE "
            f"| {title[:100]}"
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
# HASH / DEDUPLICATION
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

        if not item:
            continue

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

        seen.add(
            key
        )

        output.append(
            item
        )

    print(
        f"🧹 Deduplication: "
        f"Input={len(items)} | "
        f"Dropped={dropped} | "
        f"Unique={len(output)}"
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


# ============================================================
# BUILD REAL PIB ARTICLE URL
# ============================================================

def build_pib_article_url(
    rss_url,
    feed_url=""
):

    rss_url = clean_url(
        rss_url
    )

    if not rss_url:
        return ""

    m = re.search(
        r'[?&]PRID=(\d+)',
        rss_url,
        flags=re.I
    )

    if not m:

        # Sometimes PRID can be encoded
        decoded = unquote(
            rss_url
        )

        m = re.search(
            r'[?&]PRID=(\d+)',
            decoded,
            flags=re.I
        )

    if not m:

        print(
            f"⚠️ DEBUG PIB PRID NOT FOUND "
            f"| {rss_url}"
        )

        return ""

    prid = m.group(1)

    # Preserve feed language if possible
    reg = "3"
    lang = "1"

    feed_low = (
        feed_url.lower()
        if feed_url
        else ""
    )

    if "regid=3" in feed_low:
        reg = "3"

    if "lang=9" in feed_low:
        lang = "9"

    # IMPORTANT:
    # RSS iframe URL is NOT used as final article URL.
    article_url = (
        "https://www.pib.gov.in/"
        "PressReleasePage.aspx?"
        f"PRID={prid}&"
        f"reg={reg}&"
        f"lang={lang}"
    )

    return article_url


# ============================================================
# PIB ARTICLE CONTENT
# ============================================================

def extract_pib_article_content(
    soup
):

    # --------------------------------------------------------
    # Remove page-wide noise
    # --------------------------------------------------------

    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "nav",
        "footer",
        "header",
        "form",
        "iframe",
        "canvas",
        "button"
    ]):

        tag.decompose()

    candidates = []

    # --------------------------------------------------------
    # PIB selectors
    # --------------------------------------------------------

    selectors = [

        "[itemprop='articleBody']",

        ".innner-page-main-content",

        ".inner-page-main-content",

        ".press-release",

        ".pressrelease",

        ".release-content",

        ".PressRelease",

        ".content",

        ".main-content",

        "article",

    ]

    for selector in selectors:

        try:

            elements = soup.select(
                selector
            )

        except Exception:
            continue

        for el in elements:

            text = clean_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(text) >= 300:

                candidates.append(
                    text
                )

    # --------------------------------------------------------
    # Paragraph extraction
    # --------------------------------------------------------

    paragraphs = []

    for p in soup.find_all("p"):

        text = clean_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(text) < 40:
            continue

        low = text.lower()

        # Skip site navigation/footer
        if any(
            x in low
            for x in [
                "visitor count",
                "website visitor",
                "feedback",
                "contact us",
                "site map",
                "privacy policy",
                "copyright",
                "increase font size",
                "decrease font size",
                "high contrast",
            ]
        ):
            continue

        paragraphs.append(
            text
        )

    if paragraphs:

        paragraph_content = " ".join(
            paragraphs
        )

        if len(
            paragraph_content
        ) >= 300:

            candidates.append(
                paragraph_content
            )

    if not candidates:
        return ""

    # --------------------------------------------------------
    # Longest candidate
    # --------------------------------------------------------

    content = max(
        candidates,
        key=len
    )

    # --------------------------------------------------------
    # Remove duplicate release footer
    # --------------------------------------------------------

    content = re.sub(
        r'\(रिलीज़ आईडी\s*:\s*\d+\).*?$',
        '',
        content,
        flags=re.I | re.S
    )

    content = re.sub(
        r'\(Release ID\s*:\s*\d+\).*?$',
        '',
        content,
        flags=re.I | re.S
    )

    content = re.sub(
        r'आगंतुक पटल\s*:\s*\d+.*?$',
        '',
        content,
        flags=re.I | re.S
    )

    content = re.sub(
        r'Visitor Counter\s*:\s*\d+.*?$',
        '',
        content,
        flags=re.I | re.S
    )

    content = remove_common_boilerplate(
        content
    )

    content = clean_text(
        content
    )

    return content


def fetch_pib_article(
    rss_url,
    rss_title="",
    feed_url=""
):

    article_url = build_pib_article_url(
        rss_url,
        feed_url
    )

    if not article_url:

        print(
            f"⚠️ DEBUG PIB INVALID ARTICLE URL "
            f"| {rss_title}"
        )

        return "", None, ""

    print(
        f"🔗 PIB ARTICLE: "
        f"{article_url}"
    )

    html = fetch_url(
        article_url
    )

    if not html:

        print(
            f"⚠️ DEBUG PIB ARTICLE FETCH FAILED "
            f"| {rss_title}"
        )

        return "", None, article_url

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    date = extract_date_from_soup(
        soup
    )

    content = extract_pib_article_content(
        soup
    )

    # --------------------------------------------------------
    # IMPORTANT:
    # NO TITLE FALLBACK.
    # --------------------------------------------------------

    if not content:

        print(
            f"⚠️ DEBUG PIB NO ARTICLE CONTENT "
            f"| {rss_title}"
        )

        print(
            f"   URL: {article_url}"
        )

        return "", date, article_url

    if len(content) < MIN_CONTENT_CHARS:

        print(
            f"⚠️ DEBUG PIB CONTENT TOO SHORT "
            f"| chars={len(content)} "
            f"| {rss_title}"
        )

        print(
            f"   URL: {article_url}"
        )

        return "", date, article_url

    if len(content) > MAX_CONTENT_CHARS:

        print(
            f"⚠️ DEBUG PIB CONTENT TOO LARGE "
            f"| chars={len(content):,} "
            f"| {rss_title}"
        )

        print(
            f"   URL: {article_url}"
        )

        return "", date, article_url

    print(
        f"✅ PIB ARTICLE CONTENT "
        f"| {len(content):,} chars "
        f"| {rss_title[:90]}"
    )

    return (
        content,
        date,
        article_url
    )


# ============================================================
# SCRAPE PIB RSS
# ============================================================

def scrape_pib_rss():

    print(
        "\n🇮🇳 PIB NATIONAL SCRAPER"
    )

    all_entries = []

    for feed_url in PIB_FEEDS:

        print(
            f"🔎 PIB feed: "
            f"{feed_url}"
        )

        try:

            raw = fetch_url(
                feed_url
            )

            if not raw:

                print(
                    "Found RSS items: 0"
                )

                continue

            parsed = feedparser.parse(
                raw
            )

            entries = (
                parsed.entries
                or []
            )

            print(
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

                if not link:
                    continue

                date = None

                # Feed date
                for field in [
                    "published",
                    "updated",
                    "pubDate",
                    "date"
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

                # feedparser structured date
                if not date:

                    for field in [
                        "published_parsed",
                        "updated_parsed"
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
                    "PIB RSS:",
                    (
                        date.strftime(
                            "%Y-%m-%d %H:%M"
                        )
                        if date
                        else "NO DATE"
                    ),
                    "|",
                    title[:90]
                )

                rss_content = clean_text(
                    entry.get(
                        "summary",
                        ""
                    )
                    or entry.get(
                        "description",
                        ""
                    )
                )

                all_entries.append({

                    "title": title,

                    "url": link,

                    "date": date,

                    "content": rss_content,

                    "feed_url": feed_url,

                })

        except Exception as e:

            print(
                f"⚠️ PIB RSS error: "
                f"{e}"
            )

    # --------------------------------------------------------
    # Deduplicate RSS
    # --------------------------------------------------------

    unique_map = {}

    for x in all_entries:

        key = (
            x["url"]
            or x["title"]
        )

        if key not in unique_map:
            unique_map[key] = x

    all_entries = list(
        unique_map.values()
    )

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(all_entries)}"
    )

    today_items = []
    yesterday_items = []
    undated_items = []

    for item in all_entries:

        d = item["date"]

        if d:

            if d.date() == TODAY:

                today_items.append(
                    item
                )

            elif d.date() == YESTERDAY:

                yesterday_items.append(
                    item
                )

        else:

            undated_items.append(
                item
            )

    print(
        f"📅 PIB yesterday items: "
        f"{len(yesterday_items)}"
    )

    print(
        f"📅 PIB today items: "
        f"{len(today_items)}"
    )

    # --------------------------------------------------------
    # Selection
    # --------------------------------------------------------

    selected = []

    selected.extend(
        yesterday_items[
            :MAX_PER_SOURCE
        ]
    )

    if len(selected) < MAX_PER_SOURCE:

        selected.extend(
            today_items[
                :MAX_PER_SOURCE
                - len(selected)
            ]
        )

    # RSS currently sometimes gives no usable date.
    # Use latest feed entries as emergency fallback.
    if len(selected) < 5:

        print(
            "⚠️ PIB date filtering produced "
            "too few items. Using latest RSS "
            "entries as emergency fallback."
        )

        for item in all_entries:

            if item in selected:
                continue

            selected.append(
                item
            )

            if len(selected) >= MAX_PER_SOURCE:
                break

    results = []

    # --------------------------------------------------------
    # Fetch REAL PIB article
    # --------------------------------------------------------

    for item in selected:

        content, article_date, article_url = (
            fetch_pib_article(
                item["url"],
                item["title"],
                item["feed_url"]
            )
        )

        # NEVER use RSS title as content
        if not content:

            print(
                f"⚠️ DEBUG PIB ITEM REJECTED "
                f"| NO REAL CONTENT "
                f"| {item['title'][:100]}"
            )

            continue

        final_date = (
            article_date
            or item["date"]
        )

        obj = make_item(

            source="PIB",

            title=item["title"],

            url=(
                article_url
                or item["url"]
            ),

            date=final_date,

            content=content,

            item_type="RSS + Full Article"

        )

        if obj:
            results.append(
                obj
            )

    results = deduplicate(
        results
    )

    print(
        f"✅ PIB usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PIB WEBSITE FALLBACK
# ============================================================

PIB_HOME = (
    "https://www.pib.gov.in/"
)


def scrape_pib_website_fallback():

    print(
        "\n🔎 PIB WEBSITE FALLBACK"
    )

    html = fetch_url(
        PIB_HOME
    )

    if not html:
        return []

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    candidates = []

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = clean_url(
            urljoin(
                PIB_HOME,
                a.get("href", "")
            )
        )

        if not href:
            continue

        if "pib.gov.in" not in (
            href.lower()
        ):
            continue

        # Only actual press release pages
        if (
            "PressReleasePage.aspx"
            not in href
            and
            "PressReleaseIframePage.aspx"
            not in href
        ):
            continue

        title = clean_title(
            a.get_text(
                " ",
                strip=True
            )
        )

        if len(title) < 20:
            continue

        candidates.append(
            (
                title,
                href
            )
        )

    # Dedup
    seen = set()
    unique = []

    for title, href in candidates:

        if href in seen:
            continue

        seen.add(href)

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, url in unique[:40]:

        # Convert iframe URL to actual article
        article_url = (
            build_pib_article_url(
                url
            )
            or url
        )

        content, date = (
            fetch_generic_article_content(
                article_url
            )
        )

        if not content:
            continue

        if date:

            age = (
                TODAY
                - date.date()
            ).days

            if age > 3:
                continue

        obj = make_item(

            source="PIB",

            title=title,

            url=article_url,

            date=date,

            content=content,

            item_type="Website Fallback"

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
        f"✅ PIB website fallback: "
        f"{len(results)}"
    )

    return results


# ============================================================
# NEWS ON AIR
# ============================================================

NEWS_ON_AIR_HOME = (
    "https://newsonair.gov.in/"
)

NEWS_ON_AIR_CATEGORIES = [

    "https://newsonair.gov.in/category/national/",

    "https://newsonair.gov.in/category/india/",

    "https://newsonair.gov.in/category/regional-news/",

]


def is_air_article_url(url):

    low = url.lower()

    return (
        "newsonair.gov.in" in low
        and
        not any(
            x in low
            for x in [
                "/category/",
                "/news-categories/",
                "/regional-units/",
                "/regional-units-state/",
                "/bulletins-category/",
                "/archives/",
                "/contact",
                "/about",
                "/privacy",
                "/search",
            ]
        )
    )


def extract_air_article_content(
    soup
):

    for tag in soup([
        "script",
        "style",
        "noscript",
        "svg",
        "nav",
        "footer",
        "header",
        "form",
        "iframe",
        "button",
    ]):

        tag.decompose()

    candidates = []

    selectors = [

        "article",

        ".entry-content",

        ".post-content",

        ".article-content",

        ".single-post-content",

        ".td-post-content",

        ".content",

        "main",

    ]

    for selector in selectors:

        try:

            for el in soup.select(
                selector
            ):

                txt = clean_text(
                    el.get_text(
                        " ",
                        strip=True
                    )
                )

                if len(txt) >= 300:

                    candidates.append(
                        txt
                    )

        except Exception:
            pass

    if not candidates:

        paragraphs = []

        for p in soup.find_all("p"):

            txt = clean_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 40:
                paragraphs.append(
                    txt
                )

        if paragraphs:

            txt = " ".join(
                paragraphs
            )

            if len(txt) >= 300:
                candidates.append(
                    txt
                )

    if not candidates:
        return ""

    content = max(
        candidates,
        key=len
    )

    return clean_text(
        content
    )


def scrape_news_on_air_category(
    category_url,
    source_name="News On AIR",
    bihar_only=False
):

    html = fetch_url(
        category_url
    )

    if not html:
        return []

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
                category_url,
                a.get("href")
            )
        )

        if not href:
            continue

        if not is_air_article_url(
            href
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

        # Bihar filter
        if bihar_only:

            low = title.lower()

            bihar_words = [

                "bihar",
                "patna",
                "nitish",
                "samrat",
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
                "supaul",
                "saharsa",
                "siwan",
                "nalanda",
                "nawada",
                "buxar",
                "bhojpur",
                "rohtas",
                "aurangabad",
                "katihar",
                "kishanganj",
                "madhepura",
                "munger",
                "jamui",
                "lakhisarai",
                "khagaria",
                "sheikhpura",
                "araria",
                "arwal",
                "kaimur",
                "vaishali",
            ]

            if not any(
                x in low
                for x in bihar_words
            ):
                continue

        links.append(
            (
                title,
                href
            )
        )

    # dedup URLs
    seen = set()
    unique = []

    for title, href in links:

        if href in seen:
            continue

        seen.add(href)

        unique.append(
            (
                title,
                href
            )
        )

    results = []

    for title, href in unique[:40]:

        content, date = (
            fetch_generic_article_content(
                href
            )
        )

        if not content:

            print(
                f"⚠️ DEBUG AIR NO CONTENT "
                f"| {title}"
            )

            continue

        # Skip sports for national scraper
        if not bihar_only:

            low = title.lower()

            if any(
                x in low
                for x in [
                    "cricket",
                    "football",
                    "tennis",
                    "badminton",
                    "sports",
                    "ipl",
                ]
            ):
                continue

        obj = make_item(

            source=source_name,

            title=title,

            url=href,

            date=date,

            content=content,

            item_type=(
                "News On AIR Bihar"
                if bihar_only
                else "News On AIR"
            )

        )

        if obj:
            results.append(
                obj
            )

        if len(results) >= MAX_PER_SOURCE:
            break

    return deduplicate(
        results
    )


# ============================================================
# NEWS ON AIR NATIONAL
# ============================================================

def scrape_news_on_air_national():

    print(
        "\n📻 NEWS ON AIR NATIONAL SCRAPER"
    )

    results = []

    for category in NEWS_ON_AIR_CATEGORIES:

        print(
            f"🔎 AIR category: "
            f"{category}"
        )

        items = (
            scrape_news_on_air_category(
                category,
                "News On AIR",
                False
            )
        )

        results.extend(
            items
        )

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ News On AIR usable news: "
        f"{len(results)}"
    )

    return results[:MAX_PER_SOURCE]


# ============================================================
# NEWS ON AIR BIHAR
# ============================================================

NEWS_ON_AIR_BIHAR_URLS = [

    # Current Bihar category
    "https://newsonair.gov.in/category/bihar/",

    # Regional category
    "https://newsonair.gov.in/category/regional-news/",

]


def scrape_news_on_air_bihar():

    print(
        "\n📻 NEWS ON AIR BIHAR"
    )

    results = []

    for page_url in (
        NEWS_ON_AIR_BIHAR_URLS
    ):

        print(
            f"🔎 AIR Bihar page: "
            f"{page_url}"
        )

        items = (
            scrape_news_on_air_category(
                page_url,
                "News On AIR Bihar",
                True
            )
        )

        results.extend(
            items
        )

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ News On AIR Bihar usable: "
        f"{len(results)}"
    )

    return results[:MAX_PER_SOURCE]


# ============================================================
# CMO BIHAR
# ============================================================

CMO_URL = (
    "https://cm.bihar.gov.in/"
    "users/preessrelease.aspx"
)


def scrape_cmo_bihar():

    print(
        "\n🏛️ CMO BIHAR SCRAPER"
    )

    html = fetch_url(
        CMO_URL
    )

    if not html:

        print(
            "⚠️ CMO page fetch failed."
        )

        return []

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
                CMO_URL,
                a.get("href")
            )
        )

        if not href:
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
                "login",
                "gallery",
                "photo",
                "feedback",
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

    # Remove duplicates
    seen = set()
    unique = []

    for title, href in links:

        if href in seen:
            continue

        seen.add(href)

        unique.append(
            (
                title,
                href
            )
        )

    print(
        f"🔎 CMO candidate links: "
        f"{len(unique)}"
    )

    results = []

    for title, href in unique[:40]:

        content, date = (
            fetch_generic_article_content(
                href
            )
        )

        if not content:

            print(
                f"⚠️ DEBUG CMO NO CONTENT "
                f"| {title}"
            )

            continue

        obj = make_item(

            source="CMO Bihar",

            title=title,

            url=href,

            date=date,

            content=content,

            item_type="Article Scraped"

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
        "https://state.bihar.gov.in/"
        "prdbihar/"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=8931"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=8930"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/"
        "SectionInformation.html?"
        "editForm&rowId=6996"
    ),

]


def is_iprd_real_article(
    title,
    url
):

    low_title = title.lower()
    low_url = url.lower()

    # Reject obvious portal pages
    reject_title_words = [

        "accessibility",

        "order/circular/notification",

        "compendium of government circulars",

        "hindi translation of judgement",

        "empanelled cultural parties",

        "speech given by honourable governor",

        "state profile",

        "governance profile",

        "facts and figure",

        "total prohibition",

        "physical and financial progress",

        "national highways",

        "communication sector",

        "impact assessment",

    ]

    if any(
        x in low_title
        for x in reject_title_words
    ):
        return False

    # Avoid obvious static information pages
    if (
        "sectioninformation.html"
        in low_url
        and
        any(
            x in low_title
            for x in [
                "profile",
                "facts",
                "circular",
                "notification",
                "order",
                "judgement",
                "cultural",
                "speech",
            ]
        )
    ):
        return False

    return True


def scrape_iprd_bihar():

    print(
        "\n📢 IPRD BIHAR SCRAPER"
    )

    results = []

    for source, page_url in IPRD_PAGES:

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

            if (
                "state.bihar.gov.in"
                not in href.lower()
            ):
                continue

            # Only IPRD section
            if (
                "/prdbihar/"
                not in href.lower()
            ):
                continue

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 20:
                continue

            if not is_iprd_real_article(
                title,
                href
            ):
                continue

            links.append(
                (
                    title,
                    href
                )
            )

        # dedup
        seen = set()
        unique = []

        for title, href in links:

            if href in seen:
                continue

            seen.add(href)

            unique.append(
                (
                    title,
                    href
                )
            )

        print(
            f"🔎 IPRD candidate links: "
            f"{len(unique)}"
        )

        for title, href in unique[:50]:

            print(
                f"🔍 IPRD checking: "
                f"{title[:120]}"
            )

            content, date = (
                fetch_generic_article_content(
                    href
                )
            )

            if not content:

                print(
                    f"⚠️ DEBUG IPRD NO CONTENT "
                    f"| {title}"
                )

                continue

            score = boilerplate_score(
                content
            )

            if score >= 3:

                print(
                    f"⚠️ DEBUG IPRD REJECTED "
                    f"| PORTAL_BOILERPLATE_SCORE_{score} "
                    f"| {title}"
                )

                continue

            # Prevent giant portal pages/speeches
            if len(content) > 50000:

                print(
                    f"⚠️ DEBUG IPRD REJECTED "
                    f"| IPRD_CONTENT_TOO_LARGE_"
                    f"{len(content)} "
                    f"| {title}"
                )

                continue

            # Recent content only when date available
            if date:

                age = (
                    TODAY
                    - date.date()
                ).days

                if age > 7:

                    print(
                        f"⚠️ DEBUG IPRD OLD ARTICLE "
                        f"| age={age} "
                        f"| {title}"
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
# BIHAR CABINET
# ============================================================

CABINET_PAGES = [

    "https://state.bihar.gov.in/csd/",

    "https://state.bihar.gov.in/"
    "csd/CitizenHome.html",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html?"
    "editForm&rowId=2929",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html?"
    "editForm&rowId=1323",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html?"
    "editForm&rowId=4935",

]


def scrape_bihar_cabinet():

    print(
        "\n🏛️ BIHAR CABINET SCRAPER"
    )

    results = []

    for page_url in CABINET_PAGES:

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

            if not href:
                continue

            if (
                "state.bihar.gov.in/csd"
                not in href.lower()
            ):
                continue

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
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
                    "approved",
                ]
            ):
                continue

            content, date = (
                fetch_generic_article_content(
                    href
                )
            )

            if not content:

                print(
                    f"⚠️ DEBUG CABINET NO CONTENT "
                    f"| {title}"
                )

                continue

            if is_boilerplate(
                content
            ):
                continue

            if date:

                age = (
                    TODAY
                    - date.date()
                ).days

                if age > 7:
                    continue

            obj = make_item(

                source=(
                    "Bihar Cabinet Decision"
                ),

                title=title,

                url=href,

                date=date,

                content=content,

                item_type=(
                    "Cabinet Decision"
                )

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
        f"✅ Bihar Cabinet usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# BUILD NEWS
# ============================================================

def build_news():

    # ========================================================
    # NATIONAL
    # ========================================================

    pib = scrape_pib_rss()

    # PIB fallback only if RSS yielded weak results
    if len(pib) < 5:

        print(
            "\n⚠️ PIB RSS insufficient."
        )

        pib_web = (
            scrape_pib_website_fallback()
        )

        pib = deduplicate(
            pib + pib_web
        )

    # --------------------------------------------------------
    # IMPORTANT:
    # News On AIR is ALSO scraped.
    #
    # It is not only a fallback.
    # --------------------------------------------------------

    air = scrape_news_on_air_national()

    national = deduplicate(
        pib + air
    )

    # ========================================================
    # BIHAR
    # ========================================================

    cmo = scrape_cmo_bihar()

    iprd = scrape_iprd_bihar()

    cabinet = scrape_bihar_cabinet()

    # News On AIR Bihar is ALSO scraped
    # regardless of official source count.
    air_bihar = scrape_news_on_air_bihar()

    bihar = deduplicate(
        cmo
        + iprd
        + cabinet
        + air_bihar
    )

    # ========================================================
    # FINAL
    # ========================================================

    national = deduplicate(
        national
    )

    bihar = deduplicate(
        bihar
    )

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

    print(
        f"\n💾 {OUTPUT_FILE} "
        f"updated successfully!"
    )

    print(
        f"📦 Total news saved: "
        f"{len(all_news)}"
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
            f"{e}"
        )

        raise
