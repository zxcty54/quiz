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

# Maximum accepted articles per source
MAX_PER_SOURCE = 15

# Number of listing/detail links to inspect
MAX_LINKS_PER_SOURCE = 80

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
}

warnings.filterwarnings(
    "ignore",
    category=MarkupResemblesLocatorWarning
)


# ============================================================
# TIMEZONE
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
    """
    Converts:
        [https://example.com/page](https://example.com/page)

    into:
        https://example.com/page
    """

    if not url:
        return ""

    url = str(url).strip()

    # Markdown link
    m = re.search(
        r'\]\(\s*(https?://[^)\s]+)\s*\)',
        url
    )

    if m:
        url = m.group(1)

    # Sometimes source data contains escaped markdown URL
    url = url.replace("\\&", "&")
    url = url.replace("\\?", "?")
    url = url.replace("\\:", ":")
    url = url.replace("\\/", "/")

    # Remove markdown wrapper
    url = re.sub(
        r'^\s*\[[^\]]*\]\(',
        '',
        url
    )

    if url.endswith(")"):
        url = url[:-1]

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


# ============================================================
# HTTP FETCH
# ============================================================

def fetch_url(url, timeout=TIMEOUT):
    """
    Fetch page using curl_cffi.

    Returns:
        HTML string
        OR None
    """

    url = clean_url(url)

    if not url:
        return None

    try:

        response = requests.get(
            url,
            headers=HEADERS,
            timeout=timeout,
            impersonate="chrome",
            allow_redirects=True,
            verify=True
        )

        final_url = response.url

        if response.status_code >= 400:

            print(
                f"⚠️ HTTP {response.status_code}: "
                f"{url}"
            )

            return None

        if not response.text:
            print(
                f"⚠️ EMPTY RESPONSE: {url}"
            )

            return None

        return response.text

    except Exception as e:

        print(
            f"⚠️ FETCH FAILED: {url} | {e}"
        )

        return None


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

    text = (
        text
        .replace("\xa0", " ")
        .replace("\u200b", " ")
        .replace("\ufeff", " ")
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
        r'(PTI|Press Trust of India|'
        r'PIB|News On AIR|Doordarshan News|'
        r'Sansad TV).*$',
        '',
        title,
        flags=re.I
    )

    return title.strip()


# ============================================================
# HASH / NORMALIZATION
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
            clean_url(item.get("url", ""))
            or item.get("title", "")
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

    if not value:
        return None

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

    # Search inside larger text
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

        candidate = m.group(0)

        for fmt in [
            "%d-%m-%Y",
            "%d/%m/%Y",
            "%d-%b-%Y",
            "%d-%B-%Y",
            "%d/%b/%Y",
            "%d/%B/%Y",
            "%d %b %Y",
            "%d %B %Y",
            "%Y-%m-%d",
        ]:

            try:

                d = datetime.strptime(
                    candidate,
                    fmt
                )

                return d.replace(
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
        "meta[name='published']",
        "meta[name='date']",
        "meta[name='DC.date']",

        "meta[itemprop='datePublished']",
        "meta[itemprop='dateModified']",

        "[itemprop='datePublished']",
        "[itemprop='dateCreated']",

        ".date",
        ".published",
        ".publish-date",
        ".posted-date",
        ".news-date",
        ".article-date",
        ".story-date",

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

    return None


# ============================================================
# REMOVE PAGE NOISE
# ============================================================

REMOVE_TAGS = [

    "script",
    "style",
    "noscript",
    "svg",
    "canvas",

    "nav",
    "footer",
    "header",

    "form",

    "iframe",

    "aside",

    "button",

]


def remove_page_noise(soup):

    for tag in soup(
        REMOVE_TAGS
    ):

        try:
            tag.decompose()
        except Exception:
            pass

    # Remove obvious UI blocks
    for selector in [

        ".cookie",
        ".cookies",
        ".cookie-banner",

        ".social-share",
        ".share",
        ".sharing",

        ".advertisement",
        ".advert",
        ".ads",
        ".ad-container",

        ".sidebar",
        ".right-sidebar",
        ".left-sidebar",

        ".breadcrumb",

        ".navigation",
        ".menu",

        ".related-posts",
        ".related-news",

        ".comments",
        ".comment-section",

        ".newsletter",

        ".login",
        ".modal",

    ]:

        try:

            for el in soup.select(
                selector
            ):

                el.decompose()

        except Exception:
            pass

    return soup


# ============================================================
# BOILERPLATE
# ============================================================

PORTAL_NOISE = [

    "accessibility options",
    "skip to main content",
    "screen reader access",

    "site map",
    "sitemap",

    "contact us",
    "feedback",

    "copyright",
    "web information manager",

    "privacy policy",
    "terms and conditions",

    "follow us",
    "subscribe",

    "previous next",

    "read more",

    "login",
    "sign in",

]


def boilerplate_score(text):

    low = text.lower()

    return sum(
        1
        for x in PORTAL_NOISE
        if x in low
    )


def is_bad_content(text):

    if not text:
        return True

    text = clean_text(text)

    if len(text) < 120:
        return True

    score = boilerplate_score(text)

    # A giant page with lots of portal UI
    # should not be considered an article.
    if score >= 5:
        return True

    return False


# ============================================================
# JSON-LD ARTICLE EXTRACTION
# ============================================================

def extract_jsonld_content(soup):

    results = []

    for script in soup.find_all(
        "script",
        type=re.compile(
            r'application/ld\+json',
            re.I
        )
    ):

        raw = script.string or script.get_text()

        if not raw:
            continue

        try:
            data = json.loads(
                raw.strip()
            )
        except Exception:
            continue

        objects = []

        if isinstance(data, dict):

            objects.append(data)

            graph = data.get("@graph")

            if isinstance(
                graph,
                list
            ):
                objects.extend(
                    graph
                )

        elif isinstance(data, list):

            objects.extend(data)

        for obj in objects:

            if not isinstance(
                obj,
                dict
            ):
                continue

            typ = obj.get("@type", "")

            if isinstance(
                typ,
                list
            ):
                typ = " ".join(
                    map(str, typ)
                )

            typ = str(
                typ
            ).lower()

            if any(
                x in typ
                for x in [
                    "article",
                    "newsarticle",
                    "report",
                    "blogposting",
                    "scholarlyarticle",
                ]
            ):

                for key in [
                    "articleBody",
                    "description",
                ]:

                    value = obj.get(
                        key
                    )

                    if value:

                        txt = clean_text(
                            value
                        )

                        if len(txt) >= 120:
                            results.append(
                                txt
                            )

    if not results:
        return ""

    return max(
        results,
        key=len
    )


# ============================================================
# META CONTENT
# ============================================================

def extract_meta_content(soup):

    values = []

    for selector in [

        "meta[property='og:description']",
        "meta[name='description']",

        "meta[name='twitter:description']",

    ]:

        try:

            for el in soup.select(
                selector
            ):

                value = el.get(
                    "content",
                    ""
                )

                value = clean_text(
                    value
                )

                if len(value) >= 120:
                    values.append(
                        value
                    )

        except Exception:
            pass

    if not values:
        return ""

    return max(
        values,
        key=len
    )


# ============================================================
# ARTICLE CONTAINER EXTRACTION
# ============================================================

ARTICLE_SELECTORS = [

    # Generic
    "article",
    "[itemprop='articleBody']",

    # Common CMS
    ".article-body",
    ".articleBody",
    ".article-content",
    ".articleContent",

    ".story-content",
    ".storyContent",
    ".story-body",
    ".storyBody",

    ".news-content",
    ".newsContent",
    ".news-body",

    ".post-content",
    ".entry-content",
    ".single-post-content",

    ".content-area",
    ".main-content",
    ".main-content-area",

    "main",

    # WordPress
    ".td-post-content",
    ".jeg_main_content",
    ".post-entry-content",

    # Bootstrap/common
    ".container .article",
    ".container article",

]


def extract_article_containers(soup):

    candidates = []

    for selector in ARTICLE_SELECTORS:

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

            if len(txt) >= 120:

                candidates.append(
                    txt
                )

    if not candidates:
        return ""

    return max(
        candidates,
        key=len
    )


# ============================================================
# PARAGRAPH EXTRACTION
# ============================================================

def extract_paragraphs(soup):

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

        # Reject obvious navigation
        low = txt.lower()

        if any(
            x in low
            for x in [
                "click here",
                "read more",
                "subscribe",
                "follow us",
                "privacy policy",
                "terms and conditions",
            ]
        ):
            continue

        paragraphs.append(
            txt
        )

    if not paragraphs:
        return ""

    text = " ".join(
        paragraphs
    )

    return clean_text(
        text
    )


# ============================================================
# MAIN CONTENT EXTRACTION
# ============================================================

def extract_best_content(
    html,
    title="",
    debug_prefix=""
):

    if not html:
        return "", None, "EMPTY_HTML"

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    date = extract_date_from_soup(
        soup
    )

    remove_page_noise(
        soup
    )

    candidates = []

    # 1. JSON-LD articleBody
    jsonld = extract_jsonld_content(
        soup
    )

    if jsonld:
        candidates.append(
            (
                "JSON-LD articleBody",
                jsonld
            )
        )

    # 2. Article containers
    container = extract_article_containers(
        soup
    )

    if container:
        candidates.append(
            (
                "ARTICLE CONTAINER",
                container
            )
        )

    # 3. Paragraphs
    paragraphs = extract_paragraphs(
        soup
    )

    if paragraphs:
        candidates.append(
            (
                "PARAGRAPHS",
                paragraphs
            )
        )

    # 4. Meta description
    meta = extract_meta_content(
        soup
    )

    if meta:
        candidates.append(
            (
                "META DESCRIPTION",
                meta
            )
        )

    # --------------------------------------------------------
    # Score candidates
    # --------------------------------------------------------

    scored = []

    normalized_title = normalize_for_hash(
        title
    )

    for method, text in candidates:

        text = clean_text(
            text
        )

        if not text:
            continue

        # Remove title repetition
        if normalized_title:

            title_norm = normalize_for_hash(
                title
            )

            content_norm = normalize_for_hash(
                text
            )

            if content_norm == title_norm:
                continue

        # Reject short content
        if len(text) < 120:
            continue

        score = len(text)

        # Prefer actual article containers
        if method == "JSON-LD articleBody":
            score += 5000

        elif method == "ARTICLE CONTAINER":
            score += 3000

        elif method == "PARAGRAPHS":
            score += 2000

        elif method == "META DESCRIPTION":
            score += 500

        # Penalize portal boilerplate
        score -= (
            boilerplate_score(text)
            * 1000
        )

        scored.append(
            (
                score,
                method,
                text
            )
        )

    if not scored:

        return (
            "",
            date,
            "NO_VALID_CONTENT"
        )

    scored.sort(
        key=lambda x: x[0],
        reverse=True
    )

    best_score, method, content = (
        scored[0]
    )

    # If content is overwhelmingly
    # portal garbage, reject.
    if is_bad_content(
        content
    ):

        return (
            "",
            date,
            "PORTAL_BOILERPLATE"
        )

    # Extra protection:
    # If the content is essentially the title
    # reject it.
    title_norm = normalize_for_hash(
        title
    )

    content_norm = normalize_for_hash(
        content
    )

    if title_norm and (
        content_norm == title_norm
    ):

        return (
            "",
            date,
            "CONTENT_EQUALS_TITLE"
        )

    return (
        content,
        date,
        method
    )


# ============================================================
# ARTICLE FETCHER
# ============================================================

def fetch_article(
    url,
    title,
    source
):

    url = clean_url(
        url
    )

    if not url:
        return "", None, "INVALID_URL"

    html = fetch_url(
        url
    )

    if not html:

        print(
            f"⚠️ DEBUG NO HTML | "
            f"{source} | {url}"
        )

        return (
            "",
            None,
            "FETCH_FAILED"
        )

    content, date, method = (
        extract_best_content(
            html,
            title=title,
            debug_prefix=source
        )
    )

    if not content:

        print(
            f"⚠️ DEBUG NO CONTENT | "
            f"{source} | {url}"
        )

        print(
            f"   TITLE: {title[:180]}"
        )

        print(
            f"   REASON: {method}"
        )

        return (
            "",
            date,
            method
        )

    print(
        f"   ✅ CONTENT | "
        f"{source} | "
        f"{len(content):,} chars | "
        f"{method} | "
        f"{title[:80]}"
    )

    return (
        content,
        date,
        method
    )


# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(
    source,
    title,
    url,
    date,
    content,
    item_type
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

    # --------------------------------------------------------
    # ABSOLUTE RULE:
    # Never use title as content.
    # --------------------------------------------------------

    if not content:
        return None

    if len(content) < 120:
        return None

    if normalize_for_hash(
        content
    ) == normalize_for_hash(
        title
    ):
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
            else ""
        ),

        "content": content,

        "content_chars": len(
            content
        ),

        "type": item_type,

    }


# ============================================================
# GENERIC LINK DISCOVERY
# ============================================================

def discover_links(
    html,
    base_url,
    source
):

    if not html:
        return []

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    links = []

    seen = set()

    for a in soup.find_all(
        "a",
        href=True
    ):

        href = clean_url(
            urljoin(
                base_url,
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

        if len(title) < 20:
            continue

        if href in seen:
            continue

        seen.add(href)

        links.append(
            (
                title,
                href
            )
        )

    print(
        f"🔎 {source} candidate links: "
        f"{len(links)}"
    )

    return links


# ============================================================
# SOURCE LINK FILTER
# ============================================================

def same_domain(
    url,
    domains
):

    host = (
        urlparse(url)
        .netloc
        .lower()
    )

    return any(
        d in host
        for d in domains
    )


def looks_like_navigation(
    title,
    url
):

    low_title = title.lower()
    low_url = url.lower()

    bad_title = [

        "home",
        "about us",
        "contact us",
        "contact",
        "feedback",

        "login",
        "sign in",
        "register",

        "privacy",
        "terms",

        "sitemap",

        "accessibility",
        "accessibility options",

        "search",

        "subscribe",

        "facebook",
        "twitter",
        "instagram",
        "youtube",
        "linkedin",

        "previous",
        "next",

    ]

    if any(
        x == low_title
        or x in low_title
        for x in bad_title
    ):
        return True

    bad_url = [

        "/login",
        "/signin",
        "/register",

        "/contact",
        "/feedback",

        "/privacy",
        "/terms",

        "/sitemap",

        "/search",

    ]

    if any(
        x in low_url
        for x in bad_url
    ):
        return True

    return False


# ============================================================
# GENERIC SOURCE SCRAPER
# ============================================================

def scrape_source(
    source,
    listing_urls,
    domains,
    keywords=None,
    max_items=MAX_PER_SOURCE
):

    print(
        f"\n{'=' * 65}"
    )

    print(
        f"📰 {source.upper()} SCRAPER"
    )

    print(
        f"{'=' * 65}"
    )

    all_links = []

    # --------------------------------------------------------
    # STEP 1: collect listing links
    # --------------------------------------------------------

    for listing_url in listing_urls:

        print(
            f"🔎 Listing: {listing_url}"
        )

        html = fetch_url(
            listing_url
        )

        if not html:
            continue

        links = discover_links(
            html,
            listing_url,
            source
        )

        for title, href in links:

            if not same_domain(
                href,
                domains
            ):
                continue

            if looks_like_navigation(
                title,
                href
            ):
                continue

            if keywords:

                combined = (
                    title + " " + href
                ).lower()

                if not any(
                    k.lower()
                    in combined
                    for k in keywords
                ):
                    continue

            all_links.append(
                (
                    title,
                    href
                )
            )

    # dedupe links
    unique_links = []

    seen_urls = set()

    for title, href in all_links:

        if href in seen_urls:
            continue

        seen_urls.add(href)

        unique_links.append(
            (
                title,
                href
            )
        )

    print(
        f"🔗 {source} unique candidate "
        f"articles: {len(unique_links)}"
    )

    # --------------------------------------------------------
    # STEP 2: fetch actual article pages
    # --------------------------------------------------------

    results = []

    checked = 0

    for title, href in unique_links:

        if checked >= MAX_LINKS_PER_SOURCE:
            break

        checked += 1

        print(
            f"\n🔍 {source} checking: "
            f"{title[:120]}"
        )

        content, date, method = (
            fetch_article(
                href,
                title,
                source
            )
        )

        # NEVER title fallback
        if not content:

            print(
                f"⚠️ REJECTED | "
                f"{method} | "
                f"{title[:120]}"
            )

            continue

        obj = make_item(

            source=source,

            title=title,

            url=href,

            date=date,

            content=content,

            item_type=(
                f"{source} Article"
            )

        )

        if obj:

            results.append(
                obj
            )

        if len(results) >= max_items:
            break

        # small delay
        time.sleep(0.15)

    results = deduplicate(
        results
    )

    print(
        f"✅ {source} usable news: "
        f"{len(results)}"
    )

    return results


# ============================================================
# PTI
# ============================================================

PTI_LISTING_URLS = [

    "https://www.ptinews.com/",

    "https://www.ptinews.com/latest-news",

    "https://www.ptinews.com/national",

    "https://www.ptinews.com/business",

    "https://www.ptinews.com/world",

]

PTI_DOMAINS = [
    "ptinews.com",
    "pti.in",
]


def scrape_pti():

    return scrape_source(

        source="PTI",

        listing_urls=PTI_LISTING_URLS,

        domains=PTI_DOMAINS,

        max_items=MAX_PER_SOURCE

    )


# ============================================================
# PRS INDIA
# ============================================================

PRS_LISTING_URLS = [

    "https://prsindia.org/",

    "https://prsindia.org/announcements",

    "https://prsindia.org/billtrack/category/all",

    "https://prsindia.org/acts/parliament",

    "https://prsindia.org/sessiontrack",

]

PRS_DOMAINS = [
    "prsindia.org"
]


def scrape_prs():

    return scrape_source(

        source="PRS India",

        listing_urls=PRS_LISTING_URLS,

        domains=PRS_DOMAINS,

        max_items=MAX_PER_SOURCE

    )


# ============================================================
# INDIA.GOV.IN
# ============================================================

INDIA_GOV_LISTING_URLS = [

    "https://www.india.gov.in/",

    "https://www.india.gov.in/news",

    "https://www.india.gov.in/news/press-release",

]

INDIA_GOV_DOMAINS = [
    "india.gov.in"
]


def scrape_india_gov():

    return scrape_source(

        source="India.gov.in",

        listing_urls=INDIA_GOV_LISTING_URLS,

        domains=INDIA_GOV_DOMAINS,

        max_items=MAX_PER_SOURCE

    )


# ============================================================
# DOORDARSHAN / NEWS ON AIR
# ============================================================

DD_LISTING_URLS = [

    "https://www.newsonair.gov.in/",

    "https://www.newsonair.gov.in/category/national/",

    "https://www.newsonair.gov.in/category/state/",

    "https://www.newsonair.gov.in/category/business/",

]

DD_DOMAINS = [

    "newsonair.gov.in",

    "prasarbharati.gov.in",

]

def scrape_doordarshan():

    return scrape_source(

        source="Doordarshan News",

        listing_urls=DD_LISTING_URLS,

        domains=DD_DOMAINS,

        max_items=MAX_PER_SOURCE

    )


# ============================================================
# SANSAD TV
# ============================================================

SANSAD_LISTING_URLS = [

    "https://sansadtv.nic.in/",

    "https://sansadtv.nic.in/show_type/sansad-mein-aaj",

    "https://sansadtv.nic.in/category/news",

]

SANSAD_DOMAINS = [
    "sansadtv.nic.in"
]


def scrape_sansad_tv():

    return scrape_source(

        source="Sansad TV",

        listing_urls=SANSAD_LISTING_URLS,

        domains=SANSAD_DOMAINS,

        max_items=MAX_PER_SOURCE

    )


# ============================================================
# EXTRA: DIRECT ARTICLE DISCOVERY FROM HTML
# ============================================================

def discover_deep_article_links(
    listing_url,
    source,
    domains
):

    """
    Second extraction path.

    Some sites do not expose article links
    in normal <a> text.

    This also looks at:
      - data-url
      - data-href
      - canonical
      - og:url
    """

    html = fetch_url(
        listing_url
    )

    if not html:
        return []

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    found = []

    # canonical
    for el in soup.select(
        "link[rel='canonical']"
    ):

        href = clean_url(
            el.get("href")
        )

        if href and same_domain(
            href,
            domains
        ):

            found.append(
                (
                    "",
                    href
                )
            )

    # OG URL
    for el in soup.select(
        "meta[property='og:url']"
    ):

        href = clean_url(
            el.get("content")
        )

        if href and same_domain(
            href,
            domains
        ):

            found.append(
                (
                    "",
                    href
                )
            )

    # data-url / data-href
    for el in soup.find_all(
        True
    ):

        for attr in [
            "data-url",
            "data-href",
            "data-link",
        ]:

            value = el.get(
                attr
            )

            if not value:
                continue

            href = clean_url(
                urljoin(
                    listing_url,
                    value
                )
            )

            if href and same_domain(
                href,
                domains
            ):

                title = clean_title(
                    el.get_text(
                        " ",
                        strip=True
                    )
                )

                found.append(
                    (
                        title,
                        href
                    )
                )

    return found


# ============================================================
# MAIN
# ============================================================

def build_news():

    print(
        "\n"
        "########################################################\n"
        "# INDIA NEWS MULTI-SOURCE SCRAPER                      #\n"
        "# PIB DISABLED                                          #\n"
        "# PTI + PRS + INDIA.GOV.IN + DOORDARSHAN + SANSAD TV  #\n"
        "########################################################\n"
    )

    # --------------------------------------------------------
    # 1. PTI
    # --------------------------------------------------------

    pti = scrape_pti()

    # --------------------------------------------------------
    # 2. PRS
    # --------------------------------------------------------

    prs = scrape_prs()

    # --------------------------------------------------------
    # 3. INDIA.GOV.IN
    # --------------------------------------------------------

    india_gov = scrape_india_gov()

    # --------------------------------------------------------
    # 4. DOORDARSHAN
    # --------------------------------------------------------

    doordarshan = scrape_doordarshan()

    # --------------------------------------------------------
    # 5. SANSAD TV
    # --------------------------------------------------------

    sansad = scrape_sansad_tv()

    # --------------------------------------------------------
    # FINAL DEDUPE
    # --------------------------------------------------------

    all_news = (
        pti
        + prs
        + india_gov
        + doordarshan
        + sansad
    )

    all_news = deduplicate(
        all_news
    )

    # --------------------------------------------------------
    # SOURCE BREAKDOWN
    # --------------------------------------------------------

    breakdown = {}

    for item in all_news:

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
        "\n"
        "================ SOURCE BREAKDOWN ================\n"
    )

    print(
        json.dumps(
            breakdown,
            ensure_ascii=False,
            indent=2
        )
    )

    print(
        "\n"
        f"📰 TOTAL NEWS: "
        f"{len(all_news)}"
    )

    return (
        all_news,
        breakdown
    )


# ============================================================
# SAVE
# ============================================================

def save_output(
    all_news,
    breakdown
):

    output = {

        "generated_at":
            now_ist().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "total_news":
            len(all_news),

        "source_breakdown":
            breakdown,

        "news":
            all_news,

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

    # --------------------------------------------------------
    # SIZE
    # --------------------------------------------------------

    try:

        size_mb = (
            os.path.getsize(
                OUTPUT_FILE
            )
            / (
                1024 * 1024
            )
        )

        print(
            f"📦 JSON size: "
            f"{size_mb:.2f} MB"
        )

    except Exception:
        pass


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":

    try:

        news, breakdown = (
            build_news()
        )

        save_output(
            news,
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