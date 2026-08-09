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

# Maximum items from each source
MAX_PER_SOURCE = 15

# Minimum characters required for actual article content
MIN_CONTENT_CHARS = 120

# Debug content extraction
DEBUG_CONTENT = True

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/150.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,image/avif,image/webp,*/*;q=0.8"
    ),
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

def fetch_url(url, timeout=TIMEOUT, verify=True):

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
            allow_redirects=True,
            verify=verify
        )

        if r.status_code >= 400:

            print(
                f"⚠️ HTTP {r.status_code}: {url}"
            )

            return None

        return r.text

    except Exception as e:

        # SSL fallback
        if verify:

            error_text = str(e).lower()

            if (
                "certificate" in error_text
                or "ssl" in error_text
                or "verify" in error_text
            ):

                print(
                    f"⚠️ SSL issue. Retrying without "
                    f"certificate verification: {url}"
                )

                try:

                    r = requests.get(
                        url,
                        headers=HEADERS,
                        timeout=timeout,
                        impersonate="chrome",
                        allow_redirects=True,
                        verify=False
                    )

                    if r.status_code >= 400:

                        print(
                            f"⚠️ HTTP {r.status_code}: {url}"
                        )

                        return None

                    return r.text

                except Exception as retry_error:

                    print(
                        f"⚠️ Direct fetch failed: "
                        f"{url} | {retry_error}"
                    )

                    return None

        print(
            f"⚠️ Direct fetch failed: "
            f"{url} | {e}"
        )

        return None


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

    # Escape cleanup
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

    text = text.replace(
        "\xa0",
        " "
    )

    text = re.sub(
        r'\s+',
        ' ',
        text
    )

    return text.strip()


# ============================================================
# TITLE CLEANING
# ============================================================

def clean_title(title):

    title = clean_text(title)

    title = re.sub(
        r'\s*[-|–—]\s*'
        r'(PIB|Press Information Bureau|News On AIR).*$',
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

    # Search date inside string
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

        "meta[name='publication-date']",

        "meta[name='date']",

        "meta[name='DC.date']",

        "meta[name='DC.Date']",

        "meta[itemprop='datePublished']",

        "meta[itemprop='dateModified']",

        "meta[name='pubdate']",

        "span.date",

        ".date",

        ".published",

        ".publish-date",

        ".news-date",

        ".article-date",

        ".publishDate",

        ".publishedDate",

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

            d = parse_date(value)

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

        if not m:
            continue

        d = parse_date(
            m.group(0)
        )

        if d:
            return d

    return None


# ============================================================
# CONTENT VALIDATION
# ============================================================

def content_is_real(content, title=""):

    content = clean_text(content)
    title = clean_title(title)

    if not content:
        return False

    if len(content) < MIN_CONTENT_CHARS:

        if DEBUG_CONTENT:

            print(
                f"⚠️ CONTENT TOO SHORT | "
                f"{len(content)} chars | "
                f"title={title[:100]}"
            )

        return False

    # Exact title = NOT article content
    if (
        title
        and content.lower() == title.lower()
    ):

        if DEBUG_CONTENT:

            print(
                f"⚠️ CONTENT IS ONLY TITLE | "
                f"title={title[:100]}"
            )

        return False

    # Highly similar title/content
    if title:

        title_words = set(
            normalize_for_hash(title).split()
        )

        content_words = set(
            normalize_for_hash(content).split()
        )

        if (
            len(title_words) >= 5
            and title_words.issubset(
                content_words
            )
            and len(content) < 220
        ):

            if DEBUG_CONTENT:

                print(
                    f"⚠️ CONTENT LOOKS LIKE TITLE "
                    f"ONLY | title={title[:100]}"
                )

            return False

    return True


# ============================================================
# GENERIC ARTICLE CONTENT
# ============================================================

def fetch_generic_article_content(url, expected_title=""):

    url = clean_url(url)

    if not url:

        return "", None

    html = fetch_url(url)

    if not html:

        if DEBUG_CONTENT:

            print(
                f"⚠️ CONTENT FETCH FAILED | "
                f"{url}"
            )

        return "", None

    try:

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

    except Exception as e:

        print(
            f"⚠️ BeautifulSoup error: "
            f"{url} | {e}"
        )

        return "", None

    # --------------------------------------------------------
    # DATE
    # --------------------------------------------------------

    date = extract_date_from_soup(
        soup
    )

    # --------------------------------------------------------
    # JSON-LD articleBody
    # --------------------------------------------------------

    candidates = []

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        try:

            raw = script.string

            if not raw:
                continue

            data = json.loads(raw)

            objects = []

            if isinstance(data, dict):

                objects.append(data)

                if "@graph" in data:
                    graph = data["@graph"]

                    if isinstance(
                        graph,
                        list
                    ):
                        objects.extend(
                            graph
                        )

            elif isinstance(data, list):

                objects.extend(
                    data
                )

            for obj in objects:

                if not isinstance(
                    obj,
                    dict
                ):
                    continue

                body = (
                    obj.get("articleBody")
                    or obj.get("text")
                    or ""
                )

                body = clean_text(
                    body
                )

                if content_is_real(
                    body,
                    expected_title
                ):

                    candidates.append(
                        body
                    )

                if not date:

                    date_value = (
                        obj.get(
                            "datePublished"
                        )
                        or obj.get(
                            "dateModified"
                        )
                    )

                    date = parse_date(
                        date_value
                    )

        except Exception:
            pass

    # --------------------------------------------------------
    # Remove unwanted elements
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
        "aside",
        "button",
        "input",
        "select",
        "textarea",
    ]):

        tag.decompose()

    # --------------------------------------------------------
    # Article selectors
    # --------------------------------------------------------

    selectors = [

        "article",

        "[itemprop='articleBody']",

        "[itemprop='articlebody']",

        ".article-body",

        ".articleBody",

        ".article_body",

        ".story-content",

        ".storyContent",

        ".story-content__body",

        ".news-content",

        ".newsContent",

        ".news-content-body",

        ".press-release",

        ".pressrelease",

        ".press-release-content",

        ".pressrelease-content",

        ".content-area",

        ".main-content",

        ".article-content",

        ".articleContent",

        ".article__content",

        ".story-body",

        ".story-body-content",

        ".story_text",

        ".storyText",

        ".entry-content",

        ".post-content",

        ".post-body",

        ".field-name-body",

        ".field--name-body",

        "#articleBody",

        "#article-body",

        "#content",

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

            if content_is_real(
                txt,
                expected_title
            ):

                candidates.append(
                    txt
                )

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

        if len(txt) < 35:
            continue

        if is_boilerplate(txt):
            continue

        paragraphs.append(
            txt
        )

    if paragraphs:

        paragraph_content = " ".join(
            paragraphs
        )

        if content_is_real(
            paragraph_content,
            expected_title
        ):

            candidates.append(
                paragraph_content
            )

    # --------------------------------------------------------
    # DIV based extraction
    # --------------------------------------------------------

    for div in soup.find_all(
        "div"
    ):

        txt = clean_text(
            div.get_text(
                " ",
                strip=True
            )
        )

        if len(txt) < MIN_CONTENT_CHARS:
            continue

        if len(txt) > 30000:
            continue

        if content_is_real(
            txt,
            expected_title
        ):

            candidates.append(
                txt
            )

    # --------------------------------------------------------
    # BODY fallback
    # --------------------------------------------------------

    body = soup.body

    if body:

        txt = clean_text(
            body.get_text(
                " ",
                strip=True
            )
        )

        if content_is_real(
            txt,
            expected_title
        ):

            candidates.append(
                txt
            )

    # --------------------------------------------------------
    # Clean candidates
    # --------------------------------------------------------

    cleaned_candidates = []

    seen = set()

    for content in candidates:

        content = remove_common_boilerplate(
            content
        )

        if not content_is_real(
            content,
            expected_title
        ):
            continue

        key = hashlib.sha1(
            normalize_for_hash(
                content[:3000]
            ).encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if key in seen:
            continue

        seen.add(key)

        cleaned_candidates.append(
            content
        )

    # --------------------------------------------------------
    # Pick best candidate
    # --------------------------------------------------------

    if not cleaned_candidates:

        if DEBUG_CONTENT:

            print(
                f"⚠️ CONTENT NOT FOUND | "
                f"source page={url} | "
                f"title={expected_title[:100]}"
            )

        return "", date

    # Prefer reasonable article body.
    # Avoid giant complete-page captures.
    reasonable = [
        x for x in cleaned_candidates
        if len(x) <= 25000
    ]

    if reasonable:

        content = max(
            reasonable,
            key=len
        )

    else:

        content = max(
            cleaned_candidates,
            key=len
        )

    if not content_is_real(
        content,
        expected_title
    ):

        if DEBUG_CONTENT:

            print(
                f"⚠️ FINAL CONTENT REJECTED | "
                f"url={url}"
            )

        return "", date

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

    "web information manager",

    "copyright",

]


def is_boilerplate(text):

    if not text:
        return True

    low = text.lower()

    hits = sum(
        1
        for p in BOILERPLATE_PATTERNS
        if p in low
    )

    return hits >= 2


def remove_common_boilerplate(text):

    if not text:
        return ""

    patterns = [

        r"We have tried to put most accurate.*$",

        r"Help Web Information Manager.*$",

        r"Copyright IPRD.*$",

        r"Web Information Manager.*$",

    ]

    for pattern in patterns:

        text = re.sub(
            pattern,
            "",
            text,
            flags=re.I
        )

    return clean_text(
        text
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

    title = clean_title(title)
    url = clean_url(url)
    content = clean_text(content)

    if not title:

        print(
            f"⚠️ ITEM REJECTED: EMPTY TITLE | "
            f"source={source}"
        )

        return None

    if not url:

        print(
            f"⚠️ ITEM REJECTED: EMPTY URL | "
            f"title={title[:100]}"
        )

        return None

    # NEVER use title as content
    if (
        not content
        or content.lower() == title.lower()
    ):

        print(
            f"⚠️ ITEM REJECTED: NO ARTICLE CONTENT | "
            f"source={source} | "
            f"title={title[:100]}"
        )

        return None

    if not content_is_real(
        content,
        title
    ):

        print(
            f"⚠️ ITEM REJECTED: INVALID CONTENT | "
            f"source={source} | "
            f"title={title[:100]}"
        )

        return None

    if is_boilerplate(content):

        print(
            f"⚠️ ITEM REJECTED: BOILERPLATE | "
            f"source={source} | "
            f"title={title[:100]}"
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
                date
                or ""
            )
        ),

        "content": content,

        "content_chars": len(
            content
        ),

        "type": item_type,

    }


# ============================================================
# DEDUPLICATION
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

        key_source = (

            item.get("url")

            or item.get("title")

            or item.get(
                "content",
                ""
            )

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


def scrape_pib_rss():

    print(
        "\n🇮🇳 PIB NATIONAL SCRAPER"
    )

    all_entries = []

    for feed_url in PIB_FEEDS:

        print(
            f"🔎 PIB feed: {feed_url}"
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

                # Normal RSS date
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

                # feedparser structured date
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

                    title[:90]

                )

                summary = clean_text(

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

                    "content": summary,

                })

        except Exception as e:

            print(
                f"⚠️ PIB RSS error: {e}"
            )

    # --------------------------------------------------------
    # Local dedupe without destroying datetime
    # --------------------------------------------------------

    seen = set()

    unique_entries = []

    for item in all_entries:

        key = hashlib.sha1(
            normalize_for_hash(
                item["url"]
            ).encode(
                "utf-8",
                errors="ignore"
            )
        ).hexdigest()

        if key in seen:
            continue

        seen.add(key)

        unique_entries.append(
            item
        )

    all_entries = unique_entries

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(all_entries)}"
    )

    # --------------------------------------------------------
    # Date groups
    # --------------------------------------------------------

    yesterday_items = []

    today_items = []

    dated_other = []

    undated_items = []

    for item in all_entries:

        d = item["date"]

        if not d:

            undated_items.append(
                item
            )

            continue

        if d.date() == YESTERDAY:

            yesterday_items.append(
                item
            )

        elif d.date() == TODAY:

            today_items.append(
                item
            )

        else:

            dated_other.append(
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

    print(
        f"📅 PIB other dated items: "
        f"{len(dated_other)}"
    )

    print(
        f"📅 PIB undated items: "
        f"{len(undated_items)}"
    )

    # --------------------------------------------------------
    # Priority:
    #
    # 1. Yesterday
    # 2. Today
    # 3. Undated latest RSS
    # 4. Other recent
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

    if len(selected) < MAX_PER_SOURCE:

        selected.extend(
            undated_items[
                :MAX_PER_SOURCE
                - len(selected)
            ]
        )

    if len(selected) < MAX_PER_SOURCE:

        selected.extend(
            dated_other[
                :MAX_PER_SOURCE
                - len(selected)
            ]
        )

    if not selected:

        print(
            "⚠️ PIB RSS produced no entries."
        )

        return []

    # --------------------------------------------------------
    # Fetch actual article
    # --------------------------------------------------------

    results = []

    for item in selected:

        content, article_date = (
            fetch_generic_article_content(
                item["url"],
                expected_title=item["title"]
            )
        )

        final_date = (
            article_date
            or item["date"]
        )

        # IMPORTANT:
        # RSS summary can be used only if it is
        # actual content and not merely the title.
        final_content = content

        if not final_content:

            rss_content = clean_text(
                item.get(
                    "content",
                    ""
                )
            )

            if content_is_real(
                rss_content,
                item["title"]
            ):

                final_content = (
                    rss_content
                )

        # NEVER title fallback
        if not final_content:

            print(
                f"❌ PIB SKIPPED - "
                f"actual content unavailable | "
                f"title={item['title'][:100]}"
            )

            continue

        obj = make_item(

            source="PIB",

            title=item["title"],

            url=item["url"],

            date=final_date,

            content=final_content,

            item_type="RSS + Article"

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

PIB_HOME = "https://pib.gov.in/"


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
                a.get("href")
            )
        )

        if not href:
            continue

        if (
            "pib.gov.in"
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

        # Strong PIB article URL filter
        if not any(
            x in href.lower()
            for x in [

                "pressrelease",

                "press-release",

                "release",

                "pib.gov.in",

            ]
        ):
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

    # Dedupe
    seen = set()

    unique = []

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

    for title, url in unique[:40]:

        content, date = (
            fetch_generic_article_content(
                url,
                expected_title=title
            )
        )

        if not content:

            print(
                f"⚠️ PIB WEBSITE SKIP - "
                f"no article content | "
                f"{title[:100]}"
            )

            continue

        if date:

            age = (
                TODAY
                - date.date()
            ).days

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
# NEWS ON AIR NATIONAL
# ============================================================

NEWS_ON_AIR_HOME = (
    "https://newsonair.gov.in/"
)


def scrape_news_on_air_national():

    print(
        "\n📻 NEWS ON AIR NATIONAL SCRAPER"
    )

    html = fetch_url(
        NEWS_ON_AIR_HOME
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
                NEWS_ON_AIR_HOME,
                a.get("href")
            )
        )

        if not href:
            continue

        if (
            "newsonair.gov.in"
            not in href.lower()
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

        # Avoid category/navigation
        low_href = href.lower()

        if any(
            x in low_href
            for x in [

                "/category/",
                "/about",
                "/contact",
                "/privacy",
                "/terms",

            ]
        ):
            continue

        links.append(
            (
                title,
                href
            )
        )

    # Dedupe URLs
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

    results = []

    for title, href in unique_links:

        content, date = (
            fetch_generic_article_content(
                href,
                expected_title=title
            )
        )

        if not content:

            print(
                f"⚠️ AIR SKIP - "
                f"no article content | "
                f"{title[:100]}"
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

            ]
        ):
            continue

        links.append(
            (
                title,
                href
            )
        )

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

    results = []

    for title, href in unique_links:

        content, date = (
            fetch_generic_article_content(
                href,
                expected_title=title
            )
        )

        if not content:

            print(
                f"⚠️ CMO SKIP - "
                f"actual content unavailable | "
                f"{title[:100]}"
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
        "https://state.bihar.gov.in/prdbihar/"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html"
        "?editForm&rowId=8931"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html"
        "?editForm&rowId=8930"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html"
        "?editForm&rowId=6996"
    ),

]


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
                not in href
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

                ]
            ):
                continue

            links.append(
                (
                    title,
                    href
                )
            )

        # ----------------------------------------------------
        # Process article links
        # ----------------------------------------------------

        for title, href in links[:50]:

            content, date = (
                fetch_generic_article_content(
                    href,
                    expected_title=title
                )
            )

            if not content:

                print(
                    f"⚠️ IPRD SKIP - "
                    f"actual content unavailable | "
                    f"{title[:100]}"
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
    "csd/SectionInformation.html"
    "?editForm&rowId=2929",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html"
    "?editForm&rowId=1323",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html"
    "?editForm&rowId=4935",

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

            links.append(
                (
                    title,
                    href
                )
            )

        for title, href in links[:50]:

            content, date = (
                fetch_generic_article_content(
                    href,
                    expected_title=title
                )
            )

            if not content:

                print(
                    f"⚠️ CABINET SKIP - "
                    f"actual content unavailable | "
                    f"{title[:100]}"
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

                if age > 14:
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
# NEWS ON AIR BIHAR
# ============================================================

NEWS_ON_AIR_BIHAR_URLS = [

    "https://newsonair.gov.in/"
    
]


BIHAR_KEYWORDS = [

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

    "motihari",

    "east champaran",

    "west champaran",

    "chapra",

    "ara",

    "arrah",

    "buxar",

    "rohtas",

    "sasaram",

    "nalanda",

    "rajgir",

    "jamui",

    "katihar",

    "kishanganj",

    "saharsa",

    "supaul",

    "madhepura",

    "lakhisarai",

    "sheikhpura",

    "nawada",

    "aurangabad",

    "jehanabad",

    "khagaria",

    "munger",

    "banka",

    "kaimur",

    "siwan",

    "gopalganj",

]


def scrape_news_on_air_bihar():

    print(
        "\n📻 NEWS ON AIR BIHAR SCRAPER"
    )

    results = []

    for page_url in (
        NEWS_ON_AIR_BIHAR_URLS
    ):

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
                "newsonair.gov.in"
                not in href.lower()
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

            low = title.lower()

            # Bihar relevance
            if not any(
                keyword in low
                for keyword in BIHAR_KEYWORDS
            ):
                continue

            content, date = (
                fetch_generic_article_content(
                    href,
                    expected_title=title
                )
            )

            if not content:

                print(
                    f"⚠️ AIR BIHAR SKIP - "
                    f"actual content unavailable | "
                    f"{title[:100]}"
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

            if len(results) >= MAX_PER_SOURCE:
                break

        if len(results) >= MAX_PER_SOURCE:
            break

    results = deduplicate(
        results
    )

    print(
        f"✅ News On AIR Bihar usable: "
        f"{len(results)}"
    )

    return results


# ============================================================
# SOURCE PRIORITY / BUILD NEWS
# ============================================================

def build_news():

    # ========================================================
    # NATIONAL
    #
    # IMPORTANT:
    # PIB + NEWS ON AIR BOTH RUN.
    #
    # News On AIR is NOT only a fallback anymore.
    # ========================================================

    print(
        "\n"
        + "=" * 65
    )

    print(
        "🇮🇳 NATIONAL NEWS SOURCES"
    )

    print(
        "=" * 65
    )

    pib = scrape_pib_rss()

    # PIB website fallback only if RSS weak
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
    # NEWS ON AIR ALWAYS SCRAPED
    # --------------------------------------------------------

    air = scrape_news_on_air_national()

    # Combine BOTH
    national = deduplicate(
        pib + air
    )

    # --------------------------------------------------------
    # If PIB is still empty, AIR remains available.
    # No replacement logic here.
    # --------------------------------------------------------

    if not pib:

        print(
            "⚠️ PIB produced no usable "
            "article content."
        )

    if not air:

        print(
            "⚠️ News On AIR produced "
            "no usable article content."
        )

    # ========================================================
    # BIHAR
    #
    # ALL official sources are independently scraped.
    # ========================================================

    print(
        "\n"
        + "=" * 65
    )

    print(
        "🏛️ BIHAR NEWS SOURCES"
    )

    print(
        "=" * 65
    )

    # --------------------------------------------------------
    # CMO
    # --------------------------------------------------------

    cmo = scrape_cmo_bihar()

    # --------------------------------------------------------
    # IPRD
    # --------------------------------------------------------

    iprd = scrape_iprd_bihar()

    # --------------------------------------------------------
    # CABINET
    # --------------------------------------------------------

    cabinet = scrape_bihar_cabinet()

    # --------------------------------------------------------
    # NEWS ON AIR BIHAR
    #
    # Also always scraped.
    # --------------------------------------------------------

    air_bihar = (
        scrape_news_on_air_bihar()
    )

    # --------------------------------------------------------
    # Combine ALL Bihar sources
    # --------------------------------------------------------

    bihar = deduplicate(

        cmo
        + iprd
        + cabinet
        + air_bihar

    )

    # ========================================================
    # FINAL SOURCE BREAKDOWN
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
            )
            + 1
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

        "generated_at": (
            now_ist().strftime(
                "%Y-%m-%d %H:%M:%S"
            )
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

    print(
        f"\n💾 {OUTPUT_FILE} "
        f"updated successfully!"
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
            f"\n❌ FATAL ERROR: {e}"
        )

        raise
