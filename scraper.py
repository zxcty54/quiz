import os
import re
import json
import time
import warnings
import hashlib
import feedparser

from datetime import datetime, timedelta, timezone
from urllib.parse import urljoin, urlparse, parse_qs, urlencode, urlunparse

from curl_cffi import requests
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================

# CONFIG

# ============================================================

OUTPUT_FILE = "rawnews.json"

TIMEOUT = 25

# Maximum articles kept from each source

MAX_PER_SOURCE = 15

# Maximum size of actual article content

# Prevents portal/homepage/speech pages from making 7 MB JSON.

MAX_CONTENT_CHARS = 30000

# Minimum useful article text

MIN_CONTENT_CHARS = 180

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
"Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
"Connection": "keep-alive",
}

warnings.filterwarnings(
"ignore",
category=MarkupResemblesLocatorWarning
)

# ============================================================

# DATE / TIME

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
print(f"⚠️ DEBUG {msg}")

# ============================================================

# URL CLEANING

# ============================================================

def clean_url(url):

```
if not url:
    return ""

url = str(url).strip()

# Markdown:
# [https://example.com](https://example.com)
m = re.search(
    r"\]\((https?://[^)]+)\)",
    url
)

if m:
    url = m.group(1)

# Remove markdown wrapper
url = re.sub(
    r"^\[.*?\]\(",
    "",
    url
)

url = re.sub(
    r"\)$",
    "",
    url
)

# Escaped URL characters
url = url.replace("\\&", "&")
url = url.replace("\\:", ":")
url = url.replace("\\?", "?")
url = url.replace("\\/", "/")

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
```

# ============================================================

# HTTP FETCH

# ============================================================

def fetch_url(
url,
timeout=TIMEOUT,
allow_ssl_fallback=True
):

```
url = clean_url(url)

if not url:
    return None

try:

    r = requests.get(
        url,
        headers=HEADERS,
        timeout=timeout,
        impersonate="chrome",
        allow_redirects=True,
        verify=True
    )

    if r.status_code >= 400:

        print(
            f"⚠️ HTTP {r.status_code}: {url}"
        )

        # Try SSL fallback for government / Sansad sites
        if allow_ssl_fallback:

            try:

                print(
                    f"🔁 SSL fallback: {url}"
                )

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
                        f"⚠️ HTTP {r.status_code} "
                        f"after SSL fallback: {url}"
                    )

                    return None

                return r.text

            except Exception as e:

                print(
                    f"⚠️ SSL fallback failed: "
                    f"{url} | {e}"
                )

        return None

    return r.text

except Exception as e:

    print(
        f"⚠️ FETCH FAILED: {url} | {e}"
    )

    # ----------------------------------------------------
    # IMPORTANT:
    # Sansad TV / Bihar Government sometimes has a broken
    # certificate chain from GitHub Actions.
    # Try verify=False ONLY as fallback.
    # ----------------------------------------------------

    if allow_ssl_fallback:

        try:

            print(
                f"🔁 SSL fallback: {url}"
            )

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

        except Exception as e2:

            print(
                f"⚠️ SSL fallback FAILED: "
                f"{url} | {e2}"
            )

    return None
```

# ============================================================

# TEXT CLEANING

# ============================================================

def clean_text(text):

```
if not text:
    return ""

text = BeautifulSoup(
    str(text),
    "html.parser"
).get_text(
    " ",
    strip=True
)

text = text.replace(
    "\xa0",
    " "
)

text = re.sub(
    r"\s+",
    " ",
    text
)

return text.strip()
```

def clean_title(title):

```
title = clean_text(title)

title = re.sub(
    r"\s*[-|–—]\s*"
    r"(PIB|Press Information Bureau|News On AIR|"
    r"Sansad TV).*$",
    "",
    title,
    flags=re.I
)

return title.strip()
```

# ============================================================

# DATE PARSER

# ============================================================

DATE_FORMATS = [

```
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
```

]

def parse_date(value):

```
if not value:
    return None

value = clean_text(value)

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

    return (
        d.replace(
            tzinfo=timezone.utc
        )
        .astimezone(IST)
    )

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

# Search embedded date
patterns = [

    r"(\d{1,2}[-/]\d{1,2}[-/]\d{4})",

    r"(\d{1,2}[-/][A-Za-z]{3,9}[-/]\d{4})",

    r"(\d{4}-\d{2}-\d{2})",

    r"(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})",

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
```

# ============================================================

# DATE FROM HTML

# ============================================================

def extract_date_from_soup(soup):

```
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

    ".article-date",

    ".publication-date",

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
```

# ============================================================

# BOILERPLATE

# ============================================================

PORTAL_BOILERPLATE_PATTERNS = [

```
"previous next",

"accessibility options",

"skip to main content",

"site owned by",

"web information manager",

"copyright",

"state profile",

"governance profile",

"facts and figure",

"read more",

"contact us",

"feedback",

"sitemap",

"login",

"search",

"menu",

"home",
```

]

def portal_boilerplate_score(text):

```
if not text:
    return 0

low = text.lower()

score = 0

for p in PORTAL_BOILERPLATE_PATTERNS:

    if p in low:
        score += 1

return score
```

def is_common_boilerplate(text):

```
if not text:
    return True

low = text.lower()

patterns = [

    "we have tried to put most accurate",

    "help web information manager",

    "feedback.commonportal",

    "forgot email",

    "not your computer",

    "learn more about using",

    "phone directory",

]

hits = sum(
    1
    for p in patterns
    if p in low
)

return hits >= 2
```

# ============================================================

# CONTENT CLEANUP

# ============================================================

def remove_common_boilerplate(text):

```
if not text:
    return ""

patterns = [

    r"We have tried to put most accurate.*?$",

    r"Help Web Information Manager.*?$",

    r"Copyright IPRD.*?$",

]

for pattern in patterns:

    text = re.sub(
        pattern,
        "",
        text,
        flags=re.I
    )

return clean_text(text)
```

# ============================================================

# ARTICLE CONTENT EXTRACTION

# ============================================================

def extract_article_content(
soup,
source="UNKNOWN"
):

```
# --------------------------------------------------------
# Remove obvious non-content
# --------------------------------------------------------

for tag in soup([
    "script",
    "style",
    "noscript",
    "svg",
    "iframe",
    "form",
    "nav",
    "footer",
    "header"
]):

    tag.decompose()

candidates = []

# --------------------------------------------------------
# Highest priority article selectors
# --------------------------------------------------------

selectors = [

    "article",

    "[itemprop='articleBody']",

    ".article-body",

    ".articleBody",

    ".article-content",

    ".articleContent",

    ".story-content",

    ".storyContent",

    ".news-content",

    ".newsContent",

    ".press-release",

    ".pressrelease",

    ".press-release-content",

    ".main-article",

    ".single-post-content",

    ".post-content",

    ".entry-content",

    ".content-area",

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

        if len(txt) >= MIN_CONTENT_CHARS:

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

    if len(txt) >= 40:

        paragraphs.append(
            txt
        )

if paragraphs:

    paragraph_content = " ".join(
        paragraphs
    )

    if len(paragraph_content) >= MIN_CONTENT_CHARS:

        candidates.append(
            paragraph_content
        )

# --------------------------------------------------------
# Div fallback
# --------------------------------------------------------

if not candidates:

    for div in soup.find_all("div"):

        txt = clean_text(
            div.get_text(
                " ",
                strip=True
            )
        )

        if (
            MIN_CONTENT_CHARS
            <= len(txt)
            <= MAX_CONTENT_CHARS
        ):

            candidates.append(
                txt
            )

if not candidates:

    return ""

# --------------------------------------------------------
# Choose candidate intelligently
#
# DO NOT simply choose giant portal page.
# --------------------------------------------------------

valid = []

for text in candidates:

    if len(text) > MAX_CONTENT_CHARS:
        continue

    score = 0

    # Article-like content gets preference
    if len(text) >= 500:
        score += 3

    if len(text) >= 1000:
        score += 2

    # Penalize portal navigation
    score -= portal_boilerplate_score(
        text
    )

    valid.append(
        (score, len(text), text)
    )

if not valid:

    return ""

valid.sort(
    key=lambda x: (
        x[0],
        x[1]
    ),
    reverse=True
)

content = valid[0][2]

content = remove_common_boilerplate(
    content
)

if len(content) > MAX_CONTENT_CHARS:

    debug(
        f"{source} CONTENT TOO LARGE | "
        f"{len(content)}"
    )

    return ""

return content
```

# ============================================================

# GENERIC ARTICLE FETCH

# ============================================================

def fetch_generic_article_content(
url,
source="UNKNOWN"
):

```
url = clean_url(url)

if not url:
    return "", None

html = fetch_url(url)

if not html:

    debug(
        f"NO HTML | {source} | {url}"
    )

    return "", None

soup = BeautifulSoup(
    html,
    "html.parser"
)

date = extract_date_from_soup(
    soup
)

content = extract_article_content(
    soup,
    source
)

if not content:

    debug(
        f"NO CONTENT | {source} | {url}"
    )

return content, date
```

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

```
title = clean_title(title)

url = clean_url(url)

content = clean_text(content)

# --------------------------------------------------------
# NEVER use title as content
# --------------------------------------------------------

if not content:

    debug(
        f"REJECTED NO CONTENT | "
        f"{source} | {title[:100]}"
    )

    return None

# Title-only content protection
if (
    clean_text(content).lower()
    == clean_text(title).lower()
):

    debug(
        f"REJECTED TITLE AS CONTENT | "
        f"{source} | {title[:100]}"
    )

    return None

if len(content) < MIN_CONTENT_CHARS:

    debug(
        f"REJECTED CONTENT TOO SHORT "
        f"{len(content)} | "
        f"{source} | {title[:100]}"
    )

    return None

if len(content) > MAX_CONTENT_CHARS:

    debug(
        f"REJECTED CONTENT TOO LARGE "
        f"{len(content)} | "
        f"{source} | {title[:100]}"
    )

    return None

if is_common_boilerplate(content):

    debug(
        f"REJECTED COMMON BOILERPLATE | "
        f"{source} | {title[:100]}"
    )

    return None

if not title or not url:
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

    "content_chars": len(content),

    "type": item_type,

}
```

# ============================================================

# DEDUPLICATION

# ============================================================

def normalize_for_hash(text):

```
text = clean_text(
    text
).lower()

text = re.sub(
    r"[^a-z0-9\u0900-\u097f]+",
    " ",
    text
)

return text.strip()
```

def deduplicate(items):

```
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
```

# ============================================================

# PIB URL CONVERTER

# ============================================================

def convert_pib_url(url):

```
url = clean_url(url)

if not url:
    return ""

parsed = urlparse(url)

host = parsed.netloc.lower()

if "pib.gov.in" not in host:
    return url

# --------------------------------------------------------
# RSS often gives:
#
# PressReleaseIframePage.aspx?PRID=2296750
#
# Actual article:
#
# PressReleasePage.aspx?PRID=2296750&reg=3&lang=1
# --------------------------------------------------------

if (
    "PressReleaseIframePage.aspx"
    not in parsed.path
):

    return url

qs = parse_qs(
    parsed.query
)

prid = (
    qs.get("PRID", [""])[0]
    or qs.get("prid", [""])[0]
)

if not prid:
    return url

reg = (
    qs.get("reg", ["3"])[0]
    or "3"
)

lang = (
    qs.get("lang", ["1"])[0]
    or "1"
)

new_query = urlencode({

    "PRID": prid,

    "reg": reg,

    "lang": lang

})

new_url = (
    "https://www.pib.gov.in/"
    "PressReleasePage.aspx?"
    + new_query
)

print(
    f"🔄 PIB article URL:\n"
    f"   RSS : {url}\n"
    f"   PAGE: {new_url}"
)

return new_url
```

# ============================================================

# PIB RSS

# ============================================================

PIB_FEEDS = [

```
"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=1",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=5",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=6",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=17",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=20",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=22",

"https://pib.gov.in/RssMain.aspx?ModId=6&Lang=9&Regid=1",
```

]

def scrape_pib_rss():

```
print(
    "\n🇮🇳 PIB NATIONAL SCRAPER"
)

entries_all = []

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

    except Exception as e:

        print(
            f"⚠️ RSS parse error: {e}"
        )

        continue

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

        if not title or not link:
            continue

        date = None

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
                else
                "NO DATE"
            ),
            "|",
            title[:100]
        )

        entries_all.append({

            "title": title,

            "url": link,

            "date": date,

        })

entries_all = deduplicate([

    {

        "source": "PIB",

        "title": x["title"],

        "url": x["url"],

        "date": (
            x["date"].strftime(
                "%Y-%m-%d"
            )
            if x["date"]
            else ""
        ),

    }

    for x in entries_all

])

print(
    f"📊 Total unique PIB RSS items: "
    f"{len(entries_all)}"
)

# --------------------------------------------------------
# IMPORTANT:
# RSS dates are broken on PIB currently.
#
# Therefore do NOT discard everything because of date.
# RSS ordering itself is used as freshness fallback.
# --------------------------------------------------------

selected = entries_all[
    :MAX_PER_SOURCE
]

results = []

for item in selected:

    rss_url = item["url"]

    article_url = convert_pib_url(
        rss_url
    )

    content, article_date = (
        fetch_generic_article_content(
            article_url,
            source="PIB"
        )
    )

    if not content:

        print(
            "⚠️ DEBUG PIB NO ARTICLE "
            "CONTENT |",
            item["title"]
        )

        continue

    final_date = (
        article_date
        or parse_date(
            item["date"]
        )
    )

    obj = make_item(

        source="PIB",

        title=item["title"],

        url=article_url,

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
```

# ============================================================

# NEWS ON AIR NATIONAL

# ============================================================

NEWS_ON_AIR_HOME = (
"https://newsonair.gov.in/"
)

def scrape_news_on_air_national():

```
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

candidates = []

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

    if (
        "newsonair.gov.in"
        not in href.lower()
    ):
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

    candidates.append(
        (title, href)
    )

# unique URLs
seen = set()

candidates_unique = []

for title, href in candidates:

    if href in seen:
        continue

    seen.add(href)

    candidates_unique.append(
        (title, href)
    )

for title, href in candidates_unique[
    :30
]:

    content, date = (
        fetch_generic_article_content(
            href,
            source="News On AIR"
        )
    )

    if not content:

        debug(
            f"AIR NO CONTENT | "
            f"{title}"
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
```

# ============================================================

# CMO BIHAR

# ============================================================

CMO_URL = (
"https://cm.bihar.gov.in/"
"users/preessrelease.aspx"
)

def scrape_cmo_bihar():

```
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

candidates = []

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

    title = clean_title(
        a.get_text(
            " ",
            strip=True
        )
    )

    if not href:
        continue

    if len(title) < 20:
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
            "menu",
            "sitemap",

        ]
    ):
        continue

    candidates.append(
        (title, href)
    )

print(
    f"🔎 CMO candidate links: "
    f"{len(candidates)}"
)

seen = set()

for title, href in candidates:

    if href in seen:
        continue

    seen.add(href)

    content, date = (
        fetch_generic_article_content(
            href,
            source="CMO Bihar"
        )
    )

    if not content:

        debug(
            f"CMO NO CONTENT | "
            f"{title}"
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

results = deduplicate(
    results
)

print(
    f"✅ CMO Bihar usable news: "
    f"{len(results)}"
)

return results
```

# ============================================================

# IPRD BIHAR

# ============================================================

IPRD_PAGES = [

```
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
```

]

def is_iprd_real_article(
title,
url
):

```
low_title = title.lower()
low_url = url.lower()

# --------------------------------------------------------
# Generic IPRD portal pages.
# These are NOT news.
# --------------------------------------------------------

reject_title_patterns = [

    "order/circular/notification",

    "compendium of government circulars",

    "hindi translation of judgement",

    "empanelled cultural parties",

    "speech given by honourable governor",

    "total prohibition of alcohol",

    "physical and financial progress",

    "national highways,state highways",

    "communication sector in bihar gsdp",

    "impact assessment of total prohibition",

    "state profile",

    "governance profile",

    "facts and figure",

]

for p in reject_title_patterns:

    if p in low_title:

        return False

# SectionInformation itself is frequently
# a portal/listing page.
if (
    "sectioninformation.html"
    in low_url
    and
    "rowid="
    in low_url
):

    # Allow only if title looks like a real
    # current press release.
    keywords = [

        "minister",
        "मुख्यमंत्री",
        "मुख्य सचिव",
        "सरकार",
        "सरकारी",
        "press release",
        "announcement",
        "announced",
        "launch",
        "launched",
        "meeting",
        "review",
        "inaugur",
        "cabinet",
        "scheme",
        "योजना",
        "बैठक",
        "उद्घाटन",
        "घोषणा",

    ]

    if not any(
        k in low_title
        for k in keywords
    ):

        return False

return True
```

def scrape_iprd_bihar():

```
print(
    "\n📢 IPRD BIHAR SCRAPER"
)

results = []

all_candidates = []

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

        if len(title) < 20:
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
                "accessibility",
                "department",
                "login",
                "sitemap",

            ]
        ):
            continue

        if not is_iprd_real_article(
            title,
            href
        ):
            continue

        all_candidates.append(
            (
                title,
                href
            )
        )

# --------------------------------------------------------
# Unique candidate URLs
# --------------------------------------------------------

seen = set()

candidates = []

for title, href in all_candidates:

    if href in seen:
        continue

    seen.add(href)

    candidates.append(
        (
            title,
            href
        )
    )

print(
    f"🔎 IPRD candidate links: "
    f"{len(candidates)}"
)

# --------------------------------------------------------
# Fetch article pages
# --------------------------------------------------------

for title, href in candidates[:

    50
]:

    print(
        f"🔍 IPRD checking: "
        f"{title[:120]}"
    )

    content, date = (
        fetch_generic_article_content(
            href,
            source="IPRD Bihar"
        )
    )

    if not content:

        debug(
            f"IPRD NO CONTENT | "
            f"{title}"
        )

        continue

    # Prevent giant portal/speech pages
    if len(content) > MAX_CONTENT_CHARS:

        debug(
            f"IPRD CONTENT TOO LARGE | "
            f"{len(content)} | "
            f"{title}"
        )

        continue

    # Do not allow portal-like content
    score = portal_boilerplate_score(
        content
    )

    if score >= 5:

        debug(
            f"IPRD PORTAL BOILERPLATE | "
            f"SCORE={score} | "
            f"{title}"
        )

        continue

    # Current/recent articles only if date exists
    if date:

        age = (
            TODAY - date.date()
        ).days

        if age > 7:

            debug(
                f"IPRD OLD ARTICLE | "
                f"{age} days | "
                f"{title}"
            )

            continue

    obj = make_item(

        source="IPRD Bihar",

        title=title,

        url=href,

        date=date,

        content=content,

        item_type="IPRD Press Release"

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
    f"✅ IPRD Bihar usable news: "
    f"{len(results)}"
)

return results
```

# ============================================================

# BIHAR CABINET

# ============================================================

CABINET_PAGES = [

```
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
```

]

def scrape_bihar_cabinet():

```
print(
    "\n🏛️ BIHAR CABINET SCRAPER"
)

results = []

candidates = []

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
                "मंत्रिपरिषद",
                "निर्णय",
                "स्वीकृति",

            ]
        ):
            continue

        candidates.append(
            (
                title,
                href
            )
        )

# unique
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

print(
    f"🔎 Cabinet candidate links: "
    f"{len(unique)}"
)

for title, href in unique[:
    40
]:

    content, date = (
        fetch_generic_article_content(
            href,
            source="Bihar Cabinet Decision"
        )
    )

    if not content:

        debug(
            f"CABINET NO CONTENT | "
            f"{title}"
        )

        continue

    if date:

        age = (
            TODAY - date.date()
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

```
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
"east champaran",
"west champaran",
"bhojpur",
"nalanda",
"katihar",
"kishanganj",
"araria",
"saharsa",
"supaul",
"madhepura",
"jamui",
"lakhisarai",
"sheikhpura",
"buxar",
"rohtas",
"aurangabad",
"jehanabad",
"arwal",
"khagaria",
"siwan",
"gopalganj",
"nawada",


]

def scrape_news_on_air_bihar():

```
print(
    "\n📻 NEWS ON AIR BIHAR"
)

results = []

candidates = []

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

        if (
            "newsonair.gov.in"
            not in href.lower()
        ):
            continue

        low = title.lower()

        if not any(
            keyword in low
            for keyword in BIHAR_KEYWORDS
        ):
            continue

        candidates.append(
            (
                title,
                href
            )
        )

# unique
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

print(
    f"🔎 AIR Bihar candidates: "
    f"{len(unique)}"
)

for title, href in unique[:
    40
]:

    content, date = (
        fetch_generic_article_content(
            href,
            source="News On AIR Bihar"
        )
    )

    if not content:

        debug(
            f"AIR BIHAR NO CONTENT | "
            f"{title}"
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

results = deduplicate(
    results
)

print(
    f"✅ News On AIR Bihar usable: "
    f"{len(results)}"
)

return results
```

# ============================================================

# SANSAD TV

# ============================================================

SANSAD_TV_LISTINGS = [

```
"https://sansadtv.nic.in/",

"https://sansadtv.nic.in/"
"show_type/sansad-mein-aaj",

"https://sansadtv.nic.in/"
"category/news",


]

def scrape_sansad_tv():


print(
    "\n🏛️ SANSAD TV SCRAPER"
)

results = []

candidates = []

for listing in SANSAD_TV_LISTINGS:

    print(
        f"🔎 Listing: {listing}"
    )

    html = fetch_url(
        listing,
        timeout=30,
        allow_ssl_fallback=True
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
                listing,
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

        if (
            "sansadtv.nic.in"
            not in href.lower()
        ):
            continue

        if len(title) < 25:
            continue

        low = title.lower()

        if any(
            x in low
            for x in [

                "home",
                "about",
                "contact",
                "login",
                "privacy",
                "terms",
                "accessibility",

            ]
        ):
            continue

        candidates.append(
            (
                title,
                href
            )
        )

# unique
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

print(
    f"🔗 Sansad TV unique candidate "
    f"articles: {len(unique)}"
)

for title, href in unique[:
    40
]:

    content, date = (
        fetch_generic_article_content(
            href,
            source="Sansad TV"
        )
    )

    if not content:

        debug(
            f"SANSAD TV NO CONTENT | "
            f"{title}"
        )

        continue

    obj = make_item(

        source="Sansad TV",

        title=title,

        url=href,

        date=date,

        content=content,

        item_type="Sansad TV Article"

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
    f"✅ Sansad TV usable news: "
    f"{len(results)}"
)

return results


# ============================================================

# BUILD NEWS

# ============================================================

def build_news():

```
# ========================================================
# NATIONAL
#
# IMPORTANT:
# All sources are scraped.
# Fallback does NOT replace sources.
# ========================================================

print(
    "\n"
    + "=" * 65
)

print(
    "🇮🇳 NATIONAL SOURCES"
)

print(
    "=" * 65
)

pib = scrape_pib_rss()

air_national = (
    scrape_news_on_air_national()
)

sansad = scrape_sansad_tv()

# --------------------------------------------------------
# ALL national sources remain active
# --------------------------------------------------------

national = deduplicate(
    pib
    + air_national
    + sansad
)

# ========================================================
# BIHAR
#
# ALL Bihar official sources remain active.
# ========================================================

print(
    "\n"
    + "=" * 65
)

print(
    "🏛️ BIHAR SOURCES"
)

print(
    "=" * 65
)

cmo = scrape_cmo_bihar()

iprd = scrape_iprd_bihar()

cabinet = scrape_bihar_cabinet()

air_bihar = (
    scrape_news_on_air_bihar()
)

# --------------------------------------------------------
# IMPORTANT:
# No source replaces another.
# CMO + IPRD + Cabinet + AIR Bihar
# all stay in final output.
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
    national
    + bihar
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
        \+ 1
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

```
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

    "total_news":
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

print(
    f"📰 Total records: "
    f"{len(all_news)}"
)
```

# ============================================================

# MAIN

# ============================================================

if **name** == "**main**":


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

