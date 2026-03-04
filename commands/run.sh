#!/bin/bash
# =============================================================
# Pull EA logs with proper quoting - 2026-03-04 v3
# =============================================================

echo "=== EA Logs Analysis - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. EA logs - TRADE/JOURNAL entries
echo "========== TRADE ACTIONS =========="
for f in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$f" ] || continue
    TRADES=$(strings "$f" | grep -E "TRADE|JOURNAL|OPEN|CLOSE|TP|SL.*HIT|ORDER")
    if [ -n "$TRADES" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$TRADES"
    fi
done

# 2. BLOCKED
echo ""
echo "========== BLOCKED SUMMARY =========="
for f in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$f" ] || continue
    BLOCKED=$(strings "$f" | grep "BLOCKED" | sort | uniq -c | sort -rn)
    if [ -n "$BLOCKED" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$BLOCKED"
    fi
done

# 3. HEARTBEAT
echo ""
echo "========== HEARTBEAT =========="
for f in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$f" ] || continue
    HB=$(strings "$f" | grep "HEARTBEAT")
    if [ -n "$HB" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$HB"
    fi
done

# 4. Signals
echo ""
echo "========== SIGNALS =========="
for f in "$MT5/MQL5/Logs/"*.log; do
    [ -f "$f" ] || continue
    SIG=$(strings "$f" | grep -E "SMC.*scan|SIGNAL|FVG|LiqSweep=yes|OB=yes")
    if [ -n "$SIG" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$SIG"
    fi
done

# 5. Terminal deals
echo ""
echo "========== TERMINAL LOGS =========="
for f in "$MT5/Logs/"*.log; do
    [ -f "$f" ] || continue
    DEALS=$(strings "$f" | grep -iE "deal|order #|instant|market|buy|sell" | tail -40)
    if [ -n "$DEALS" ]; then
        echo ""
        echo "--- $(basename "$f") ---"
        echo "$DEALS"
    fi
done

echo ""
echo "=== Done ==="
