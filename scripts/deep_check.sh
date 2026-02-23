#!/bin/bash
# Deep check v2 - properly handle spaces in paths
echo "=== DEEP CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- 1. MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- 2. EA Log (MQL5/Logs) ---"
ls -la "$MT5/MQL5/Logs/" 2>&1
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "TODAY EA LOG EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0'
else
    echo "No EA log for today (EA may not be attached to chart)"
fi

echo ""
echo "--- 3. Terminal Log TODAY (logs/) ---"
ls -la "$MT5/logs/" 2>&1
echo ""
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -80
else
    echo "No terminal log for today"
fi

echo ""
echo "--- 4. Terminal Log YESTERDAY ---"
if [ -f "$MT5/logs/20260222.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260222.log") bytes"
    cat "$MT5/logs/20260222.log" | tr -d '\0' | tail -20
fi

echo ""
echo "--- 5. Config files ---"
echo "PropFirmBot files:"
ls -la "$MT5/MQL5/Files/PropFirmBot/" 2>&1
echo ""
echo "CSV files:"
find "$MT5/MQL5/Files/" -name "*.csv" -type f 2>/dev/null || echo "None"
echo ""
echo "Chart profiles:"
ls "$MT5/MQL5/Profiles/Charts/" 2>/dev/null || echo "None"

echo ""
echo "--- 6. Wine log (key lines) ---"
if [ -f /tmp/mt5_wine.log ]; then
    echo "Size: $(stat -c%s /tmp/mt5_wine.log) bytes"
    head -20 /tmp/mt5_wine.log | grep -v "^$"
fi

echo ""
echo "--- 7. Telegram ---"
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔍 Deep Check $(date '+%H:%M UTC') - MT5 $(pgrep -f terminal64 > /dev/null 2>&1 && echo RUNNING || echo DOWN)" > /dev/null 2>&1
echo "Sent"

echo ""
echo "=== DONE ==="
