#!/bin/bash
# Post-restart verification - triggered 2026-03-17 after EA code update
echo "=== POST-RESTART CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
TERM_LOG_DIR="${MT5_BASE}/logs"

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

# 3. Account state config
echo ""
echo "--- account_state.json ---"
if [ -f "$EA_FILES_DIR/account_state.json" ]; then
    cat "$EA_FILES_DIR/account_state.json" 2>&1
else
    echo "account_state.json not found"
fi

# 4. Latest EA log (last 50 lines)
echo ""
echo "--- Latest EA Log (last 50 lines) ---"
TODAY_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TODAY_LOG" ]; then
    echo "Log file: $TODAY_LOG"
    tail -50 "$TODAY_LOG" 2>&1
else
    echo "No EA log files found"
fi

# 5. Open positions / recent trades
echo ""
echo "--- Recent Trade Entries ---"
if [ -n "$TODAY_LOG" ]; then
    grep -i -E "order|trade|buy|sell|position|open|close|profit|loss" "$TODAY_LOG" 2>/dev/null | tail -20 || echo "No trade entries"
fi

# 6. Guardian state
echo ""
echo "--- Guardian Entries ---"
if [ -n "$TODAY_LOG" ]; then
    grep -i -E "guardian|drawdown|DD|safety|halt|emergency|shutdown" "$TODAY_LOG" 2>/dev/null | tail -10 || echo "No guardian entries"
fi

# 7. Trade journal
echo ""
echo "--- Recent Trade Journal ---"
find "$EA_FILES_DIR" -name "*Journal*" -mtime -7 -exec echo "File: {}" \; -exec tail -10 {} \; 2>/dev/null || echo "No journal files"

# 8. Disk & Wine
echo ""
echo "--- System ---"
df -h / | tail -1
echo "Wine processes: $(pgrep -c -f wine 2>/dev/null || echo 0)"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
