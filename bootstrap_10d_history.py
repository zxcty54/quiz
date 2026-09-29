import os
import json
import csv
import io
import requests
from datetime import datetime, timezone, timedelta

OUTPUT_HISTORY_FILE = "stock_history_20d.json"
IST = timezone(timedelta(hours=5, minutes=30))
NOW = datetime.now(IST)

def download_bhavcopy_for_date(target_date):
    """
    Downloads NSE Bhavcopy for a specific date if available.
    """
    trade_date_str = target_date.strftime("%d%m%Y")
    iso_date_str = target_date.strftime("%Y-%m-%d")
    url = f"https://nsearchives.nseindia.com/products/content/sec_bhavdata_full_{trade_date_str}.csv"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept": "*/*"
    }

    try:
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code == 200 and "SYMBOL" in resp.text:
            return resp.text, iso_date_str
    except Exception:
        pass
    return None, None

def save_compact_one_liner_json(data, filepath):
    """
    Saves clean one-liner JSON structure.
    """
    lines = ["{"]
    symbols = sorted(data.keys())
    for s_idx, sym in enumerate(symbols):
        records = data[sym]
        records_str = ", ".join(json.dumps(r) for r in records)
        comma = "," if s_idx < len(symbols) - 1 else ""
        lines.append(f'  "{sym}": [{records_str}]{comma}')
    lines.append("}")
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

def backfill_last_10_trading_days():
    print("=" * 75)
    print("⏳ FETCHING LAST 10 ACTIVE TRADING SESSIONS FROM NSE BHAVCOPY...")
    print("=" * 75)

    valid_sessions = []
    # Pichle 25 dinon mein check karenge taaki 10 working days mil sakein
    for days_back in range(0, 25):
        target_date = NOW - timedelta(days=days_back)
        if target_date.weekday() in (5, 6):  # Skip Saturday & Sunday
            continue

        csv_text, iso_date = download_bhavcopy_for_date(target_date)
        if csv_text:
            print(f"  ✅ Found Session {len(valid_sessions) + 1}/10: {iso_date}")
            valid_sessions.append((iso_date, csv_text))
            if len(valid_sessions) == 10:
                break
        else:
            print(f"  ⏭️ No data for: {target_date.strftime('%Y-%m-%d')} (Holiday/Pending)")

    if len(valid_sessions) < 10:
        print(f"\n⚠️ Sirf {len(valid_sessions)} sessions mile. Jitna mila hai utna process kar rahe hain...")

    # Data ko chronological order mein sort karein (Purana din pehle, Aaj ka din aakhir mein)
    valid_sessions.reverse()

    history_data = {}

    print("\n⚙️ Processing & Applying Liquidity Filters...")

    for iso_date_str, csv_text in valid_sessions:
        reader = csv.DictReader(io.StringIO(csv_text))
        
        for row in reader:
            clean_row = {k.strip(): v.strip() for k, v in row.items() if k}
            symbol = clean_row.get("SYMBOL", "")
            series = clean_row.get("SERIES", "")

            # 1. Filter: Series EQ Only
            if series != "EQ" or symbol.endswith("BEES") or symbol.endswith("ETF"):
                continue

            try:
                open_px = float(clean_row.get("OPEN_PRICE", 0.0))
                high_px = float(clean_row.get("HIGH_PRICE", 0.0))
                low_px = float(clean_row.get("LOW_PRICE", 0.0))
                close_px = float(clean_row.get("CLOSE_PRICE", 0.0))
                traded_qty = int(clean_row.get("TTL_TRD_QNTY", 0))
                deliv_pct = float(clean_row.get("DELIV_PER", 0.0))
                turnover_lacs = float(clean_row.get("TURNOVER_LACS", 0.0))
            except (ValueError, TypeError):
                continue

            # 2. Strict Filter: Close >= ₹100, Volume >= 10k, Turnover >= ₹25 Lakh
            if close_px < 100.0 or traded_qty < 10000 or turnover_lacs < 25.0:
                continue

            # Record: [date, open, high, low, close, volume, deliv_pct]
            record = [
                iso_date_str,
                round(open_px, 2),
                round(high_px, 2),
                round(low_px, 2),
                round(close_px, 2),
                traded_qty,
                round(deliv_pct, 2)
            ]

            if symbol not in history_data:
                history_data[symbol] = []

            # Avoid duplicates
            history_data[symbol] = [e for e in history_data[symbol] if e[0] != iso_date_str]
            history_data[symbol].append(record)

    # Sirf wahi stocks retain karein jinke paas full active 10 sessions ka data ho
    final_history = {k: v[-10:] for k, v in history_data.items() if len(v) >= 10}

    save_compact_one_liner_json(final_history, OUTPUT_HISTORY_FILE)

    file_size_kb = os.path.getsize(OUTPUT_HISTORY_FILE) / 1024
    print("=" * 75)
    print(f"🎉 10-DAY DATA POPULATED SUCCESSFULLY!")
    print(f"   • Total Active Liquid Stocks (With 10 Sessions) : {len(final_history)}")
    print(f"   • Saved to File                                  : '{OUTPUT_HISTORY_FILE}'")
    print(f"   • File Size                                      : {file_size_kb:.1f} KB")
    print("=" * 75)

if __name__ == "__main__":
    backfill_last_10_trading_days()
