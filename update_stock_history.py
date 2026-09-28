import os
import json
import csv
import io
import requests
from datetime import datetime, timezone, timedelta

OUTPUT_HISTORY_FILE = "stock_history_20d.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_latest_available_bhavcopy():
    """
    Tries current date first. If 404 (due to late-night runs, weekends, or holidays),
    automatically steps back to the most recent active trading day.
    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    # Checks up to the last 5 days
    for days_back in range(0, 5):
        target_date = NOW - timedelta(days=days_back)
        
        # Skip Saturdays (5) and Sundays (6)
        if target_date.weekday() in (5, 6):
            continue

        trade_date_str = target_date.strftime("%d%m%Y")
        iso_date_str = target_date.strftime("%Y-%m-%d")

        url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"
        print(f"🔍 Checking Bhavcopy for: {trade_date_str} ({iso_date_str})...")

        try:
            resp = requests.get(url, headers=headers, timeout=15)
            if resp.status_code == 200 and "SYMBOL" in resp.text:
                print(f"✅ Found and downloaded Bhavcopy for: {trade_date_str}")
                return resp.text, iso_date_str
            elif resp.status_code == 404:
                print(f"   ℹ️ Not available for {trade_date_str} (HTTP 404). Trying previous session...")
        except Exception as e:
            print(f"   ⚠️ Network error for {trade_date_str}: {e}")

    return None, None

def fetch_and_update_history():
    print("=" * 80)
    print("📊 NSE ROLLING 20-DAY OHLC & DELIVERY UPDATER (EQ, Price >= ₹100)")
    print(f"📅 Timestamp: {NOW.strftime('%d-%b-%Y %H:%M:%S IST')}")
    print("=" * 80)

    csv_text, iso_date_str = download_latest_available_bhavcopy()
    if not csv_text:
        print("❌ Could not locate any valid Bhavcopy in the last 5 days. Exiting.")
        return

    # Load existing JSON archive
    history_data = {}
    if os.path.exists(OUTPUT_HISTORY_FILE):
        try:
            with open(OUTPUT_HISTORY_FILE, "r", encoding="utf-8") as f:
                history_data = json.load(f)
                if not isinstance(history_data, dict):
                    history_data = {}
        except Exception as e:
            print(f"⚠️ Starting fresh JSON history: {e}")
            history_data = {}

    reader = csv.DictReader(io.StringIO(csv_text))
    qualifying_count = 0

    for row in reader:
        clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
        
        symbol = clean_row.get("SYMBOL", "")
        series = clean_row.get("SERIES", "")

        # 1. Strict EQ Series Filter (Exclude Debt, SGB, Warrants, SME)
        if series != "EQ":
            continue

        # 2. Block ETFs
        if symbol.endswith("BEES") or symbol.endswith("ETF"):
            continue

        try:
            open_px = float(clean_row.get("OPEN_PRICE", 0.0))
            high_px = float(clean_row.get("HIGH_PRICE", 0.0))
            low_px = float(clean_row.get("LOW_PRICE", 0.0))
            close_px = float(clean_row.get("CLOSE_PRICE", 0.0))
            traded_qty = int(clean_row.get("TTL_TRD_QNTY", 0))
            deliv_qty = int(clean_row.get("DELIV_QTY", 0))
            deliv_pct = float(clean_row.get("DELIV_PER", 0.0))
        except (ValueError, TypeError):
            continue

        # 3. Filter stocks below ₹100
        if close_px < 100.0:
            continue

        qualifying_count += 1

        day_record = {
            "date": iso_date_str,
            "open": round(open_px, 2),
            "high": round(high_px, 2),
            "low": round(low_px, 2),
            "close": round(close_px, 2),
            "total_traded_qty": traded_qty,
            "delivery_qty": deliv_qty,
            "delivery_pct": round(deliv_pct, 2)
        }

        if symbol not in history_data:
            history_data[symbol] = []

        # Deduplicate same-day entries
        history_data[symbol] = [e for e in history_data[symbol] if e.get("date") != iso_date_str]
        history_data[symbol].append(day_record)

        # 4. Strict Rolling 20-Day Truncation
        if len(history_data[symbol]) > 20:
            history_data[symbol] = history_data[symbol][-20:]

    with open(OUTPUT_HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history_data, f, ensure_ascii=False, indent=2)

    file_size_mb = os.path.getsize(OUTPUT_HISTORY_FILE) / (1024 * 1024)
    print("\n" + "=" * 80)
    print(f"✅ SUCCESS:")
    print(f"   • Captured Trade Date        : {iso_date_str}")
    print(f"   • Qualified Stocks Processed : {qualifying_count}")
    print(f"   • Total Active Tickers       : {len(history_data)}")
    print(f"   • Output JSON File Size      : {file_size_mb:.2f} MB")
    print(f"   • Saved to                   : '{OUTPUT_HISTORY_FILE}'")
    print("=" * 80)

if __name__ == "__main__":
    fetch_and_update_history()
