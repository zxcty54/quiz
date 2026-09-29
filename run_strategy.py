import json
import os
from datetime import datetime

INPUT_FILE = "stock_history_20d.json"
OUTPUT_JSON_FILE = "scanner_output.json"

def run_volatility_squeeze_scanner():
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Error: '{INPUT_FILE}' file nahi mili. Pehle data generate karein.")
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        try:
            history_data = json.load(f)
        except Exception as e:
            print(f"❌ JSON read error: {e}")
            return

    triggers = []
    watchlist = []

    for symbol, records in sorted(history_data.items()):
        # Formula ke liye minimum 10 sessions required hain
        if len(records) < 10:
            continue

        # Last 10 records:
        # Schema: [0:date, 1:open, 2:high, 3:low, 4:close, 5:volume, 6:deliv_pct]
        last_10 = records[-10:]

        # Day 4 to Day 8 = Pichle 5 din ka base (Consolidation phase)
        # Day 9 = Current / Latest Trading Day (Breakout test)
        prev_base = last_10[4:9]
        today = last_10[9]

        today_date = today[0]
        today_open = today[1]
        today_high = today[2]
        today_low = today[3]
        today_close = today[4]
        today_volume = today[5]
        today_deliv = today[6]

        # 1. Base Tightness (Volatility Squeeze) Calculation
        high_range = max(r[2] for r in prev_base)
        low_range = min(r[3] for r in prev_base)

        if low_range <= 0:
            continue

        squeeze_pct = (high_range - low_range) / low_range

        # 2. Base Average Volume & Delivery % Calculation
        avg_dry_vol = sum(r[5] for r in prev_base) / len(prev_base)
        avg_delivery = sum(r[6] for r in prev_base) / len(prev_base)

        if avg_dry_vol <= 0:
            continue

        # 3. Breakout Conditions
        price_breakout = today_close > high_range
        volume_blast = today_volume >= (3.0 * avg_dry_vol)

        # CORE FORMULA FILTER: Squeeze <= 8% aur Avg Delivery >= 45%
        if squeeze_pct <= 0.08 and avg_delivery >= 45.0:
            vol_spike = today_volume / avg_dry_vol

            # CASE A: Breakout Trigger (Price Breakout + 3x Volume Blast)
            if price_breakout and volume_blast:
                triggers.append({
                    "symbol": symbol,
                    "date": today_date,
                    "close": round(today_close, 2),
                    "volume_spike": round(vol_spike, 1),
                    "delivery_pct": round(today_deliv, 1),
                    "base_high": round(high_range, 2),
                    "base_low": round(low_range, 2),
                    "squeeze_pct": round(squeeze_pct * 100, 1)
                })

            # CASE B: Squeeze Watchlist (Base tight, Volume dry, Ready to pop)
            elif not price_breakout:
                watchlist.append({
                    "symbol": symbol,
                    "date": today_date,
                    "close": round(today_close, 2),
                    "squeeze_pct": round(squeeze_pct * 100, 1),
                    "avg_delivery": round(avg_delivery, 1),
                    "avg_volume": int(avg_dry_vol),
                    "base_high": round(high_range, 2),
                    "base_low": round(low_range, 2)
                })

    # Save to JSON for App API
    app_payload = {
        "scan_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_universe": len(history_data),
        "triggers_count": len(triggers),
        "watchlist_count": len(watchlist),
        "triggers": triggers,
        "watchlist": watchlist
    }

    with open(OUTPUT_JSON_FILE, "w", encoding="utf-8") as out_f:
        json.dump(app_payload, out_f, indent=2, ensure_ascii=False)

    # Clean Console Output
    print("\n" + "=" * 80)
    print("🔥 TODAY'S BUY TRIGGERS (5D Range Break + 3x Volume Spike)")
    print("=" * 80)
    if not triggers:
        print("  None. Aaj koi 3x volume blast breakout trigger nahi hua.")
    else:
        print(f"{'Symbol':<14} | {'Price':<10} | {'Vol Spike':<12} | {'Today Del%':<12} | {'Squeeze Range':<15}")
        print("-" * 80)
        for t in triggers:
            print(f"{t['symbol']:<14} | ₹{t['close']:<9} | {t['volume_spike']}x{'':<8} | {t['delivery_pct']}%{'':<6} | {t['squeeze_pct']}% (₹{t['base_low']} - ₹{t['base_high']})")

    print("\n" + "=" * 80)
    print("👀 SQUEEZE WATCHLIST (Tight Base <= 8% + Institutional Delivery >= 45%)")
    print("=" * 80)
    if not watchlist:
        print("  None. Watchlist criteria par koi stock match nahi hua.")
    else:
        print(f"{'Symbol':<14} | {'Price':<10} | {'Squeeze %':<12} | {'Avg Del%':<12} | {'5D Base Range':<18}")
        print("-" * 80)
        # Squeeze percentage ke hisab se sort (tightest base first)
        watchlist.sort(key=lambda x: x["squeeze_pct"])
        for w in watchlist:
            print(f"{w['symbol']:<14} | ₹{w['close']:<9} | {w['squeeze_pct']}%{'':<6} | {w['avg_delivery']}%{'':<6} | ₹{w['base_low']} - ₹{w['base_high']}")

    print("=" * 80)
    print(f"📁 Scanned Output saved to: '{OUTPUT_JSON_FILE}'")
    print("=" * 80 + "\n")

if __name__ == "__main__":
    run_volatility_squeeze_scanner()
