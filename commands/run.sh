#!/bin/bash
# Full bot status check
echo "=== BOT STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

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
    echo ""
    echo "File age: $(stat -c '%y' "$EA_FILES_DIR/status.json" 2>/dev/null)"
else
    echo "status.json not found"
fi

# 3. Account info from latest EA log
echo ""
echo "--- Latest EA Log (last 50 lines) ---"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log: $LATEST_LOG"
    tail -50 "$LATEST_LOG" 2>&1
else
    echo "No EA logs found"
fi

# 4. Open positions / recent trades
echo ""
echo "--- Trade activity (last entries) ---"
if [ -n "$LATEST_LOG" ]; then
    grep -i -E "order|trade|buy|sell|position|open|close|profit|loss|guardian" "$LATEST_LOG" 2>/dev/null | tail -20
fi

# 5. Guardian state
echo ""
echo "--- Guardian entries ---"
if [ -n "$LATEST_LOG" ]; then
    grep -i -E "guardian|drawdown|safety|halt|emergency|shutdown|caution" "$LATEST_LOG" 2>/dev/null | tail -10
fi

# 6. Disk & system
echo ""
echo "--- System ---"
df -h / | tail -1
free -h | head -2

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
