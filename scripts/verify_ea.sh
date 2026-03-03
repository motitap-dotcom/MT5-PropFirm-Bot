#!/bin/bash
# Verify EA is running and trading
TODAY=$(date '+%Y%m%d')
echo "=== VPS CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- MT5 Process ---"
if ps aux | grep -q "[t]erminal64"; then
    echo "MT5 is RUNNING ✅"
    ps aux | grep "[t]erminal64" | awk '{print "PID:"$2, "CPU:"$3"%", "MEM:"$4"%", "START:"$9}'
else
    echo "MT5 is NOT RUNNING ❌"
fi

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Terminal Log (today) ---"
TLOG="$MT5/logs/${TODAY}.log"
if [ -f "$TLOG" ]; then
    echo "Size: $(stat -c%s "$TLOG") bytes"
    cat "$TLOG" | tr -d '\0' | tail -25
else
    echo "No terminal log for today"
    echo "Latest terminal log:"
    ls -lt "$MT5/logs/"*.log 2>/dev/null | head -3
fi

echo ""
echo "--- EA Log (today) ---"
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EALOG" ]; then
    echo "EA LOG EXISTS ✅ Size: $(stat -c%s "$EALOG") bytes"
    cat "$EALOG" | tr -d '\0' | tail -30
else
    echo "No EA log for today"
    echo "Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -3
fi

echo ""
echo "--- Disk & Memory ---"
df -h / | tail -1 | awk '{print "Disk: "$3" used / "$2" total ("$5" used)"}'
free -h | grep Mem | awk '{print "RAM: "$3" used / "$2" total"}'

echo ""
echo "--- Uptime ---"
uptime

echo ""
echo "=== DONE ==="
