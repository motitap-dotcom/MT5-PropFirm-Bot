#!/bin/bash
# Check if bot is actively trading or still blocked
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

echo ""
echo "=== MT5 Process ==="
ps aux | grep "terminal64.exe" | grep -v grep

echo ""
echo "=== FULL EA Log (last 60 lines) ==="
tail -60 "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log" 2>/dev/null

echo ""
echo "=== Any 'auto trading disabled' errors? ==="
grep -c "auto trading disabled\|10027" "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log" 2>/dev/null || echo "0"

echo ""
echo "=== Any trades opened? ==="
grep -i "order\|deal\|position\|opened\|filled\|BUY\|SELL" "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log" 2>/dev/null | tail -20

echo ""
echo "=== Terminal Log (connection/trade status) ==="
TERM_LOG=$(ls -t "/root/.wine/drive_c/Program Files/MetaTrader 5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    tail -30 "$TERM_LOG"
fi

echo ""
echo "=== Account trade permissions ==="
grep -i "trade\|expert\|auto" "/root/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini" 2>/dev/null

echo ""
echo "DONE $(date)"
