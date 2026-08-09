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

# Disable insecure request warnings

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

SCRAPINGANT_KEY = os.environ.get("SCRAPINGANT_API_KEY")

MAX_ARTICLE_CHARS = 10000
MIN_CONTENT_CHARS = 150
MIN_PARAGRAPH_CHARS = 35

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

```
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
    val = int(relative_match.group(1))
    unit = relative_match.group(2)

    if "day" in unit:
        return now - timedelta(days=val)

    if "hour" in unit or "hr" in unit:
        return now - timedelta(hours=val)

    if "min" in unit:
        return now - timedelta(minutes=val)

if date_str.isdigit():
    try:
        ts = int(date_str)

        if ts > 1e11:
            ts /= 1000

        return datetime.fromtimestamp(ts)

    except Exception:
        pass

try:
    pub_tuple = email.utils.parsedate_tz(date_str)

    if pub_tuple:
        return datetime.fromtimestamp(
            email.utils.mktime_tz(pub_tuple)
        )

except Exception:
    pass

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
```

def is_yesterday_news(pub_date_str, target_dt):
if not pub_date_str:
return True

```
pub_dt = parse_any_date(pub_date_str)

if pub_dt:
    start_window = target_dt - timedelta(days=3)
    end_window = target_dt + timedelta(days=1.5)

    return start_window <= pub_dt <= end_window

return True
```

# =============================================================

# 2. TEXT CLEANING

# =============================================================

def clean_cdata_and_html(text):
if not text:
return ""

```
text = str(text)

text = re.sub(
    r"\<!\[CDATA\[(.*?)\]\]>",
    r"\1",
    text,
    flags=re.DOTALL
)

soup = BeautifulSoup(text, "html.parser")

return " ".join(
    soup.get_text(" ", strip=True).split()
).strip()
```

def normalize_text(text):
if not text:
return ""

```
text = BeautifulSoup(
    str(text),
    "html.parser"
).get_text(" ", strip=True)

text = re.sub(r"\s+", " ", text)

return text.strip()
```

# =============================================================

# 3. SAFE FETCHER

# =============================================================

def safe_fetch(url, timeout=12):

```
if not url:
    return None

headers = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36",

    "Accept":
        "text/html,application/xhtml+xml,application/xml;"
        "q=0.9,*/*;q=0.8",

    "Accept-Language":
        "en-US,en;q=0.9,hi;q=0.8"
}

try:

    res = requests.get(
        url,
        impersonate="chrome",
        headers=headers,
        timeout=timeout,
        verify=False
    )

    if res.status_code == 200:
        return res.content

except Exception as e:

    print(
        f"⚠️ Direct fetch failed: "
        f"{url[:80]} | {e}"
    )

# ---------------------------------------------------------
# ScrapingAnt fallback
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
            timeout=20
        )

        if sa_res.status_code == 200:
            return sa_res.content

    except Exception as e:

        print(
            f"❌ ScrapingAnt failed: {e}"
        )

return None
```

# =============================================================

# 4. JSON-LD ARTICLE EXTRACTION

# =============================================================

def extract_jsonld_article(soup):

```
for script in soup.find_all(
    "script",
    type="application/ld+json"
):

    raw = script.string or script.get_text()

    if not raw:
        continue

    try:

        data = json.loads(
            raw.strip()
        )

        objects = (
            data
            if isinstance(data, list)
            else [data]
        )

        if (
            isinstance(data, dict)
            and isinstance(
                data.get("@graph"),
                list
            )
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

                if (
                    body
                    and len(body) >= MIN_CONTENT_CHARS
                ):

                    return normalize_text(
                        body
                    )

    except Exception:
        continue

return ""
```

# =============================================================

# 5. GENERIC ARTICLE SCRAPER

# =============================================================

def fetch_generic_article_content(article_url):

```
if (
    not article_url
    or not isinstance(article_url, str)
):
    return ""

if "news.google.com" in article_url:
    return ""

content = safe_fetch(
    article_url,
    timeout=10
)

if not content:
    return ""

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    # -----------------------------------------------------
    # JSON-LD first
    # -----------------------------------------------------

    jsonld_text = extract_jsonld_article(
        soup
    )

    if len(jsonld_text) >= 250:
        return jsonld_text[:MAX_ARTICLE_CHARS]

    # -----------------------------------------------------
    # Remove noise
    # -----------------------------------------------------

    for noise in soup.select(
        "script, style, nav, footer, header, "
        "form, iframe, .advertisement, "
        ".ads, .social-share"
    ):
        noise.decompose()

    # -----------------------------------------------------
    # Common article containers
    # -----------------------------------------------------

    content_div = (
        soup.find(class_="article-body")
        or soup.find(id="content-body")
        or soup.find(class_="story-element")
        or soup.find(class_="full-details")
        or soup.find(class_="article-content")
        or soup.find(class_="story-content")
        or soup.find(class_="articleBody")
        or soup.find(class_="story-body")
    )

    if content_div:

        elements = content_div.find_all(
            ["p", "li"]
        )

    else:

        elements = soup.find_all("p")

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

    return result[:MAX_ARTICLE_CHARS]

except Exception:
    return ""
```

# =============================================================

# 6. PIB DEEP SCRAPER

# =============================================================

def fetch_deep_pib_content(article_url):

```
if (
    not article_url
    or not isinstance(article_url, str)
):
    return ""

prid_match = re.search(
    r"PRID=(\d+)",
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

else:

    target_url = article_url

content = safe_fetch(
    target_url,
    timeout=12
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
        "header, form, .release_back, "
        ".share-box, .social"
    ):
        noise.decompose()

    content_div = (
        soup.find(
            id="ContentPlaceHolder1_divpri"
        )
        or soup.find(id="divpri")
        or soup.find(class_="ReleaseIdText")
        or soup.find(class_="innercontent")
        or soup.find(class_="release_text")
    )

    if content_div:

        elements = content_div.find_all(
            ["p", "tr", "li"]
        )

        text_blocks = []

        for el in elements:

            text = normalize_text(
                el.get_text(
                    " ",
                    strip=True
                )
            )

            if len(text) > MIN_PARAGRAPH_CHARS:
                text_blocks.append(text)

        full_text = " ".join(
            text_blocks
        )

    else:

        paragraphs = soup.find_all("p")

        full_text = " ".join(
            normalize_text(
                p.get_text(
                    " ",
                    strip=True
                )
            )
            for p in paragraphs
            if len(
                normalize_text(
                    p.get_text(
                        " ",
                        strip=True
                    )
                )
            ) > MIN_PARAGRAPH_CHARS
        )

    result = normalize_text(
        full_text
    )

    return result[:MAX_ARTICLE_CHARS]

except Exception as e:

    print(
        f"⚠️ PIB parsing error: {e}"
    )

    return ""
```

# =============================================================

# 7. GENERIC PAGE / LISTING HELPERS

# =============================================================

def is_generic_bihar_portal_text(text):

```
if not text:
    return True

text_lower = text.lower()

bad_patterns = [
    "web information manager",
    "copyright iprd",
    "content managed by information",
    "department of revenue & land reform",
    "office of the chief electoral officer",
    "bihar is located in the eastern part",
    "we have tried to put most accurate",
    "feedback.commonportal",
    "help web information manager",
    "cabinet secretariat department is an important department"
]

matches = sum(
    1
    for p in bad_patterns
    if p in text_lower
)

return matches >= 2
```

def is_valid_article_content(text):

```
if not text:
    return False

text = normalize_text(text)

if len(text) < MIN_CONTENT_CHARS:
    return False

if is_generic_bihar_portal_text(text):
    return False

return True
```

def absolute_url(base_url, link):

```
if not link:
    return ""

link = str(link).strip()

if link.startswith("#"):
    return ""

return urllib.parse.urljoin(
    base_url,
    link
)
```

def extract_links_from_page(
page_url,
html_content
):

```
links = []

if not html_content:
    return links

try:

    soup = BeautifulSoup(
        html_content,
        "html.parser"
    )

    for a in soup.find_all("a"):

        href = a.get("href")

        if not href:
            continue

        title = normalize_text(
            a.get_text(
                " ",
                strip=True
            )
        )

        url = absolute_url(
            page_url,
            href
        )

        if not url:
            continue

        links.append({
            "title": title,
            "url": url
        })

except Exception:
    pass

return links
```

# =============================================================

# 8. IPRD BIHAR

# =============================================================

IPRD_BASE = (
"https://state.bihar.gov.in/prdbihar/"
)

IPRD_2026_PAGE = (
"https://state.bihar.gov.in/"
"prdbihar/SectionInformation.html"
"?editForm&rowId=8931"
)

def is_iprd_2026_listing_title(title):

```
if not title:
    return False

t = normalize_text(title).lower()

# Only current IPRD 2026 pages
if "2026" not in t:
    return False

allowed = [
    "press release",
    "press note",
    "press notes",
    "ipr",
    "release"
]

return any(
    x in t
    for x in allowed
)
```

def is_iprd_bad_link(title, url):

```
text = (
    normalize_text(title)
    + " "
    + str(url)
).lower()

bad_words = [
    "cabinet ministers",
    "cabinet secretariat",
    "phone directory",
    "old cabinet",
    "old press",
    "contact",
    "feedback",
    "login",
    "citizenhome",
    "sitemap"
]

return any(
    word in text
    for word in bad_words
)
```

def fetch_iprd_listing_links():

```
print(
    "🏛️ Fetching IPRD Bihar 2026 listing..."
)

content = safe_fetch(
    IPRD_2026_PAGE,
    timeout=15
)

if not content:
    print(
        "⚠️ IPRD listing fetch failed"
    )
    return []

links = extract_links_from_page(
    IPRD_2026_PAGE,
    content
)

valid = []
seen = set()

for item in links:

    title = item["title"]
    url = item["url"]

    if not title:
        continue

    if is_iprd_bad_link(
        title,
        url
    ):
        continue

    # Reject obvious navigation
    if len(title) < 15:
        continue

    # Only Bihar state portal links
    if "state.bihar.gov.in" not in url:
        continue

    key = (
        title.lower(),
        url.lower()
    )

    if key in seen:
        continue

    seen.add(key)

    valid.append(item)

print(
    f"  🔎 IPRD candidate links: "
    f"{len(valid)}"
)

return valid
```

def fetch_iprd_article(
title,
url
):

```
content = safe_fetch(
    url,
    timeout=12
)

if not content:
    return ""

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    # Remove portal-level noise
    for noise in soup.select(
        "script, style, nav, footer, "
        "header, form, iframe, "
        ".menu, .navbar, .footer"
    ):
        noise.decompose()

    # JSON-LD
    jsonld = extract_jsonld_article(
        soup
    )

    if is_valid_article_content(
        jsonld
    ):
        return jsonld[:MAX_ARTICLE_CHARS]

    # -----------------------------------------------------
    # Important:
    # Do NOT simply scrape every <p> from SectionInformation
    # because that produces the whole Bihar portal text.
    # -----------------------------------------------------

    selectors = [
        "#ContentPlaceHolder1_ContentPlaceHolder1_lblContent",
        "#ContentPlaceHolder1_lblContent",
        "#ContentPlaceHolder1_divContent",
        "#ContentPlaceHolder1_divpri",
        "#divpri",
        ".innercontent",
        ".release_text",
        ".pressrelease",
        ".press-release",
        ".news-content",
        ".content-area",
        ".article-content"
    ]

    content_div = None

    for selector in selectors:

        try:

            content_div = soup.select_one(
                selector
            )

            if content_div:
                break

        except Exception:
            pass

    if content_div:

        elements = content_div.find_all(
            ["p", "div", "li", "td"]
        )

    else:

        # More conservative fallback.
        # Never use entire page text.
        elements = soup.find_all(
            ["p", "td"]
        )

    blocks = []

    for el in elements:

        text = normalize_text(
            el.get_text(
                " ",
                strip=True
            )
        )

        if (
            len(text) >= MIN_PARAGRAPH_CHARS
            and not is_generic_bihar_portal_text(
                text
            )
        ):

            blocks.append(text)

    # Remove repeated blocks
    unique_blocks = []

    for block in blocks:

        if block not in unique_blocks:
            unique_blocks.append(block)

    result = normalize_text(
        " ".join(unique_blocks)
    )

    if is_valid_article_content(
        result
    ):

        return result[:MAX_ARTICLE_CHARS]

except Exception as e:

    print(
        f"⚠️ IPRD parsing error: "
        f"{title[:50]} | {e}"
    )

return ""
```

def scrape_iprd_bihar():

```
items = []

candidates = fetch_iprd_listing_links()

count = 0

for item in candidates[:30]:

    title = normalize_text(
        item["title"]
    )

    url = item["url"]

    # Reject obvious old-year links
    if re.search(
        r"\b(2023|2024|2025)\b",
        title
    ):
        continue

    print(
        f"  🔎 IPRD: {title[:70]}"
    )

    article_content = fetch_iprd_article(
        title,
        url
    )

    if not is_valid_article_content(
        article_content
    ):

        print(
            "     ❌ No valid article content"
        )

        continue

    # Try to identify date from page
    date_value = ""

    page_content = safe_fetch(
        url,
        timeout=10
    )

    if page_content:

        try:

            page_soup = BeautifulSoup(
                page_content,
                "html.parser"
            )

            page_text = normalize_text(
                page_soup.get_text(
                    " ",
                    strip=True
                )
            )

            date_match = re.search(
                r"\b\d{1,2}[-/ ]"
                r"(?:\d{1,2}|"
                r"Jan|Feb|Mar|Apr|May|Jun|"
                r"Jul|Aug|Sep|Oct|Nov|Dec)"
                r"[-/ ,]\d{2,4}\b",
                page_text,
                re.IGNORECASE
            )

            if date_match:
                date_value = (
                    date_match.group(0)
                )

        except Exception:
            pass

    items.append({
        "source": "IPRD Bihar",
        "title": title,
        "url": url,
        "date": date_value,
        "content": article_content,
        "content_chars": len(
            article_content
        ),
        "type": "Deep Scraped"
    })

    count += 1

    if count >= 8:
        break

    time.sleep(0.4)

print(
    f"  ✅ IPRD valid news: {count}"
)

return items
```

# =============================================================

# 9. CMO BIHAR

# =============================================================

CMO_URL = (
"https://cm.bihar.gov.in/"
"users/preessrelease.aspx"
)

def scrape_cmo_bihar():

```
items = []

print(
    "\n🏛️ Scraping CMO Bihar..."
)

content = safe_fetch(
    CMO_URL,
    timeout=15
)

if not content:
    print(
        "⚠️ CMO fetch failed"
    )
    return items

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    candidates = []

    for a in soup.find_all("a"):

        href = a.get("href")

        title = normalize_text(
            a.get_text(
                " ",
                strip=True
            )
        )

        if not href:
            continue

        if len(title) < 15:
            continue

        url = absolute_url(
            CMO_URL,
            href
        )

        if not url:
            continue

        candidates.append({
            "title": title,
            "url": url
        })

    # -----------------------------------------------------
    # If links are not available, inspect table rows
    # -----------------------------------------------------

    if not candidates:

        for row in soup.find_all("tr"):

            cols = row.find_all("td")

            if len(cols) < 2:
                continue

            title = normalize_text(
                cols[1].get_text(
                    " ",
                    strip=True
                )
            )

            if len(title) < 15:
                continue

            link = cols[1].find("a")

            if not link:
                continue

            href = link.get("href")

            url = absolute_url(
                CMO_URL,
                href
            )

            if url:

                candidates.append({
                    "title": title,
                    "url": url
                })

    seen = set()
    count = 0

    for item in candidates[:30]:

        title = item["title"]
        url = item["url"]

        key = url.lower()

        if key in seen:
            continue

        seen.add(key)

        # Ignore navigation pages
        bad = [
            "contact",
            "login",
            "about",
            "feedback",
            "sitemap",
            "directory"
        ]

        if any(
            b in (
                title + " " + url
            ).lower()
            for b in bad
        ):
            continue

        print(
            f"  🔎 CMO: {title[:70]}"
        )

        article_content = fetch_generic_article_content(
            url
        )

        # CMO may have ASP.NET structure.
        if not is_valid_article_content(
            article_content
        ):

            page = safe_fetch(
                url,
                timeout=12
            )

            if page:

                try:

                    psoup = BeautifulSoup(
                        page,
                        "html.parser"
                    )

                    for noise in psoup.select(
                        "script,style,nav,footer,"
                        "header,form,iframe"
                    ):
                        noise.decompose()

                    blocks = []

                    for p in psoup.find_all(
                        ["p", "td"]
                    ):

                        text = normalize_text(
                            p.get_text(
                                " ",
                                strip=True
                            )
                        )

                        if (
                            len(text)
                            >= MIN_PARAGRAPH_CHARS
                        ):
                            blocks.append(text)

                    candidate_text = normalize_text(
                        " ".join(blocks)
                    )

                    if is_valid_article_content(
                        candidate_text
                    ):
                        article_content = (
                            candidate_text
                        )

                except Exception:
                    pass

        if not is_valid_article_content(
            article_content
        ):

            print(
                "     ❌ CMO content not valid"
            )

            continue

        items.append({
            "source": "CMO Bihar",
            "title": title,
            "url": url,
            "date": "",
            "content": article_content,
            "content_chars": len(
                article_content
            ),
            "type": "Deep Scraped"
        })

        count += 1

        if count >= 8:
            break

        time.sleep(0.4)

except Exception as e:

    print(
        f"⚠️ CMO Bihar Error: {e}"
    )

print(
    f"  ✅ CMO valid news: {len(items)}"
)

return items
```

# =============================================================

# 10. BIHAR CABINET DECISIONS

# =============================================================

CABINET_URL = (
"https://state.bihar.gov.in/"
"csd/SectionInformation.html"
"?editForm&rowId=2929"
)

def is_bad_cabinet_link(title, url):

```
text = (
    normalize_text(title)
    + " "
    + str(url)
).lower()

bad_words = [
    "cabinet secretariat",
    "cabinet ministers",
    "phone directory",
    "old cabinet",
    "contact",
    "login",
    "citizenhome",
    "sitemap",
    "email",
    "mailto:"
]

return any(
    x in text
    for x in bad_words
)
```

def fetch_cabinet_article(
title,
url
):

```
content = safe_fetch(
    url,
    timeout=12
)

if not content:
    return ""

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    for noise in soup.select(
        "script,style,nav,footer,"
        "header,form,iframe"
    ):
        noise.decompose()

    jsonld = extract_jsonld_article(
        soup
    )

    if is_valid_article_content(
        jsonld
    ):
        return jsonld[:MAX_ARTICLE_CHARS]

    selectors = [
        "#ContentPlaceHolder1_divpri",
        "#divpri",
        ".innercontent",
        ".release_text",
        ".content-area",
        ".article-content",
        ".news-content"
    ]

    content_div = None

    for selector in selectors:

        try:

            content_div = soup.select_one(
                selector
            )

            if content_div:
                break

        except Exception:
            pass

    if content_div:

        elements = content_div.find_all(
            ["p", "div", "li", "td", "tr"]
        )

    else:

        elements = soup.find_all(
            ["p", "td"]
        )

    blocks = []

    for el in elements:

        text = normalize_text(
            el.get_text(
                " ",
                strip=True
            )
        )

        if len(text) >= MIN_PARAGRAPH_CHARS:

            if not is_generic_bihar_portal_text(
                text
            ):
                blocks.append(text)

    unique_blocks = []

    for block in blocks:

        if block not in unique_blocks:
            unique_blocks.append(block)

    result = normalize_text(
        " ".join(unique_blocks)
    )

    if is_valid_article_content(
        result
    ):

        return result[:MAX_ARTICLE_CHARS]

except Exception as e:

    print(
        f"⚠️ Cabinet parsing error: "
        f"{title[:50]} | {e}"
    )

return ""
```

def scrape_bihar_cabinet():

```
items = []

print(
    "\n🏛️ Scraping Bihar Cabinet Decisions..."
)

content = safe_fetch(
    CABINET_URL,
    timeout=15
)

if not content:
    print(
        "⚠️ Cabinet listing fetch failed"
    )
    return items

try:

    links = extract_links_from_page(
        CABINET_URL,
        content
    )

    candidates = []
    seen = set()

    for item in links:

        title = normalize_text(
            item["title"]
        )

        url = item["url"]

        if len(title) < 15:
            continue

        if is_bad_cabinet_link(
            title,
            url
        ):
            continue

        # Avoid generic portal pages
        if (
            "sectioninformation.html"
            in url.lower()
            and "rowid=" in url.lower()
        ):

            # Listing pages themselves should not
            # become news items.
            # Keep only if title looks like an
            # actual individual decision.
            generic_titles = [
                "cabinet decisions",
                "cabinet decision",
                "department cabinet decision",
                "old cabinet decisions",
                "cabinet secretariat department"
            ]

            if title.lower() in generic_titles:
                continue

        key = (
            title.lower(),
            url.lower()
        )

        if key in seen:
            continue

        seen.add(key)

        candidates.append(item)

    count = 0

    for item in candidates[:30]:

        title = item["title"]
        url = item["url"]

        print(
            f"  🔎 Cabinet: {title[:70]}"
        )

        article_content = fetch_cabinet_article(
            title,
            url
        )

        if not is_valid_article_content(
            article_content
        ):

            print(
                "     ❌ No valid cabinet content"
            )

            continue

        items.append({
            "source": "Bihar Cabinet Decision",
            "title": title,
            "url": url,
            "date": "",
            "content": article_content,
            "content_chars": len(
                article_content
            ),
            "type": "Deep Scraped"
        })

        count += 1

        if count >= 6:
            break

        time.sleep(0.4)

except Exception as e:

    print(
        f"⚠️ Cabinet Error: {e}"
    )

print(
    f"  ✅ Cabinet valid news: {len(items)}"
)

return items
```

# =============================================================

# 11. GOOGLE NEWS BIHAR

# =============================================================

GOOGLE_BIHAR_URL = (
"https://news.google.com/rss/search?"
"q=Bihar+Government+Schemes+OR+Infrastructure"
"+OR+Economy+when:2d"
"&hl=hi&gl=IN&ceid=IN:hi"
)

def fetch_google_news_real_article(
google_url
):

```
# Google News redirect page itself is not
# article content. Try resolving through
# the redirect URL.

try:

    headers = {
        "User-Agent":
            "Mozilla/5.0 "
            "(Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 "
            "(KHTML, like Gecko) "
            "Chrome/122.0 Safari/537.36"
    }

    res = requests.get(
        google_url,
        headers=headers,
        impersonate="chrome",
        timeout=15,
        verify=False,
        allow_redirects=True
    )

    final_url = str(
        getattr(
            res,
            "url",
            ""
        )
    )

    if (
        final_url
        and "news.google.com"
        not in final_url
    ):

        article_content = (
            fetch_generic_article_content(
                final_url
            )
        )

        if is_valid_article_content(
            article_content
        ):

            return (
                final_url,
                article_content
            )

except Exception:
    pass

return (
    google_url,
    ""
)
```

def scrape_google_bihar():

```
items = []

print(
    "\n📍 Scraping Bihar News..."
)

content = safe_fetch(
    GOOGLE_BIHAR_URL,
    timeout=15
)

if not content:
    print(
        "⚠️ Google News Bihar fetch failed"
    )
    return items

try:

    root = ET.fromstring(
        content
    )

    count = 0

    for item in root.findall(
        ".//item"
    )[:20]:

        title = clean_cdata_and_html(
            item.find("title").text
            if item.find("title")
            is not None
            else ""
        )

        link = clean_cdata_and_html(
            item.find("link").text
            if item.find("link")
            is not None
            else ""
        )

        pub_date = clean_cdata_and_html(
            item.find("pubDate").text
            if item.find("pubDate")
            is not None
            else ""
        )

        desc = clean_cdata_and_html(
            item.find("description").text
            if item.find("description")
            is not None
            else ""
        )

        if not title:
            continue

        if not is_yesterday_news(
            pub_date,
            datetime.now() - timedelta(days=1)
        ):
            continue

        # -------------------------------------------------
        # IMPORTANT:
        # RSS description may contain only title + source.
        # Never save that as article content.
        # -------------------------------------------------

        final_url, deep_content = (
            fetch_google_news_real_article(
                link
            )
        )

        if not is_valid_article_content(
            deep_content
        ):

            print(
                f"  ❌ Google RSS rejected: "
                f"{title[:70]}"
            )

            continue

        items.append({
            "source": "Google News Bihar",
            "title": title,
            "url": final_url,
            "date": pub_date,
            "content": deep_content,
            "content_chars": len(
                deep_content
            ),
            "type": "Deep Scraped"
        })

        count += 1

        if count >= 8:
            break

        time.sleep(0.4)

except Exception as e:

    print(
        f"⚠️ Google News Bihar Error: {e}"
    )

print(
    f"  ✅ Google Bihar valid news: "
    f"{len(items)}"
)

return items
```

# =============================================================

# 12. NATIONAL - PIB CENTRAL

# =============================================================

def scrape_pib():

```
items = []

print(
    "\n🇮🇳 Scraping PIB Central Releases..."
)

pib_rss_url = (
    "https://www.pib.gov.in/"
    "RssMain.aspx?Mod=1&Lang=1"
)

pib_content = safe_fetch(
    pib_rss_url
)

if not pib_content:
    return items

try:

    soup = BeautifulSoup(
        pib_content,
        "html.parser"
    )

    target_dt = (
        datetime.now()
        - timedelta(days=1)
    )

    count = 0

    for item in soup.find_all(
        "item"
    )[:20]:

        title = clean_cdata_and_html(
            item.find("title").text
            if item.find("title")
            else ""
        )

        link = clean_cdata_and_html(
            item.find("link").text
            if item.find("link")
            else ""
        )

        pub_date = clean_cdata_and_html(
            item.find("pubdate").text
            if item.find("pubdate")
            else ""
        )

        if not title:
            continue

        # PIB is intentionally yesterday-focused.
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

            content_to_use = deep_text
            content_type = (
                "Deep Scraped"
            )

        else:

            desc = item.find(
                "description"
            )

            fallback = (
                clean_cdata_and_html(
                    desc.text
                )
                if desc
                else ""
            )

            # PIB RSS fallback is allowed only
            # when it has meaningful content.
            if len(fallback) < 120:
                continue

            content_to_use = fallback
            content_type = "RSS Backup"

        items.append({
            "source": "PIB Central",
            "title": title,
            "url": link,
            "date": pub_date,
            "content": content_to_use,
            "content_chars": len(
                content_to_use
            ),
            "type": content_type
        })

        count += 1

        if count >= 10:
            break

except Exception as e:

    print(
        f"⚠️ PIB RSS Error: {e}"
    )

print(
    f"  ✅ PIB valid news: {len(items)}"
)

return items
```

# =============================================================

# 13. NATIONAL - THE HINDU

# =============================================================

def scrape_the_hindu():

```
items = []

print(
    "\n📰 Scraping The Hindu..."
)

rss_url = (
    "https://www.thehindu.com/"
    "news/national/feeder/default.rss"
)

content = safe_fetch(
    rss_url
)

if not content:
    return items

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    target_dt = (
        datetime.now()
        - timedelta(days=1)
    )

    count = 0

    for item in soup.find_all(
        "item"
    )[:20]:

        title = clean_cdata_and_html(
            item.find("title").text
            if item.find("title")
            else ""
        )

        link = clean_cdata_and_html(
            item.find("link").text
            if item.find("link")
            else ""
        )

        pub_date = clean_cdata_and_html(
            item.find("pubdate").text
            if item.find("pubdate")
            else ""
        )

        if not title:
            continue

        if not is_yesterday_news(
            pub_date,
            target_dt
        ):
            continue

        deep_text = (
            fetch_generic_article_content(
                link
            )
        )

        if len(deep_text) < 200:
            continue

        items.append({
            "source": "The Hindu",
            "title": title,
            "url": link,
            "date": pub_date,
            "content": deep_text,
            "content_chars": len(
                deep_text
            ),
            "type": "Deep Scraped"
        })

        count += 1

        if count >= 6:
            break

        time.sleep(0.4)

except Exception as e:

    print(
        f"⚠️ The Hindu Error: {e}"
    )

print(
    f"  ✅ The Hindu valid news: "
    f"{len(items)}"
)

return items
```

# =============================================================

# 14. NATIONAL - INDIAN EXPRESS

# =============================================================

def scrape_indian_express():

```
items = []

print(
    "\n📰 Scraping Indian Express..."
)

rss_url = (
    "https://indianexpress.com/"
    "section/india/feed/"
)

content = safe_fetch(
    rss_url
)

if not content:
    return items

try:

    soup = BeautifulSoup(
        content,
        "html.parser"
    )

    target_dt = (
        datetime.now()
        - timedelta(days=1)
    )

    count = 0

    for item in soup.find_all(
        "item"
    )[:20]:

        title = clean_cdata_and_html(
            item.find("title").text
            if item.find("title")
            else ""
        )

        link = clean_cdata_and_html(
            item.find("link").text
            if item.find("link")
            else ""
        )

        pub_date = clean_cdata_and_html(
            item.find("pubdate").text
            if item.find("pubdate")
            else ""
        )

        if not title:
            continue

        if not is_yesterday_news(
            pub_date,
            target_dt
        ):
            continue

        deep_text = (
            fetch_generic_article_content(
                link
            )
        )

        if len(deep_text) < 200:
            continue

        items.append({
            "source": "Indian Express",
            "title": title,
            "url": link,
            "date": pub_date,
            "content": deep_text,
            "content_chars": len(
                deep_text
            ),
            "type": "Deep Scraped"
        })

        count += 1

        if count >= 6:
            break

        time.sleep(0.4)

except Exception as e:

    print(
        f"⚠️ Indian Express Error: {e}"
    )

print(
    f"  ✅ Indian Express valid news: "
    f"{len(items)}"
)

return items
```

# =============================================================

# 15. OBJECT DEDUPLICATION

# =============================================================

def remove_duplicate_news(
news_list
):

```
seen_titles = set()
unique_news = []
dropped_count = 0

for news in news_list:

    if not isinstance(news, dict):
        continue

    title = normalize_text(
        news.get("title", "")
    )

    clean_title = re.sub(
        r"[^a-z0-9\u0900-\u097F]",
        "",
        title.lower()
    )

    clean_title = clean_title[:120]

    if (
        clean_title
        and clean_title not in seen_titles
    ):

        seen_titles.add(
            clean_title
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
```

# =============================================================

# 16. MAIN SCRAPER

# =============================================================

def run_scraper():

```
target_dt, date_str, key_str = (
    get_yesterday_info()
)

print(
    "🔄 Starting Optimized Deep Scraper "
    f"for Date: {date_str}\n"
)

bihar_items = []
national_items = []

source_stats = {}

# =========================================================
# A. IPRD BIHAR
# =========================================================

iprd_items = scrape_iprd_bihar()

bihar_items.extend(
    iprd_items
)

source_stats[
    "IPRD Bihar"
] = len(iprd_items)

# =========================================================
# B. CMO BIHAR
# =========================================================

cmo_items = scrape_cmo_bihar()

bihar_items.extend(
    cmo_items
)

source_stats[
    "CMO Bihar"
] = len(cmo_items)

# =========================================================
# C. BIHAR CABINET
# =========================================================

cabinet_items = (
    scrape_bihar_cabinet()
)

bihar_items.extend(
    cabinet_items
)

source_stats[
    "Bihar Cabinet Decision"
] = len(cabinet_items)

# =========================================================
# D. GOOGLE NEWS BIHAR
# =========================================================

google_items = (
    scrape_google_bihar()
)

bihar_items.extend(
    google_items
)

source_stats[
    "Google News Bihar"
] = len(google_items)

# =========================================================
# E. PIB CENTRAL
# =========================================================

pib_items = scrape_pib()

national_items.extend(
    pib_items
)

source_stats[
    "PIB Central"
] = len(pib_items)

# =========================================================
# F. THE HINDU
# =========================================================

hindu_items = scrape_the_hindu()

national_items.extend(
    hindu_items
)

source_stats[
    "The Hindu"
] = len(hindu_items)

# =========================================================
# G. INDIAN EXPRESS
# =========================================================

ie_items = scrape_indian_express()

national_items.extend(
    ie_items
)

source_stats[
    "Indian Express"
] = len(ie_items)

# =========================================================
# FINAL CLEAN
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

print(
    "\n📊 --- RAW SCRAPING SUMMARY BREAKDOWN ---"
)

print(
    json.dumps(
        source_stats,
        indent=2,
        ensure_ascii=False
    )
)

print(
    f"\n🇮🇳 Bihar total: "
    f"{len(bihar_clean)}"
)

print(
    f"🇮🇳 National total: "
    f"{len(national_clean)}"
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
    "\n💾 'rawnews.json' "
    "updated successfully!"
)


# =============================================================

# RUN

# =============================================================

if **name** == "**main**":
run_scraper()
