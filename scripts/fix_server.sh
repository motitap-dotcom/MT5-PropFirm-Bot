#!/bin/bash
# Fix FundedNext server connection - extract IPs and restart MT5
echo "=== FIX SERVER CONNECTION $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo ""
echo "--- 1. Extract IPs from servers.dat ---"
if [ -f "$MT5/config/servers.dat" ]; then
    echo "servers.dat found ($(stat -c%s "$MT5/config/servers.dat") bytes)"
    echo "Strings containing IPs:"
    strings "$MT5/config/servers.dat" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u
    echo "Strings containing FundedNext:"
    strings "$MT5/config/servers.dat" | grep -i "funded\|server\|next" | head -20
    echo "Strings containing access/port:"
    strings "$MT5/config/servers.dat" | grep -iE "access|:443|:1950|:1951" | head -20
fi

echo ""
echo "--- 2. Extract IPs from downloaded FN installer ---"
if [ -f "/tmp/fn_mt5_setup.exe" ]; then
    echo "Installer found ($(stat -c%s /tmp/fn_mt5_setup.exe) bytes)"
    echo "IPs in installer:"
    strings /tmp/fn_mt5_setup.exe | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u
    echo "Server strings:"
    strings /tmp/fn_mt5_setup.exe | grep -i "funded\|server\|access" | sort -u | head -20
else
    echo "Installer not found, downloading..."
    curl -L -o /tmp/fn_mt5_setup.exe "https://download.mql5.com/cdn/web/fundednext.ltd/mt5/fundednext5setup.exe" 2>/dev/null
    echo "Downloaded: $(stat -c%s /tmp/fn_mt5_setup.exe 2>/dev/null) bytes"
    echo "IPs:"
    strings /tmp/fn_mt5_setup.exe | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u
    echo "Server strings:"
    strings /tmp/fn_mt5_setup.exe | grep -i "funded\|server\|access" | sort -u | head -20
fi

echo ""
echo "--- 3. Check Config/servers.dat (uppercase C) ---"
if [ -f "$MT5/Config/servers.dat" ]; then
    echo "Config/servers.dat found ($(stat -c%s "$MT5/Config/servers.dat") bytes)"
    echo "IPs:"
    strings "$MT5/Config/servers.dat" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u
fi

echo ""
echo "--- 4. Check accounts.dat ---"
if [ -f "$MT5/Config/accounts.dat" ]; then
    echo "accounts.dat found ($(stat -c%s "$MT5/Config/accounts.dat") bytes)"
    echo "Content:"
    strings "$MT5/Config/accounts.dat" | head -20
fi

echo ""
echo "--- 5. Test connectivity to all found IPs ---"
# Collect all unique IPs
ALL_IPS=$(
    strings "$MT5/config/servers.dat" 2>/dev/null;
    strings "$MT5/Config/servers.dat" 2>/dev/null;
    strings /tmp/fn_mt5_setup.exe 2>/dev/null
) | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u

echo "Testing all unique IPs for MT5 broker ports (443, 443):"
for IP in $ALL_IPS; do
    # Skip private IPs and common non-broker IPs
    case "$IP" in
        127.*|10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|0.0.0.0|255.*) continue ;;
    esac
    RESULT=""
    for PORT in 443 1950 1951 1952 1953; do
        timeout 2 bash -c "echo > /dev/tcp/$IP/$PORT" 2>/dev/null && RESULT="${RESULT}${PORT}:OK " || true
    done
    [ -n "$RESULT" ] && echo "  $IP -> $RESULT"
done

echo ""
echo "--- 6. Full terminal.ini check ---"
if [ -f "$MT5/config/terminal.ini" ]; then
    echo "terminal.ini ($(stat -c%s "$MT5/config/terminal.ini") bytes)"
    grep -iE "server|login|proxy|network|connect" "$MT5/config/terminal.ini" | head -20
fi

echo ""
echo "--- 7. Kill MT5, install from FundedNext setup, restart ---"
echo "Killing MT5..."
pkill -f terminal64.exe 2>/dev/null
sleep 2
wineserver -k 2>/dev/null
sleep 3

if [ -f "/tmp/fn_mt5_setup.exe" ]; then
    echo "Running FundedNext MT5 installer (silent)..."
    # Try to install - this should update server configs
    cd /tmp
    timeout 120 wine fn_mt5_setup.exe /auto 2>/dev/null &
    INST_PID=$!
    echo "Installer PID: $INST_PID"

    # Wait for installer but not too long
    sleep 60

    # Kill installer if still running
    kill $INST_PID 2>/dev/null
    pkill -f fn_mt5_setup 2>/dev/null
    sleep 5

    echo "Checking if server config was updated..."
    echo "config/servers/ contents:"
    ls -la "$MT5/config/servers/" 2>/dev/null || echo "  empty/missing"
    echo "servers.dat size: $(stat -c%s "$MT5/config/servers.dat" 2>/dev/null)"
    echo "New files:"
    find "$MT5/config" -newer /tmp/fn_mt5_setup.exe -type f 2>/dev/null
fi

echo ""
echo "--- 8. Start MT5 with login params ---"
# Kill any remaining Wine processes
wineserver -k 2>/dev/null; sleep 2
pkill -9 -f wine 2>/dev/null; sleep 2

echo "Starting MT5..."
cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server </dev/null >/dev/null 2>&1 &
disown -a
echo "MT5 started, waiting 60s for connection..."
sleep 60

echo ""
echo "--- 9. Check if MT5 connected ---"
PID=$(pgrep -f terminal64.exe 2>/dev/null | head -1)
echo "MT5 PID: $PID"

echo "Terminal log (last 15 lines):"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -15

echo ""
echo "EA log:"
TODAY=$(date '+%Y%m%d')
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
[ -f "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -15 || echo "No EA log"

echo ""
echo "Outbound connections:"
ss -tn state established | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "=== DONE ==="
