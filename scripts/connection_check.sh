#!/bin/bash
# Check full terminal log + terminal.ini for login status
echo "=== CONNECTION CHECK $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- 1. FULL Terminal Log Today ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    echo "Modified: $(stat -c%y "$MT5/logs/20260223.log")"
    echo ""
    cat "$MT5/logs/20260223.log" | tr -d '\0'
else
    echo "No terminal log today"
fi

echo ""
echo "--- 2. Network/Auth lines in terminal log ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    cat "$MT5/logs/20260223.log" | tr -d '\0' | grep -i "network\|auth\|login\|connect\|account\|invalid\|server\|failed"
else
    echo "No log"
fi

echo ""
echo "--- 3. terminal.ini (login/connection config) ---"
cat "$MT5/config/terminal.ini" | tr -d '\0' 2>/dev/null | head -80

echo ""
echo "--- 4. MT5 Process status ---"
ps aux | grep terminal64 | grep -v grep || echo "NOT RUNNING"

echo ""
echo "--- 5. Check if it's weekend (market closed) ---"
echo "Day: $(date +%A)"
echo "UTC time: $(date '+%H:%M %Z')"
echo "Note: Forex market closed Friday 22:00 UTC to Sunday 22:00 UTC"

echo ""
echo "--- 6. Try restart MT5 without /portable ---"
# Stop current MT5
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 2

# Start WITHOUT portable - use saved configs
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine2.log 2>&1 &
disown
echo "MT5 started without /portable"

sleep 20

# Check new logs
echo ""
echo "--- 7. Post-restart terminal log ---"
if [ -f "$MT5/logs/20260223.log" ]; then
    echo "Size: $(stat -c%s "$MT5/logs/20260223.log") bytes"
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -30
fi

echo ""
echo "--- 8. Post-restart EA log ---"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EA LOG EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -30
else
    echo "Still no EA log"
fi

echo ""
echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
echo "=== DONE ==="
