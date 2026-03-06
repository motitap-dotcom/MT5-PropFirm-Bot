#!/bin/bash
# =============================================================
# Full status check - March 6, 2026
# =============================================================

echo "============================================"
echo "  Full Status Check"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Is MT5 running?
echo "=== [1] MT5 Process ==="
if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 is RUNNING (PID: $(pgrep -f terminal64.exe | head -1))"
else
    echo "MT5 is NOT running!"
fi
echo ""

# 2. Account status from today's terminal log
echo "=== [2] Terminal Log (today) ==="
TODAY=$(date '+%Y%m%d')
TERM_LOG="$MT5_BASE/logs/${TODAY}.log"
if [ -f "$TERM_LOG" ]; then
    tail -20 "$TERM_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
else
    echo "No terminal log for today. Latest:"
    ls -lt "$MT5_BASE/logs/"*.log 2>/dev/null | head -3
fi
echo ""

# 3. EA Expert log (today)
echo "=== [3] EA Log (today) ==="
EA_LOG="$MT5_BASE/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    echo "Log file: $EA_LOG"
    echo "--- Last 50 lines ---"
    tail -50 "$EA_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
else
    echo "No EA log for today. Latest:"
    LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log: $LATEST_LOG"
        tail -30 "$LATEST_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings
    fi
fi
echo ""

# 4. Check EA files are up to date
echo "=== [4] EA Files ==="
ls -la "$MT5_BASE/MQL5/Experts/PropFirmBot/" 2>/dev/null | head -15
echo ""

# 5. Account balance check from log
echo "=== [5] Last Balance/Equity Info ==="
LATEST_LOG=$(ls -t "$MT5_BASE/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    grep -i "HEARTBEAT\|Balance\|Equity\|position\|trade\|ORDER\|DEAL" "$LATEST_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings | tail -20
fi
echo ""

# 6. Any open positions?
echo "=== [6] Trade History (recent) ==="
if [ -n "$LATEST_LOG" ]; then
    grep -i "OPEN\|CLOSE\|BUY\|SELL\|profit\|SIGNAL.*ENTRY\|SIGNAL.*EXIT" "$LATEST_LOG" 2>/dev/null | sed 's/ \x00//g; s/\x00//g' | strings | tail -20
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
