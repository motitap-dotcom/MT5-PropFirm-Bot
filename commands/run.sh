#!/bin/bash
# Quick status check after manual compile
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "=== MT5 Processes ==="
ps aux | grep -i "terminal64" | grep -v grep

echo ""
echo "=== EA .ex5 file ==="
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "=== Last 40 EA log lines ==="
LOG_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log"
tail -40 "$LOG_FILE" 2>/dev/null

echo ""
echo "=== AutoTrading config ==="
grep -i "autotrad\|ExpertsEnabled\|AllowLive" "/root/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini" 2>/dev/null

echo ""
echo "=== status.json ==="
cat "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null

echo ""
echo "DONE $(date)"
