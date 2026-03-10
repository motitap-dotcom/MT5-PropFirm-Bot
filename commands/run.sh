#!/bin/bash
# Verify EA is active after restart
echo "=== EA VERIFICATION $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 process
echo "[1] MT5 Process:"
pgrep -af terminal64 2>/dev/null || echo "NOT RUNNING!"

# 2. Today's EA log - check for recent activity
echo ""
echo "[2] EA Log (last 20 lines):"
LOG_FILE="$MT5_DIR/MQL5/Logs/$(date '+%Y%m%d').log"
if [ -f "$LOG_FILE" ]; then
    tail -20 "$LOG_FILE" | strings | sed 's/\x00//g'
else
    echo "No log for today"
fi

# 3. Terminal log
echo ""
echo "[3] MT5 Terminal Journal (last 10 lines):"
TERM_LOG_DIR="$MT5_DIR/logs"
LATEST_TERM=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "File: $LATEST_TERM"
    tail -10 "$LATEST_TERM" | strings | sed 's/\x00//g'
fi

# 4. Status JSON
echo ""
echo "[4] Bot Status:"
STATUS_FILE="$MT5_DIR/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
else
    echo "No status file"
fi

# 5. Check /var/bots/mt5_status.json
echo ""
echo "[5] Monitor Status:"
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "No monitor status"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
