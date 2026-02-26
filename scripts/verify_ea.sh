#!/bin/bash
# Verify EA is running and trading
echo "=== VERIFY $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date -u '+%Y%m%d')

echo "--- Wine Version ---"
wine --version 2>/dev/null

echo ""
echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- VNC Process ---"
ps aux | grep x11vnc | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- PropFirmBot.ex5 ---"
find "$MT5" -name "PropFirmBot.ex5" 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- EA files in Experts ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/"*.ex5 2>/dev/null || echo "No .ex5 in PropFirmBot/"
ls -la "$MT5/MQL5/Experts/"PropFirmBot.ex5 2>/dev/null || echo "No .ex5 in Experts/"

echo ""
echo "--- Outbound Connections ---"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "--- Terminal Log (latest) ---"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $TLOG ($(stat -c%s "$TLOG") bytes)"
    cat "$TLOG" | tr -d '\0' | tail -25
fi

echo ""
echo "--- EA Log (latest) ---"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "File: $EALOG ($(stat -c%s "$EALOG") bytes)"
    cat "$EALOG" | tr -d '\0' | tail -30
else
    echo "No EA logs found"
fi

echo ""
echo "--- status.json ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null | head -20 || echo "No status.json"

echo ""
echo "--- Account State ---"
cat "$MT5/MQL5/Files/PropFirmBot/account_state.json" 2>/dev/null | head -10 || echo "No account_state.json"

echo ""
echo "=== DONE ==="
