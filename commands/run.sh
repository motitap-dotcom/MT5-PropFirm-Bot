#!/bin/bash
# Debug failed challenge - get full logs
echo "=== FAILED CHALLENGE DEBUG $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# 1. MT5 process
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    UPTIME=$(ps -o etime= -p "$MT5_PID" 2>/dev/null)
    echo "MT5: RUNNING (PID=$MT5_PID, uptime=$UPTIME)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. Status.json
echo ""
echo "--- status.json ---"
if [ -f "$EA_FILES_DIR/status.json" ]; then
    cat "$EA_FILES_DIR/status.json" 2>&1
else
    echo "status.json not found"
fi

# 3. Last 200 lines of EA log (need more to see what went wrong)
echo ""
echo "--- Latest EA Log (last 200 lines) ---"
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    echo "Log file: $TODAY_LOG"
    tail -200 "$TODAY_LOG" 2>&1
else
    echo "No EA log files found"
fi

# 4. All Guardian entries from all recent logs
echo ""
echo "--- ALL Guardian & Drawdown Entries (last 3 log files) ---"
for LOG in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    echo "=== File: $LOG ==="
    grep -i -E "guardian|drawdown|DD|safety|halt|emergency|shutdown|HEARTBEAT|equity|high.water|HWM|trailing" "$LOG" 2>/dev/null | tail -50
done

# 5. All trade entries
echo ""
echo "--- ALL Trade Entries (last 3 log files) ---"
for LOG in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    echo "=== File: $LOG ==="
    grep -i -E "TRADE|CLOSED|BUY|SELL|order|position|profit|loss|PnL" "$LOG" 2>/dev/null | tail -30
done

# 6. Trade journal CSVs
echo ""
echo "--- Trade Journal CSVs ---"
find "$EA_FILES_DIR" -name "*Journal*" -mtime -30 -exec echo "File: {}" \; -exec cat {} \; 2>/dev/null || echo "No journal files"

# 7. RiskMgr entries
echo ""
echo "--- RiskMgr Entries ---"
for LOG in $(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -3); do
    echo "=== File: $LOG ==="
    grep -i "RiskMgr" "$LOG" 2>/dev/null | tail -20
done

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
