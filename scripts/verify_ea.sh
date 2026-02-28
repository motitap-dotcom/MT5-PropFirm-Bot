#!/bin/bash
# Verify EA is running and trading
TODAY=$(date '+%Y%m%d')
echo "=== VPS STATUS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 NOT RUNNING!"

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Terminal Log (today) ---"
TLOG="$MT5/logs/${TODAY}.log"
if [ -f "$TLOG" ]; then
    echo "Size: $(stat -c%s "$TLOG") bytes"
    cat "$TLOG" | tr -d '\0' | tail -30
else
    echo "No terminal log for today ($TODAY)"
    echo "Latest terminal logs:"
    ls -lt "$MT5/logs/"*.log 2>/dev/null | head -3
fi

echo ""
echo "--- EA Log (today) ---"
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EALOG" ]; then
    echo "EA LOG EXISTS! Size: $(stat -c%s "$EALOG") bytes"
    cat "$EALOG" | tr -d '\0' | tail -30
else
    echo "No EA log for today ($TODAY)"
    echo "Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi

echo ""
echo "--- EA Compiled File ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null || echo "EA .ex5 NOT FOUND!"

echo ""
echo "--- Disk Space ---"
df -h / | tail -1

echo ""
echo "--- Uptime ---"
uptime

echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null

echo ""
echo "=== CHECK COMPLETE ==="
