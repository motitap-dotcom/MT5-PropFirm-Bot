#!/bin/bash
# Final verification - EA v3.01 running
echo "=== FINAL CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] MT5 Process:"
pgrep -af terminal64 2>/dev/null || echo "NOT RUNNING"

echo ""
echo "[2] Compiled EA:"
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "[3] Bot Status:"
cat "$MT5_DIR/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "No status yet"

echo ""
echo "[4] EA Log (last 20 lines):"
LOG_FILE="$MT5_DIR/MQL5/Logs/$(date '+%Y%m%d').log"
if [ -f "$LOG_FILE" ]; then
    tail -20 "$LOG_FILE" | strings | sed 's/\x00//g'
else
    echo "No log file"
fi

echo ""
echo "=== DONE ==="
