
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
            allow_redirects=True,
            verify=False
        )

        if r.status_code >= 400:

            print(
                f"⚠️ HTTP {r.status_code}: {url}"
            )

            return None

        return r.text

    except Exception as e:

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

    # Markdown URL
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

    url = url.replace("\\&", "&")
    url = url.replace("\\:", ":")
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
            d.replace(
                tzinfo=timezone.utc
            )
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

    patterns = [

        r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})',

        r'(\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4})',

        r'(\d{4}-\d{2}-\d{2})',

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

        "meta[itemprop='datePublished']",

        "meta[itemprop='dateModified']",

        "span.date",

        ".date",

        ".published",

        ".publish-date",

        ".news-date",

        ".press-date",

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

    text = soup.get_text(
        " ",
        strip=True
    )

    patterns = [

        r'\b\d{1,2}-[A-Za-z]{3}-\d{4}\b',

        r'\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b',

        r'\b\d{1,2}/\d{1,2}/\d{4}\b',

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
# BOILERPLATE
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

    "previous next",

    "state profile",

    "governance profile",

    "facts and figure",

    "distribution of population",

    "decadal growth",

    "read more",

    "speech given by honourable governor",

    "bihar is located in the eastern part",

]


def boilerplate_score(text):

    if not text:
        return 0

    low = text.lower()

    return sum(
        1
        for p in BOILERPLATE_PATTERNS
        if p in low
    )


def is_boilerplate(text):

    if not text:
        return True

    score = boilerplate_score(text)

    return score >= 2


def remove_common_boilerplate(text):

    if not text:
        return ""

    # Remove obvious footer text
    patterns = [

        r"We have tried to put most accurate.*$",

        r"Help Web Information Manager.*$",

        r"Copyright IPRD.*$",

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
# CONTENT QUALITY CHECK
# ============================================================

GENERIC_PAGE_TITLES = {

    "order/circular/notification",

    "compendium of government circulars orders",

    "hindi translation of judgement/order",

    "empanelled cultural parties / theatrical parties / solo artists",

    "state profile",

    "governance profile",

    "facts and figure",

    "phone directory",

    "contact us",

    "feedback",

    "home",

}


def is_generic_page_title(title):

    normalized = clean_text(
        title
    ).lower()

    return normalized in GENERIC_PAGE_TITLES


def content_quality_check(
    title,
    content,
    source=""
):

    title = clean_text(title)
    content = clean_text(content)

    if not content:

        return False, "EMPTY_CONTENT"

    # NEVER accept title as content
    if (
        content.lower()
        == title.lower()
    ):

        return False, "CONTENT_IS_TITLE"

    # Very short content
    if len(content) < 180:

        return False, (
            f"CONTENT_TOO_SHORT_{len(content)}"
        )

    # Generic IPRD pages
    if (
        source == "IPRD Bihar"
        and is_generic_page_title(title)
    ):

        return False, "GENERIC_IPRD_PAGE"

    score = boilerplate_score(
        content
    )

    if score >= 2:

        return False, (
            f"PORTAL_BOILERPLATE_SCORE_{score}"
        )

    # Detect repeated portal menu
    menu_hits = 0

    menu_terms = [

        "previous next",

        "state profile",

        "governance profile",

        "facts and figure",

        "read more",

        "speech given by honourable governor",

        "distribution of population",

        "decadal growth",

    ]

    low = content.lower()

    for term in menu_terms:

        if term in low:
            menu_hits += 1

    if menu_hits >= 3:

        return False, (
            f"IPRD_PORTAL_CONTENT_{menu_hits}"
        )

    # Excessively huge page = probably portal page
    if source == "IPRD Bihar":

        if len(content) > 12000:

            return False, (
                f"IPRD_CONTENT_TOO_LARGE_{len(content)}"
            )

    return True, "OK"


# ============================================================
# GENERIC ARTICLE CONTENT
# ============================================================

def fetch_generic_article_content(
    url,
    source=""
):

    url = clean_url(url)

    if not url:
        return "", None

    html = fetch_url(url)

    if not html:
        return "", None

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    # --------------------------------------------------------
    # DATE BEFORE REMOVING TAGS
    # --------------------------------------------------------

    date = extract_date_from_soup(
        soup
    )

    # --------------------------------------------------------
    # REMOVE NON-CONTENT
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

    ]):

        tag.decompose()

    candidates = []

    # --------------------------------------------------------
    # ARTICLE SELECTORS
    # --------------------------------------------------------

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

        ".press-release-content",

        ".release-content",

        ".content-area",

        ".main-content",

        ".article-content",

        ".article_content",

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

            if len(txt) >= 180:

                candidates.append(
                    txt
                )

    # --------------------------------------------------------
    # PARAGRAPH FALLBACK
    # --------------------------------------------------------

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

            candidates.append(
                " ".join(paragraphs)
            )

    # --------------------------------------------------------
    # BODY FALLBACK
    # --------------------------------------------------------

    if not candidates:

        body = soup.body

        if body:

            txt = clean_text(
                body.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 180:

                candidates.append(
                    txt
                )

    if not candidates:

        print(
            f"   ⚠️ DEBUG NO CONTENT | "
            f"{source} | {url}"
        )

        return "", date

    # --------------------------------------------------------
    # SELECT BEST CANDIDATE
    # --------------------------------------------------------

    candidates = sorted(
        candidates,
        key=len,
        reverse=True
    )

    content = candidates[0]

    content = remove_common_boilerplate(
        content
    )

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

    # IMPORTANT:
    # Never convert title into content.
    valid, reason = content_quality_check(
        title,
        content,
        source
    )

    if not valid:

        print(
            f"   ⚠️ DEBUG CONTENT REJECTED | "
            f"source={source} | "
            f"reason={reason} | "
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
                    title[:90]
                )

                content = clean_text(
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

                    "content": content,

                })

        except Exception as e:

            print(
                f"⚠️ PIB RSS error: {e}"
            )

    # Do not lose date object
    seen = set()

    unique_entries = []

    for item in all_entries:

        key = item["url"]

        if key in seen:
            continue

        seen.add(key)

        unique_entries.append(
            item
        )

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(unique_entries)}"
    )

    yesterday_items = []
    today_items = []
    undated_items = []

    for item in unique_entries:

        d = item["date"]

        if d:

            if d.date() == YESTERDAY:

                yesterday_items.append(
                    item
                )

            elif d.date() == TODAY:

                today_items.append(
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
    # Priority:
    # Yesterday -> Today -> Undated
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

    # Emergency latest RSS
    if len(selected) < 5:

        print(
            "⚠️ PIB date filtering produced "
            "too few items. "
            "Using latest RSS entries "
            "as emergency fallback."
        )

        for item in unique_entries:

            if item not in selected:

                selected.append(
                    item
                )

            if len(selected) >= MAX_PER_SOURCE:

                break

    results = []

    for item in selected[
        :MAX_PER_SOURCE
    ]:

        content, article_date = (
            fetch_generic_article_content(
                item["url"],
                "PIB"
            )
        )

        final_date = (
            article_date
            or item["date"]
        )

        # IMPORTANT:
        # RSS summary can be title-like.
        # Do NOT use title as content.
        if not content:

            print(
                f"   ⚠️ DEBUG PIB "
                f"NO ARTICLE CONTENT | "
                f"{item['title'][:100]}"
            )

            continue

        obj = make_item(

            source="PIB",

            title=item["title"],

            url=item["url"],

            date=final_date,

            content=content,

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
                a.get("href", "")
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

        # Only actual PIB article links
        if not any(
            x in href.lower()
            for x in [

                "pressrelease",
                "press-release",
                "release",

            ]
        ):

            continue

        candidates.append(
            (
                title,
                href
            )
        )

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

    for title, url in unique[
        :40
    ]:

        content, date = (
            fetch_generic_article_content(
                url,
                "PIB"
            )
        )

        if not content:

            print(
                f"   ⚠️ DEBUG PIB FALLBACK "
                f"NO CONTENT | {title[:100]}"
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

    results = []

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

                "cricket",
                "football",
                "tennis",
                "badminton",
                "sports",

            ]
        ):

            continue

        content, date = (
            fetch_generic_article_content(
                href,
                "News On AIR"
            )
        )

        # NEVER title fallback
        if not content:

            print(
                f"   ⚠️ DEBUG AIR "
                f"NO CONTENT | {title[:100]}"
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

    results = []

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

        content, date = (
            fetch_generic_article_content(
                href,
                "CMO Bihar"
            )
        )

        # NEVER use title
        if not content:

            print(
                f"   ⚠️ DEBUG CMO "
                f"NO CONTENT | {title[:100]}"
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
        "prdbihar/SectionInformation.html?"
        "editForm&rowId=8931"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html?"
        "editForm&rowId=8930"
    ),

    (
        "IPRD Bihar",
        "https://state.bihar.gov.in/"
        "prdbihar/SectionInformation.html?"
        "editForm&rowId=6996"
    ),

]


def is_iprd_article_link(
    title,
    href
):

    low_title = clean_text(
        title
    ).lower()

    low_url = href.lower()

    # Generic section pages
    if is_generic_page_title(
        title
    ):

        return False

    # Known portal sections
    blocked_title_terms = [

        "order/circular/notification",

        "compendium",

        "hindi translation",

        "empanelled cultural",

        "theatrical parties",

        "solo artists",

        "state profile",

        "governance profile",

        "facts and figure",

        "phone directory",

        "department",

        "organization chart",

    ]

    if any(
        x in low_title
        for x in blocked_title_terms
    ):

        return False

    # Same SectionInformation pages are often
    # category/listing pages.
    if (
        "sectioninformation.html"
        in low_url
    ):

        # Only allow if title strongly resembles
        # an actual news/press release.
        allowed_terms = [

            "press release",
            "प्रेस विज्ञप्ति",
            "समाचार",
            "news",
            "मुख्यमंत्री",
            "मंत्री",
            "सरकार",
            "बिहार",
            "उद्घाटन",
            "शुभारंभ",
            "बैठक",
            "कार्यक्रम",
            "योजना",
            "घोषणा",
            "निर्देश",
            "आदेश",
            "सम्मेलन",
            "कार्यशाला",
            "पुरस्कार",
            "नियुक्ति",

        ]

        if not any(
            term in low_title
            for term in allowed_terms
        ):

            return False

    return True


def scrape_iprd_bihar():

    print(
        "\n📢 IPRD BIHAR SCRAPER"
    )

    results = []

    discovered = []

    # --------------------------------------------------------
    # DISCOVER LINKS
    # --------------------------------------------------------

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

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 25:

                continue

            if not is_iprd_article_link(
                title,
                href
            ):

                continue

            discovered.append(
                (
                    title,
                    href
                )
            )

    # --------------------------------------------------------
    # DEDUPE DISCOVERED LINKS
    # --------------------------------------------------------

    seen = set()

    unique_links = []

    for title, href in discovered:

        if href in seen:

            continue

        seen.add(href)

        unique_links.append(
            (
                title,
                href
            )
        )

    print(
        f"🔎 IPRD candidate links: "
        f"{len(unique_links)}"
    )

    # --------------------------------------------------------
    # FETCH ACTUAL CONTENT
    # --------------------------------------------------------

    for title, href in unique_links:

        print(
            f"   🔍 IPRD checking: "
            f"{title[:100]}"
        )

        content, date = (
            fetch_generic_article_content(
                href,
                "IPRD Bihar"
            )
        )

        # IMPORTANT:
        # NO TITLE FALLBACK
        if not content:

            print(
                f"   ⚠️ DEBUG IPRD "
                f"NO CONTENT | "
                f"{title[:100]}"
            )

            continue

        valid, reason = (
            content_quality_check(
                title,
                content,
                "IPRD Bihar"
            )
        )

        if not valid:

            print(
                f"   ⚠️ DEBUG IPRD "
                f"REJECTED | "
                f"{reason} | "
                f"{title[:100]}"
            )

            continue

        # Old archive filtering
        if date:

            age = (
                TODAY
                - date.date()
            ).days

            if age > 3:

                print(
                    f"   ⏭️ IPRD old: "
                    f"{title[:80]}"
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

            print(
                f"   ✅ IPRD accepted | "
                f"{len(content)} chars"
            )

            results.append(
                obj
            )

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
                    href,
                    "Bihar Cabinet Decision"
                )
            )

            # NO TITLE FALLBACK
            if not content:

                print(
                    f"   ⚠️ DEBUG CABINET "
                    f"NO CONTENT | "
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

                source=(
                    "Bihar Cabinet Decision"
                ),

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
    "category/regional-news/",

    "https://newsonair.gov.in/"
    "category/regional/",

    "https://newsonair.gov.in/",

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

]


def scrape_news_on_air_bihar():

    print(
        "\n📻 NEWS ON AIR BIHAR"
    )

    results = []

    for page_url in NEWS_ON_AIR_BIHAR_URLS:

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

            title = clean_title(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 25:

                continue

            low = title.lower()

            if not any(
                x in low
                for x in BIHAR_KEYWORDS
            ):

                continue

            content, date = (
                fetch_generic_article_content(
                    href,
                    "News On AIR Bihar"
                )
            )

            # NO TITLE FALLBACK
            if not content:

                print(
                    f"   ⚠️ DEBUG AIR BIHAR "
                    f"NO CONTENT | "
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
# BUILD NEWS
# ============================================================

def build_news():

    # ========================================================
    # NATIONAL
    # ========================================================

    # PIB ALWAYS SCRAPE
    pib = scrape_pib_rss()

    # PIB website fallback if needed
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
    # NEWS ON AIR ALWAYS SCRAPE
    # --------------------------------------------------------

    air = (
        scrape_news_on_air_national()
    )

    # IMPORTANT:
    # AIR is NOT replacement for PIB.
    # Both sources remain.
    national = deduplicate(
        pib + air
    )

    # ========================================================
    # BIHAR
    # ========================================================

    # ALL official sources independently scrape
    cmo = scrape_cmo_bihar()

    iprd = scrape_iprd_bihar()

    cabinet = scrape_bihar_cabinet()

    # News On AIR Bihar also scrape
    air_bihar = (
        scrape_news_on_air_bihar()
    )

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

    output = {

        "generated_at":
            now_ist().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "bihar_raw_count":
            len(bihar),

        "national_raw_count":
            len(national),

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

