#!/bin/bash
# Simple fix: check common.ini, restart MT5 cleanly, wait
echo "=== SIMPLE FIX $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- 1. Current common.ini ---"
cat "$MT5/config/common.ini" 2>/dev/null | tr -d '\0'

echo ""
echo "--- 2. Current MT5 status ---"
pgrep -a terminal64 || echo "MT5 not running"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -5

echo ""
echo "--- 3. Wine DLL overrides ---"
wine reg query "HKCU\\Software\\Wine\\DllOverrides" 2>/dev/null

echo ""
echo "--- 4. settings.ini ---"
cat "$MT5/config/settings.ini" 2>/dev/null | tr -d '\0' | head -40

echo ""
echo "--- 5. Kill MT5 gently ---"
pkill -f terminal64.exe 2>/dev/null
sleep 5
wineserver -k 2>/dev/null
sleep 5

echo ""
echo "--- 6. Start MT5 with Wine debug ---"
cd "$MT5"
WINEDEBUG=+winsock timeout 90 wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/wine_debug.log 2>&1 &
sleep 90

echo "MT5 running: $(pgrep -f terminal64.exe > /dev/null 2>&1 && echo YES || echo NO)"

echo ""
echo "--- 7. Terminal log ---"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -20

echo ""
echo "--- 8. Wine debug (network related) ---"
grep -iE "socket|connect|error|fail|refused|ECONN|winsock" /tmp/wine_debug.log 2>/dev/null | tail -30

echo ""
echo "--- 9. Connections ---"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -10

echo "=== DONE ==="
