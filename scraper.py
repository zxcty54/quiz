import os
import json
import time
import urllib.parse
import re
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET

import urllib3
from curl_cffi import requests
from bs4 import BeautifulSoup
from dateutil import parser as date_parser

# =============================================================
# CONFIG
# =============================================================

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_PARAGRAPH_CHARS = 35

# Desired minimum numbers
TARGET_NATIONAL = 12
TARGET_BIHAR = 15

# =============================================================
# 1. DATE ENGINE
# =============================================================

def get_date_info():
    now = datetime.now()
    yesterday_dt = now - timedelta(days=1)

    return {
        "now": now,
        "yesterday": yesterday_dt,
        "today_str": now.strftime("%d %b %Y"),
        "yesterday_str": yesterday_dt.strftime("%d %b %Y"),
        "today_key": now.strftime("%Y-%m-%d"),
        "yesterday_key": yesterday_dt.strftime("%Y-%m-%d")
    }


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

    # Timestamp
    if date_str.isdigit():
        try:
            ts = int(date_str)

            if ts > 1e11:
                ts /= 1000

            return datetime.fromtimestamp(ts)

        except Exception:
            pass

    # RFC / RSS date
    try:
        pub_tuple = email.utils.parsedate_tz(date_str)

        if pub_tuple:
            return datetime.fromtimestamp(
                email.utils.mktime_tz(pub_tuple)
            )

    except Exception:
        pass

    # Generic parser
    try:
        parsed_dt = date_parser.parse(
            date_str,
            fuzzy=True,
            dayfirst=True
        )

        if parsed_dt.tzinfo is not None:
            parsed_dt = parsed_dt.astimezone().replace(
                tzinfo=None
            )

        return parsed_dt

    except Exception:
        pass

    return None


def is_recent_news(pub_date_str, allow_days=2):
    """
    Used for normal RSS sources.
    Allows yesterday + today.
    """

    if not pub_date_str:
        return True

    pub_dt = parse_any_date(pub_date_str)

    if not pub_dt:
        return True

    now = datetime.now()

    start = now - timedelta(days=allow_days)
    end = now + timedelta(hours=6)

    return start <= pub_dt <= end


def is_yesterday_news(pub_date_str, target_dt):
    """
    Yesterday-first filter.

    A slightly broad window is intentional because
    government RSS feeds sometimes expose timezone/date
    inconsistencies.
    """

    if not pub_date_str:
        return False

    pub_dt = parse_any_date(pub_date_str)

    if not pub_dt:
        return False

    start = target_dt.replace(
        hour=0,
        minute=0,
        second=0,
        microsecond=0
    )

    end = start + timedelta(days=1)

    return start <= pub_dt < end


def is_today_news(pub_date_str):
    if not pub_date_str:
        return False

    pub_dt = parse_any_date(pub_date_str)

    if not pub_dt:
        return False

    today = datetime.now().date()

    return pub_dt.date() == today


# =============================================================
# 2. TEXT CLEANING
# =============================================================

def clean_cdata_and_html(text):
    if not text:
        return ""

    text = str(text)

    text = re.sub(
        r"\<\!\[CDATA\[(.*?)\]\]>",
        r"\1",
        text,
        flags=re.DOTALL
    )

    soup = BeautifulSoup(text, "html.parser")

    return " ".join(
        soup.get_text(" ", strip=True).split()
    ).strip()


def normalize_text(text):
    if not text:
        return ""

    text = BeautifulSoup(
        str(text),
        "html.parser"
    ).get_text(" ", strip=True)

    text = re.sub(r"\s+", " ", text)

    return text.strip()


def clean_url(url):
    if not url:
        return ""

    url = str(url).strip()

    # Remove markdown link wrapper accidentally present
    markdown_match = re.match(
        r"\[.*?\]\((https?://.*?)\)",
        url
    )

    if markdown_match:
        return markdown_match.group(1)

    return url


# =============================================================
# 3. SAFE FETCHER
# =============================================================

def safe_fetch(url, timeout=15):
    if not url:
        return None

    url = clean_url(url)

    headers = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/150.0.0.0 Safari/537.36",

        "Accept":
            "text/html,application/xhtml+xml,application/xml;"
            "q=0.9,*/*;q=0.8",

        "Accept-Language":
            "en-US,en;q=0.9,hi;q=0.8",

        "Cache-Control": "no-cache",

        "Referer":
            "https://www.google.com/"
    }

    # -----------------------------
    # Direct fetch
    # -----------------------------

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

            return res.content

        print(
            f"⚠️ HTTP {res.status_code}: "
            f"{url[:100]}"
        )

    except Exception as e:

        print(
            f"⚠️ Direct fetch failed: "
            f"{url[:80]} | {e}"
        )

    # -----------------------------
    # ScrapingAnt fallback
    # -----------------------------

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
                "&browser=false"
            )

            sa_res = requests.get(
                sa_url,
                timeout=25
            )

            if (
                sa_res.status_code == 200
                and sa_res.content
            ):
                return sa_res.content

        except Exception as e:

            print(
                f"❌ ScrapingAnt failed: {e}"
            )

    return None


# =============================================================
# 4. JSON-LD ARTICLE EXTRACTION
# =============================================================

def extract_jsonld_article(soup):

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        raw = script.string or script.get_text()

        if not raw:
            continue

        try:

            data = json.loads(raw.strip())

            objects = []

            if isinstance(data, list):
                objects.extend(data)

            elif isinstance(data, dict):

                objects.append(data)

                if isinstance(
                    data.get("@graph"),
                    list
                ):
                    objects.extend(
                        data["@graph"]
                    )

            for obj in objects:

                if not isinstance(obj, dict):
                    continue

                obj_type = str(
                    obj.get("@type", "")
                ).lower()

                if (
                    "article" in obj_type
                    or "newsarticle" in obj_type
                ):

                    body = obj.get(
                        "articleBody"
                    )

                    if body:

                        body = normalize_text(
                            body
                        )

                        if len(body) >= MIN_CONTENT_CHARS:
                            return body

        except Exception:
            continue

    return ""


# =============================================================
# 5. GENERIC ARTICLE EXTRACTION
# =============================================================

def extract_article_text(
    content,
    source_url=""
):

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # JSON-LD first
        jsonld_text = extract_jsonld_article(
            soup
        )

        if len(jsonld_text) >= 250:
            return jsonld_text[:MAX_ARTICLE_CHARS]

        # Remove obvious noise
        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form, iframe, "
            ".advertisement, .ads, "
            ".social-share, .share"
        ):
            noise.decompose()

        candidate_containers = [

            # Common article containers
            soup.find(
                class_=re.compile(
                    r"article-body|articleBody|"
                    r"story-body|story-content|"
                    r"article-content",
                    re.I
                )
            ),

            soup.find(
                id=re.compile(
                    r"content-body|article-body|"
                    r"story-body",
                    re.I
                )
            ),

            soup.find(
                class_=re.compile(
                    r"full-details|"
                    r"story-element|"
                    r"article-detail",
                    re.I
                )
            )
        ]

        content_div = next(
            (
                x for x in candidate_containers
                if x is not None
            ),
            None
        )

        if content_div:

            elements = content_div.find_all(
                ["p", "div", "li"]
            )

        else:

            elements = soup.find_all("p")

        text_blocks = []

        for el in elements:

            txt = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= MIN_PARAGRAPH_CHARS:

                # Avoid generic site garbage
                if is_bad_generic_text(txt):
                    continue

                text_blocks.append(txt)

        # Deduplicate repeated paragraphs
        unique_blocks = []

        seen = set()

        for block in text_blocks:

            key = re.sub(
                r"[^a-z0-9\u0900-\u097F]+",
                "",
                block.lower()
            )[:300]

            if key and key not in seen:

                seen.add(key)

                unique_blocks.append(
                    block
                )

        result = normalize_text(
            " ".join(unique_blocks)
        )

        return result[:MAX_ARTICLE_CHARS]

    except Exception as e:

        print(
            f"⚠️ Article parsing error: {e}"
        )

        return ""


# =============================================================
# 6. GENERIC PORTAL GARBAGE FILTER
# =============================================================

BAD_GENERIC_PHRASES = [

    "we have tried to put most accurate",
    "website maintained by",
    "web information manager",
    "copyright iprd",
    "suggestions,if any",
    "feedback.commonportal",
    "screen-reader",
    "last updated on",
    "department information",
    "important links",
    "citizen home",
    "bihar is located in the eastern part",
    "distribution of population decadal",
    "50% reservation for women",
    "35% reservation for women",
    "physical and financial progress",
    "we are contemplating as how to ensure",
    "with the remain villages now getting power",
    "bihar was 98.8 per cent electrified"
]


def is_bad_generic_text(text):

    if not text:
        return True

    low = text.lower()

    matches = 0

    for phrase in BAD_GENERIC_PHRASES:

        if phrase in low:
            matches += 1

    # If several generic portal phrases occur,
    # this is almost certainly a CitizenHome page.
    if matches >= 2:
        return True

    # Strong single indicators
    if (
        "web information manager" in low
        or "feedback.commonportal" in low
    ):
        return True

    return False


# =============================================================
# 7. PIB DEEP CONTENT
# =============================================================

def fetch_deep_pib_content(article_url):

    if not article_url:
        return ""

    article_url = clean_url(
        article_url
    )

    prid_match = re.search(
        r"PRID=(\d+)",
        article_url,
        re.I
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

    else:

        target_url = article_url

    content = safe_fetch(
        target_url,
        timeout=15
    )

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # Remove noise
        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form, .release_back, "
            ".share-box, .social"
        ):
            noise.decompose()

        # PIB known containers
        content_div = (

            soup.find(
                id="ContentPlaceHolder1_divpri"
            )

            or soup.find(
                id="divpri"
            )

            or soup.find(
                class_="ReleaseIdText"
            )

            or soup.find(
                class_="innercontent"
            )

            or soup.find(
                class_="release_text"
            )
        )

        if content_div:

            elements = content_div.find_all(
                ["p", "tr", "li", "div"]
            )

        else:

            elements = soup.find_all(
                "p"
            )

        blocks = []

        for el in elements:

            txt = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= MIN_PARAGRAPH_CHARS:

                if is_bad_generic_text(txt):
                    continue

                blocks.append(txt)

        # Remove duplicate blocks
        unique = []

        seen = set()

        for block in blocks:

            key = re.sub(
                r"[^a-z0-9\u0900-\u097F]+",
                "",
                block.lower()
            )[:400]

            if key not in seen:

                seen.add(key)
                unique.append(block)

        result = normalize_text(
            " ".join(unique)
        )

        return result[:MAX_ARTICLE_CHARS]

    except Exception as e:

        print(
            f"⚠️ PIB parsing error: {e}"
        )

        return ""


# =============================================================
# 8. RSS HELPERS
# =============================================================

def get_xml_items(content):

    if not content:
        return []

    try:

        root = ET.fromstring(
            content
        )

        return root.findall(
            ".//item"
        )

    except Exception as e:

        print(
            f"⚠️ XML parsing error: {e}"
        )

        return []


def rss_value(item, tag):

    el = item.find(tag)

    if el is None:
        return ""

    return clean_cdata_and_html(
        el.text or ""
    )


def make_news_object(
    source,
    title,
    url,
    date,
    content,
    news_type="Scraped"
):

    title = normalize_text(title)
    url = clean_url(url)
    date = normalize_text(date)
    content = normalize_text(content)

    return {
        "source": source,
        "title": title,
        "url": url,
        "date": date,
        "content": content[:MAX_ARTICLE_CHARS],
        "content_chars": len(content),
        "type": news_type
    }


# =============================================================
# 9. PIB RSS FETCHER
# =============================================================

PIB_FEEDS = [

    # Main English
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",

    # Other PIB feeds / regions
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",

    # Hindi
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=9&Regid=1"
]


def scrape_pib():

    print("\n🇮🇳 PIB NATIONAL SCRAPER")

    all_items = []

    seen_urls = set()

    for feed_url in PIB_FEEDS:

        print(
            f"  🔎 PIB feed: {feed_url}"
        )

        content = safe_fetch(
            feed_url,
            timeout=15
        )

        if not content:
            continue

        items = get_xml_items(
            content
        )

        print(
            f"     Found RSS items: {len(items)}"
        )

        for item in items[:50]:

            title = rss_value(
                item,
                "title"
            )

            link = rss_value(
                item,
                "link"
            )

            pub_date = (
                rss_value(item, "pubDate")
                or rss_value(item, "pubdate")
            )

            description = rss_value(
                item,
                "description"
            )

            if not title or not link:
                continue

            link = clean_url(link)

            if link in seen_urls:
                continue

            seen_urls.add(link)

            all_items.append({
                "title": title,
                "url": link,
                "date": pub_date,
                "description": description
            })

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(all_items)}"
    )

    # ---------------------------------------------------------
    # PASS 1: YESTERDAY
    # ---------------------------------------------------------

    yesterday_items = []

    date_info = get_date_info()

    for item in all_items:

        if is_yesterday_news(
            item["date"],
            date_info["yesterday"]
        ):

            yesterday_items.append(
                item
            )

    print(
        f"📅 PIB yesterday items: "
        f"{len(yesterday_items)}"
    )

    # ---------------------------------------------------------
    # PASS 2: TODAY IF NEEDED
    # ---------------------------------------------------------

    today_items = []

    if len(yesterday_items) < TARGET_NATIONAL:

        for item in all_items:

            if is_today_news(
                item["date"]
            ):

                today_items.append(
                    item
                )

        print(
            f"📅 PIB today fallback items: "
            f"{len(today_items)}"
        )

    # ---------------------------------------------------------
    # Merge yesterday first
    # ---------------------------------------------------------

    selected = []

    selected_urls = set()

    for item in (
        yesterday_items + today_items
    ):

        if item["url"] in selected_urls:
            continue

        selected_urls.add(
            item["url"]
        )

        selected.append(
            item
        )

    # ---------------------------------------------------------
    # Deep scrape
    # ---------------------------------------------------------

    results = []

    for item in selected:

        if len(results) >= TARGET_NATIONAL:
            break

        print(
            f"  📰 PIB: "
            f"{item['title'][:90]}"
        )

        deep_content = fetch_deep_pib_content(
            item["url"]
        )

        if len(deep_content) >= 150:

            final_content = deep_content
            news_type = "PIB Deep"

        else:

            final_content = item[
                "description"
            ]

            if len(final_content) < 100:
                continue

            news_type = "PIB RSS"

        results.append(
            make_news_object(
                source="PIB",
                title=item["title"],
                url=item["url"],
                date=item["date"],
                content=final_content,
                news_type=news_type
            )
        )

    print(
        f"✅ PIB usable news: "
        f"{len(results)}"
    )

    return results


# =============================================================
# 10. NEWS ON AIR
# =============================================================

NEWS_ON_AIR_URLS = [

    # National homepage
    "https://newsonair.gov.in/",

    # National category
    "https://newsonair.gov.in/category/national/",

    # Search/category variations
    "https://newsonair.gov.in/category/national-news/"
]


def scrape_news_on_air():

    print("\n📻 NEWS ON AIR NATIONAL SCRAPER")

    results = []
    seen_urls = set()

    for page_url in NEWS_ON_AIR_URLS:

        if len(results) >= TARGET_NATIONAL:
            break

        print(
            f"  🔎 News On AIR: {page_url}"
        )

        content = safe_fetch(
            page_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            # Find links
            links = soup.find_all(
                "a",
                href=True
            )

            for a in links:

                if len(results) >= TARGET_NATIONAL:
                    break

                title = normalize_text(
                    a.get_text(
                        " ",
                        strip=True
                    )
                )

                href = a.get(
                    "href",
                    ""
                )

                if not title:
                    continue

                if len(title) < 25:
                    continue

                if len(title) > 300:
                    continue

                if href.startswith("/"):
                    href = (
                        "https://newsonair.gov.in"
                        + href
                    )

                elif href.startswith(
                    "http://"
                ):
                    href = href.replace(
                        "http://",
                        "https://",
                        1
                    )

                if (
                    "newsonair.gov.in"
                    not in href
                ):
                    continue

                if href in seen_urls:
                    continue

                seen_urls.add(href)

                # Skip navigation/category links
                low_href = href.lower()

                if any(
                    x in low_href
                    for x in [
                        "/category/",
                        "/tag/",
                        "/author/",
                        "/page/",
                        "#"
                    ]
                ):
                    continue

                print(
                    f"  📰 AIR: "
                    f"{title[:90]}"
                )

                article_content = (
                    fetch_generic_article_content_air(
                        href
                    )
                )

                if len(article_content) < 180:
                    continue

                results.append(
                    make_news_object(
                        source="News On AIR",
                        title=title,
                        url=href,
                        date="",
                        content=article_content,
                        news_type="News On AIR Deep"
                    )
                )

        except Exception as e:

            print(
                f"⚠️ News On AIR error: {e}"
            )

    print(
        f"✅ News On AIR usable news: "
        f"{len(results)}"
    )

    return results


def fetch_generic_article_content_air(
    article_url
):

    content = safe_fetch(
        article_url,
        timeout=15
    )

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # JSON-LD
        jsonld = extract_jsonld_article(
            soup
        )

        if len(jsonld) >= 180:
            return jsonld[:MAX_ARTICLE_CHARS]

        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form, iframe, "
            ".advertisement"
        ):
            noise.decompose()

        candidates = []

        for selector in [
            ".entry-content",
            ".post-content",
            ".article-content",
            ".td-post-content",
            ".single-post-content",
            "article"
        ]:

            found = soup.select(
                selector
            )

            candidates.extend(found)

        content_div = (
            candidates[0]
            if candidates
            else None
        )

        if content_div:
            elements = content_div.find_all(
                ["p", "div", "li"]
            )
        else:
            elements = soup.find_all(
                "p"
            )

        blocks = []

        for el in elements:

            txt = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 35:
                blocks.append(txt)

        result = normalize_text(
            " ".join(blocks)
        )

        return result[:MAX_ARTICLE_CHARS]

    except Exception:
        return ""


# =============================================================
# 11. CMO BIHAR
# =============================================================

CMO_PRESS_URL = (
    "https://cm.bihar.gov.in/users/"
    "preessrelease.aspx"
)


def scrape_cmo_bihar():

    print("\n🏛️ CMO BIHAR SCRAPER")

    results = []

    content = safe_fetch(
        CMO_PRESS_URL,
        timeout=15
    )

    if not content:
        return results

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # Find all links to viewnews.aspx
        links = soup.find_all(
            "a",
            href=True
        )

        seen = set()

        for a in links:

            if len(results) >= 10:
                break

            href = a.get(
                "href",
                ""
            )

            title = normalize_text(
                a.get_text(
                    " ",
                    strip=True
                )
            )

            if not title:
                continue

            if "viewnews.aspx" not in href.lower():
                continue

            if href.startswith("/"):
                href = (
                    "https://cm.bihar.gov.in"
                    + href
                )

            elif not href.startswith(
                "http"
            ):
                href = urllib.parse.urljoin(
                    CMO_PRESS_URL,
                    href
                )

            if href in seen:
                continue

            seen.add(href)

            # ---------------------------------------------
            # Actual CMO article page
            # ---------------------------------------------

            article_content = (
                fetch_generic_article_content(
                    href
                )
            )

            # If generic extraction fails,
            # directly parse Read News page
            if len(article_content) < 150:

                article_content = (
                    fetch_cmo_read_news(
                        href
                    )
                )

            if len(article_content) < 150:
                print(
                    f"  ⚠️ CMO content failed: "
                    f"{title[:80]}"
                )
                continue

            # Extract date from article
            article_date = extract_cmo_date(
                article_content
            )

            print(
                f"  📰 CMO: "
                f"{title[:100]}"
            )

            results.append(
                make_news_object(
                    source="CMO Bihar",
                    title=title,
                    url=href,
                    date=article_date,
                    content=article_content,
                    news_type="CMO Deep"
                )
            )

    except Exception as e:

        print(
            f"⚠️ CMO Bihar error: {e}"
        )

    print(
        f"✅ CMO Bihar usable news: "
        f"{len(results)}"
    )

    return results


def fetch_cmo_read_news(url):

    content = safe_fetch(
        url,
        timeout=15
    )

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form"
        ):
            noise.decompose()

        # CMO Read News pages generally contain
        # the article inside the page body.
        paragraphs = soup.find_all(
            "p"
        )

        blocks = []

        for p in paragraphs:

            txt = normalize_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )

            if len(txt) >= 35:

                if (
                    "Bihar Government" in txt
                    or "Chief Minister Secretariat"
                    in txt
                    or "Copyright" in txt
                ):
                    continue

                blocks.append(txt)

        return normalize_text(
            " ".join(blocks)
        )[:MAX_ARTICLE_CHARS]

    except Exception:
        return ""


def extract_cmo_date(text):

    if not text:
        return ""

    patterns = [
        r"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}\b",
        r"\b\d{1,2}-\d{1,2}-\d{2,4}\b",
        r"\b\d{1,2}/\d{1,2}/\d{2,4}\b"
    ]

    for pattern in patterns:

        m = re.search(
            pattern,
            text
        )

        if m:
            return m.group(0)

    return ""


# =============================================================
# 12. IPRD BIHAR
# =============================================================

IPRD_SEARCH_URL = (
    "https://state.bihar.gov.in/"
    "prdbihar/SearchContent.html"
)

IPRD_HOME_URL = (
    "https://state.bihar.gov.in/"
    "prdbihar/CitizenHome.html"
)


def scrape_iprd_bihar():

    print("\n📢 IPRD BIHAR SCRAPER")

    results = []

    # ---------------------------------------------------------
    # Important:
    #
    # We DO NOT scrape CitizenHome/SectionInformation as news.
    # Those pages contain generic portal information.
    #
    # Instead, we try to find actual release links.
    # ---------------------------------------------------------

    pages = [
        IPRD_SEARCH_URL,
        IPRD_HOME_URL
    ]

    seen = set()

    for page_url in pages:

        if len(results) >= 8:
            break

        content = safe_fetch(
            page_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            for a in soup.find_all(
                "a",
                href=True
            ):

                if len(results) >= 8:
                    break

                title = normalize_text(
                    a.get_text(
                        " ",
                        strip=True
                    )
                )

                href = a.get(
                    "href",
                    ""
                )

                if not title:
                    continue

                if len(title) < 15:
                    continue

                if len(title) > 300:
                    continue

                if href.startswith("/"):
                    href = urllib.parse.urljoin(
                        page_url,
                        href
                    )

                elif not href.startswith(
                    "http"
                ):
                    href = urllib.parse.urljoin(
                        page_url,
                        href
                    )

                low = href.lower()

                # ------------------------------------------------
                # Reject generic portal pages
                # ------------------------------------------------

                if (
                    "citizenhome" in low
                    or "sectioninformation" in low
                    or "departmentinformation" in low
                ):
                    continue

                # Actual downloadable/article links
                allowed = (
                    "press"
                    in low
                    or "release"
                    in low
                    or ".pdf" in low
                    or "news" in low
                )

                if not allowed:
                    continue

                if href in seen:
                    continue

                seen.add(href)

                article_content = (
                    fetch_generic_article_content(
                        href
                    )
                )

                if len(article_content) < 180:
                    continue

                if is_bad_generic_text(
                    article_content
                ):
                    continue

                print(
                    f"  📰 IPRD: "
                    f"{title[:100]}"
                )

                results.append(
                    make_news_object(
                        source="IPRD Bihar",
                        title=title,
                        url=href,
                        date="",
                        content=article_content,
                        news_type="IPRD Deep"
                    )
                )

        except Exception as e:

            print(
                f"⚠️ IPRD error: {e}"
            )

    print(
        f"✅ IPRD Bihar usable news: "
        f"{len(results)}"
    )

    return results


# =============================================================
# 13. BIHAR CABINET
# =============================================================

CABINET_URLS = [

    "https://state.bihar.gov.in/csd/",

    "https://state.bihar.gov.in/"
    "csd/SectionInformation.html?"
    "editForm&rowId=2929"
]


def scrape_bihar_cabinet():

    print("\n🏛️ BIHAR CABINET SCRAPER")

    results = []

    for page_url in CABINET_URLS:

        if len(results) >= 6:
            break

        content = safe_fetch(
            page_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            for a in soup.find_all(
                "a",
                href=True
            ):

                if len(results) >= 6:
                    break

                title = normalize_text(
                    a.get_text(
                        " ",
                        strip=True
                    )
                )

                href = a.get(
                    "href",
                    ""
                )

                if not title:
                    continue

                low_title = title.lower()
                low_href = href.lower()

                if not any(
                    word in (
                        low_title + " "
                        + low_href
                    )
                    for word in [
                        "cabinet",
                        "decision",
                        "निर्णय"
                    ]
                ):
                    continue

                if href.startswith("/"):
                    href = urllib.parse.urljoin(
                        page_url,
                        href
                    )

                elif not href.startswith(
                    "http"
                ):
                    href = urllib.parse.urljoin(
                        page_url,
                        href
                    )

                # Do NOT accept generic Cabinet Secretariat page
                if (
                    "citizenhome" in href.lower()
                    or (
                        "cabinet" not in low_href
                        and "decision" not in low_href
                    )
                ):
                    continue

                article_content = (
                    fetch_generic_article_content(
                        href
                    )
                )

                if len(article_content) < 180:
                    continue

                if is_bad_generic_text(
                    article_content
                ):
                    continue

                results.append(
                    make_news_object(
                        source="Bihar Cabinet Decision",
                        title=title,
                        url=href,
                        date="",
                        content=article_content,
                        news_type="Cabinet Deep"
                    )
                )

        except Exception as e:

            print(
                f"⚠️ Cabinet error: {e}"
            )

    print(
        f"✅ Cabinet usable news: "
        f"{len(results)}"
    )

    return results


# =============================================================
# 14. BIHAR NEWS ON AIR
# =============================================================

def scrape_news_on_air_bihar():

    print("\n📻 NEWS ON AIR BIHAR FALLBACK")

    results = []

    urls = [
        "https://newsonair.gov.in/",
        "https://newsonair.gov.in/category/regional/"
    ]

    seen = set()

    for page_url in urls:

        if len(results) >= 6:
            break

        content = safe_fetch(
            page_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            for a in soup.find_all(
                "a",
                href=True
            ):

                if len(results) >= 6:
                    break

                title = normalize_text(
                    a.get_text(
                        " ",
                        strip=True
                    )
                )

                href = a.get(
                    "href",
                    ""
                )

                if len(title) < 25:
                    continue

                if href.startswith("/"):
                    href = (
                        "https://newsonair.gov.in"
                        + href
                    )

                if (
                    "newsonair.gov.in"
                    not in href
                ):
                    continue

                if href in seen:
                    continue

                seen.add(href)

                # Bihar-specific title/content
                if not any(
                    word in title.lower()
                    for word in [
                        "bihar",
                        "patna",
                        "बिहार",
                        "पटना"
                    ]
                ):
                    continue

                article_content = (
                    fetch_generic_article_content_air(
                        href
                    )
                )

                if len(article_content) < 180:
                    continue

                results.append(
                    make_news_object(
                        source="News On AIR Bihar",
                        title=title,
                        url=href,
                        date="",
                        content=article_content,
                        news_type="News On AIR Deep"
                    )
                )

        except Exception:
            continue

    print(
        f"✅ News On AIR Bihar usable: "
        f"{len(results)}"
    )

    return results


# =============================================================
# 15. DEDUPLICATION
# =============================================================

def title_key(title):

    title = normalize_text(
        title
    ).lower()

    title = re.sub(
        r"[^a-z0-9\u0900-\u097F]",
        "",
        title
    )

    return title[:150]


def remove_duplicate_news(
    news_list
):

    unique = []

    seen_titles = set()
    seen_urls = set()

    dropped = 0

    for news in news_list:

        title = news.get(
            "title",
            ""
        )

        url = news.get(
            "url",
            ""
        )

        key = title_key(
            title
        )

        if (
            key
            and key in seen_titles
        ):
            dropped += 1
            continue

        if (
            url
            and url in seen_urls
        ):
            dropped += 1
            continue

        if key:
            seen_titles.add(
                key
            )

        if url:
            seen_urls.add(
                url
            )

        unique.append(
            news
        )

    print(
        f"🧹 Deduplication: "
        f"Input={len(news_list)} | "
        f"Dropped={dropped} | "
        f"Unique={len(unique)}"
    )

    return unique


# =============================================================
# 16. QUALITY FILTER
# =============================================================

def quality_filter(news_list):

    clean = []

    for news in news_list:

        title = normalize_text(
            news.get("title", "")
        )

        content = normalize_text(
            news.get("content", "")
        )

        if len(title) < 10:
            continue

        # Actual content required
        if len(content) < MIN_CONTENT_CHARS:
            continue

        # Reject title-only RSS
        if content.lower() == title.lower():
            continue

        # Reject portal garbage
        if is_bad_generic_text(
            content
        ):
            continue

        # Reject obvious email/login garbage
        if (
            "forgot email" in content.lower()
            or "not your computer" in content.lower()
        ):
            continue

        news["title"] = title
        news["content"] = content
        news["content_chars"] = len(
            content
        )

        clean.append(
            news
        )

    return clean


# =============================================================
# 17. MAIN SCRAPER
# =============================================================

def run_scraper():

    date_info = get_date_info()

    print("=" * 70)

    print(
        "🚀 STARTING GOVERNMENT NEWS SCRAPER"
    )

    print(
        f"Today     : "
        f"{date_info['today_str']}"
    )

    print(
        f"Yesterday : "
        f"{date_info['yesterday_str']}"
    )

    print("=" * 70)

    # =========================================================
    # NATIONAL
    # =========================================================

    national_items = []

    # ---------------------------------------------------------
    # 1. PIB = PRIMARY
    # ---------------------------------------------------------

    pib_items = scrape_pib()

    national_items.extend(
        pib_items
    )

    # ---------------------------------------------------------
    # 2. News On AIR = FALLBACK
    # ---------------------------------------------------------

    if len(national_items) < TARGET_NATIONAL:

        print(
            "\n⚠️ PIB insufficient. "
            "Using News On AIR fallback..."
        )

        air_items = scrape_news_on_air()

        national_items.extend(
            air_items
        )

    # Quality + dedup
    national_items = quality_filter(
        national_items
    )

    national_items = remove_duplicate_news(
        national_items
    )

    # =========================================================
    # BIHAR
    # =========================================================

    bihar_items = []

    # ---------------------------------------------------------
    # 1. CMO Bihar
    # ---------------------------------------------------------

    cmo_items = scrape_cmo_bihar()

    bihar_items.extend(
        cmo_items
    )

    # ---------------------------------------------------------
    # 2. IPRD Bihar
    # ---------------------------------------------------------

    iprd_items = scrape_iprd_bihar()

    bihar_items.extend(
        iprd_items
    )

    # ---------------------------------------------------------
    # 3. Bihar Cabinet
    # ---------------------------------------------------------

    cabinet_items = scrape_bihar_cabinet()

    bihar_items.extend(
        cabinet_items
    )

    # ---------------------------------------------------------
    # 4. News On AIR Bihar fallback
    # ---------------------------------------------------------

    if len(bihar_items) < TARGET_BIHAR:

        air_bihar = (
            scrape_news_on_air_bihar()
        )

        bihar_items.extend(
            air_bihar
        )

    # Quality + dedup
    bihar_items = quality_filter(
        bihar_items
    )

    bihar_items = remove_duplicate_news(
        bihar_items
    )

    # =========================================================
    # LIMIT
    # =========================================================

    national_items = national_items[
        :TARGET_NATIONAL
    ]

    bihar_items = bihar_items[
        :TARGET_BIHAR
    ]

    # =========================================================
    # SOURCE STATS
    # =========================================================

    source_stats = {}

    for news in (
        national_items
        + bihar_items
    ):

        source = news.get(
            "source",
            "Unknown"
        )

        source_stats[source] = (
            source_stats.get(
                source,
                0
            ) + 1
        )

    # =========================================================
    # FINAL PAYLOAD
    # =========================================================

    raw_payload = {

        "timestamp":
            datetime.now().strftime(
                "%Y-%m-%d %H:%M:%S"
            ),

        "target_date_str":
            date_info["yesterday_str"],

        "target_key_str":
            date_info["yesterday_key"],

        "source_stats":
            source_stats,

        "bihar_raw_count":
            len(bihar_items),

        "national_raw_count":
            len(national_items),

        "bihar_raw_news":
            bihar_items,

        "national_raw_news":
            national_items
    }

    # =========================================================
    # SAVE
    # =========================================================

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
    # SUMMARY
    # =========================================================

    print("\n")
    print("=" * 70)
    print(
        "📊 FINAL SCRAPING SUMMARY"
    )
    print("=" * 70)

    print(
        json.dumps(
            source_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print(
        f"\n🇮🇳 National News : "
        f"{len(national_items)}"
    )

    print(
        f"🏛️ Bihar News    : "
        f"{len(bihar_items)}"
    )

    print(
        "\n💾 rawnews.json updated successfully!"
    )

    print("=" * 70)


# =============================================================
# RUN
# =============================================================

if __name__ == "__main__":

    run_scraper()
