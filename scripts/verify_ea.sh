#!/bin/bash
# Verify EA is running and trading after manual connection
echo "=== VERIFY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Terminal Log (latest) ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -25
fi

echo ""
echo "--- EA Log Today ---"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EA LOG EXISTS! Size: $(stat -c%s "$MT5/MQL5/Logs/20260223.log") bytes"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -30
else
    echo "No EA log for today"
    echo "Latest EA log:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -3
fi

echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null

echo ""
echo "=== DONE ==="
