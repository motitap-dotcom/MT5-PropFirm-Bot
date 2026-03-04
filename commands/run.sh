#!/bin/bash
# =============================================================
# Pull EA logs - UTF-16 fix - 2026-03-04 v4
# =============================================================

echo "=== EA Logs Analysis - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Helper: convert UTF-16 to UTF-8
utf16to8() {
    iconv -f UTF-16LE -t UTF-8 "$1" 2>/dev/null || cat "$1" | tr -d '\0'
}

# 1. EA logs - TRADE/JOURNAL entries
echo "========== TRADE ACTIONS =========="
for f in "$MT5"/MQL5/Logs/*.log; do
    [ -f "$f" ] || continue
    TRADES=$(utf16to8 "$f" | grep -E "TRADE|JOURNAL|OPEN|CLOSE|TP|SL.*HIT|ORDER")
    if [ -n "$TRADES" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$TRADES"
    fi
done

# 2. BLOCKED
echo ""
echo "========== BLOCKED SUMMARY =========="
for f in "$MT5"/MQL5/Logs/*.log; do
    [ -f "$f" ] || continue
    BLOCKED=$(utf16to8 "$f" | grep "BLOCKED" | sed 's/.*BLOCKED/BLOCKED/' | sort | uniq -c | sort -rn)
    if [ -n "$BLOCKED" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$BLOCKED"
    fi
done

# 3. HEARTBEAT (last 10 per file)
echo ""
echo "========== HEARTBEAT =========="
for f in "$MT5"/MQL5/Logs/*.log; do
    [ -f "$f" ] || continue
    HB=$(utf16to8 "$f" | grep "HEARTBEAT" | tail -10)
    if [ -n "$HB" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$HB"
    fi
done

# 4. Signals that passed
echo ""
echo "========== SIGNALS & SCANS =========="
for f in "$MT5"/MQL5/Logs/*.log; do
    [ -f "$f" ] || continue
    SIG=$(utf16to8 "$f" | grep -E "SMC.*scan|SIGNAL|LiqSweep=yes|OB=yes|FVG=yes|EMA.*Cross" | tail -30)
    if [ -n "$SIG" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$SIG"
    fi
done

# 5. Terminal logs
echo ""
echo "========== TERMINAL LOGS =========="
for f in "$MT5"/Logs/*.log; do
    [ -f "$f" ] || continue
    DEALS=$(utf16to8 "$f" | grep -iE "deal|order|buy|sell|instant|market|position" | tail -40)
    if [ -n "$DEALS" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$DEALS"
    fi
done

echo ""
echo "=== Done ==="
