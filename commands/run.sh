#!/bin/bash
echo "============================================"
echo "  LIVE Trading Check - $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Current status
echo "=== [1] Bot Status (status.json) ==="
STATUS_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json"
cat "$STATUS_FILE" 2>/dev/null
echo ""

# 2. Today's EA log - what signals is it seeing?
echo "=== [2] Today's EA Log (last 100 lines) ==="
TODAY=$(date '+%Y%m%d')
MQL_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/${TODAY}.log"
if [ -f "$MQL_LOG" ]; then
    echo "Log file: $MQL_LOG ($(wc -l < "$MQL_LOG") lines)"
    echo ""
    tail -100 "$MQL_LOG"
else
    echo "Today's log not found. Checking available:"
    ls -lt "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -5
    LATEST=$(ls -t "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo "--- Latest log: $LATEST ---"
        tail -100 "$LATEST"
    fi
fi
echo ""

# 3. Terminal log - connection
echo "=== [3] Terminal Log (last 30 lines) ==="
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_TERM=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "Log: $LATEST_TERM"
    tail -30 "$LATEST_TERM"
fi
echo ""

# 4. Open positions
echo "=== [4] Trade History / Journal ==="
JOURNAL="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/trade_journal.json"
if [ -f "$JOURNAL" ]; then
    echo "Journal file exists ($(wc -c < "$JOURNAL") bytes)"
    tail -50 "$JOURNAL"
else
    echo "No trade journal found"
fi
echo ""

# 5. Check if market data is flowing
echo "=== [5] Is market data updating? ==="
echo "Checking EURUSD tick..."
# Look for recent tick data in logs
grep -i "tick\|price\|bid\|ask\|signal\|scan\|trade\|order\|position" "$MQL_LOG" 2>/dev/null | tail -30
echo ""

echo "=== CHECK COMPLETE ==="
