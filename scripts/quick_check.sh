#!/bin/bash
# Quick status check after Wine upgrade
echo "=== QUICK CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "Wine: $(wine --version 2>/dev/null || echo NOT_FOUND)"
echo "Wine64: $(wine64 --version 2>/dev/null || echo NOT_FOUND)"
echo ""
echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
ps aux | grep terminal64 | grep -v grep
echo ""
echo "Outbound TCP (non-SSH/VNC):"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10
echo ""
echo "Terminal log (last 15):"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -15
fi
echo ""
echo "EA log:"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "YES!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -15
else
    echo "No"
fi
echo ""
echo "Wine packages:"
dpkg -l 2>/dev/null | grep wine | awk '{print $2, $3}' | head -10
echo "=== DONE ==="
