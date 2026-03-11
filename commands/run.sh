#!/bin/bash
# Check bot status and recent trades - triggered 2026-03-11
echo "=== BOT STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# 1. Is MT5 running?
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$MT5_PID)"
    ps -p $MT5_PID -o pid,etime,rss --no-headers 2>/dev/null
else
    echo "MT5: NOT RUNNING!"
fi

# 2. Account & trade info from logs
echo ""
echo "--- Recent EA Logs (last 50 lines) ---"
LATEST=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "Log file: $LATEST"
    tail -50 "$LATEST" 2>&1
else
    echo "No log files found"
fi

# 3. Check journal for trades
echo ""
echo "--- Trade-related log entries ---"
if [ -n "$LATEST" ]; then
    grep -i -E "order|trade|buy|sell|position|deal|profit|loss|open|close" "$LATEST" 2>/dev/null | tail -30
    echo ""
    echo "Total trade-related entries: $(grep -i -c -E 'order|trade|buy|sell|position|deal' "$LATEST" 2>/dev/null)"
fi

# 4. Check all recent logs
echo ""
echo "--- All log files (last 7 days) ---"
find "$EA_LOG_DIR" -name "*.log" -mtime -7 -ls 2>/dev/null

# 5. Check terminal journal too
JOURNAL_DIR="${MT5_BASE}/MQL5/Logs"
TERM_LOG_DIR="${MT5_BASE}/logs"
echo ""
echo "--- Terminal Logs ---"
TERM_LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "Terminal log: $TERM_LATEST"
    grep -i -E "order|trade|buy|sell|position|deal|connected|login|account" "$TERM_LATEST" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
