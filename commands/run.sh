#!/bin/bash
# Full status check
echo "=== BOT STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_LOG_DIR="${MT5_BASE}/MQL5/Logs"
EA_FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
TERM_LOG_DIR="${MT5_BASE}/logs"

# 1. MT5 process
echo "--- MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    UPTIME=$(ps -p "$MT5_PID" -o etime= 2>/dev/null)
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

# 5. Open positions / trades
echo ""
echo "--- Trade entries (last 30) ---"
if [ -n "$TODAY_LOG" ]; then
    grep -i -E "order|trade|buy|sell|position|deal|open|close|profit|loss" "$TODAY_LOG" 2>/dev/null | tail -30 || echo "No trade entries"
fi

# 6. Terminal log (last 30 lines)
echo ""
echo "--- Terminal Log (last 30 lines) ---"
TERM_LATEST=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$TERM_LATEST" ]; then
    echo "Terminal log: $TERM_LATEST"
    tail -30 "$TERM_LATEST" 2>&1
fi

# 7. Disk & memory
echo ""
echo "--- System Resources ---"
df -h / | tail -1
free -h | head -2

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
