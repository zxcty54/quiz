import os
import json
import re
import time
import hashlib
import feedparser
import warnings
from urllib.parse import quote
from datetime import datetime, timedelta, timezone

from googlenewsdecoder import gdecoderv1
from curl_cffi import requests as curl_requests
import requests as normal_requests

from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning

# ============================================================
# CONFIGURATION
# ============================================================

OUTPUT_FILE = "rawnews.json"
TIMEOUT = 25
MAX_PER_CATEGORY = 5

MIN_CONTENT_WORDS = 100     # Minimum 100 words strictly required
MAX_CONTENT_WORDS = 1500    # Maximum 1500 words limit

IST = timezone(timedelta(hours=5, minutes=30))

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "hi-IN,hi;q=0.9,en-IN;q=0.8,en;q=0.7",
    "Referer": "https://www.google.com/",
    "Upgrade-Insecure-Requests": "1"
}

warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

# ============================================================
# EXCLUDE KEYWORDS BLACKLIST
# ============================================================

EXCLUDE_KEYWORDS = [
    "murder", "police", "arrest", "theft", "accident", "rape", "crime", "fir", "killed", "dead", "gang",
    "bjp", "congress", "rjd", "jdu", "aap", "election campaign", "rally", "neta", "mp", "mla",
    "party", "opposition", "voter", "vote", "seat", "by-poll",
    "uttar pradesh", "up news", "madhya pradesh", "rajasthan", "maharashtra", "mumbai",
    "delhi news", "punjab", "haryana", "karnataka", "tamil nadu", "kerala", "gujarat", "bengal",
    "chief minister", "yogi", "siddaramaiah", "stalin", "mamata", "kejriwal", "hemant",
    "fadnavis", "shinde", "gehlot", "chouhan"
]

CATEGORY_VERIFICATION_KEYWORDS = {
    "Polity & Governance": ["supreme court", "high court", "bill", "act", "amendment", "constitutional", "election commission", "parliament", "judgement", "cabinet", "governance", "law"],
    "Govt Schemes & Welfare": ["scheme", "yojana", "welfare", "pradhan mantri", "subsidy", "beneficiary", "mission", "pension", "portal", "grant", "allowance", "financial assistance"],
    "Economy & Banking": ["rbi", "repo rate", "gdp", "inflation", "gst", "budget", "sebi", "banking", "economy", "finance", "fiscal", "export", "import", "taxation", "sensex"],
    "International Relations": ["bilateral", "g20", "brics", "quad", "sco", "summit", "diplomatic", "mou", "pact", "foreign policy", "envoy", "ambassador", "treaty"],
    "Science, Tech & Defense": ["isro", "nasa", "drdo", "satellite", "defense", "military", "exercise", "navy", "army", "air force", "missile", "artificial intelligence", "technology"],
    "Environment & Infrastructure": ["ramsar", "expressway", "renewable energy", "gi tag", "tiger reserve", "solar", "climate change", "pollution", "smart city", "metro", "green hydrogen"],
    "Bihar Schemes & Welfare": ["bihar", "mukhyamantri", "scheme", "yojana", "patna", "welfare", "subsidy", "bihar cabinet"],
    "Bihar Development": ["bihar", "patna", "expressway", "metro", "infrastructure", "bridge", "development", "project"]
}

def check_blacklist_reason(title, content=""):
    text = (title + " " + content).lower()
    for bad_word in EXCLUDE_KEYWORDS:
        if re.search(r'\b' + re.escape(bad_word) + r'\b', text):
            return bad_word
    return None

def verify_category_relevance(title, content, category):
    keywords = CATEGORY_VERIFICATION_KEYWORDS.get(category, [])
    if not keywords: return True
    full_text = (title + " " + content).lower()
    for kw in keywords:
        if re.search(r'\b' + re.escape(kw) + r'\b', full_text):
            return True
    return False

def now_ist(): return datetime.now(IST)
def debug(msg): print(f"🔍 {msg}")
def warn(msg): print(f"⚠️ {msg}")
def success(msg): print(f"✅ {msg}")

# ============================================================
# TEXT CLEANING
# ============================================================

def clean_url(url):
    if not url: return ""
    url = str(url).strip()
    m = re.search(r'\]\((https?://[^)]+)\)', url)
    if m: url = m.group(1)
    url = re.sub(r'^\[.*?\]\(', '', url)
    url = re.sub(r'\)$', '', url)
    return url if url.startswith(("http://", "https://")) else ""

def clean_text(text):
    if not text: return ""
    text = BeautifulSoup(str(text), "html.parser").get_text(" ", strip=True)
    text = text.replace("\xa0", " ").replace("\u200b", " ").replace("\ufeff", " ")
    return re.sub(r'\s+', ' ', text).strip()

def clean_title(title):
    title = clean_text(title)
    title = re.sub(r'\s*[-|–—]\s*(The Hindu|Indian Express|Hindustan Times|Times of India|NDTV|Aaj Tak|ABP News|PIB|Livemint|Business Standard).*$', '', title, flags=re.I)
    return title.strip()

def word_count(text):
    return len(re.findall(r'\S+', text)) if text else 0

def trim_to_max_words(text, max_words=MAX_CONTENT_WORDS):
    words = re.findall(r'\S+', text)
    if len(words) > max_words:
        return " ".join(words[:max_words]) + "..."
    return text

def is_content_too_similar_to_title(title, content):
    title_words = set(re.findall(r'\w+', title.lower()))
    content_words = set(re.findall(r'\w+', content.lower()))
    if not title_words or not content_words: return True
    overlap = title_words.intersection(content_words)
    if len(overlap) / len(title_words) > 0.70 and len(content_words) < len(title_words) + 15:
        return True
    return False

# ============================================================
# WEB SCRAPER ENGINE
# ============================================================

def get_real_publisher_url(google_rss_url):
    try:
        if "news.google.com" in google_rss_url:
            decoded = gdecoderv1(google_rss_url)
            if decoded.get("status") and decoded.get("decoded_url"):
                return decoded["decoded_url"]
    except Exception:
        pass
    return google_rss_url

def fetch_web_article(url):
    real_url = get_real_publisher_url(url)
    if not real_url or "news.google.com" in real_url: 
        return "", real_url

    html_raw = None
    try:
        r = curl_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, impersonate="chrome", allow_redirects=True)
        if r.status_code < 400: html_raw = r.text
    except Exception:
        pass

    if not html_raw:
        try:
            r = normal_requests.get(real_url, headers=HEADERS, timeout=TIMEOUT, allow_redirects=True, verify=False)
            if r.status_code < 400: html_raw = r.text
        except Exception:
            return "", real_url

    if not html_raw: return "", real_url

    soup = BeautifulSoup(html_raw, "lxml")
    for tag in soup(["script", "style", "noscript", "svg", "nav", "footer", "form", "aside", "header"]):
        tag.decompose()

    candidates = []

    # 1. JSON-LD Extraction
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or script.get_text())
            objects = data if isinstance(data, list) else [data]
            for obj in objects:
                if isinstance(obj, dict) and obj.get("articleBody"):
                    txt = clean_text(obj.get("articleBody"))
                    if word_count(txt) >= MIN_CONTENT_WORDS:
                        candidates.append(txt)
        except Exception:
            pass

    # 2. Main Article Selectors
    selectors = [
        "[itemprop='articleBody']", "article", ".article-body", ".articleBody",
        ".article-content", ".story-content", ".news-content", "main", ".entry-content",
        "#article-body", ".full-article", ".post-content"
    ]
    for selector in selectors:
        for el in soup.select(selector):
            txt = clean_text(el.get_text(" ", strip=True))
            if word_count(txt) >= MIN_CONTENT_WORDS:
                candidates.append(txt)

    # 3. Paragraph Aggregation
    paragraphs = [clean_text(p.get_text(" ", strip=True)) for p in soup.find_all("p")]
    paragraphs = [p for p in paragraphs if word_count(p) >= 8]
    if paragraphs:
        joined = clean_text(" ".join(paragraphs))
        if word_count(joined) >= MIN_CONTENT_WORDS:
            candidates.append(joined)

    if not candidates: return "", real_url

    best_text = max(candidates, key=lambda t: word_count(t))
    return best_text, real_url

# ============================================================
# ITEM BUILDER
# ============================================================

def make_item(source, title, url, date=None, content="", item_type="Google News", category="General"):
    clean_title_str = clean_title(title)
    clean_url_str = clean_url(url)
    clean_content_str = clean_text(content)

    # STRICT RULE 1: Reject if content is empty or basically title repeated
    if not clean_content_str or is_content_too_similar_to_title(clean_title_str, clean_content_str):
        warn(f"REJECTED (Content same as Title) | {clean_title_str[:50]}")
        return None

    # STRICT RULE 2: Minimum word count check
    total_words = word_count(clean_content_str)
    if total_words < MIN_CONTENT_WORDS:
        warn(f"REJECTED ({total_words} words < min {MIN_CONTENT_WORDS}) | {clean_title_str[:50]}")
        return None

    # STRICT RULE 3: Category Verification
    if not verify_category_relevance(clean_title_str, clean_content_str, category):
        warn(f"REJECTED (Category Mismatch '{category}') | {clean_title_str[:50]}")
        return None

    if total_words > MAX_CONTENT_WORDS:
        clean_content_str = trim_to_max_words(clean_content_str, MAX_CONTENT_WORDS)

    # STRICT RULE 4: Blacklist Check
    matched_bad_word = check_blacklist_reason(clean_title_str, clean_content_str)
    if matched_bad_word:
        warn(f"REJECTED (Blacklisted: '{matched_bad_word}') | {clean_title_str[:50]}")
        return None

    parsed_date = date or now_ist()

    success(f"ACCEPTED | Words: {word_count(clean_content_str)} | Category: {category} | Title: {clean_title_str[:50]}")

    return {
        "source": source,
        "category": category,
        "title": clean_title_str,
        "url": clean_url_str,
        "date": parsed_date.strftime("%a, %d %b %Y %H:%M:%S GMT"),
        "content": clean_content_str,
        "content_chars": len(clean_content_str),
        "content_words": word_count(clean_content_str),
        "type": item_type,
    }

def deduplicate(items):
    seen = set()
    output = []
    for item in items:
        key = item.get("url") or item.get("title")
        key_hash = hashlib.sha1(key.lower().encode("utf-8")).hexdigest()
        if key_hash not in seen:
            seen.add(key_hash)
            output.append(item)
    return output

# ============================================================
# MAIN SCRAPING PIPELINE
# ============================================================

NATIONAL_CATEGORIES = {
    "Polity & Governance": '("Supreme Court" OR "Cabinet Approves" OR "Act" OR "Bill")',
    "Govt Schemes & Welfare": '("Govt Scheme" OR "Pradhan Mantri" OR "Welfare")',
    "Economy & Banking": '("RBI Policy" OR "Union Budget" OR "Economic Survey" OR "GST Council")',
    "International Relations": '("Bilateral" OR "G20" OR "BRICS" OR "Quad" OR "Summit")',
    "Science, Tech & Defense": '("ISRO" OR "NASA" OR "Defense Exercise" OR "DRDO")',
    "Environment & Infrastructure": '("Ramsar Site" OR "Expressway" OR "Renewable Energy" OR "GI Tag")'
}

BIHAR_CATEGORIES = {
    "Bihar Schemes & Welfare": '("Bihar Scheme" OR "Mukhyamantri Scheme" OR "Bihar Welfare")',
    "Bihar Development": '("Bihar Expressway" OR "Patna Metro" OR "Bihar Infrastructure" OR "Bihar Development")'
}

def fetch_google_news_feed(categories_dict, source_label, is_bihar=False):
    print(f"\n" + "=" * 70 + f"\n🌐 SCRAPING SOURCE: {source_label}\n" + "=" * 70)
    category_results = []

    for cat_name, query in categories_dict.items():
        encoded_q = quote(f"{query} when:3d")
        rss_url = f"https://news.google.com/rss/search?q={encoded_q}&hl=en-IN&gl=IN&ceid=IN:en"

        feed = feedparser.parse(rss_url)
        entries = feed.entries or []
        debug(f"RSS returned {len(entries)} items for [{cat_name}]")

        count = 0
        # Scan up to 15 articles to find 5 valid fully scraped ones
        for entry in entries[:MAX_PER_CATEGORY * 3]:
            title = clean_title(getattr(entry, 'title', ''))
            rss_link = clean_url(getattr(entry, 'link', ''))

            if not title or not rss_link: continue

            # REAL SCRAPE ONLY (NO RSS FALLBACK)
            content, final_url = fetch_web_article(rss_link)

            if not content or word_count(content) < MIN_CONTENT_WORDS:
                warn(f"REJECTED (Scraping Failed/Blocked) | {title[:50]}")
                continue

            obj = make_item(
                source="Google News Central" if not is_bihar else "Google News Bihar",
                title=title,
                url=final_url or rss_link,
                date=now_ist(),
                content=content,
                item_type="National News" if not is_bihar else "Bihar News",
                category=cat_name
            )

            if obj:
                category_results.append(obj)
                count += 1

            if count >= MAX_PER_CATEGORY:
                break

    return deduplicate(category_results)

def build_news():
    national = fetch_google_news_feed(NATIONAL_CATEGORIES, "National", is_bihar=False)
    bihar = fetch_google_news_feed(BIHAR_CATEGORIES, "Bihar", is_bihar=True)

    breakdown = {
        "Google News National": len(national),
        "Google News Bihar": len(bihar)
    }

    return national, bihar, breakdown

def save_output(national, bihar, breakdown):
    all_news = national + bihar

    output = {
        "generated_at": now_ist().strftime("%Y-%m-%d %H:%M:%S"),
        "bihar_raw_count": len(bihar),
        "national_raw_count": len(national),
        "total_raw_count": len(all_news),
        "bihar_raw_news": bihar,
        "national_raw_news": national,
        "source_breakdown": breakdown,
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 80)
    print(f"💾 {OUTPUT_FILE} saved successfully with {len(all_news)} full-length items!")
    print("=" * 80)

if __name__ == "__main__":
    national, bihar, breakdown = build_news()
    save_output(national, bihar, breakdown)
