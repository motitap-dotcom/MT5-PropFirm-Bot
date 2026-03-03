#!/bin/bash
# Verify EA is running and trading - uses dynamic dates
echo "=== VERIFY $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date -u '+%Y%m%d')

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 NOT RUNNING!"

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Terminal Log (latest) ---"
TERM_LOG=$(find "$MT5/logs/" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
if [ -n "$TERM_LOG" ]; then
    echo "File: $(basename "$TERM_LOG") | Size: $(stat -c%s "$TERM_LOG") bytes"
    cat "$TERM_LOG" | tr -d '\0' | tail -25
else
    echo "No terminal logs found"
fi

echo ""
echo "--- EA Log (latest) ---"
EA_LOG=$(find "$MT5/MQL5/Logs/" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
if [ -n "$EA_LOG" ]; then
    echo "File: $(basename "$EA_LOG") | Size: $(stat -c%s "$EA_LOG") bytes"
    cat "$EA_LOG" | tr -d '\0' | tail -30
else
    echo "No EA logs found"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -3
fi

echo ""
echo "--- Account Status ---"
if [ -f "$MT5/MQL5/Files/PropFirmBot/status.json" ]; then
    cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null
else
    echo "No status.json found"
fi

echo ""
echo "--- Disk & Memory ---"
df -h / | tail -1
free -h | head -2

echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null

echo ""
echo "--- Uptime ---"
uptime

echo ""
echo "=== DONE ==="
