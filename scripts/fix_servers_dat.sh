#!/bin/bash
# Fix corrupt servers.dat - delete and let MT5 re-download
echo "=== FIX SERVERS.DAT $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- 1. Kill MT5 ---"
pkill -f terminal64.exe 2>/dev/null; sleep 3
wineserver -k 2>/dev/null; sleep 3

echo ""
echo "--- 2. Backup and remove servers.dat files ---"
mkdir -p /tmp/mt5_backup
echo "config/servers.dat: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null) bytes"
echo "Config/servers.dat: $(stat -c%s "$MT5/Config/servers.dat" 2>/dev/null) bytes"

cp "$MT5/config/servers.dat" /tmp/mt5_backup/servers_lower.dat 2>/dev/null
cp "$MT5/Config/servers.dat" /tmp/mt5_backup/servers_upper.dat 2>/dev/null

# Try using Config/servers.dat (bigger, possibly older/uncorrupted) instead of config/servers.dat
echo ""
echo "Approach A: Copy Config/servers.dat -> config/servers.dat (bigger version)"
cp "$MT5/Config/servers.dat" "$MT5/config/servers.dat" 2>/dev/null
echo "config/servers.dat now: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null) bytes"

echo ""
echo "--- 3. Also copy accounts.dat if different ---"
cp "$MT5/Config/accounts.dat" "$MT5/config/accounts.dat" 2>/dev/null
echo "accounts.dat: $(stat -c%s "$MT5/config/accounts.dat" 2>/dev/null) bytes"

echo ""
echo "--- 4. Start MT5 with approach A ---"
cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server </dev/null >/dev/null 2>&1 &
disown -a
echo "MT5 started, waiting 120s for connection..."
sleep 120

echo ""
echo "--- 5. Check approach A ---"
CONN=$(ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -5)
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
AUTH=""
[ -n "$TLOG" ] && AUTH=$(cat "$TLOG" | tr -d '\0' | grep -i "authoriz\|Network" | tail -5)

echo "Connections: $CONN"
echo "Auth messages: $AUTH"
echo "Terminal log:"
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -10

if [ -n "$AUTH" ]; then
    echo ""
    echo "*** APPROACH A WORKED! ***"
else
    echo ""
    echo "Approach A failed. Trying approach B..."

    echo ""
    echo "--- 6. Kill MT5, delete servers.dat entirely ---"
    pkill -f terminal64.exe 2>/dev/null; sleep 3
    wineserver -k 2>/dev/null; sleep 3

    rm -f "$MT5/config/servers.dat"
    rm -f "$MT5/Config/servers.dat"
    echo "Deleted both servers.dat files"

    echo ""
    echo "--- 7. Start MT5 fresh (should re-download server list) ---"
    cd "$MT5"
    nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server </dev/null >/dev/null 2>&1 &
    disown -a
    echo "MT5 started, waiting 120s..."
    sleep 120

    echo ""
    echo "--- 8. Check approach B ---"
    echo "servers.dat recreated: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null || echo NO) bytes"
    echo "Connections:"
    ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -5
    echo "Terminal log:"
    TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
    [ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -15
    echo "Auth:"
    [ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | grep -i "authoriz\|Network" | tail -5

    echo ""
    echo "EA log:"
    TODAY=$(date '+%Y%m%d')
    EALOG="$MT5/MQL5/Logs/${TODAY}.log"
    [ -f "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -15 || echo "No EA log"
fi

echo ""
echo "--- 9. Final status ---"
echo "MT5: $(pgrep -f terminal64.exe > /dev/null 2>&1 && echo RUNNING || echo NOT_RUNNING)"
echo "servers.dat: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null || echo MISSING)"
echo "config/servers/ files: $(find "$MT5/config/servers" -type f 2>/dev/null | wc -l)"

echo "=== DONE ==="
