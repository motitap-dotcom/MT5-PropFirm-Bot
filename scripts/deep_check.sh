#!/bin/bash
# Deep check after MT5 restart
echo "=== DEEP CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- MT5 Process ---"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- ALL Log files ---"
ls -la "$MT5/MQL5/Logs/" 2>&1

echo ""
echo "--- Today's log (20260223) ---"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EXISTS! Size: $(stat -c%s "$MT5/MQL5/Logs/20260223.log") bytes"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0'
else
    echo "NOT FOUND YET"
fi

echo ""
echo "--- Wine output log ---"
if [ -f /tmp/mt5_wine.log ]; then
    echo "Size: $(stat -c%s /tmp/mt5_wine.log) bytes"
    tail -50 /tmp/mt5_wine.log
else
    echo "No Wine log"
fi

echo ""
echo "--- MT5 Terminal logs (not EA) ---"
for f in $(ls -t "$MT5/logs/"*.log 2>/dev/null | head -3); do
    echo "==> $f ($(stat -c%s "$f") bytes)"
    cat "$f" | tr -d '\0' | tail -30
    echo ""
done

echo ""
echo "--- MT5 config ---"
cat "$MT5/config/common.ini" 2>/dev/null || echo "No config"

echo ""
echo "--- Connection check (WebRequest test) ---"
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔍 Deep Check $(date '+%H:%M UTC')
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo 'RUNNING' || echo 'DOWN')
New Log: $([ -f '$MT5/MQL5/Logs/20260223.log' ] && echo 'YES' || echo 'NO')" > /dev/null 2>&1

echo ""
echo "--- Delayed check result (if exists) ---"
# Check if the delayed Telegram was sent
echo "delayed_check.sh ran: $([ -f /tmp/delayed_check.sh ] && echo 'YES' || echo 'NO')"

echo ""
echo "=== DEEP CHECK DONE ==="
