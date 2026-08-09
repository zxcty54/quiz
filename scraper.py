
import os
import json
import time
import urllib.parse
import re
import io
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET

import urllib3
from curl_cffi import requests
from bs4 import BeautifulSoup
from dateutil import parser as date_parser

# Optional PDF extraction
try:
    import fitz  # PyMuPDF
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False


# =============================================================
# CONFIG
# =============================================================

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_PARAGRAPH_CHARS = 35

DIRECT_TIMEOUT = 15
SCRAPINGANT_TIMEOUT = 30

# Bihar official sources
IPRD_HOME = "https://state.bihar.gov.in/prdbihar/"
IPRD_SEARCH = "https://state.bihar.gov.in/prdbihar/SearchContent.html"

# These are intentionally used as discovery/fallback sources.
BIHAR_GOV_HOME = "https://state.bihar.gov.in/"
CABINET_DEPT = "https://state.bihar.gov.in/csd/"

# Known Bihar government portal pattern
CM_PRESS_RELEASE_PATTERN = "SectionInformation.html?editForm=&rowId=8929"


# =============================================================
# 1. DATE ENGINE
# =============================================================

def get_yesterday_info():
    yesterday_dt = datetime.now() - timedelta(days=1)

    date_str = yesterday_dt.strftime("%d %b %Y")
    key_str = yesterday_dt.strftime("%Y-%m-%d")

    return yesterday_dt, date_str, key_str


def parse_any_date(date_str):
    if not date_str:
        return None

    date_str = str(date_str).strip()

    if not date_str:
        return None

    now = datetime.now()
    lower_str = date_str.lower()

    # Relative dates
    if "yesterday" in lower_str:
        return now - timedelta(days=1)

    if "today" in lower_str:
        return now

    relative_match = re.search(
        r"(\d+)\s+(hour|hr|day|min|minute)s?\s+ago",
        lower_str
    )

    if relative_match:
        val = int(relative_match.group(1))
        unit = relative_match.group(2)

        if "day" in unit:
            return now - timedelta(days=val)

        if "hour" in unit or "hr" in unit:
            return now - timedelta(hours=val)

        if "min" in unit:
            return now - timedelta(minutes=val)

    # Unix timestamp
    if date_str.isdigit():
        try:
            ts = int(date_str)

            if ts > 1e11:
                ts /= 1000

            return datetime.fromtimestamp(ts)

        except Exception:
            pass

    # RFC date
    try:
        pub_tuple = email.utils.parsedate_tz(date_str)

        if pub_tuple:
            return datetime.fromtimestamp(
                email.utils.mktime_tz(pub_tuple)
            )

    except Exception:
        pass

    # Generic date parser
    try:
        parsed_dt = date_parser.parse(
            date_str,
            fuzzy=True,
            dayfirst=True
        )

        if parsed_dt.tzinfo is not None:
            parsed_dt = parsed_dt.astimezone().replace(tzinfo=None)

        return parsed_dt

    except Exception:
        pass

    return None


def is_target_news(pub_date_str, target_dt):

    # If date missing, don't reject.
    if not pub_date_str:
        return True

    pub_dt = parse_any_date(pub_date_str)

    if pub_dt:

        # Broad enough for RSS timezone/date inconsistencies.
        start_window = target_dt - timedelta(days=2)
        end_window = target_dt + timedelta(days=1)

        return start_window <= pub_dt <= end_window

    return True


# =============================================================
# 2. TEXT CLEANING
# =============================================================

def normalize_text(text):

    if not text:
        return ""

    text = str(text)

    # Remove CDATA
    text = re.sub(
        r"<!\[CDATA\[(.*?)\]\]>",
        r"\1",
        text,
        flags=re.DOTALL
    )

    soup = BeautifulSoup(text, "html.parser")

    text = soup.get_text(" ", strip=True)

    text = re.sub(r"\s+", " ", text)

    return text.strip()


def clean_cdata_and_html(text):
    return normalize_text(text)


def is_valid_content(text):

    if not text:
        return False

    text = normalize_text(text)

    if len(text) < MIN_CONTENT_CHARS:
        return False

    bad_patterns = [
        "terms of use",
        "privacy policy",
        "cookie policy",
        "all rights reserved",
        "subscribe to newsletter",
        "sign up for newsletter"
    ]

    lower = text.lower()

    # Don't reject article merely because one bad word exists.
    # Reject only when content is mostly noise.
    bad_count = sum(x in lower for x in bad_patterns)

    if bad_count >= 3 and len(text) < 600:
        return False

    return True


# =============================================================
# 3. URL RESOLVER
# =============================================================

def resolve_url(base_url, link):

    if not link:
        return ""

    link = link.strip()

    # Sometimes RSS gives escaped URLs
    link = link.replace("&amp;", "&")

    return urllib.parse.urljoin(base_url, link)


# =============================================================
# 4. SAFE FETCHER
# =============================================================

def safe_fetch(url, timeout=DIRECT_TIMEOUT):

    if not url:
        return None

    headers = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/150.0.0.0 Safari/537.36",

        "Accept":
            "text/html,application/xhtml+xml,application/xml,"
            "application/pdf,text/plain,*/*;q=0.8",

        "Accept-Language":
            "en-US,en;q=0.9,hi;q=0.8",

        "Cache-Control": "no-cache",

        "Pragma": "no-cache"
    }

    # ---------------------------------------------------------
    # ATTEMPT 1 — Direct curl_cffi
    # ---------------------------------------------------------

    try:

        res = requests.get(
            url,
            impersonate="chrome",
            headers=headers,
            timeout=timeout,
            verify=False,
            allow_redirects=True
        )

        if res.status_code == 200 and res.content:

            print(
                f"    ✓ Direct: "
                f"{res.status_code} | "
                f"{len(res.content)} bytes"
            )

            return res.content

        print(
            f"    ⚠️ Direct HTTP {res.status_code}: "
            f"{url[:80]}"
        )

    except Exception as e:

        print(
            f"    ⚠️ Direct failed: "
            f"{url[:80]} | {e}"
        )

    # ---------------------------------------------------------
    # ATTEMPT 2 — ScrapingAnt
    # ---------------------------------------------------------

    if SCRAPINGANT_KEY:

        try:

            encoded_url = urllib.parse.quote(
                url,
                safe=""
            )

            sa_url = (
                "https://api.scrapingant.com/v2/general"
                f"?url={encoded_url}"
                f"&x-api-key={SCRAPINGANT_KEY}"
                "&browser=true"
            )

            sa_res = requests.get(
                sa_url,
                timeout=SCRAPINGANT_TIMEOUT
            )

            if sa_res.status_code == 200 and sa_res.content:

                print(
                    f"    ✓ ScrapingAnt: "
                    f"{len(sa_res.content)} bytes"
                )

                return sa_res.content

            print(
                f"    ⚠️ ScrapingAnt HTTP "
                f"{sa_res.status_code}"
            )

        except Exception as e:

            print(
                f"    ❌ ScrapingAnt failed: {e}"
            )

    return None


# =============================================================
# 5. PDF EXTRACTION
# =============================================================

def extract_pdf_text(content):

    if not PDF_AVAILABLE:
        return ""

    if not content:
        return ""

    try:

        if not content.startswith(b"%PDF"):
            return ""

        doc = fitz.open(
            stream=content,
            filetype="pdf"
        )

        pages = []

        for page in doc:

            txt = page.get_text("text")

            if txt:
                pages.append(txt)

        doc.close()

        text = normalize_text(
            " ".join(pages)
        )

        return text[:MAX_ARTICLE_CHARS]

    except Exception as e:

        print(
            f"    ⚠️ PDF extraction error: {e}"
        )

        return ""


# =============================================================
# 6. JSON-LD ARTICLE EXTRACTION
# =============================================================

def extract_jsonld_article(soup):

    if not soup:
        return ""

    scripts = soup.find_all(
        "script",
        type="application/ld+json"
    )

    for script in scripts:

        raw = (
            script.string
            or script.get_text()
            or ""
        ).strip()

        if not raw:
            continue

        try:

            data = json.loads(raw)

        except Exception:

            # Some sites contain malformed JSON-LD.
            # Try cleaning common control chars.
            try:

                raw2 = re.sub(
                    r"[\x00-\x08\x0b\x0c\x0e-\x1f]",
                    "",
                    raw
                )

                data = json.loads(raw2)

            except Exception:
                continue

        objects = []

        if isinstance(data, list):

            objects.extend(data)

        elif isinstance(data, dict):

            objects.append(data)

            graph = data.get("@graph")

            if isinstance(graph, list):
                objects.extend(graph)

        for obj in objects:

            if not isinstance(obj, dict):
                continue

            obj_type = obj.get("@type", "")

            if isinstance(obj_type, list):
                obj_type = " ".join(
                    str(x) for x in obj_type
                )

            obj_type = str(
                obj_type
            ).lower()

            body = (
                obj.get("articleBody")
                or obj.get("description")
                or ""
            )

            body = normalize_text(body)

            if (
                "article" in obj_type
                or "newsarticle" in obj_type
            ):

                if len(body) >= MIN_CONTENT_CHARS:
                    return body

    return ""


# =============================================================
# 7. GENERIC ARTICLE EXTRACTOR
# =============================================================

def extract_html_article_content(soup):

    if not soup:
        return ""

    # Make a copy-like cleanup
    for selector in [
        "script",
        "style",
        "noscript",
        "template",
        "svg",
        "iframe",
        "nav",
        "footer",
        "header",
        "form",
        ".advertisement",
        ".ads",
        ".ad",
        ".social-share",
        ".share-box",
        ".newsletter",
        ".comments",
        ".related",
        ".recommended"
    ]:

        try:

            for node in soup.select(selector):
                node.decompose()

        except Exception:
            pass

    # ---------------------------------------------------------
    # Strong content containers
    # ---------------------------------------------------------

    container_selectors = [

        # Generic
        "article",
        "main",

        # The Hindu
        ".article-body",
        ".articlebody",
        ".story-content",
        ".article-container",

        # Indian Express
        ".full-details",
        ".story-details",
        ".story-content",

        # Generic CMS
        "#content-body",
        "#article-body",
        "#story-body",
        "#articleBody",
        "#content",
        ".content-body",
        ".article-content",
        ".article-content-area",
        ".story-element",
        ".story__content",
        ".entry-content",
        ".post-content",

        # Bihar / government style
        ".innercontent",
        ".inner-content",
        ".release_text",
        ".release-text",
        ".pressrelease",
        ".press-release",
        ".content",
        ".main-content",
        ".page-content"
    ]

    candidates = []

    for selector in container_selectors:

        try:

            found = soup.select(selector)

            for node in found:

                text = normalize_text(
                    node.get_text(
                        " ",
                        strip=True
                    )
                )

                if len(text) >= MIN_CONTENT_CHARS:
                    candidates.append(
                        (len(text), node)
                    )

        except Exception:
            continue

    # Largest relevant container first
    candidates.sort(
        key=lambda x: x[0],
        reverse=True
    )

    # ---------------------------------------------------------
    # Extract paragraphs from best candidates
    # ---------------------------------------------------------

    for _, container in candidates[:8]:

        blocks = []

        for el in container.find_all(
            ["p", "div", "li", "td"]
        ):

            txt = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                len(txt) >= MIN_PARAGRAPH_CHARS
                and txt not in blocks
            ):

                # Ignore navigation-like garbage
                low = txt.lower()

                if low in [
                    "home",
                    "contact us",
                    "read more",
                    "share",
                    "subscribe"
                ]:
                    continue

                blocks.append(txt)

        if blocks:

            text = normalize_text(
                " ".join(blocks)
            )

            if len(text) >= MIN_CONTENT_CHARS:

                return text[:MAX_ARTICLE_CHARS]

    # ---------------------------------------------------------
    # Last fallback — all paragraphs
    # ---------------------------------------------------------

    paragraphs = []

    for p in soup.find_all("p"):

        txt = normalize_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(txt) >= MIN_PARAGRAPH_CHARS:

            if txt not in paragraphs:
                paragraphs.append(txt)

    text = normalize_text(
        " ".join(paragraphs)
    )

    return text[:MAX_ARTICLE_CHARS]


# =============================================================
# 8. DEEP GENERIC ARTICLE FETCH
# =============================================================

def fetch_generic_article_content(article_url):

    if not article_url:
        return ""

    if not article_url.startswith("http"):
        return ""

    print(
        f"    🔎 Deep crawl: "
        f"{article_url[:100]}"
    )

    content = safe_fetch(
        article_url,
        timeout=DIRECT_TIMEOUT
    )

    if not content:
        return ""

    # PDF
    if (
        content.startswith(b"%PDF")
        or ".pdf" in article_url.lower()
    ):

        pdf_text = extract_pdf_text(content)

        if len(pdf_text) >= MIN_CONTENT_CHARS:
            return pdf_text

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # -----------------------------------------------------
        # Strategy 1 — JSON-LD
        # -----------------------------------------------------

        jsonld_text = extract_jsonld_article(
            soup
        )

        if len(jsonld_text) >= MIN_CONTENT_CHARS:

            print(
                f"    ✓ JSON-LD content: "
                f"{len(jsonld_text)} chars"
            )

            return jsonld_text[
                :MAX_ARTICLE_CHARS
            ]

        # -----------------------------------------------------
        # Strategy 2 — HTML deep extraction
        # -----------------------------------------------------

        html_text = extract_html_article_content(
            soup
        )

        if len(html_text) >= MIN_CONTENT_CHARS:

            print(
                f"    ✓ HTML content: "
                f"{len(html_text)} chars"
            )

            return html_text[
                :MAX_ARTICLE_CHARS
            ]

    except Exception as e:

        print(
            f"    ⚠️ Generic parser error: {e}"
        )

    return ""


# =============================================================
# 9. PIB DEEP EXTRACTION
# =============================================================

def fetch_deep_pib_content(article_url):

    if not article_url:
        return ""

    target_url = article_url

    # Extract PRID
    prid_match = re.search(
        r"PRID[=/](\d+)",
        article_url,
        re.IGNORECASE
    )

    if (
        "pib.gov.in" in article_url.lower()
        and prid_match
    ):

        prid = prid_match.group(1)

        target_url = (
            "https://pib.gov.in/"
            f"PressReleasePage.aspx?PRID={prid}"
        )

    print(
        f"    🇮🇳 PIB deep: "
        f"{target_url}"
    )

    return fetch_generic_article_content(
        target_url
    )


# =============================================================
# 10. RSS PARSER
# =============================================================

def parse_rss_items(content):

    if not content:
        return []

    try:

        root = ET.fromstring(
            content
        )

        return root.findall(
            ".//item"
        )

    except Exception:

        try:

            soup = BeautifulSoup(
                content,
                "xml"
            )

            return soup.find_all(
                "item"
            )

        except Exception:
            return []


def rss_value(item, tag):

    # XML ElementTree
    try:

        node = item.find(tag)

        if node is not None:
            return normalize_text(
                node.text
            )

    except Exception:
        pass

    # BeautifulSoup
    try:

        node = item.find(tag)

        if node:
            return normalize_text(
                node.get_text()
            )

    except Exception:
        pass

    return ""


# =============================================================
# 11. GENERIC NEWS RSS SOURCE
# =============================================================

def scrape_rss_source(
    rss_url,
    source_name,
    target_dt,
    max_items=10
):

    results = []

    print(
        f"\n📰 {source_name}"
    )

    content = safe_fetch(
        rss_url
    )

    if not content:
        return results

    items = parse_rss_items(
        content
    )

    count = 0

    for item in items[:30]:

        title = rss_value(
            item,
            "title"
        )

        link = rss_value(
            item,
            "link"
        )

        pub_date = (
            rss_value(
                item,
                "pubDate"
            )
            or
            rss_value(
                item,
                "pubdate"
            )
        )

        description = rss_value(
            item,
            "description"
        )

        if not title:
            continue

        if not is_target_news(
            pub_date,
            target_dt
        ):
            continue

        print(
            f"  → {title[:80]}"
        )

        article_text = ""

        if link:

            article_text = (
                fetch_generic_article_content(
                    link
                )
            )

        if not is_valid_content(
            article_text
        ):

            article_text = (
                description
                if is_valid_content(
                    description
                )
                else ""
            )

        results.append({

            "source": source_name,

            "title": title,

            "url": link,

            "date": pub_date,

            "content": article_text,

            "content_chars": len(
                article_text
            )

        })

        count += 1

        if count >= max_items:
            break

    return results


# =============================================================
# 12. IPRD BIHAR — LINK DISCOVERY
# =============================================================

def extract_links_from_page(
    page_url,
    html
):

    results = []

    if not html:
        return results

    try:

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        for a in soup.find_all(
            "a",
            href=True
        ):

            href = a.get(
                "href",
                ""
            ).strip()

            if not href:
                continue

            text = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            absolute = resolve_url(
                page_url,
                href
            )

            if not absolute:
                continue

            results.append({
                "title": text,
                "url": absolute
            })

    except Exception:
        pass

    return results


def is_bihar_release_link(
    title,
    url
):

    combined = (
        f"{title} {url}"
    ).lower()

    keywords = [

        "press",
        "release",
        "pressrelease",
        "press-release",
        "pr no",
        "prid",
        "cabinet",
        "decision",
        "nirnay",
        "मंत्रिमंडल",
        "कैबिनेट",
        "प्रेस",
        "प्रेस विज्ञप्ति",
        "निर्णय"
    ]

    return any(
        k in combined
        for k in keywords
    )


# =============================================================
# 13. IPRD BIHAR DETAIL CONTENT EXTRACTION
# =============================================================

def fetch_bihar_detail(
    title,
    url,
    pub_date="",
    source_type="IPRD Bihar"
):

    print(
        f"\n  🏛️ Bihar deep:"
        f" {title[:90]}"
    )

    content = safe_fetch(
        url,
        timeout=DIRECT_TIMEOUT
    )

    if not content:
        return {
            "source": source_type,
            "title": title,
            "url": url,
            "date": pub_date,
            "content": "",
            "content_chars": 0,
            "type": source_type
        }

    # PDF
    pdf_text = extract_pdf_text(
        content
    )

    if len(pdf_text) >= MIN_CONTENT_CHARS:

        return {
            "source": source_type,
            "title": title,
            "url": url,
            "date": pub_date,
            "content": pdf_text,
            "content_chars": len(pdf_text),
            "type": "PDF"
        }

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # -----------------------------------------------------
        # JSON-LD
        # -----------------------------------------------------

        jsonld_text = (
            extract_jsonld_article(
                soup
            )
        )

        if len(jsonld_text) >= MIN_CONTENT_CHARS:

            return {
                "source": source_type,
                "title": title,
                "url": url,
                "date": pub_date,
                "content": jsonld_text[
                    :MAX_ARTICLE_CHARS
                ],
                "content_chars": len(
                    jsonld_text
                ),
                "type": "JSON-LD"
            }

        # -----------------------------------------------------
        # Government page specific extraction
        # -----------------------------------------------------

        # Remove obvious site chrome
        for selector in [
            "script",
            "style",
            "noscript",
            "nav",
            "footer",
            "header",
            "form",
            "iframe",
            ".menu",
            ".navbar",
            ".sidebar",
            ".footer"
        ]:

            try:

                for node in soup.select(
                    selector
                ):
                    node.decompose()

            except Exception:
                pass

        # Find strongest possible content
        candidates = []

        selectors = [

            "#ContentPlaceHolder1_divpri",
            "#ContentPlaceHolder1_ContentPlaceHolder1_divpri",
            "#divpri",

            ".innercontent",
            ".inner-content",

            ".release_text",
            ".release-text",

            ".pressrelease",
            ".press-release",

            ".content",
            ".main-content",
            ".page-content",

            "article",
            "main",

            "#content",
            "#content-body",
            ".content-body"
        ]

        for selector in selectors:

            try:

                nodes = soup.select(
                    selector
                )

                for node in nodes:

                    txt = normalize_text(
                        node.get_text(
                            " ",
                            strip=True
                        )
                    )

                    if len(txt) >= MIN_CONTENT_CHARS:

                        candidates.append(
                            (len(txt), node)
                        )

            except Exception:
                continue

        candidates.sort(
            key=lambda x: x[0],
            reverse=True
        )

        for _, node in candidates[:10]:

            blocks = []

            # Important:
            # Don't use only <p>.
            # Government portals often use
            # div/table/td/li.
            elements = node.find_all(
                [
                    "p",
                    "div",
                    "li",
                    "td",
                    "span"
                ]
            )

            for el in elements:

                txt = normalize_text(
                    el.get_text(
                        " ",
                        strip=True
                    )
                )

                if (
                    len(txt)
                    >= MIN_PARAGRAPH_CHARS
                ):

                    if txt not in blocks:
                        blocks.append(txt)

            result = normalize_text(
                " ".join(blocks)
            )

            if len(result) >= MIN_CONTENT_CHARS:

                return {
                    "source": source_type,
                    "title": title,
                    "url": url,
                    "date": pub_date,
                    "content": result[
                        :MAX_ARTICLE_CHARS
                    ],
                    "content_chars": len(
                        result
                    ),
                    "type": "HTML"
                }

        # -----------------------------------------------------
        # Last fallback: all meaningful text
        # -----------------------------------------------------

        paragraphs = []

        for el in soup.find_all(
            ["p", "td", "li"]
        ):

            txt = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                len(txt)
                >= MIN_PARAGRAPH_CHARS
            ):

                if txt not in paragraphs:
                    paragraphs.append(txt)

        result = normalize_text(
            " ".join(paragraphs)
        )

        return {
            "source": source_type,
            "title": title,
            "url": url,
            "date": pub_date,
            "content": result[
                :MAX_ARTICLE_CHARS
            ],
            "content_chars": len(
                result
            ),
            "type": "Fallback"
        }

    except Exception as e:

        print(
            f"    ⚠️ Bihar parse error: {e}"
        )

    return {
        "source": source_type,
        "title": title,
        "url": url,
        "date": pub_date,
        "content": "",
        "content_chars": 0,
        "type": "Failed"
    }


# =============================================================
# 14. IPRD BIHAR LISTING SCRAPER
# =============================================================

def scrape_iprd_bihar(
    target_dt,
    max_items=15
):

    print(
        "\n🏛️ ================================="
    )
    print(
        "🏛️ IPRD BIHAR DEEP SCRAPER"
    )
    print(
        "🏛️ ================================="
    )

    results = []

    # ---------------------------------------------------------
    # Start with official IPRD portal
    # ---------------------------------------------------------

    pages_to_try = [

        IPRD_HOME,

        # Search page
        IPRD_SEARCH,

        # Official Bihar cabinet department
        CABINET_DEPT
    ]

    discovered = []

    seen_urls = set()

    for page_url in pages_to_try:

        print(
            f"\n  🔎 Discovering:"
            f" {page_url}"
        )

        html = safe_fetch(
            page_url,
            timeout=DIRECT_TIMEOUT
        )

        if not html:
            continue

        links = extract_links_from_page(
            page_url,
            html
        )

        for item in links:

            url = item["url"]
            title = item["title"]

            if not url:
                continue

            if url in seen_urls:
                continue

            if is_bihar_release_link(
                title,
                url
            ):

                seen_urls.add(url)

                discovered.append(
                    item
                )

    print(
        f"\n  🔗 Potential Bihar "
        f"release links: {len(discovered)}"
    )

    # ---------------------------------------------------------
    # Crawl discovered links
    # ---------------------------------------------------------

    count = 0

    for item in discovered:

        if count >= max_items:
            break

        title = item["title"]
        url = item["url"]

        # Skip meaningless anchors
        if len(title) < 8:
            continue

        # Detect type
        combined = (
            f"{title} {url}"
        ).lower()

        if (
            "cabinet" in combined
            or "decision" in combined
            or "मंत्रिमंडल" in combined
            or "कैबिनेट" in combined
            or "निर्णय" in combined
        ):

            source_type = (
                "Bihar Cabinet Decision"
            )

        else:

            source_type = (
                "IPRD Bihar"
            )

        result = fetch_bihar_detail(
            title=title,
            url=url,
            pub_date="",
            source_type=source_type
        )

        # Don't keep completely empty pages
        if (
            result["content_chars"]
            >= MIN_CONTENT_CHARS
        ):

            results.append(
                result
            )

            count += 1

            print(
                f"    ✅ {source_type}: "
                f"{result['content_chars']} chars"
            )

        else:

            print(
                f"    ⚠️ No useful content:"
                f" {title[:70]}"
            )

    return results


# =============================================================
# 15. BIHAR CM PRESS RELEASE LISTING
# =============================================================

def scrape_bihar_cm_press_releases(
    target_dt,
    max_items=10
):

    print(
        "\n🏛️ Bihar CM Press Releases"
    )

    results = []

    # Try official Bihar departments because
    # the same SectionInformation page can be
    # exposed through different department portals.

    candidate_urls = [

        "https://state.bihar.gov.in/prdbihar/"
        + CM_PRESS_RELEASE_PATTERN,

        "https://state.bihar.gov.in/gad/"
        + CM_PRESS_RELEASE_PATTERN,

        "https://state.bihar.gov.in/fcp/"
        + CM_PRESS_RELEASE_PATTERN,

        "https://state.bihar.gov.in/mines/"
        + CM_PRESS_RELEASE_PATTERN
    ]

    seen = set()

    for listing_url in candidate_urls:

        html = safe_fetch(
            listing_url,
            timeout=DIRECT_TIMEOUT
        )

        if not html:
            continue

        try:

            soup = BeautifulSoup(
                html,
                "html.parser"
            )

            # Find tables
            for row in soup.find_all("tr"):

                cols = row.find_all(
                    ["td", "th"]
                )

                if len(cols) < 3:
                    continue

                row_text = [
                    normalize_text(
                        c.get_text(
                            " ",
                            strip=True
                        )
                    )
                    for c in cols
                ]

                # Date detection
                date_found = ""

                for txt in row_text:

                    if re.search(
                        r"\d{1,2}/\d{1,2}/\d{4}",
                        txt
                    ):

                        date_found = txt
                        break

                if date_found:

                    parsed = parse_any_date(
                        date_found
                    )

                    if parsed:

                        if not is_target_news(
                            date_found,
                            target_dt
                        ):
                            continue

                # Find title/link
                link_node = row.find(
                    "a",
                    href=True
                )

                if not link_node:
                    continue

                href = link_node.get(
                    "href"
                )

                url = resolve_url(
                    listing_url,
                    href
                )

                title = normalize_text(
                    row.get_text(
                        " ",
                        strip=True
                    )
                )

                if not title:
                    continue

                if url in seen:
                    continue

                seen.add(url)

                result = fetch_bihar_detail(
                    title=title,
                    url=url,
                    pub_date=date_found,
                    source_type=(
                        "Bihar CM Press Release"
                    )
                )

                if (
                    result["content_chars"]
                    >= MIN_CONTENT_CHARS
                ):

                    results.append(
                        result
                    )

                    if len(results) >= max_items:
                        return results

        except Exception as e:

            print(
                f"⚠️ CM listing error: {e}"
            )

    return results


# =============================================================
# 16. GOOGLE NEWS BIHAR BACKUP
# =============================================================

def scrape_google_bihar(
    target_dt,
    max_items=8
):

    google_url = (
        "https://news.google.com/rss/search?"
        "q=Bihar+Government+Schemes+OR+"
        "Infrastructure+OR+Economy+OR+Cabinet"
        "+when:2d"
        "&hl=hi&gl=IN&ceid=IN:hi"
    )

    results = []

    print(
        "\n📰 Google News Bihar backup"
    )

    content = safe_fetch(
        google_url
    )

    if not content:
        return results

    items = parse_rss_items(
        content
    )

    count = 0

    for item in items[:30]:

        title = rss_value(
            item,
            "title"
        )

        link = rss_value(
            item,
            "link"
        )

        pub_date = rss_value(
            item,
            "pubDate"
        )

        desc = rss_value(
            item,
            "description"
        )

        if not title:
            continue

        if not is_target_news(
            pub_date,
            target_dt
        ):
            continue

        # Google News links may redirect.
        # Try direct deep crawl.
        article_text = ""

        if link:
            article_text = (
                fetch_generic_article_content(
                    link
                )
            )

        if not article_text:
            article_text = desc

        results.append({

            "source":
                "Google News Bihar",

            "title":
                title,

            "url":
                link,

            "date":
                pub_date,

            "content":
                article_text,

            "content_chars":
                len(article_text),

            "type":
                "RSS Backup"

        })

        count += 1

        if count >= max_items:
            break

    return results


# =============================================================
# 17. DEDUPLICATION
# =============================================================

def title_key(title):

    title = normalize_text(
        title
    ).lower()

    # Hindi + English compatible
    title = re.sub(
        r"[^\w\u0900-\u097F]+",
        "",
        title
    )

    return title[:120]


def remove_duplicate_objects(
    news_list
):

    seen = set()

    unique = []

    for item in news_list:

        key = title_key(
            item.get(
                "title",
                ""
            )
        )

        if not key:
            continue

        if key in seen:
            continue

        seen.add(key)

        unique.append(
            item
        )

    print(
        f"🧹 Dedup: "
        f"{len(news_list)} → "
        f"{len(unique)}"
    )

    return unique


# =============================================================
# 18. MAIN PIPELINE
# =============================================================

def run_scraper():

    target_dt, date_str, key_str = (
        get_yesterday_info()
    )

    print(
        "\n=========================================="
    )

    print(
        "🚀 DEEP NEWS SCRAPER"
    )

    print(
        f"📅 Target: {date_str}"
    )

    print(
        "==========================================\n"
    )

    national_items = []
    bihar_items = []

    source_stats = {}

    # =========================================================
    # NATIONAL
    # =========================================================

    # ---------------------------------------------------------
    # PIB
    # ---------------------------------------------------------

    pib_url = (
        "https://www.pib.gov.in/"
        "RssMain.aspx?Mod=1&Lang=1"
    )

    pib_results = scrape_rss_source(
        pib_url,
        "PIB Central",
        target_dt,
        max_items=10
    )

    # Replace generic fetch with PIB-specific deep
    # extraction for PIB URLs.
    for item in pib_results:

        if item.get("url"):

            pib_text = (
                fetch_deep_pib_content(
                    item["url"]
                )
            )

            if len(pib_text) >= MIN_CONTENT_CHARS:

                item["content"] = pib_text

                item["content_chars"] = (
                    len(pib_text)
                )

    national_items.extend(
        pib_results
    )

    source_stats[
        "PIB Central"
    ] = len(pib_results)

    # ---------------------------------------------------------
    # THE HINDU
    # ---------------------------------------------------------

    hindu_results = scrape_rss_source(
        "https://www.thehindu.com/"
        "news/national/feeder/default.rss",
        "The Hindu",
        target_dt,
        max_items=8
    )

    national_items.extend(
        hindu_results
    )

    source_stats[
        "The Hindu"
    ] = len(hindu_results)

    # ---------------------------------------------------------
    # INDIAN EXPRESS
    # ---------------------------------------------------------

    ie_results = scrape_rss_source(
        "https://indianexpress.com/"
        "section/india/feed/",
        "Indian Express",
        target_dt,
        max_items=8
    )

    national_items.extend(
        ie_results
    )

    source_stats[
        "Indian Express"
    ] = len(ie_results)

    # =========================================================
    # BIHAR
    # =========================================================

    # ---------------------------------------------------------
    # 1. IPRD BIHAR PRIMARY
    # ---------------------------------------------------------

    iprd_results = scrape_iprd_bihar(
        target_dt,
        max_items=15
    )

    bihar_items.extend(
        iprd_results
    )

    source_stats[
        "IPRD Bihar"
    ] = len(iprd_results)

    # ---------------------------------------------------------
    # 2. Bihar CM Press Releases
    # ---------------------------------------------------------

    cm_results = (
        scrape_bihar_cm_press_releases(
            target_dt,
            max_items=10
        )
    )

    bihar_items.extend(
        cm_results
    )

    source_stats[
        "Bihar CM Press Release"
    ] = len(cm_results)

    # ---------------------------------------------------------
    # 3. Google News Bihar BACKUP
    # ---------------------------------------------------------

    google_results = scrape_google_bihar(
        target_dt,
        max_items=8
    )

    bihar_items.extend(
        google_results
    )

    source_stats[
        "Google News Bihar Backup"
    ] = len(google_results)

    # =========================================================
    # DEDUP
    # =========================================================

    national_clean = (
        remove_duplicate_objects(
            national_items
        )
    )

    bihar_clean = (
        remove_duplicate_objects(
            bihar_items
        )
    )

    # =========================================================
    # CONTENT QUALITY STATS
    # =========================================================

    def content_stats(items):

        good = 0
        weak = 0

        for item in items:

            if (
                item.get(
                    "content_chars",
                    0
                )
                >= MIN_CONTENT_CHARS
            ):
                good += 1
            else:
                weak += 1

        return {
            "with_deep_content": good,
            "weak_or_empty": weak
        }

    quality_stats = {

        "national":
            content_stats(
                national_clean
            ),

        "bihar":
            content_stats(
                bihar_clean
            )
    }

    # =========================================================
    # SAVE JSON
    # =========================================================

    raw_payload = {

        "timestamp":
            datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "target_date_str":
            date_str,

        "target_key_str":
            key_str,

        "source_stats":
            source_stats,

        "quality_stats":
            quality_stats,

        "bihar_raw_count":
            len(bihar_clean),

        "national_raw_count":
            len(national_clean),

        "bihar_raw_news":
            bihar_clean,

        "national_raw_news":
            national_clean
    }

    with open(
        "rawnews.json",
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            raw_payload,
            f,
            ensure_ascii=False,
            indent=2
        )

    # =========================================================
    # DEBUG SUMMARY
    # =========================================================

    print(
        "\n=========================================="
    )

    print(
        "📊 SCRAPING SUMMARY"
    )

    print(
        "=========================================="
    )

    print(
        json.dumps(
            source_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print(
        "\n📈 CONTENT QUALITY"
    )

    print(
        json.dumps(
            quality_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print(
        f"\n🇮🇳 National: "
        f"{len(national_clean)}"
    )

    print(
        f"🏛️ Bihar: "
        f"{len(bihar_clean)}"
    )

    print(
        "\n💾 rawnews.json updated."
    )


# =============================================================
# RUN
# =============================================================

if __name__ == "__main__":
    run_scraper()
```
