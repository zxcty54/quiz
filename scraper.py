import os
import json
import time
import urllib.parse
import re
from datetime import datetime, timedelta
import email.utils
import xml.etree.ElementTree as ET
import warnings

from curl_cffi import requests
from bs4 import BeautifulSoup, MarkupResemblesLocatorWarning
from dateutil import parser as date_parser

# =============================================================
# CONFIG
# =============================================================

warnings.filterwarnings(
    "ignore",
    category=MarkupResemblesLocatorWarning
)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_PARAGRAPH_CHARS = 35

PIB_TARGET_COUNT = 12
AIR_TARGET_COUNT = 12

BIHAR_TARGET_COUNT = 15

REQUEST_TIMEOUT = 15


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
        r"(\d+)\s+(hour|hr|day|min|minute|second)s?\s+ago",
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

        if "second" in unit:
            return now - timedelta(seconds=val)

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

    # Generic parser
    try:

        parsed_dt = date_parser.parse(
            date_str,
            fuzzy=True,
            dayfirst=True
        )

        if parsed_dt.tzinfo is not None:

            parsed_dt = (
                parsed_dt
                .astimezone()
                .replace(tzinfo=None)
            )

        return parsed_dt

    except Exception:
        pass

    return None


def date_bucket(pub_date_str, target_dt):
    """
    Returns:
        yesterday
        today
        old
        unknown
    """

    if not pub_date_str:
        return "unknown"

    pub_dt = parse_any_date(pub_date_str)

    if not pub_dt:
        return "unknown"

    target_date = target_dt.date()

    yesterday_date = (
        target_dt - timedelta(days=1)
    ).date()

    if pub_dt.date() == yesterday_date:
        return "yesterday"

    if pub_dt.date() == target_date:
        return "today"

    return "old"


def is_recent_date(pub_date_str, target_dt, allow_old_days=2):

    if not pub_date_str:
        return False

    pub_dt = parse_any_date(pub_date_str)

    if not pub_dt:
        return False

    start = target_dt - timedelta(days=allow_old_days)

    end = target_dt + timedelta(days=1)

    return start <= pub_dt <= end


# =============================================================
# 2. TEXT CLEANING
# =============================================================

def clean_cdata_and_html(text):

    if not text:
        return ""

    text = str(text)

    text = re.sub(
        r"<!\[CDATA\[(.*?)\]\]>",
        r"\1",
        text,
        flags=re.DOTALL
    )

    # Don't feed obvious URLs to BeautifulSoup
    if re.match(
        r"^https?://",
        text.strip(),
        re.IGNORECASE
    ):
        return text.strip()

    soup = BeautifulSoup(
        text,
        "html.parser"
    )

    return " ".join(
        soup.get_text(
            " ",
            strip=True
        ).split()
    ).strip()


def normalize_text(text):

    if not text:
        return ""

    text = str(text)

    text = BeautifulSoup(
        text,
        "html.parser"
    ).get_text(
        " ",
        strip=True
    )

    text = re.sub(
        r"\s+",
        " ",
        text
    )

    return text.strip()


def clean_url(url):

    if not url:
        return ""

    url = str(url).strip()

    # Remove accidental markdown link wrappers
    md_match = re.match(
        r"\[.*?\]\((https?://.*?)\)",
        url
    )

    if md_match:
        url = md_match.group(1)

    # Remove escaped characters accidentally inserted
    url = url.replace("\\&", "&")
    url = url.replace("\\_", "_")

    return url.strip()


# =============================================================
# 3. SAFE FETCHER
# =============================================================

def safe_fetch(url, timeout=REQUEST_TIMEOUT):

    url = clean_url(url)

    if not url:
        return None

    headers = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/150.0.0.0 Safari/537.36",

        "Accept":
            "text/html,application/xhtml+xml,"
            "application/xml;q=0.9,*/*;q=0.8",

        "Accept-Language":
            "en-US,en;q=0.9,hi;q=0.8",

        "Referer":
            "https://www.google.com/"
    }

    # ---------------------------------------------------------
    # DIRECT
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

        if res.status_code == 200:

            return res.content

        print(
            f"⚠️ HTTP {res.status_code}: {url[:100]}"
        )

    except Exception as e:

        print(
            f"⚠️ Direct fetch failed: "
            f"{url[:80]} | {e}"
        )

    # ---------------------------------------------------------
    # SCRAPINGANT
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
                "&browser=false"
            )

            sa_res = requests.get(
                sa_url,
                timeout=25
            )

            if sa_res.status_code == 200:

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

    if not soup:
        return ""

    for script in soup.find_all(
        "script",
        type="application/ld+json"
    ):

        raw = (
            script.string
            or script.get_text()
        )

        if not raw:
            continue

        try:

            data = json.loads(
                raw.strip()
            )

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

                if not isinstance(
                    obj,
                    dict
                ):
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
# 5. GENERIC ARTICLE SCRAPER
# =============================================================

def fetch_generic_article_content(article_url):

    article_url = clean_url(article_url)

    if not article_url:
        return ""

    if "news.google.com" in article_url.lower():
        return ""

    content = safe_fetch(
        article_url,
        timeout=12
    )

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # JSON-LD FIRST
        jsonld_text = extract_jsonld_article(
            soup
        )

        if len(jsonld_text) >= 250:

            return jsonld_text[
                :MAX_ARTICLE_CHARS
            ]

        # Remove obvious noise
        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form, iframe, "
            ".advertisement, .ads, "
            ".social-share, .share"
        ):

            noise.decompose()

        # Common article containers
        content_div = (
            soup.find(
                class_="article-body"
            )
            or soup.find(
                id="content-body"
            )
            or soup.find(
                class_="story-element"
            )
            or soup.find(
                class_="article-content"
            )
            or soup.find(
                class_="story-content"
            )
            or soup.find(
                class_="full-details"
            )
            or soup.find(
                class_="articleBody"
            )
            or soup.find(
                class_="content"
            )
        )

        if content_div:

            elements = content_div.find_all(
                ["p", "li"]
            )

        else:

            elements = soup.find_all(
                "p"
            )

        text_blocks = []

        for p in elements:

            text = normalize_text(
                p.get_text(" ", strip=True)
            )

            if len(text) >= MIN_PARAGRAPH_CHARS:

                text_blocks.append(text)

        result = normalize_text(
            " ".join(text_blocks)
        )

        return result[
            :MAX_ARTICLE_CHARS
        ]

    except Exception as e:

        print(
            f"⚠️ Generic parsing error: {e}"
        )

        return ""


# =============================================================
# 6. PIB DEEP SCRAPER
# =============================================================

def fetch_deep_pib_content(article_url):

    article_url = clean_url(article_url)

    if not article_url:
        return ""

    prid_match = re.search(
        r"PRID=(\d+)",
        article_url,
        re.IGNORECASE
    )

    if (
        "pib.gov.in"
        in article_url.lower()
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

        for noise in soup.select(
            "script, style, nav, footer, "
            "header, form, iframe, "
            ".share-box, .social"
        ):

            noise.decompose()

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
                ["p", "tr", "li"]
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

                blocks.append(txt)

        result = normalize_text(
            " ".join(blocks)
        )

        return result[
            :MAX_ARTICLE_CHARS
        ]

    except Exception as e:

        print(
            f"⚠️ PIB parsing error: {e}"
        )

        return ""


# =============================================================
# 7. GENERIC ITEM BUILDER
# =============================================================

def make_news_item(
    source,
    title,
    url,
    date,
    content,
    item_type="Scraped"
):

    title = normalize_text(title)
    content = normalize_text(content)
    url = clean_url(url)

    if not title:
        return None

    # Don't store title as fake article content
    if (
        not content
        or content.lower().strip()
        == title.lower().strip()
    ):
        return None

    if len(content) < MIN_CONTENT_CHARS:
        return None

    return {
        "source": source,
        "title": title,
        "url": url,
        "date": date or "",
        "content": content[:MAX_ARTICLE_CHARS],
        "content_chars": min(
            len(content),
            MAX_ARTICLE_CHARS
        ),
        "type": item_type
    }


# =============================================================
# 8. DEDUPLICATION
# =============================================================

def remove_duplicate_news(news_list):

    seen = set()

    unique_news = []

    dropped = 0

    for news in news_list:

        if not isinstance(news, dict):
            continue

        title = normalize_text(
            news.get("title", "")
        )

        key = re.sub(
            r"[^a-z0-9\u0900-\u097F]",
            "",
            title.lower()
        )

        key = key[:120]

        if key and key not in seen:

            seen.add(key)

            unique_news.append(
                news
            )

        else:

            dropped += 1

    print(
        f"🧹 Deduplication: "
        f"Input={len(news_list)} | "
        f"Dropped={dropped} | "
        f"Unique={len(unique_news)}"
    )

    return unique_news


# =============================================================
# 9. PIB RSS SCRAPER
# =============================================================

def scrape_pib_rss(target_dt):

    print(
        "\n🇮🇳 PIB NATIONAL SCRAPER"
    )

    feeds = [
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",
        "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=9&Regid=1"
    ]

    all_items = []

    for feed_url in feeds:

        print(
            f"🔎 PIB feed: {feed_url}"
        )

        content = safe_fetch(
            feed_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "xml"
            )

            items = soup.find_all(
                "item"
            )

            print(
                f"Found RSS items: "
                f"{len(items)}"
            )

            for item in items[:40]:

                title = clean_cdata_and_html(
                    item.find("title").get_text()
                    if item.find("title")
                    else ""
                )

                link = clean_url(
                    item.find("link").get_text()
                    if item.find("link")
                    else ""
                )

                pub_date = clean_cdata_and_html(
                    item.find("pubDate").get_text()
                    if item.find("pubDate")
                    else (
                        item.find("pubdate").get_text()
                        if item.find("pubdate")
                        else ""
                    )
                )

                description = clean_cdata_and_html(
                    item.find("description").get_text()
                    if item.find("description")
                    else ""
                )

                if not title or not link:
                    continue

                bucket = date_bucket(
                    pub_date,
                    target_dt
                )

                # Only yesterday/today/unknown
                if bucket == "old":
                    continue

                all_items.append({
                    "title": title,
                    "link": link,
                    "date": pub_date,
                    "description": description,
                    "bucket": bucket
                })

        except Exception as e:

            print(
                f"⚠️ PIB RSS parse error: {e}"
            )

    # Deduplicate RSS items
    unique = {}

    for item in all_items:

        key = re.sub(
            r"[^a-z0-9]",
            "",
            item["title"].lower()
        )

        if key not in unique:

            unique[key] = item

    all_items = list(
        unique.values()
    )

    print(
        f"📊 Total unique PIB RSS items: "
        f"{len(all_items)}"
    )

    yesterday = [
        x for x in all_items
        if x["bucket"] == "yesterday"
    ]

    today = [
        x for x in all_items
        if x["bucket"] == "today"
    ]

    unknown = [
        x for x in all_items
        if x["bucket"] == "unknown"
    ]

    print(
        f"📅 PIB yesterday items: "
        f"{len(yesterday)}"
    )

    print(
        f"📅 PIB today items: "
        f"{len(today)}"
    )

    # ---------------------------------------------------------
    # Priority:
    # 1 yesterday
    # 2 today
    # 3 unknown only if required
    # ---------------------------------------------------------

    ordered = (
        yesterday
        + today
        + unknown
    )

    result = []

    for item in ordered:

        deep = fetch_deep_pib_content(
            item["link"]
        )

        if len(deep) < MIN_CONTENT_CHARS:

            deep = item["description"]

        news = make_news_item(
            source="PIB",
            title=item["title"],
            url=item["link"],
            date=item["date"],
            content=deep,
            item_type="PIB RSS + Deep"
        )

        if news:

            result.append(news)

            print(
                f"  ✅ PIB: "
                f"{len(deep)} chars | "
                f"{item['title'][:80]}"
            )

        if len(result) >= PIB_TARGET_COUNT:
            break

    print(
        f"✅ PIB usable news: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 10. PIB WEBSITE FALLBACK
# =============================================================

def scrape_pib_website_fallback():

    print(
        "\n🔎 PIB WEBSITE FALLBACK"
    )

    urls = [
        "https://www.pib.gov.in/PressReleasePage.aspx",
        "https://www.pib.gov.in/PressReleaseDetail.aspx"
    ]

    result = []

    for page_url in urls:

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

            for a in soup.find_all("a"):

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

                if len(title) < 20:
                    continue

                if (
                    "PressRelease"
                    not in href
                    and "PressRelease"
                    not in str(a)
                ):
                    continue

                link = urllib.parse.urljoin(
                    page_url,
                    href
                )

                deep = fetch_deep_pib_content(
                    link
                )

                if len(deep) < MIN_CONTENT_CHARS:
                    continue

                news = make_news_item(
                    source="PIB",
                    title=title,
                    url=link,
                    date="",
                    content=deep,
                    item_type="PIB Website Fallback"
                )

                if news:

                    result.append(news)

                if len(result) >= PIB_TARGET_COUNT:
                    break

            if len(result) >= PIB_TARGET_COUNT:
                break

        except Exception as e:

            print(
                f"⚠️ PIB website error: {e}"
            )

    return remove_duplicate_news(
        result
    )


# =============================================================
# 11. NEWS ON AIR NATIONAL
# =============================================================

def scrape_news_on_air_national():

    print(
        "\n📻 NEWS ON AIR NATIONAL SCRAPER"
    )

    home_url = (
        "https://newsonair.gov.in/"
    )

    content = safe_fetch(
        home_url,
        timeout=15
    )

    if not content:
        return []

    result = []

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        links = soup.find_all("a")

        for a in links:

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

            if len(title) < 30:
                continue

            link = urllib.parse.urljoin(
                home_url,
                href
            )

            # Avoid categories, tags etc.
            if any(
                x in link.lower()
                for x in [
                    "/category/",
                    "/tag/",
                    "/author/",
                    "/page/"
                ]
            ):
                continue

            # Article content
            article_content = (
                fetch_generic_article_content(
                    link
                )
            )

            if len(article_content) < MIN_CONTENT_CHARS:

                # Sometimes AIR page itself
                # contains article body
                article_content = ""

            news = make_news_item(
                source="News On AIR",
                title=title,
                url=link,
                date="",
                content=article_content,
                item_type="News On AIR"
            )

            if news:

                result.append(news)

                print(
                    f"📰 AIR: "
                    f"{title[:90]}"
                )

            if len(result) >= AIR_TARGET_COUNT:
                break

    except Exception as e:

        print(
            f"⚠️ News On AIR error: {e}"
        )

    result = remove_duplicate_news(
        result
    )

    print(
        f"✅ News On AIR usable news: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 12. CMO BIHAR
# =============================================================

def scrape_cmo_bihar():

    print(
        "\n🏛️ CMO BIHAR SCRAPER"
    )

    url = (
        "https://cm.bihar.gov.in/"
        "users/preessrelease.aspx"
    )

    content = safe_fetch(
        url,
        timeout=15
    )

    if not content:
        return []

    result = []

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        # Main listing table
        rows = soup.find_all("tr")

        for row in rows:

            cols = row.find_all(
                "td"
            )

            if len(cols) < 2:
                continue

            date_text = normalize_text(
                cols[0].get_text(
                    " ",
                    strip=True
                )
            )

            title = normalize_text(
                cols[1].get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 20:
                continue

            link = ""

            # Find actual View/Download link
            for a in row.find_all("a"):

                href = a.get(
                    "href",
                    ""
                )

                if href:

                    link = urllib.parse.urljoin(
                        url,
                        href
                    )

                    break

            # If no link, don't fake article
            if not link:
                continue

            article_content = (
                fetch_generic_article_content(
                    link
                )
            )

            if len(article_content) < MIN_CONTENT_CHARS:
                continue

            news = make_news_item(
                source="CMO Bihar",
                title=title,
                url=link,
                date=date_text,
                content=article_content,
                item_type="CMO Press Release"
            )

            if news:

                result.append(news)

                print(
                    f"  ✅ CMO: "
                    f"{date_text} | "
                    f"{title[:80]}"
                )

            if len(result) >= 10:
                break

    except Exception as e:

        print(
            f"⚠️ CMO error: {e}"
        )

    result = remove_duplicate_news(
        result
    )

    print(
        f"✅ CMO Bihar usable news: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 13. IPRD BIHAR
# =============================================================

def scrape_iprd_bihar():

    print(
        "\n📢 IPRD BIHAR SCRAPER"
    )

    # Only actual relevant sections.
    # Old/general portal pages are intentionally excluded.
    section_urls = [

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
            "?editForm&rowId=4660"
        )
    ]

    result = []

    for source, section_url in section_urls:

        content = safe_fetch(
            section_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            # Find links inside tables
            for row in soup.find_all("tr"):

                cols = row.find_all(
                    "td"
                )

                if not cols:
                    continue

                row_text = normalize_text(
                    row.get_text(
                        " ",
                        strip=True
                    )
                )

                if len(row_text) < 20:
                    continue

                links = row.find_all("a")

                if not links:
                    continue

                article_link = ""

                for a in links:

                    href = a.get(
                        "href",
                        ""
                    )

                    if not href:
                        continue

                    full_link = (
                        urllib.parse.urljoin(
                            section_url,
                            href
                        )
                    )

                    # Skip navigation
                    if any(
                        bad in full_link.lower()
                        for bad in [
                            "javascript:",
                            "mailto:",
                            "#"
                        ]
                    ):
                        continue

                    article_link = full_link
                    break

                if not article_link:
                    continue

                # Try to get date from row
                date_text = ""

                for col in cols:

                    txt = normalize_text(
                        col.get_text(
                            " ",
                            strip=True
                        )
                    )

                    if re.search(
                        r"\b\d{1,2}[-/ ]"
                        r"(?:Jan|Feb|Mar|Apr|May|Jun|"
                        r"Jul|Aug|Sep|Oct|Nov|Dec)"
                        r"[-/ ]\d{2,4}\b",
                        txt,
                        re.IGNORECASE
                    ):
                        date_text = txt
                        break

                # Find title from anchor
                title = ""

                for a in links:

                    txt = normalize_text(
                        a.get_text(
                            " ",
                            strip=True
                        )
                    )

                    if len(txt) >= 20:

                        title = txt
                        break

                if not title:
                    title = row_text[:250]

                # -------------------------------------------------
                # IMPORTANT:
                # Don't scrape section page itself.
                # Scrape actual linked release.
                # -------------------------------------------------

                article_content = (
                    fetch_generic_article_content(
                        article_link
                    )
                )

                if len(article_content) < MIN_CONTENT_CHARS:
                    continue

                news = make_news_item(
                    source=source,
                    title=title,
                    url=article_link,
                    date=date_text,
                    content=article_content,
                    item_type="IPRD Press Release"
                )

                if news:

                    result.append(news)

                if len(result) >= 10:
                    break

        except Exception as e:

            print(
                f"⚠️ IPRD error: {e}"
            )

    result = remove_duplicate_news(
        result
    )

    print(
        f"✅ IPRD Bihar usable news: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 14. BIHAR CABINET
# =============================================================

def scrape_bihar_cabinet():

    print(
        "\n🏛️ BIHAR CABINET SCRAPER"
    )

    section_urls = [

        "https://state.bihar.gov.in/"
        "csd/SectionInformation.html"
        "?editForm&rowId=2929",

        "https://state.bihar.gov.in/"
        "csd/SectionInformation.html"
        "?editForm&rowId=4935"
    ]

    result = []

    for section_url in section_urls:

        content = safe_fetch(
            section_url,
            timeout=15
        )

        if not content:
            continue

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            for row in soup.find_all("tr"):

                cols = row.find_all(
                    "td"
                )

                if not cols:
                    continue

                links = row.find_all("a")

                if not links:
                    continue

                article_link = ""

                for a in links:

                    href = a.get(
                        "href",
                        ""
                    )

                    if not href:
                        continue

                    full_link = (
                        urllib.parse.urljoin(
                            section_url,
                            href
                        )
                    )

                    if any(
                        x in full_link.lower()
                        for x in [
                            "javascript:",
                            "mailto:"
                        ]
                    ):
                        continue

                    article_link = full_link
                    break

                if not article_link:
                    continue

                title = ""

                for a in links:

                    txt = normalize_text(
                        a.get_text(
                            " ",
                            strip=True
                        )
                    )

                    if len(txt) >= 15:

                        title = txt
                        break

                if not title:
                    continue

                # Cabinet article/document
                article_content = (
                    fetch_generic_article_content(
                        article_link
                    )
                )

                if len(article_content) < MIN_CONTENT_CHARS:

                    # Cabinet documents can sometimes be
                    # directly readable PDF/HTML.
                    # Don't use generic portal text.
                    continue

                news = make_news_item(
                    source="Bihar Cabinet Decision",
                    title=title,
                    url=article_link,
                    date="",
                    content=article_content,
                    item_type="Cabinet Decision"
                )

                if news:

                    result.append(news)

                if len(result) >= 8:
                    break

        except Exception as e:

            print(
                f"⚠️ Cabinet error: {e}"
            )

    result = remove_duplicate_news(
        result
    )

    print(
        f"✅ Bihar Cabinet usable news: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 15. NEWS ON AIR BIHAR
# =============================================================

def scrape_news_on_air_bihar():

    print(
        "\n📻 NEWS ON AIR BIHAR FALLBACK"
    )

    # New AIR site does not reliably expose
    # /category/regional/ so don't use the old 404 URL.
    # Search homepage links for Bihar-related stories.

    home_url = (
        "https://newsonair.gov.in/"
    )

    content = safe_fetch(
        home_url,
        timeout=15
    )

    if not content:
        return []

    result = []

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        for a in soup.find_all("a"):

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

            if len(title) < 30:
                continue

            # Bihar-focused filtering
            lower_title = title.lower()

            bihar_words = [
                "bihar",
                "patna",
                "gaya",
                "muzaffarpur",
                "darbhanga",
                "bhagalpur",
                "purnia",
                "sitamarhi",
                "vaishali",
                "nalanda",
                "rajgir",
                "begusarai",
                "chhapra",
                "samastipur",
                "motihari",
                "katihar",
                "madhubani"
            ]

            if not any(
                word in lower_title
                for word in bihar_words
            ):
                continue

            link = urllib.parse.urljoin(
                home_url,
                href
            )

            article_content = (
                fetch_generic_article_content(
                    link
                )
            )

            if len(article_content) < MIN_CONTENT_CHARS:
                continue

            news = make_news_item(
                source="News On AIR Bihar",
                title=title,
                url=link,
                date="",
                content=article_content,
                item_type="AIR Bihar"
            )

            if news:

                result.append(news)

            if len(result) >= 8:
                break

    except Exception as e:

        print(
            f"⚠️ AIR Bihar error: {e}"
        )

    result = remove_duplicate_news(
        result
    )

    print(
        f"✅ News On AIR Bihar usable: "
        f"{len(result)}"
    )

    return result


# =============================================================
# 16. MAIN SCRAPER
# =============================================================

def run_scraper():

    target_dt, date_str, key_str = (
        get_yesterday_info()
    )

    print(
        "================================================="
    )

    print(
        f"🔄 SCRAPER STARTED"
    )

    print(
        f"📅 Target date: {date_str}"
    )

    print(
        "================================================="
    )

    bihar_items = []
    national_items = []

    source_stats = {}

    # =========================================================
    # NATIONAL
    # =========================================================

    # ---------------------------------------------------------
    # 1. PIB FIRST
    # ---------------------------------------------------------

    pib_items = scrape_pib_rss(
        target_dt
    )

    # If PIB RSS did not give usable news
    if len(pib_items) < 5:

        print(
            "\n⚠️ PIB RSS insufficient."
        )

        pib_web = scrape_pib_website_fallback()

        pib_items.extend(
            pib_web
        )

    pib_items = remove_duplicate_news(
        pib_items
    )

    # ---------------------------------------------------------
    # 2. NEWS ON AIR ONLY IF PIB LOW
    # ---------------------------------------------------------

    if len(pib_items) < 5:

        print(
            "\n⚠️ PIB still insufficient."
        )

        print(
            "📻 Using News On AIR fallback..."
        )

        air_items = (
            scrape_news_on_air_national()
        )

        # Keep PIB + AIR
        national_items.extend(
            pib_items
        )

        national_items.extend(
            air_items
        )

        source_stats[
            "PIB"
        ] = len(pib_items)

        source_stats[
            "News On AIR"
        ] = len(air_items)

    else:

        # PIB is enough
        national_items.extend(
            pib_items
        )

        source_stats[
            "PIB"
        ] = len(pib_items)

        source_stats[
            "News On AIR"
        ] = 0

    # Final national cleanup
    national_items = remove_duplicate_news(
        national_items
    )

    # Limit national news
    national_items = national_items[
        :15
    ]

    # =========================================================
    # BIHAR
    # =========================================================

    # ---------------------------------------------------------
    # CMO
    # ---------------------------------------------------------

    cmo_items = scrape_cmo_bihar()

    bihar_items.extend(
        cmo_items
    )

    source_stats[
        "CMO Bihar"
    ] = len(cmo_items)

    # ---------------------------------------------------------
    # IPRD
    # ---------------------------------------------------------

    iprd_items = scrape_iprd_bihar()

    bihar_items.extend(
        iprd_items
    )

    source_stats[
        "IPRD Bihar"
    ] = len(iprd_items)

    # ---------------------------------------------------------
    # CABINET
    # ---------------------------------------------------------

    cabinet_items = (
        scrape_bihar_cabinet()
    )

    bihar_items.extend(
        cabinet_items
    )

    source_stats[
        "Bihar Cabinet Decision"
    ] = len(cabinet_items)

    # ---------------------------------------------------------
    # AIR BIHAR FALLBACK
    # ---------------------------------------------------------

    if len(bihar_items) < 8:

        air_bihar_items = (
            scrape_news_on_air_bihar()
        )

        bihar_items.extend(
            air_bihar_items
        )

        source_stats[
            "News On AIR Bihar"
        ] = len(
            air_bihar_items
        )

    else:

        source_stats[
            "News On AIR Bihar"
        ] = 0

    # Final Bihar cleanup
    bihar_items = remove_duplicate_news(
        bihar_items
    )

    bihar_items = bihar_items[
        :BIHAR_TARGET_COUNT
    ]

    # =========================================================
    # FINAL STATS
    # =========================================================

    print(
        "\n📊 SOURCE BREAKDOWN"
    )

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

    # =========================================================
    # SAVE
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

        "bihar_raw_count":
            len(bihar_items),

        "national_raw_count":
            len(national_items),

        "bihar_raw_news":
            bihar_items,

        "national_raw_news":
            national_items
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

    print(
        "\n💾 rawnews.json updated successfully!"
    )


# =============================================================
# ENTRY POINT
# =============================================================

if __name__ == "__main__":

    run_scraper()
