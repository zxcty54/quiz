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

# Matches your exact GitHub Repository Secrets
BOT_TOKEN = os.environ.get("TELEGRAM_TOKEN") or os.environ.get("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.environ.get("TELEGRAM_TO") or os.environ.get("TELEGRAM_CHAT_ID")

IST = timezone(timedelta(hours=5, minutes=30))

# ============================================================
# TEMPLATE BUILDER (EXACT USER SPECIFICATION)
# ============================================================

def clean_html(text):
    """Escapes HTML entities to prevent Telegram parse errors."""
    if not text:
        return ""
    return html.escape(str(text).strip())

def build_telegram_post(card):
    facts = card.get("facts", {})
    category = clean_html(card.get("category", "CORPORATE ACTION").upper())
    company = clean_html(card.get("company_name") or card.get("symbol", ""))
    headline = clean_html(card.get("headline", ""))
    pdf_link = card.get("pdf_link", "")

    # Header
    post = f"🏷️ <b>{category}</b>\n"
    post += f"<b>{company} — {headline}</b>\n\n"

    # 1. What happened?
    what_happened = facts.get("what_happened")
    if what_happened and str(what_happened).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        post += f"<b>What happened?</b>\n{clean_html(what_happened)}\n\n"

    # 2. Key details
    details = []
    
    # What
    what_detail = facts.get("what") or facts.get("what_business")
    if what_detail and str(what_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>What:</b> {clean_html(what_detail)}")
        
    # Who
    who_detail = facts.get("who")
    if who_detail and str(who_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>Who:</b> {clean_html(who_detail)}")
        
    # Business
    biz_detail = facts.get("what_business")
    if biz_detail and biz_detail != what_detail and str(biz_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>Business:</b> {clean_html(biz_detail)}")
        
    # Value / Size
    value_detail = facts.get("how_much")
    if value_detail and str(value_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>Value / Size:</b> {clean_html(value_detail)}")
        
    # When
    when_detail = facts.get("when")
    if when_detail and str(when_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>When:</b> {clean_html(when_detail)}")
        
    # Where
    where_detail = facts.get("where")
    if where_detail and str(where_detail).lower() not in ["none", "nil", "n/a", "not disclosed"]:
        details.append(f"• <b>Where:</b> {clean_html(where_detail)}")

    if details:
        post += "<b>Key details</b>\n" + "\n".join(details) + "\n\n"

    # 3. What changes
    what_changes = facts.get("what_changes")
    if what_changes and str(what_changes).lower() not in ["none", "nil", "n/a", "not disclosed", "none disclosed"]:
        post += f"<b>What changes</b>\n{clean_html(what_changes)}\n\n"

    # 4. Not disclosed (Materially absent information only)
    not_disclosed = facts.get("what_is_not_disclosed")
    if not_disclosed and str(not_disclosed).lower() not in ["none", "nil", "n/a", "", "none disclosed"]:
        post += f"<b>Not disclosed</b>\n{clean_html(not_disclosed)}\n\n"

    # 5. Source (Clean clickable link)
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

    # Load previously posted record hashes
    posted_hashes = set()
    if os.path.exists(POSTED_LOG_FILE):
        try:
            with open(POSTED_LOG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, list):
                    posted_hashes = set(loaded)
        except Exception:
            pass

    # Reverse list so chronological order is maintained (older first, newest latest)
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

        print(f"📤 Broadcasting: {sym} — {card.get('headline')[:45]}...")
        success, response_msg = send_to_telegram(post_text)

        if success:
            posted_hashes.add(c_hash)
            dispatched += 1
            time.sleep(3)  # Respect Telegram rate limit thresholds
        else:
            print(f"   ⚠️ Telegram delivery failed for {sym}: {response_msg}")

    # Retain max 1,000 posted hashes to keep file small
    pruned_hashes = list(posted_hashes)[-1000:]
    with open(POSTED_LOG_FILE, "w", encoding="utf-8") as f:
        json.dump(pruned_hashes, f, indent=2)

    print("\n" + "=" * 80)
    print(f"✅ DISPATCH COMPLETE: {dispatched} new posts broadcast to Telegram.")
    print("=" * 80)


if __name__ == "__main__":
    dispatch_feed()
