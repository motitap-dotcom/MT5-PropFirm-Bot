#!/bin/bash
# Check when losses happened and daily reset logic - 2026-03-16b
echo "=== TRADE HISTORY & DAILY RESET CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# 1. List all log files (last 5 days)
echo "--- Available Log Files ---"
ls -lt "$EA_LOG_DIR"/*.log 2>/dev/null | head -10

# 2. Yesterday's log - find trade/loss entries
echo ""
echo "--- Yesterday's Log (20260315) - Trades & Losses ---"
YESTERDAY_LOG="$EA_LOG_DIR/20260315.log"
if [ -f "$YESTERDAY_LOG" ]; then
    echo "File size: $(wc -c < "$YESTERDAY_LOG") bytes"
    grep -i -E "trade|buy|sell|order|close|profit|loss|LOSS|consec|circuit|NEWBAR.*Guardian" "$YESTERDAY_LOG" 2>/dev/null | tail -40
else
    echo "Yesterday's log not found. Checking other recent logs..."
    ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -5
fi

# 3. Today's log - find DAILY RESET and trade entries
echo ""
echo "--- Today's Log (20260316) - Daily Reset & Trades ---"
TODAY_LOG="$EA_LOG_DIR/20260316.log"
if [ -f "$TODAY_LOG" ]; then
    echo "File size: $(wc -c < "$TODAY_LOG") bytes"
    echo ""
    echo ">> Looking for DAILY RESET:"
    grep -i -E "daily.?reset|new.?day|reset|m_consec|ACTIVE" "$TODAY_LOG" 2>/dev/null | head -20
    echo ""
    echo ">> Looking for trades/losses:"
    grep -i -E "trade|buy|sell|order|close|profit|LOSS|consec|circuit" "$TODAY_LOG" 2>/dev/null | head -30
    echo ""
    echo ">> First 30 lines of today's log:"
    head -30 "$TODAY_LOG" 2>&1
    echo ""
    echo ">> HEARTBEAT entries (shows state changes):"
    grep -i "HEARTBEAT" "$TODAY_LOG" 2>/dev/null
else
    echo "Today's log not found!"
fi

# 4. Check the DailyReset function timing
echo ""
echo "--- Server Time vs GMT ---"
echo "Current UTC: $(date -u '+%Y-%m-%d %H:%M:%S')"
echo "Note: MT5 server time may differ from UTC. Check status.json for both."

# 5. Status.json for current state
echo ""
echo "--- Current status.json ---"
cat "$EA_FILES_DIR/status.json" 2>/dev/null

# 6. Journal files
echo ""
echo "--- Trade Journal Files ---"
find "$EA_FILES_DIR" -name "*Journal*" -exec echo "File: {}" \; -exec cat {} \; 2>/dev/null

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
