import os
import json
import time
import html
from datetime import datetime, timezone, timedelta
import requests

# ============================================================
# CONFIGURATION & REPO SECRETS MAPPING
# ============================================================

INPUT_FILE = "nse_content_feed.json"
POSTED_LOG_FILE = "telegram_posted_log.json"

BOT_TOKEN = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.environ.get("TELEGRAM_TO") or os.environ.get("TELEGRAM_CHAT_ID")

IST = timezone(timedelta(hours=5, minutes=30))

# ============================================================
# MODERN POST BUILDER
# ============================================================

CATEGORY_ICONS = {
    "COMMERCIAL_PRODUCTION": "🏭",
    "NEW_PRODUCT": "🚀",
    "ORDER_WIN": "📜",
    "FINANCIAL_RESULTS": "📊",
    "RESULT": "📊",
    "CAPEX": "🏗️",
    "ACQUISITION": "🤝",
    "JOINT_VENTURE": "🤝",
    "GENERAL": "⚡"
}

def clean_html(text):
    """Escapes HTML entities to prevent Telegram parse errors."""
    if not text:
        return ""
    return html.escape(str(text).strip())

def build_telegram_post(card):
    # Agar summarizer ka direct post available hai, prefer that
    ai_post = card.get("telegram_post")
    if ai_post and "━━━━━━━━━━━━━━━━━━━━━━" in ai_post:
        return ai_post

    # Fallback to python-generated structured formatting
    facts = card.get("facts", {})
    raw_cat = card.get("category", "CORPORATE_ACTION").upper().replace(" ", "_")
    cat_icon = CATEGORY_ICONS.get(raw_cat, "⚡")
    
    company = clean_html(card.get("company_name") or card.get("symbol", ""))
    headline = clean_html(card.get("headline", ""))
    pdf_link = card.get("pdf_link", "")

    # Top Header
    post = (
        f"{cat_icon} <b>#{raw_cat}</b>\n"
        f"🏢 <b>{company}</b>\n"
        f"<b>{headline}</b>\n"
        f"━━━━━━━━━━━━━━━━━━━━━━\n\n"
    )

    # 1. What happened?
    what_happened = facts.get("what_happened")
    if what_happened and str(what_happened).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        post += f"🔹 <b>What happened?</b>\n↳ {clean_html(what_happened)}\n\n"

    # 2. Key details
    details = []
    keys_order = [
        ("what", "What"),
        ("who", "Who"),
        ("what_business", "Business"),
        ("how_much", "Value / Size"),
        ("when", "Timeline"),
        ("where", "Location")
    ]
    
    for key, label in keys_order:
        val = facts.get(key)
        if val and str(val).lower() not in ["none", "nil", "n/a", "not disclosed", "none disclosed"]:
            details.append(f"• <b>{label}:</b> {clean_html(val)}")

    if details:
        post += "🔹 <b>Key Details:</b>\n" + "\n".join(details) + "\n\n"

    # 3. What changes
    what_changes = facts.get("what_changes")
    if what_changes and str(what_changes).lower() not in ["none", "nil", "n/a", "not disclosed", "none disclosed"]:
        post += f"🔹 <b>Impact & What Changes?</b>\n↳ {clean_html(what_changes)}\n\n"

    # 4. Not disclosed (agar material gaps hain)
    not_disclosed = facts.get("what_is_not_disclosed")
    if not_disclosed and str(not_disclosed).lower() not in ["none", "nil", "n/a", "", "none disclosed"]:
        post += f"⚠️ <b>Not Disclosed:</b>\n↳ {clean_html(not_disclosed)}\n\n"

    post += "━━━━━━━━━━━━━━━━━━━━━━\n"

    # 5. Clean clickable source link
    if pdf_link and pdf_link.startswith("http"):
        post += f'📌 <b>Source:</b> <a href="{pdf_link}">NSE Corporate Filing</a>'
    else:
        post += "📌 <b>Source:</b> NSE Corporate Filing"

    return post

def send_to_telegram(text_payload):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text_payload,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    try:
        resp = requests.post(url, json=payload, timeout=20)
        return resp.status_code == 200, resp.text
    except Exception as e:
        return False, str(e)

# ============================================================
# DISPATCH ENGINE
# ============================================================

def dispatch_feed():
    print("=" * 80)
    print("🚀 TELEGRAM CURATED FEED DISPATCHER")
    print(f"📅 Timestamp: {datetime.now(IST).strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    if not BOT_TOKEN or not CHAT_ID:
        print("❌ FATAL: 'TELEGRAM_TOKEN' or 'TELEGRAM_TO' missing in GitHub environment.")
        exit(1)

    if not os.path.exists(INPUT_FILE):
        print(f"ℹ️ Input feed file '{INPUT_FILE}' not found. Exiting cleanly.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        feed_data = json.load(f)

    content_cards = feed_data.get("content_feed", [])
    print(f"📦 Total cards in active content feed: {len(content_cards)}")

    posted_hashes = set()
    if os.path.exists(POSTED_LOG_FILE):
        try:
            with open(POSTED_LOG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, list):
                    posted_hashes = set(loaded)
        except Exception:
            pass

    pending = [card for card in reversed(content_cards) if card.get("hash") not in posted_hashes]
    print(f"🎯 Fresh unposted corporate actions: {len(pending)}")

    if not pending:
        print("✅ No pending announcements to broadcast. Everything is up to date!")
        return

    dispatched = 0
    for card in pending:
        c_hash = card.get("hash")
        sym = card.get("symbol", "")
        post_text = build_telegram_post(card)

        print(f"📤 Broadcasting: {sym} — {card.get('headline', '')[:45]}...")
        success, response_msg = send_to_telegram(post_text)

        if success:
            posted_hashes.add(c_hash)
            dispatched += 1
            time.sleep(3)  # Rate limit threshold safety
        else:
            print(f"   ⚠️ Telegram delivery failed for {sym}: {response_msg}")

    # Retain up to 2,000 hashes
    pruned_hashes = list(posted_hashes)[-2000:]
    with open(POSTED_LOG_FILE, "w", encoding="utf-8") as f:
        json.dump(pruned_hashes, f, indent=2)

    print("\n" + "=" * 80)
    print(f"✅ DISPATCH COMPLETE: {dispatched} new posts broadcast to Telegram.")
    print("=" * 80)

if __name__ == "__main__":
    dispatch_feed()
