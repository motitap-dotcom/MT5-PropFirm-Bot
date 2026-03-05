#!/bin/bash
# Quick check - is MT5 running with new EA?
echo "=== QUICK CHECK $(date) ==="
pgrep -a wine 2>/dev/null | head -5
echo ""
LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST=$(ls -t "$LOG"/*.log 2>/dev/null | head -1)
echo "Log: $(basename "$LATEST")"
tail -15 "$LATEST" 2>/dev/null
echo ""
echo "EX5: $(ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null)"
echo "=== DONE ==="
