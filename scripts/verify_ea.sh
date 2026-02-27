#!/bin/bash
# Full bot status check
echo "=========================================="
echo "  BOT STATUS CHECK - $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "=========================================="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo ""
echo "--- MT5 Process ---"
if ps aux | grep terminal64 | grep -v grep; then
    echo "STATUS: MT5 is RUNNING"
else
    echo "STATUS: MT5 is NOT RUNNING!"
fi

echo ""
echo "--- Wine Version ---"
wine --version 2>/dev/null || echo "Wine not found"

echo ""
echo "--- VNC Status ---"
ps aux | grep x11vnc | grep -v grep && echo "VNC: RUNNING" || echo "VNC: NOT RUNNING"
ps aux | grep Xvfb | grep -v grep && echo "Xvfb: RUNNING" || echo "Xvfb: NOT RUNNING"

echo ""
echo "--- Network Connections (MT5) ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- EA Files ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/" 2>/dev/null || echo "EA folder not found"

echo ""
echo "--- Config Files ---"
ls -la "$MT5/MQL5/Files/PropFirmBot/" 2>/dev/null || echo "Config folder not found"

echo ""
echo "--- Terminal Log (latest entries) ---"
LATEST_TERM=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    echo "File: $LATEST_TERM ($(stat -c%s "$LATEST_TERM") bytes)"
    cat "$LATEST_TERM" | tr -d '\0' | tail -40
else
    echo "No terminal logs found"
fi

echo ""
echo "--- EA Log (latest entries) ---"
LATEST_EA=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA" ]; then
    echo "File: $LATEST_EA ($(stat -c%s "$LATEST_EA") bytes)"
    cat "$LATEST_EA" | tr -d '\0' | tail -40
else
    echo "No EA logs found"
    echo "All EA log files:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
fi

echo ""
echo "--- Disk Space ---"
df -h / | tail -1

echo ""
echo "--- Memory ---"
free -h | head -2

echo ""
echo "--- Uptime ---"
uptime

echo ""
echo "=========================================="
echo "  CHECK COMPLETE"
echo "=========================================="
