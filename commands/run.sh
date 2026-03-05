#!/bin/bash
# Restart MT5 with new EA
echo "=== RESTART MT5 $(date) ==="

export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Kill MT5
pkill -f terminal64 2>/dev/null
sleep 4

# Start MT5
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
wine64 terminal64.exe /portable &
sleep 12

# Check
echo "Wine processes:"
pgrep -a wine 2>/dev/null | head -5
echo ""

# Check latest log
LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
echo "Latest log: $(basename "$LATEST" 2>/dev/null)"
tail -10 "$LATEST" 2>/dev/null

echo ""
echo "=== DONE $(date) ==="
