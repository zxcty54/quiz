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

urllib3.disable_warnings(
    urllib3.exceptions.InsecureRequestWarning
)

SCRAPINGANT_KEY = os.environ.get(
    "SCRAPINGANT_API_KEY"
)

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_GOOD_CONTENT_CHARS = 250
MIN_PARAGRAPH_CHARS = 35


# =============================================================
# 1. DATE ENGINE
# =============================================================

def get_yesterday_info():

    yesterday_dt = (
        datetime.now() -
        timedelta(days=1)
    )

    date_str = yesterday_dt.strftime(
        "%d %b %Y"
    )

    key_str = yesterday_dt.strftime(
        "%Y-%m-%d"
    )

    return yesterday_dt, date_str, key_str


def parse_any_date(date_str):

    if not date_str:
        return None

    date_str = str(date_str).strip()

    now = datetime.now()

    lower_str = date_str.lower()

    if "yesterday" in lower_str:
        return now - timedelta(days=1)

    if "today" in lower_str:
        return now

    relative_match = re.search(
        r"(\d+)\s+(hour|hr|day|min|minute)s?\s+ago",
        lower_str
    )

    if relative_match:

        val = int(
            relative_match.group(1)
        )

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

        pub_tuple = email.utils.parsedate_tz(
            date_str
        )

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

            parsed_dt = (
                parsed_dt
                .astimezone()
                .replace(tzinfo=None)
            )

        return parsed_dt

    except Exception:
        pass

    return None


def is_yesterday_news(
    pub_date_str,
    target_dt
):

    if not pub_date_str:
        return True

    pub_dt = parse_any_date(
        pub_date_str
    )

    if pub_dt:

        start_window = (
            target_dt -
            timedelta(days=3)
        )

        end_window = (
            target_dt +
            timedelta(days=1.5)
        )

        return (
            start_window
            <= pub_dt
            <= end_window
        )

    return True


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

    soup = BeautifulSoup(
        text,
        "html.parser"
    )

    return normalize_text(
        soup.get_text(
            " ",
            strip=True
        )
    )


def normalize_text(text):

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
        .replace("\u200b", " ")
        .replace("\ufeff", " ")
    )

    text = re.sub(
        r"\s+",
        " ",
        text
    )

    return text.strip()


# =============================================================
# 3. NOISE DETECTION
# =============================================================

NOISE_PHRASES = [

    "privacy policy",
    "terms of use",
    "terms and conditions",
    "cookie policy",
    "cookie settings",
    "subscribe now",
    "subscribe to",
    "sign up",
    "log in",
    "login",
    "download our app",
    "follow us on",
    "advertisement",
    "advertisements",
    "read more",
    "related stories",
    "related articles",
    "most popular",
    "recommended",
    "you may also like",
    "share this article",
    "share on facebook",
    "share on twitter",
    "all rights reserved",
    "newsletter",
    "click here",
    "listen to this article"
]


def is_noise_text(text):

    if not text:
        return True

    low = text.lower().strip()

    if len(low) < MIN_PARAGRAPH_CHARS:
        return True

    for phrase in NOISE_PHRASES:

        if phrase in low:

            # Don't reject a genuine long paragraph
            # just because it contains "read more".
            if len(low) < 250:
                return True

    return False


def remove_duplicate_paragraphs(
    paragraphs
):

    result = []
    seen = set()

    for text in paragraphs:

        text = normalize_text(text)

        if len(text) < MIN_PARAGRAPH_CHARS:
            continue

        key = re.sub(
            r"[^a-z0-9]+",
            "",
            text.lower()
        )

        if not key:
            continue

        # Exact duplicate

        if key in seen:
            continue

        seen.add(key)

        result.append(text)

    return result


def remove_noise(soup):

    selectors = [

        "script",
        "style",
        "noscript",
        "template",

        "nav",
        "footer",
        "header",

        "form",
        "iframe",

        ".advertisement",
        ".advert",
        ".ads",
        ".ad",
        ".social-share",
        ".share",
        ".share-box",

        ".comments",
        ".comment-section",

        ".related",
        ".related-articles",
        ".recommended",

        ".newsletter",
        ".subscribe",

        "[aria-label='Advertisement']",

        "[class*='advert']",
        "[class*='sidebar']",
        "[class*='social-share']",
        "[class*='newsletter']",
        "[class*='related']"
    ]

    for selector in selectors:

        try:

            for node in soup.select(
                selector
            ):

                node.decompose()

        except Exception:
            pass

    return soup


# =============================================================
# 4. SAFE FETCHER
# =============================================================

def safe_fetch(
    url,
    timeout=15,
    use_scrapingant=True,
    browser=False
):

    if not url:
        return None

    headers = {

        "User-Agent":
            "Mozilla/5.0 "
            "(Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 "
            "(KHTML, like Gecko) "
            "Chrome/150.0.0.0 "
            "Safari/537.36",

        "Accept":
            "text/html,"
            "application/xhtml+xml,"
            "application/xml;q=0.9,"
            "*/*;q=0.8",

        "Accept-Language":
            "en-US,en;q=0.9,hi;q=0.8",

        "Cache-Control":
            "no-cache",

        "Pragma":
            "no-cache"
    }

    # =========================================================
    # ATTEMPT 1 — DIRECT
    # =========================================================

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

            print(
                f"      ↳ Direct HTTP 200 | "
                f"{len(res.content)} bytes"
            )

            return res.content

        print(
            f"      ↳ Direct HTTP {res.status_code}"
        )

    except Exception as e:

        print(
            f"      ⚠️ Direct fetch failed | "
            f"{str(e)[:120]}"
        )

    # =========================================================
    # ATTEMPT 2 — SCRAPINGANT
    # =========================================================

    if (
        use_scrapingant
        and
        SCRAPINGANT_KEY
    ):

        try:

            encoded_url = urllib.parse.quote(
                url,
                safe=""
            )

            browser_value = (
                "true"
                if browser
                else "false"
            )

            sa_url = (
                "https://api.scrapingant.com/v2/general"
                f"?url={encoded_url}"
                f"&x-api-key={SCRAPINGANT_KEY}"
                f"&browser={browser_value}"
            )

            print(
                f"      ↳ ScrapingAnt "
                f"browser={browser_value}"
            )

            sa_res = requests.get(
                sa_url,
                timeout=40
            )

            if sa_res.status_code == 200:

                print(
                    f"      ↳ ScrapingAnt 200 | "
                    f"{len(sa_res.content)} bytes"
                )

                return sa_res.content

            print(
                f"      ↳ ScrapingAnt HTTP "
                f"{sa_res.status_code}"
            )

        except Exception as e:

            print(
                f"      ❌ ScrapingAnt error | "
                f"{str(e)[:120]}"
            )

    return None


# =============================================================
# 5. JSON-LD ARTICLE BODY
# =============================================================

def extract_jsonld_article(
    soup
):

    scripts = soup.find_all(
        "script",
        type="application/ld+json"
    )

    for script in scripts:

        raw = (
            script.string
            or
            script.get_text()
        )

        if not raw:
            continue

        try:

            data = json.loads(
                raw.strip()
            )

        except Exception:

            # Some websites have invalid JSON-LD
            continue

        objects = []

        if isinstance(data, list):

            objects.extend(data)

        elif isinstance(data, dict):

            objects.append(data)

            graph = data.get(
                "@graph"
            )

            if isinstance(
                graph,
                list
            ):

                objects.extend(
                    graph
                )

        for obj in objects:

            if not isinstance(
                obj,
                dict
            ):
                continue

            obj_type = str(
                obj.get(
                    "@type",
                    ""
                )
            ).lower()

            is_article = (
                "article" in obj_type
                or
                "newsarticle" in obj_type
                or
                "report" in obj_type
            )

            if not is_article:
                continue

            body = obj.get(
                "articleBody"
            )

            if not body:
                continue

            body = normalize_text(
                body
            )

            if len(body) >= MIN_CONTENT_CHARS:

                return body

    return ""


# =============================================================
# 6. ITEMPROP ARTICLE BODY
# =============================================================

def extract_itemprop_article(
    soup
):

    candidates = []

    selectors = [

        "[itemprop='articleBody']",

        "[itemprop='articleBody'] p",

        "[property='articleBody']"
    ]

    for selector in selectors:

        try:

            nodes = soup.select(
                selector
            )

        except Exception:

            continue

        for node in nodes:

            text = normalize_text(
                node.get_text(
                    " ",
                    strip=True
                )
            )

            if len(text) >= 200:

                candidates.append(
                    text
                )

    if not candidates:
        return ""

    return max(
        candidates,
        key=len
    )


# =============================================================
# 7. CONTAINER TEXT
# =============================================================

def extract_container_text(
    container
):

    if not container:
        return ""

    paragraphs = []

    # ---------------------------------------------------------
    # Normal paragraphs
    # ---------------------------------------------------------

    for p in container.find_all(
        "p"
    ):

        text = normalize_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(text) < MIN_PARAGRAPH_CHARS:
            continue

        if is_noise_text(text):
            continue

        paragraphs.append(
            text
        )

    paragraphs = remove_duplicate_paragraphs(
        paragraphs
    )

    # ---------------------------------------------------------
    # If <p> weak, inspect blocks
    # ---------------------------------------------------------

    if len(paragraphs) < 2:

        for node in container.find_all(
            [
                "div",
                "section",
                "span"
            ]
        ):

            # Avoid parent nodes containing
            # dozens of paragraphs
            if len(
                node.find_all("p")
            ) > 3:
                continue

            text = normalize_text(
                node.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                60 <= len(text) <= 1500
                and
                not is_noise_text(text)
            ):

                paragraphs.append(
                    text
                )

    paragraphs = remove_duplicate_paragraphs(
        paragraphs
    )

    return " ".join(
        paragraphs
    )


# =============================================================
# 8. ARTICLE TEXT SCORING
# =============================================================

def score_article_text(
    text
):

    if not text:
        return -999

    text = normalize_text(
        text
    )

    length = len(text)

    if length < 150:
        return -999

    words = text.split()

    score = 0

    # ---------------------------------------------------------
    # Length
    # ---------------------------------------------------------

    if length >= 250:
        score += 20

    if length >= 500:
        score += 25

    if length >= 1000:
        score += 25

    if length >= 2000:
        score += 20

    if length >= 4000:
        score += 15

    # ---------------------------------------------------------
    # Word count
    # ---------------------------------------------------------

    if len(words) >= 100:
        score += 10

    if len(words) >= 200:
        score += 10

    # ---------------------------------------------------------
    # Sentence count
    # ---------------------------------------------------------

    sentence_count = len(
        re.findall(
            r"[.!?।]",
            text
        )
    )

    if sentence_count >= 5:
        score += 15

    if sentence_count >= 10:
        score += 15

    # ---------------------------------------------------------
    # Article language indicators
    # ---------------------------------------------------------

    article_signals = [

        "according to",
        "said",
        "said that",
        "government",
        "officials",
        "official",
        "police",
        "minister",
        "court",
        "report",
        "reported",
        "sources",
        "statement",
        "on sunday",
        "on saturday",
        "on friday",
        "new delhi",
        "bengaluru",
        "mumbai",
        "patna",
        "india"
    ]

    low = text.lower()

    for signal in article_signals:

        if signal in low:

            score += 2

    # ---------------------------------------------------------
    # Noise penalty
    # ---------------------------------------------------------

    for noise in [

        "subscribe now",
        "privacy policy",
        "terms of use",
        "download our app",
        "follow us on",
        "advertisement",
        "related stories"
    ]:

        if noise in low:

            score -= 15

    return score


# =============================================================
# 9. FIND BEST ARTICLE CONTAINER
# =============================================================

def find_best_article_container(
    soup
):

    candidates = []

    nodes = soup.find_all(
        [
            "article",
            "main",
            "section",
            "div"
        ]
    )

    for node in nodes:

        p_count = len(
            node.find_all("p")
        )

        if p_count < 2:
            continue

        text = extract_container_text(
            node
        )

        if len(text) < 200:
            continue

        score = score_article_text(
            text
        )

        identity = (

            " ".join(
                node.get(
                    "class",
                    []
                )
            )

            + " "

            + str(
                node.get(
                    "id",
                    ""
                )
            )

        ).lower()

        # -----------------------------------------------------
        # Positive semantic names
        # -----------------------------------------------------

        positive = [

            "article",
            "story",
            "content",
            "body",
            "news",
            "detail",
            "post",
            "release",
            "text"
        ]

        for word in positive:

            if word in identity:

                score += 35

        # -----------------------------------------------------
        # Negative semantic names
        # -----------------------------------------------------

        negative = [

            "sidebar",
            "related",
            "recommend",
            "footer",
            "header",
            "comment",
            "social",
            "advert",
            "navigation",
            "menu"
        ]

        for word in negative:

            if word in identity:

                score -= 50

        # -----------------------------------------------------
        # Paragraph density
        # -----------------------------------------------------

        score += min(
            p_count * 5,
            50
        )

        candidates.append(
            (
                score,
                len(text),
                text
            )
        )

    if not candidates:
        return ""

    candidates.sort(
        key=lambda x: (
            x[0],
            x[1]
        ),
        reverse=True
    )

    return candidates[0][2]


# =============================================================
# 10. PARAGRAPH CLUSTER EXTRACTION
# =============================================================

def extract_paragraph_clusters(
    soup
):

    paragraphs = []

    for p in soup.find_all(
        "p"
    ):

        text = normalize_text(
            p.get_text(
                " ",
                strip=True
            )
        )

        if len(text) < MIN_PARAGRAPH_CHARS:
            continue

        if is_noise_text(text):
            continue

        if len(text.split()) < 7:
            continue

        paragraphs.append(
            text
        )

    paragraphs = remove_duplicate_paragraphs(
        paragraphs
    )

    if len(paragraphs) < 2:
        return []

    clusters = []

    # ---------------------------------------------------------
    # Consecutive paragraphs
    # ---------------------------------------------------------

    current = []

    for text in paragraphs:

        if len(text) >= 45:

            current.append(
                text
            )

        else:

            if len(current) >= 2:

                clusters.append(
                    " ".join(current)
                )

            current = []

    if len(current) >= 2:

        clusters.append(
            " ".join(current)
        )

    # ---------------------------------------------------------
    # Sliding windows
    # ---------------------------------------------------------

    window_sizes = [
        3,
        5,
        8,
        12
    ]

    for size in window_sizes:

        if len(paragraphs) < size:
            continue

        for i in range(
            len(paragraphs) - size + 1
        ):

            combined = " ".join(
                paragraphs[
                    i:i + size
                ]
            )

            if len(combined) >= 500:

                clusters.append(
                    combined
                )

    return clusters


def best_paragraph_cluster(
    soup
):

    clusters = extract_paragraph_clusters(
        soup
    )

    if not clusters:
        return ""

    scored = []

    for text in clusters:

        score = score_article_text(
            text
        )

        if score > 0:

            scored.append(
                (
                    score,
                    len(text),
                    text
                )
            )

    if not scored:
        return ""

    scored.sort(
        key=lambda x: (
            x[0],
            x[1]
        ),
        reverse=True
    )

    return scored[0][2]


# =============================================================
# 11. MASTER HTML ARTICLE EXTRACTOR
# =============================================================

def extract_article_from_html(
    html
):

    if not html:
        return ""

    try:

        soup = BeautifulSoup(
            html,
            "html.parser"
        )

        # -----------------------------------------------------
        # METHOD 1 — JSON-LD
        # -----------------------------------------------------

        jsonld_text = extract_jsonld_article(
            soup
        )

        if len(jsonld_text) >= MIN_GOOD_CONTENT_CHARS:

            print(
                f"      🟢 JSON-LD: "
                f"{len(jsonld_text)} chars"
            )

            return jsonld_text[
                :MAX_ARTICLE_CHARS
            ]

        # -----------------------------------------------------
        # Remove noise
        # -----------------------------------------------------

        remove_noise(
            soup
        )

        # -----------------------------------------------------
        # METHOD 2 — itemprop articleBody
        # -----------------------------------------------------

        itemprop_text = extract_itemprop_article(
            soup
        )

        if len(itemprop_text) >= MIN_GOOD_CONTENT_CHARS:

            print(
                f"      🟢 itemprop articleBody: "
                f"{len(itemprop_text)} chars"
            )

            return itemprop_text[
                :MAX_ARTICLE_CHARS
            ]

        # -----------------------------------------------------
        # METHOD 3 — semantic selectors
        # -----------------------------------------------------

        selectors = [

            "article",

            "main",

            ".article-body",
            ".article-content",
            ".article-body-content",
            ".article-content-body",

            ".articleBody",
            ".articleContent",

            ".story-body",
            ".story-content",
            ".story-body-content",

            ".story-element",
            ".story-elements",

            ".content-body",
            ".content-body-content",

            ".full-details",
            ".full-detail",

            ".article-detail",
            ".article-details",

            ".article-text",
            ".story-text",

            ".news-content",
            ".news-detail",
            ".news-details",

            ".post-content",
            ".post-body",
            ".entry-content",

            ".innercontent",
            ".inner-content",

            "[class*='article']",
            "[class*='story']",
            "[class*='content']",
            "[class*='body']",
            "[class*='news']",
            "[class*='detail']"
        ]

        selector_candidates = []

        for selector in selectors:

            try:

                nodes = soup.select(
                    selector
                )

            except Exception:

                continue

            for node in nodes:

                text = extract_container_text(
                    node
                )

                if len(text) < 200:
                    continue

                score = score_article_text(
                    text
                )

                identity = (

                    " ".join(
                        node.get(
                            "class",
                            []
                        )
                    )

                    + " "

                    + str(
                        node.get(
                            "id",
                            ""
                        )
                    )

                ).lower()

                if (
                    "article" in identity
                    or
                    "story" in identity
                    or
                    "content" in identity
                    or
                    "body" in identity
                ):

                    score += 50

                selector_candidates.append(
                    (
                        score,
                        len(text),
                        text
                    )
                )

        if selector_candidates:

            selector_candidates.sort(
                key=lambda x: (
                    x[0],
                    x[1]
                ),
                reverse=True
            )

            best = selector_candidates[
                0
            ][2]

            if len(best) >= MIN_GOOD_CONTENT_CHARS:

                print(
                    f"      🟢 Selector: "
                    f"{len(best)} chars | "
                    f"score={selector_candidates[0][0]}"
                )

                return best[
                    :MAX_ARTICLE_CHARS
                ]

        # -----------------------------------------------------
        # METHOD 4 — best container
        # -----------------------------------------------------

        container_text = (
            find_best_article_container(
                soup
            )
        )

        if len(container_text) >= MIN_GOOD_CONTENT_CHARS:

            print(
                f"      🟢 Container: "
                f"{len(container_text)} chars"
            )

            return container_text[
                :MAX_ARTICLE_CHARS
            ]

        # -----------------------------------------------------
        # METHOD 5 — paragraph cluster
        # -----------------------------------------------------

        cluster_text = (
            best_paragraph_cluster(
                soup
            )
        )

        if len(cluster_text) >= MIN_GOOD_CONTENT_CHARS:

            print(
                f"      🟢 Paragraph cluster: "
                f"{len(cluster_text)} chars"
            )

            return cluster_text[
                :MAX_ARTICLE_CHARS
            ]

        # -----------------------------------------------------
        # METHOD 6 — global paragraphs
        # -----------------------------------------------------

        paragraphs = []

        for p in soup.find_all(
            "p"
        ):

            text = normalize_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )

            if (
                len(text) >= MIN_PARAGRAPH_CHARS
                and
                not is_noise_text(text)
            ):

                paragraphs.append(
                    text
                )

        paragraphs = remove_duplicate_paragraphs(
            paragraphs
        )

        if paragraphs:

            final_text = " ".join(
                paragraphs
            )

            if len(final_text) >= MIN_GOOD_CONTENT_CHARS:

                print(
                    f"      🟡 Global P: "
                    f"{len(final_text)} chars"
                )

                return final_text[
                    :MAX_ARTICLE_CHARS
                ]

        print(
            "      ❌ No article content found"
        )

        return ""

    except Exception as e:

        print(
            f"      ⚠️ HTML extraction error: "
            f"{str(e)[:150]}"
        )

        return ""


# =============================================================
# 12. GENERIC ARTICLE FETCHER
# =============================================================

def fetch_generic_article_content(
    article_url
):

    if not article_url:
        return ""

    if not isinstance(
        article_url,
        str
    ):
        return ""

    if not article_url.startswith(
        "http"
    ):
        return ""

    if (
        "news.google.com"
        in article_url.lower()
    ):
        return ""

    print(
        f"\n   🔎 ARTICLE: "
        f"{article_url[:120]}"
    )

    # =========================================================
    # ATTEMPT 1 — DIRECT HTML
    # =========================================================

    content = safe_fetch(
        article_url,
        timeout=15,
        use_scrapingant=False
    )

    if content:

        print(
            f"   📄 Direct HTML: "
            f"{len(content)} bytes"
        )

        extracted = (
            extract_article_from_html(
                content
            )
        )

        if len(extracted) >= MIN_GOOD_CONTENT_CHARS:

            print(
                f"   ✅ DIRECT SUCCESS: "
                f"{len(extracted)} chars"
            )

            return extracted

        print(
            "   ⚠️ Direct HTML received "
            "but article extraction weak."
        )

    # =========================================================
    # ATTEMPT 2 — SCRAPINGANT NORMAL
    # =========================================================

    if SCRAPINGANT_KEY:

        content = safe_fetch(
            article_url,
            timeout=40,
            use_scrapingant=True,
            browser=False
        )

        if content:

            print(
                f"   📄 ScrapingAnt HTML: "
                f"{len(content)} bytes"
            )

            extracted = (
                extract_article_from_html(
                    content
                )
            )

            if len(extracted) >= MIN_GOOD_CONTENT_CHARS:

                print(
                    f"   ✅ SCRAPINGANT SUCCESS: "
                    f"{len(extracted)} chars"
                )

                return extracted

    # =========================================================
    # ATTEMPT 3 — SCRAPINGANT BROWSER
    # =========================================================

    if SCRAPINGANT_KEY:

        print(
            "   🌐 Trying browser-rendered "
            "ScrapingAnt..."
        )

        content = safe_fetch(
            article_url,
            timeout=50,
            use_scrapingant=True,
            browser=True
        )

        if content:

            print(
                f"   📄 Browser HTML: "
                f"{len(content)} bytes"
            )

            extracted = (
                extract_article_from_html(
                    content
                )
            )

            if len(extracted) >= MIN_GOOD_CONTENT_CHARS:

                print(
                    f"   ✅ BROWSER SUCCESS: "
                    f"{len(extracted)} chars"
                )

                return extracted

    # =========================================================
    # FAILED
    # =========================================================

    print(
        "   ❌ ALL ARTICLE EXTRACTION "
        "METHODS FAILED"
    )

    return ""


# =============================================================
# 13. PIB DEEP CONTENT
# =============================================================

def fetch_deep_pib_content(
    article_url
):

    if not article_url:
        return ""

    if not isinstance(
        article_url,
        str
    ):
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

    print(
        f"\n   🇮🇳 PIB: "
        f"{target_url}"
    )

    # Direct first

    content = safe_fetch(
        target_url,
        timeout=15,
        use_scrapingant=False
    )

    # ScrapingAnt fallback

    if not content and SCRAPINGANT_KEY:

        content = safe_fetch(
            target_url,
            timeout=40,
            use_scrapingant=True,
            browser=True
        )

    if not content:
        return ""

    try:

        soup = BeautifulSoup(
            content,
            "html.parser"
        )

        remove_noise(
            soup
        )

        # PIB known containers

        candidates = []

        selectors = [

            "#ContentPlaceHolder1_divpri",
            "#divpri",

            ".ReleaseIdText",
            ".innercontent",
            ".release_text",

            "[id*='divpri']",
            "[class*='release']",
            "[class*='Release']"
        ]

        for selector in selectors:

            try:

                nodes = soup.select(
                    selector
                )

            except Exception:

                continue

            for node in nodes:

                text = extract_container_text(
                    node
                )

                if len(text) >= 150:

                    candidates.append(
                        text
                    )

        if candidates:

            result = max(
                candidates,
                key=len
            )

            print(
                f"   ✅ PIB container: "
                f"{len(result)} chars"
            )

            return result[
                :MAX_ARTICLE_CHARS
            ]

        # Generic fallback

        result = (
            extract_article_from_html(
                content
            )
        )

        if result:

            print(
                f"   ✅ PIB generic: "
                f"{len(result)} chars"
            )

            return result[
                :MAX_ARTICLE_CHARS
            ]

    except Exception as e:

        print(
            f"   ⚠️ PIB parsing error: "
            f"{str(e)[:150]}"
        )

    return ""


# =============================================================
# 14. RSS HELPERS
# =============================================================

def get_rss_text(
    item,
    tag
):

    node = item.find(
        tag
    )

    if node is None:
        return ""

    return clean_cdata_and_html(
        node.get_text(
            " ",
            strip=True
        )
    )


# =============================================================
# 15. DEDUPLICATION
# =============================================================

def remove_duplicate_news(
    news_list
):

    seen_titles = set()

    unique_news = []

    dropped_count = 0

    for news in news_list:

        title_match = re.search(
            r"Title:\s*(.*?)\s*\|\s*Article Content:",
            news,
            re.IGNORECASE
        )

        if title_match:

            title = title_match.group(1)

        else:

            title = news

        clean_title = normalize_text(
            title
        ).lower()

        clean_title = re.sub(
            r"[^a-z0-9]+",
            "",
            clean_title
        )

        if not clean_title:
            continue

        # First 100 chars enough for
        # near duplicate headlines

        key = clean_title[:100]

        if key not in seen_titles:

            seen_titles.add(
                key
            )

            unique_news.append(
                news
            )

        else:

            dropped_count += 1

    print(
        f"🧹 Deduplication: "
        f"Input={len(news_list)} | "
        f"Dropped={dropped_count} | "
        f"Unique={len(unique_news)}"
    )

    return unique_news


# =============================================================
# 16. MAIN SCRAPER
# =============================================================

def run_scraper():

    target_dt, date_str, key_str = (
        get_yesterday_info()
    )

    print(
        "\n"
        "====================================================\n"
        "🚀 DEEP NEWS SCRAPER STARTED\n"
        f"📅 Target Date: {date_str}\n"
        "====================================================\n"
    )

    bihar_items = []

    national_items = []

    source_stats = {}

    # =========================================================
    # A. PIB
    # =========================================================

    print(
        "\n🇮🇳 SCRAPING PIB CENTRAL..."
    )

    pib_count = 0

    pib_rss_url = (
        "https://www.pib.gov.in/"
        "RssMain.aspx?Mod=1&Lang=1"
    )

    pib_content = safe_fetch(
        pib_rss_url,
        timeout=20,
        use_scrapingant=True,
        browser=False
    )

    if pib_content:

        try:

            soup = BeautifulSoup(
                pib_content,
                "xml"
            )

            items = soup.find_all(
                "item"
            )

            print(
                f"   PIB RSS items: "
                f"{len(items)}"
            )

            for item in items[:20]:

                title = get_rss_text(
                    item,
                    "title"
                )

                link = get_rss_text(
                    item,
                    "link"
                )

                pub_date = get_rss_text(
                    item,
                    "pubDate"
                )

                if not title:
                    continue

                if not is_yesterday_news(
                    pub_date,
                    target_dt
                ):
                    continue

                deep_text = ""

                if link:

                    deep_text = (
                        fetch_deep_pib_content(
                            link
                        )
                    )

                if len(deep_text) >= 120:

                    content_to_use = (
                        deep_text
                    )

                    print(
                        f"   ✅ PIB: "
                        f"{title[:55]} | "
                        f"{len(deep_text)} chars"
                    )

                else:

                    desc = get_rss_text(
                        item,
                        "description"
                    )

                    content_to_use = (
                        desc
                        if desc
                        else title
                    )

                    print(
                        f"   ⚠️ PIB RSS fallback: "
                        f"{title[:55]}"
                    )

                national_items.append(
                    f"[Source: PIB Central] "
                    f"Title: {title} | "
                    f"Article Content: "
                    f"{content_to_use}"
                )

                pib_count += 1

                if pib_count >= 10:
                    break

        except Exception as e:

            print(
                f"❌ PIB RSS Error: {e}"
            )

    source_stats[
        "PIB Central"
    ] = pib_count

    # =========================================================
    # B. THE HINDU
    # =========================================================

    print(
        "\n📰 SCRAPING THE HINDU..."
    )

    hindu_count = 0

    hindu_rss = (
        "https://www.thehindu.com/"
        "news/national/feeder/default.rss"
    )

    content = safe_fetch(
        hindu_rss,
        timeout=20,
        use_scrapingant=True
    )

    if content:

        try:

            soup = BeautifulSoup(
                content,
                "xml"
            )

            items = soup.find_all(
                "item"
            )

            print(
                f"   Hindu RSS items: "
                f"{len(items)}"
            )

            for item in items[:20]:

                title = get_rss_text(
                    item,
                    "title"
                )

                link = get_rss_text(
                    item,
                    "link"
                )

                pub_date = get_rss_text(
                    item,
                    "pubDate"
                )

                desc = get_rss_text(
                    item,
                    "description"
                )

                if not title:
                    continue

                if not is_yesterday_news(
                    pub_date,
                    target_dt
                ):
                    continue

                deep_text = ""

                if link:

                    deep_text = (
                        fetch_generic_article_content(
                            link
                        )
                    )

                if len(deep_text) >= 200:

                    final_content = (
                        deep_text
                    )

                    print(
                        f"   ✅ Hindu: "
                        f"{title[:55]} | "
                        f"{len(deep_text)} chars"
                    )

                else:

                    final_content = (
                        desc
                        if desc
                        else title
                    )

                    print(
                        f"   ⚠️ Hindu RSS fallback: "
                        f"{title[:55]}"
                    )

                national_items.append(
                    f"[Source: The Hindu] "
                    f"Title: {title} | "
                    f"Article Content: "
                    f"{final_content}"
                )

                hindu_count += 1

                if hindu_count >= 6:
                    break

        except Exception as e:

            print(
                f"⚠️ The Hindu Error: {e}"
            )

    source_stats[
        "The Hindu"
    ] = hindu_count

    # =========================================================
    # C. INDIAN EXPRESS
    # =========================================================

    print(
        "\n📰 SCRAPING INDIAN EXPRESS..."
    )

    ie_count = 0

    ie_rss = (
        "https://indianexpress.com/"
        "section/india/feed/"
    )

    content = safe_fetch(
        ie_rss,
        timeout=20,
        use_scrapingant=True
    )

    if content:

        try:

            soup = BeautifulSoup(
                content,
                "xml"
            )

            items = soup.find_all(
                "item"
            )

            print(
                f"   Indian Express RSS items: "
                f"{len(items)}"
            )

            for item in items[:20]:

                title = get_rss_text(
                    item,
                    "title"
                )

                link = get_rss_text(
                    item,
                    "link"
                )

                pub_date = get_rss_text(
                    item,
                    "pubDate"
                )

                desc = get_rss_text(
                    item,
                    "description"
                )

                if not title:
                    continue

                if not is_yesterday_news(
                    pub_date,
                    target_dt
                ):
                    continue

                deep_text = ""

                if link:

                    deep_text = (
                        fetch_generic_article_content(
                            link
                        )
                    )

                if len(deep_text) >= 200:

                    final_content = (
                        deep_text
                    )

                    print(
                        f"   ✅ IE: "
                        f"{title[:55]} | "
                        f"{len(deep_text)} chars"
                    )

                else:

                    final_content = (
                        desc
                        if desc
                        else title
                    )

                    print(
                        f"   ⚠️ IE RSS fallback: "
                        f"{title[:55]}"
                    )

                national_items.append(
                    f"[Source: Indian Express] "
                    f"Title: {title} | "
                    f"Article Content: "
                    f"{final_content}"
                )

                ie_count += 1

                if ie_count >= 6:
                    break

        except Exception as e:

            print(
                f"⚠️ Indian Express Error: {e}"
            )

    source_stats[
        "Indian Express"
    ] = ie_count

    # =========================================================
    # D. GOOGLE NEWS BIHAR
    # =========================================================

    print(
        "\n📍 SCRAPING GOOGLE NEWS BIHAR..."
    )

    g_url = (
        "https://news.google.com/rss/search?"
        "q=Bihar+Government+Schemes+OR+"
        "Infrastructure+OR+Economy+when:2d"
        "&hl=hi"
        "&gl=IN"
        "&ceid=IN:hi"
    )

    content = safe_fetch(
        g_url,
        timeout=20,
        use_scrapingant=False
    )

    g_bihar_count = 0

    if content:

        try:

            root = ET.fromstring(
                content
            )

            items = root.findall(
                ".//item"
            )

            print(
                f"   Google RSS items: "
                f"{len(items)}"
            )

            for item in items[:20]:

                title_node = item.find(
                    "title"
                )

                pub_node = item.find(
                    "pubDate"
                )

                desc_node = item.find(
                    "description"
                )

                link_node = item.find(
                    "link"
                )

                title = (
                    clean_cdata_and_html(
                        title_node.text
                    )
                    if title_node is not None
                    else ""
                )

                pub_date = (
                    clean_cdata_and_html(
                        pub_node.text
                    )
                    if pub_node is not None
                    else ""
                )

                desc = (
                    clean_cdata_and_html(
                        desc_node.text
                    )
                    if desc_node is not None
                    else ""
                )

                link = (
                    link_node.text.strip()
                    if link_node is not None
                    and link_node.text
                    else ""
                )

                if not title:
                    continue

                if not is_yesterday_news(
                    pub_date,
                    target_dt
                ):
                    continue

                # Google News RSS usually gives
                # a Google redirect link.
                # Don't send that to generic scraper.

                final_content = desc

                bihar_items.append(
                    f"[Source: Google News Bihar] "
                    f"Title: {title} | "
                    f"Article Content: "
                    f"{final_content}"
                )

                g_bihar_count += 1

                if g_bihar_count >= 8:
                    break

        except Exception as e:

            print(
                f"⚠️ Google News Bihar Error: {e}"
            )

    source_stats[
        "Google News Bihar"
    ] = g_bihar_count

    # =========================================================
    # E. CMO BIHAR
    # =========================================================

    print(
        "\n🏛️ SCRAPING CMO BIHAR..."
    )

    cmo_count = 0

    cmo_url = (
        "https://cm.bihar.gov.in/"
        "users/preessrelease.aspx"
    )

    content = safe_fetch(
        cmo_url,
        timeout=20,
        use_scrapingant=True
    )

    if content:

        try:

            soup = BeautifulSoup(
                content,
                "html.parser"
            )

            rows = soup.find_all(
                "tr"
            )

            for row in rows:

                cols = row.find_all(
                    "td"
                )

                if len(cols) < 2:
                    continue

                title = normalize_text(
                    cols[1].get_text(
                        " ",
                        strip=True
                    )
                )

                if (
                    title
                    and
                    len(title) > 10
                ):

                    bihar_items.append(
                        f"[Source: CMO Bihar] "
                        f"Title: {title} | "
                        f"Article Content: "
                        f"{title}"
                    )

                    cmo_count += 1

                if cmo_count >= 8:
                    break

        except Exception as e:

            print(
                f"⚠️ CMO Bihar Error: {e}"
            )

    source_stats[
        "CMO Bihar"
    ] = cmo_count

    # =========================================================
    # DEDUPLICATION
    # =========================================================

    bihar_clean = (
        remove_duplicate_news(
            bihar_items
        )
    )

    national_clean = (
        remove_duplicate_news(
            national_items
        )
    )

    # =========================================================
    # SUMMARY
    # =========================================================

    print(
        "\n"
        "===================================================="
    )

    print(
        "📊 RAW SCRAPING SUMMARY"
    )

    print(
        "===================================================="
    )

    print(
        json.dumps(
            source_stats,
            indent=2,
            ensure_ascii=False
        )
    )

    print(
        f"\n🇮🇳 National: "
        f"{len(national_clean)}"
    )

    print(
        f"📍 Bihar: "
        f"{len(bihar_clean)}"
    )

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

    print(
        "\n💾 rawnews.json updated successfully!"
    )

    print(
        "====================================================\n"
    )


# =============================================================
# ENTRY POINT
# =============================================================

if __name__ == "__main__":

    run_scraper()
