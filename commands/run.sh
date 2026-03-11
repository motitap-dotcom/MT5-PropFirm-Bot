#!/bin/bash
# Check today's trades and NewsFilter activity - triggered by FundedNext news event email
echo "=== NEWS EVENT TRADE INVESTIGATION $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. MT5 status
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "MT5: RUNNING (PID=$MT5_PID)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. Status.json (latest snapshot)
echo ""
echo "--- status.json ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json" 2>&1
else
    echo "status.json not found"
fi

# 3. Today's EA logs - look for trades and NewsFilter
echo ""
echo "--- Today's EA Log (all entries) ---"
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    echo "Log file: $TODAY_LOG"
    echo ""
    echo ">> ALL log entries from today:"
    cat "$TODAY_LOG" 2>&1
else
    echo "No EA log files found"
fi

# 4. Look specifically for order 162361131
echo ""
echo "--- Search for Order 162361131 ---"
grep -r "162361131" "$EA_LOG_DIR"/ "$TERM_LOG_DIR"/ "$EA_FILES_DIR"/ 2>/dev/null || echo "Order 162361131 not found in logs"

# 5. NewsFilter related entries
echo ""
echo "--- NewsFilter entries in all recent logs ---"
grep -r -i "news" "$EA_LOG_DIR"/*.log 2>/dev/null | tail -30 || echo "No news-related entries"

# 6. Trade/order entries from today
echo ""
echo "--- Trade entries in EA logs ---"
grep -i -E "order|trade|buy|sell|position|deal|open|close|profit|loss" "$TODAY_LOG" 2>/dev/null | tail -50 || echo "No trade entries"

# 7. Terminal logs - look for trades today
echo ""
echo "--- Terminal Log (today) ---"
TERM_LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "Terminal log: $TERM_LATEST"
    grep -i -E "order|trade|buy|sell|deal|162361131|news" "$TERM_LATEST" 2>/dev/null | tail -30
fi

# 8. Trade journal CSV for today
echo ""
echo "--- Trade Journal CSVs ---"
find "$EA_FILES_DIR" -name "*Journal*" -mtime -3 -exec echo "File: {}" \; -exec cat {} \; 2>/dev/null || echo "No journal files found"

# 9. Check all log files modified today
echo ""
echo "--- All logs modified today ---"
find "$EA_LOG_DIR" "$TERM_LOG_DIR" -name "*.log" -mtime -1 -ls 2>/dev/null

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
