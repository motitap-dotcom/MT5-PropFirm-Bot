#!/bin/bash
# Check trade history with UTF-16 handling - 2026-03-16c
echo "=== TRADE HISTORY CHECK (UTF-16 fix) $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"

# Convert UTF-16 to UTF-8 and search
search_log() {
    local logfile="$1"
    local pattern="$2"
    local label="$3"
    echo "--- $label ---"
    if [ -f "$logfile" ]; then
        iconv -f UTF-16LE -t UTF-8 "$logfile" 2>/dev/null | grep -i -E "$pattern" | tail -30
    else
        echo "File not found: $logfile"
    fi
}

# 1. Friday's log (March 13) - when trades likely happened
echo "====== FRIDAY March 13 ======"
search_log "$EA_LOG_DIR/20260313.log" "trade|buy|sell|order|open|close|profit|loss|LOSS" "Trades on Friday"
echo ""
search_log "$EA_LOG_DIR/20260313.log" "consec|circuit|HALT|guardian.*state" "Circuit Breaker on Friday"
echo ""
search_log "$EA_LOG_DIR/20260313.log" "NEW DAY|daily.reset" "Daily Reset on Friday"

# 2. Sunday's log (March 15)
echo ""
echo "====== SUNDAY March 15 ======"
search_log "$EA_LOG_DIR/20260315.log" "NEW DAY|daily.reset|ACTIVE|consec|circuit|HALT" "State changes on Sunday"
echo ""
echo "First 10 lines of Sunday log:"
iconv -f UTF-16LE -t UTF-8 "$EA_LOG_DIR/20260315.log" 2>/dev/null | head -10
echo ""
echo "Last 10 lines of Sunday log:"
iconv -f UTF-16LE -t UTF-8 "$EA_LOG_DIR/20260315.log" 2>/dev/null | tail -10

# 3. Today's log (March 16 Monday)
echo ""
echo "====== MONDAY March 16 (TODAY) ======"
search_log "$EA_LOG_DIR/20260316.log" "NEW DAY|daily.reset|ACTIVE" "Daily Reset on Monday"
echo ""
echo "First 10 lines of today's log:"
iconv -f UTF-16LE -t UTF-8 "$EA_LOG_DIR/20260316.log" 2>/dev/null | head -10
echo ""
search_log "$EA_LOG_DIR/20260316.log" "HEARTBEAT" "All Heartbeats today"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
